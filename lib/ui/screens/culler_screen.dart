import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/culler_provider.dart';
import '../../services/saf_service.dart';
import '../../services/update_service.dart';
import '../widgets/hud_overlay.dart';
import '../widgets/info_dialog.dart';
import '../widgets/update_dialog.dart';

class CullerScreen extends ConsumerStatefulWidget {
  const CullerScreen({super.key});

  @override
  ConsumerState<CullerScreen> createState() => _CullerScreenState();
}

class _CullerScreenState extends ConsumerState<CullerScreen> {
  final FocusNode _focusNode = FocusNode();
  final TransformationController _transformationController = TransformationController();
  double _currentScale = 1.0;
  double _dragDistance = 0.0;

  @override
  void initState() {
    super.initState();
    _transformationController.addListener(_onTransformationChanged);
    _checkForAppUpdate();
  }

  Future<void> _checkForAppUpdate() async {
    final updateInfo = await UpdateService.checkForUpdates();
    if (updateInfo != null && mounted) {
      UpdateDialog.show(context, updateInfo);
    }
  }

  void _onTransformationChanged() {
    final scale = _transformationController.value.getMaxScaleOnAxis();
    if ((scale - _currentScale).abs() > 0.05) {
      setState(() {
        _currentScale = scale;
      });
    }
  }

