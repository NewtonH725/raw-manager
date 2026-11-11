import 'package:flutter/material.dart';
import '../../services/update_service.dart';

class UpdateDialog extends StatefulWidget {
  final UpdateInfo updateInfo;

  const UpdateDialog({super.key, required this.updateInfo});

  static Future<void> show(BuildContext context, UpdateInfo info) {
    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => UpdateDialog(updateInfo: info),
    );
  }

  @override
  State<UpdateDialog> createState() => _UpdateDialogState();
}

class _UpdateDialogState extends State<UpdateDialog> {
  bool _isDownloading = false;
  double _progress = 0.0;
  int _receivedBytes = 0;
  int _totalBytes = 0;
  String? _statusMessage;
  String? _errorMessage;

  String _formatMb(int bytes) {
    if (bytes <= 0) return '0.0 MB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  Future<void> _startDownloadAndInstall() async {
    setState(() {
      _isDownloading = true;
      _errorMessage = null;
      _statusMessage = 'Connessione a GitHub in corso...';
      _progress = 0.0;
    });

    try {
      final downloadedPath = await UpdateService.downloadUpdate(
        widget.updateInfo,
        (progress, received, total) {
          if (!mounted) return;
          setState(() {
            _progress = progress;
            _receivedBytes = received;
            _totalBytes = total;
            _statusMessage = 'Scaricamento in corso... ${(progress * 100).toStringAsFixed(0)}%';
          });
        },
      );

      if (!mounted) return;
      setState(() {
        _statusMessage = 'Avvio aggiornamento...';
      });

      final resultMsg = await UpdateService.applyUpdate(downloadedPath);

      if (!mounted) return;
      setState(() {
        _isDownloading = false;
        _statusMessage = resultMsg;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isDownloading = false;
        _errorMessage = 'Errore durante l\'aggiornamento: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final info = widget.updateInfo;
    final sizeStr = info.assetSize > 0 ? ' • ${_formatMb(info.assetSize)}' : '';

    return AlertDialog(
      backgroundColor: const Color(0xFF222222),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(color: Colors.amber.withValues(alpha: 0.45), width: 1),
      ),
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.amber.withValues(alpha: 0.16),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.system_update_rounded, color: Colors.amber, size: 26),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Text(
              'Nuovo Aggiornamento',
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18),
            ),
          ),
        ],
      ),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Confronto versioni
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.black26,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.white12),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'v${info.currentVersion}',
                    style: const TextStyle(color: Colors.white54, fontSize: 14, fontWeight: FontWeight.w500),
                  ),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 10),
                    child: Icon(Icons.arrow_forward_rounded, color: Colors.amber, size: 18),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                    decoration: BoxDecoration(
                      color: Colors.amber,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      'v${info.latestVersion}',
                      style: const TextStyle(color: Colors.black, fontSize: 14, fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 14),

            // Nome pacchetto per la piattaforma corrente
            Text(
              'Pacchetto: ${info.assetName}$sizeStr',
              style: const TextStyle(color: Colors.white70, fontSize: 12),
            ),

            if (info.releaseNotes.isNotEmpty) ...[
              const SizedBox(height: 12),
              Container(
                constraints: const BoxConstraints(maxHeight: 130),
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.04),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: SingleChildScrollView(
                  child: Text(
                    info.releaseNotes,
                    style: const TextStyle(color: Colors.white70, fontSize: 12, height: 1.4),
                  ),
                ),
              ),
            ],

            if (_isDownloading) ...[
              const SizedBox(height: 18),
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: LinearProgressIndicator(
                  value: _progress > 0 ? _progress : null,
                  minHeight: 8,
                  backgroundColor: Colors.white12,
                  valueColor: const AlwaysStoppedAnimation<Color>(Colors.amber),
                ),
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    _statusMessage ?? 'Scaricamento...',
                    style: const TextStyle(color: Colors.amber, fontSize: 12, fontWeight: FontWeight.w600),
                  ),
                  if (_totalBytes > 0)
                    Text(
                      '${_formatMb(_receivedBytes)} / ${_formatMb(_totalBytes)}',
                      style: const TextStyle(color: Colors.white54, fontSize: 12),
                    ),
                ],
              ),
            ] else if (_statusMessage != null && _errorMessage == null) ...[
              const SizedBox(height: 14),
              Text(
                _statusMessage!,
                style: const TextStyle(color: Colors.greenAccent, fontSize: 13, fontWeight: FontWeight.w500),
              ),
            ],

            if (_errorMessage != null) ...[
              const SizedBox(height: 14),
              Text(
                _errorMessage!,
                style: const TextStyle(color: Colors.redAccent, fontSize: 12),
              ),
            ],
          ],
        ),
      ),
      actions: [
        if (!_isDownloading)
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Più tardi', style: TextStyle(color: Colors.white60)),
          ),
        if (!_isDownloading)
          ElevatedButton.icon(
            icon: const Icon(Icons.download_rounded, size: 18),
            label: Text(
              _errorMessage != null ? 'Riprova Download' : 'Scarica e Aggiorna',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.amber,
              foregroundColor: Colors.black,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: _startDownloadAndInstall,
          ),
      ],
    );
  }
}
