import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/raf_photo.dart';
import '../../providers/culler_provider.dart';
import '../../services/raf_extractor.dart';
import 'info_dialog.dart';

class HudOverlay extends ConsumerWidget {
  final RafPhoto? currentPhoto;
  final ExtractedRafData? extractedData;
  final VoidCallback onPickSource;
  final VoidCallback onPickTarget;

  const HudOverlay({
    super.key,
    required this.currentPhoto,
    required this.extractedData,
    required this.onPickSource,
    required this.onPickTarget,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(cullerProvider);
    final notifier = ref.read(cullerProvider.notifier);
    final queue = ref.watch(fileOpsQueueProvider);

    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF1E1E1E),
        border: Border(bottom: BorderSide(color: Colors.white12, width: 1)),
        boxShadow: [
          BoxShadow(
            color: Colors.black45,
            blurRadius: 8,
            offset: Offset(0, 3),
          ),
        ],
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Riga Principale: Titolo, Badge Info, Contatori, File, Cartelle, Auto-Advance
              Wrap(
                alignment: WrapAlignment.spaceBetween,
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 12,
                runSpacing: 8,
                children: [
                  // App Title, Logo & Contatore Foto
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.camera_rounded, color: Colors.amber, size: 24),
                      const SizedBox(width: 8),
                      const Text(
                        'RAW Manager',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          letterSpacing: 0.5,
                        ),
                      ),
                      const SizedBox(width: 10),
                      // Badge Classico Informazioni
                      Tooltip(
                        message: 'Guida e Informazioni (I / F1)',
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            onTap: () => InfoDialog.show(context),
                            borderRadius: BorderRadius.circular(12),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: Colors.amber.withValues(alpha: 0.18),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: Colors.amber.withValues(alpha: 0.7), width: 1),
                              ),
                              child: const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.info, color: Colors.amber, size: 14),
                                  SizedBox(width: 4),
                                  Text(
                                    'INFO',
                                    style: TextStyle(
                                      color: Colors.amber,
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                      letterSpacing: 0.5,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      if (state.photos.isNotEmpty)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.white10,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            '${state.currentIndex + 1} / ${state.photos.length}',
                            style: const TextStyle(
                              color: Colors.white70,
                              fontWeight: FontWeight.w600,
                              fontSize: 13,
                            ),
                          ),
                        ),
                    ],
                  ),

                  // Nome File Corrente & Badge Selezionata
                  if (currentPhoto != null)
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Flexible(
                          child: Text(
                            currentPhoto!.fileName,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 10),
                        if (currentPhoto!.isCopied)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: Colors.green.shade800,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.check_circle, color: Colors.white, size: 14),
                                SizedBox(width: 4),
                                Text(
                                  'SELEZIONATA ✓',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),

                  // Cartelle Sorgente / Destinazione & Interruttore Auto-Advance
                  Wrap(
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: 8,
                    runSpacing: 4,
                    children: [
                      // Cartella Sorgente
                      OutlinedButton.icon(
                        icon: const Icon(Icons.folder_open, size: 16, color: Colors.white70),
                        label: Text(
                          state.sourcePath == null ? 'Apri Sorgente' : 'Sorgente',
                          style: const TextStyle(color: Colors.white, fontSize: 12),
                        ),
                        style: OutlinedButton.styleFrom(
                          visualDensity: VisualDensity.compact,
                          side: const BorderSide(color: Colors.white24),
                        ),
                        onPressed: onPickSource,
                      ),
                      // Cartella Destinazione
                      OutlinedButton.icon(
                        icon: const Icon(Icons.drive_file_move_outline, size: 16, color: Colors.amber),
                        label: Text(
                          state.targetPath == null ? 'Seleziona Target' : 'Target',
                          style: const TextStyle(color: Colors.amber, fontSize: 12),
                        ),
                        style: OutlinedButton.styleFrom(
                          visualDensity: VisualDensity.compact,
                          side: const BorderSide(color: Colors.amber),
                        ),
                        onPressed: onPickTarget,
                      ),

                      // Auto-Advance Switch
                      Tooltip(
                        message: 'Avanza automaticamente alla foto successiva dopo la selezione (Spazio)',
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Text(
                              'Auto-Advance',
                              style: TextStyle(color: Colors.white70, fontSize: 11),
                            ),
                            Transform.scale(
                              scale: 0.75,
                              child: Switch(
                                value: state.autoAdvance,
                                activeThumbColor: Colors.amber,
                                onChanged: (_) => notifier.toggleAutoAdvance(),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),

              // Riquadro Dati EXIF e Stato Coda I/O (mostrato subito sotto la riga comandi)
              if (currentPhoto != null) ...[
                const SizedBox(height: 6),
                Wrap(
                  spacing: 12,
                  runSpacing: 4,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    if (extractedData != null && extractedData!.exifSummary.isNotEmpty)
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.info_outline, color: Colors.white60, size: 14),
                          const SizedBox(width: 6),
                          Text(
                            extractedData!.exifSummary,
                            style: const TextStyle(color: Colors.white70, fontSize: 12),
                          ),
                        ],
                      ),
                    if (queue.pendingCount > 0 || queue.isProcessing)
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const SizedBox(
                            width: 12,
                            height: 12,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.amber),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            'Coda I/O: ${queue.pendingCount + (queue.isProcessing ? 1 : 0)} in corso',
                            style: const TextStyle(color: Colors.amber, fontSize: 12),
                          ),
                        ],
                      ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