  @override
  void dispose() {
    _transformationController.removeListener(_onTransformationChanged);
    _transformationController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _resetZoom() {
    _transformationController.value = Matrix4.identity();
    setState(() {
      _currentScale = 1.0;
    });
  }

  void _toggleZoom() {
    if (_currentScale > 1.05) {
      _resetZoom();
    } else {
      _transformationController.value = Matrix4.diagonal3Values(2.5, 2.5, 1.0);
      setState(() {
        _currentScale = 2.5;
      });
    }
  }

  Future<void> _pickSourceFolder() async {
    String? selectedDir;

    // Su Android usiamo il selettore SAF nativo per supporto totale a schede SD e USB OTG
    if (!kIsWeb && Platform.isAndroid) {
      selectedDir = await SafService.pickDirectoryUri();
    } else {
      selectedDir = await FilePicker.platform.getDirectoryPath(
        dialogTitle: 'Seleziona cartella contenente i file RAW (.RAF, .DNG, ecc.)',
      );
    }

    if (selectedDir != null && mounted) {
      await ref.read(cullerProvider.notifier).setSourceFolder(selectedDir);
      _resetZoom();
    }
  }

  Future<void> _pickTargetFolder() async {
    String? selectedDir;

    if (!kIsWeb && Platform.isAndroid) {
      selectedDir = await SafService.pickDirectoryUri();
    } else {
      selectedDir = await FilePicker.platform.getDirectoryPath(
        dialogTitle: 'Seleziona cartella di destinazione per i RAW selezionati',
      );
    }

    if (selectedDir != null && mounted) {
      await ref.read(cullerProvider.notifier).setTargetFolder(selectedDir);
    }
  }

  KeyEventResult _handleKeyEvent(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;

    final notifier = ref.read(cullerProvider.notifier);
    final key = event.logicalKey;

    if (key == LogicalKeyboardKey.arrowRight || key == LogicalKeyboardKey.keyJ) {
      _resetZoom();
      notifier.nextPhoto();
      return KeyEventResult.handled;
    } else if (key == LogicalKeyboardKey.arrowLeft || key == LogicalKeyboardKey.keyK) {
      _resetZoom();
      notifier.prevPhoto();
      return KeyEventResult.handled;
    } else if (key == LogicalKeyboardKey.space) {
      notifier.selectCurrentPhoto();
      _resetZoom();
      return KeyEventResult.handled;
    } else if (key == LogicalKeyboardKey.delete || key == LogicalKeyboardKey.backspace) {
      _resetZoom();
      notifier.deleteCurrentPhoto();
      return KeyEventResult.handled;
    } else if (key == LogicalKeyboardKey.keyH) {
      notifier.toggleHud();
      return KeyEventResult.handled;
    } else if (key == LogicalKeyboardKey.keyZ) {
      _toggleZoom();
      return KeyEventResult.handled;
    } else if (key == LogicalKeyboardKey.keyI || key == LogicalKeyboardKey.f1) {
      InfoDialog.show(context);
      return KeyEventResult.handled;
    } else if (key == LogicalKeyboardKey.f11) {
      // Toggle fullscreen (Desktop)
      return KeyEventResult.handled;
    }

    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(cullerProvider);
    final notifier = ref.read(cullerProvider.notifier);
    final cacheManager = ref.watch(cacheManagerProvider);
    final isDesktop = !kIsWeb && (Platform.isWindows || Platform.isLinux || Platform.isMacOS);

    final currentPhoto = state.currentPhoto;
    final cachedData = cacheManager.getCached(state.currentIndex);

    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      body: Focus(
        focusNode: _focusNode,
        autofocus: true,
        onKeyEvent: _handleKeyEvent,
        child: Column(
          children: [
            // Barra superiore fissa Material 3 (ancorata in alto, mai sovrapposta all'immagine)
            if (state.isHudVisible)
              HudOverlay(
                currentPhoto: currentPhoto,
                extractedData: cachedData,
                onPickSource: _pickSourceFolder,
                onPickTarget: _pickTargetFolder,
              ),

            // Area Immagine e controlli touch (occupa tutto il resto dello schermo)
            Expanded(
              child: Stack(
                children: [
                  // Area Immagine con GestureDetector & InteractiveViewer
                  Positioned.fill(
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () {
                        _focusNode.requestFocus();
                        notifier.toggleHud();
                      },
                      onDoubleTap: _toggleZoom,
                      onHorizontalDragStart: (_currentScale <= 1.05)
                          ? (_) {
                              _dragDistance = 0.0;
                            }
                          : null,
                      onHorizontalDragUpdate: (_currentScale <= 1.05)
                          ? (details) {
                              _dragDistance += details.delta.dx;
                            }
                          : null,
                      onHorizontalDragEnd: (_currentScale <= 1.05)
                          ? (details) {
                              final velocity = details.primaryVelocity ?? 0.0;
                              // Swipe a sinistra -> foto successiva
                              if (velocity < -150 || _dragDistance < -45) {
                                _resetZoom();
                                notifier.nextPhoto();
                              }
                              // Swipe a destra -> foto precedente
                              else if (velocity > 150 || _dragDistance > 45) {
                                _resetZoom();
                                notifier.prevPhoto();
                              }
                              _dragDistance = 0.0;
                            }
                          : null,
                      child: Center(
                        child: _buildImageContent(state, cachedData),
                      ),
                    ),
                  ),

                  // Pop-up Centrale per Permessi Android (Sostituisce il vecchio MaterialBanner)
                  if (!state.hasStoragePermission && !kIsWeb && Platform.isAndroid)
                    Positioned.fill(
                      child: Container(
                        color: Colors.black54,
                        child: Center(
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 420),
                            child: Card(
                              color: const Color(0xFF242424),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                              elevation: 12,
                              child: Padding(
                                padding: const EdgeInsets.all(24.0),
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(Icons.folder_shared_rounded, color: Colors.amber, size: 48),
                                    const SizedBox(height: 16),
                                    const Text(
                                      'Accesso ai File Richiesto',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    const SizedBox(height: 12),
                                    const Text(
                                      'Per visualizzare, selezionare e copiare i file RAW (.RAF, .DNG, .ARW, ecc.) sulla memoria interna o scheda SD, RAW Manager necessita dell\'autorizzazione per la gestione di tutti i file.',
                                      textAlign: TextAlign.center,
                                      style: TextStyle(color: Colors.white70, fontSize: 13, height: 1.45),
                                    ),
                                    const SizedBox(height: 20),
                                    ElevatedButton(
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.amber,
                                        foregroundColor: Colors.black,
                                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                      ),
                                      onPressed: () => notifier.requestStoragePermission(),
                                      child: const Text('CONCEDI PERMESSO', style: TextStyle(fontWeight: FontWeight.bold)),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),

                  // Barra di controllo Touch inferiore (visibile su Mobile/Tablet o se abilitata)
                  if (state.isHudVisible)
                    Positioned(
                      bottom: 12,
                      left: 12,
                      right: 12,
                      child: SafeArea(
                        top: false,
                        child: _buildBottomBar(context, state, notifier, isDesktop),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildImageContent(CullerState state, dynamic cachedData) {
    if (state.isLoadingFolder) {
      return const Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircularProgressIndicator(color: Colors.amber),
          SizedBox(height: 16),
          Text(
            'Scansione cartella RAW in corso...',
            style: TextStyle(color: Colors.white70),
          ),
        ],
      );
    }

    if (state.photos.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 28.0),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 440),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                const Icon(Icons.photo_library_outlined, size: 72, color: Colors.white24),
                const SizedBox(height: 16),
                const Text(
                  'Nessun file RAW caricato',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.white70, fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Seleziona una cartella contenente file RAW (.RAF, .DNG, .ARW, .NEF, .CR2, ecc.) per iniziare il culling',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.white38, fontSize: 14, height: 1.4),
                ),
                if (state.statusMessage != null) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.white10,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.white24),
                    ),
                    child: Text(
                      state.statusMessage!,
                      style: TextStyle(
                        color: state.statusMessage!.toLowerCase().contains('errore')
                            ? Colors.redAccent
                            : Colors.amber,
                        fontSize: 13,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ],
                const SizedBox(height: 24),
                ElevatedButton.icon(
                  icon: const Icon(Icons.folder_open),
                  label: const Text('Apri Cartella RAW'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.amber,
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  ),
                  onPressed: _pickSourceFolder,
                ),
                const SizedBox(height: 14),
                Text(
                  'v${UpdateService.appVersion}',
                  style: const TextStyle(
                    color: Colors.white24,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    if (cachedData == null) {
      return const Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 32,
            height: 32,
            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.amber),
          ),
          SizedBox(height: 12),
          Text('Caricamento anteprima...', style: TextStyle(color: Colors.white54, fontSize: 12)),
        ],
      );
    }

    return InteractiveViewer(
      transformationController: _transformationController,
      minScale: 1.0,
      maxScale: 4.0,
      panEnabled: _currentScale > 1.05,
      scaleEnabled: true,
      clipBehavior: Clip.none,
      child: Image.memory(
        cachedData.jpegBytes,
        fit: BoxFit.contain,
        filterQuality: FilterQuality.high,
        gaplessPlayback: true,
        errorBuilder: (context, error, stackTrace) => const Center(
          child: Text(
            'Anteprima JPEG non decodificabile per questo file',
            style: TextStyle(color: Colors.redAccent, fontSize: 14),
          ),
        ),
      ),
    );
  }

  Widget _buildBottomBar(
    BuildContext context,
    CullerState state,
    CullerNotifier notifier,
    bool isDesktop,
  ) {
    return Center(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: const Color(0xDD1E1E1E),
          borderRadius: BorderRadius.circular(32),
          border: Border.all(color: Colors.white12),
          boxShadow: const [
            BoxShadow(
              color: Colors.black45,
              blurRadius: 12,
              offset: Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Previous
            IconButton(
              icon: const Icon(Icons.arrow_back_ios_new, size: 20),
              color: Colors.white70,
              tooltip: 'Precedente (Freccia Sinistra / K)',
              onPressed: state.currentIndex > 0
                  ? () {
                      _resetZoom();
                      notifier.prevPhoto();
                    }
                  : null,
            ),
            const SizedBox(width: 8),

            // Delete Button
            IconButton(
              icon: const Icon(Icons.delete_outline, color: Colors.redAccent, size: 24),
              tooltip: 'Elimina RAW (Canc)',
              onPressed: state.photos.isNotEmpty
                  ? () {
                      _resetZoom();
                      notifier.deleteCurrentPhoto();
                    }
                  : null,
            ),
            const SizedBox(width: 8),

            // Select / Copy (Big Button)
            FloatingActionButton.small(
              backgroundColor: Colors.green.shade700,
              foregroundColor: Colors.white,
              tooltip: 'Seleziona e Copia (Spazio)',
              onPressed: state.photos.isNotEmpty
                  ? () {
                      _resetZoom();
                      notifier.selectCurrentPhoto();
                    }
                  : null,
              child: const Icon(Icons.check, size: 24),
            ),
            const SizedBox(width: 8),

            // Zoom toggle
            IconButton(
              icon: Icon(
                _currentScale > 1.05 ? Icons.zoom_out : Icons.zoom_in,
                color: Colors.white70,
                size: 24,
              ),
              tooltip: 'Zoom 100% / Fit (Z)',
              onPressed: state.photos.isNotEmpty ? _toggleZoom : null,
            ),
            const SizedBox(width: 8),

            // Next
            IconButton(
              icon: const Icon(Icons.arrow_forward_ios, size: 20),
              color: Colors.white70,
              tooltip: 'Successiva (Freccia Destra / J)',
              onPressed: state.currentIndex < state.photos.length - 1
                  ? () {
                      _resetZoom();
                      notifier.nextPhoto();
                    }
                  : null,
            ),
          ],
        ),
      ),
    );
  }
}
