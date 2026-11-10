import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:permission_handler/permission_handler.dart';
import '../models/raf_photo.dart';
import '../services/file_operations_queue.dart';
import '../services/image_cache_manager.dart';
import '../services/raf_extractor.dart';
import '../services/saf_service.dart';

class CullerState {
  final String? sourcePath;
  final String? targetPath;
  final List<RafPhoto> photos;
  final int currentIndex;
  final bool autoAdvance;
  final bool isHudVisible;
  final bool hasStoragePermission;
  final bool isLoadingFolder;
  final String? statusMessage;

  const CullerState({
    this.sourcePath,
    this.targetPath,
    this.photos = const [],
    this.currentIndex = 0,
    this.autoAdvance = true,
    this.isHudVisible = true,
    this.hasStoragePermission = true,
    this.isLoadingFolder = false,
    this.statusMessage,
  });

  RafPhoto? get currentPhoto =>
      (photos.isNotEmpty && currentIndex >= 0 && currentIndex < photos.length)
          ? photos[currentIndex]
          : null;

  CullerState copyWith({
    String? sourcePath,
    String? targetPath,
    List<RafPhoto>? photos,
    int? currentIndex,
    bool? autoAdvance,
    bool? isHudVisible,
    bool? hasStoragePermission,
    bool? isLoadingFolder,
    String? statusMessage,
  }) {
    return CullerState(
      sourcePath: sourcePath ?? this.sourcePath,
      targetPath: targetPath ?? this.targetPath,
      photos: photos ?? this.photos,
      currentIndex: currentIndex ?? this.currentIndex,
      autoAdvance: autoAdvance ?? this.autoAdvance,
      isHudVisible: isHudVisible ?? this.isHudVisible,
      hasStoragePermission: hasStoragePermission ?? this.hasStoragePermission,
      isLoadingFolder: isLoadingFolder ?? this.isLoadingFolder,
      statusMessage: statusMessage ?? this.statusMessage,
    );
  }
}

class CullerNotifier extends StateNotifier<CullerState> {
  final ImageCacheManager cacheManager;
  final FileOperationsQueue queue;

  CullerNotifier({
    required this.cacheManager,
    required this.queue,
  }) : super(const CullerState()) {
    checkPermissions();
  }

  Future<void> checkPermissions() async {
    if (kIsWeb) return;
    if (Platform.isAndroid) {
      final status = await Permission.manageExternalStorage.status;
      state = state.copyWith(hasStoragePermission: status.isGranted);
    } else {
      state = state.copyWith(hasStoragePermission: true);
    }
  }

  Future<bool> requestStoragePermission() async {
    if (kIsWeb || !Platform.isAndroid) return true;

    final status = await Permission.manageExternalStorage.request();
    final isGranted = status.isGranted;
    state = state.copyWith(hasStoragePermission: isGranted);
    return isGranted;
  }

  Future<void> setSourceFolder(String dirPathOrUri) async {
    state = state.copyWith(isLoadingFolder: true, sourcePath: dirPathOrUri, statusMessage: 'Scansione in corso...');

    final List<RafPhoto> rafList = [];
    final existingTargetFiles = <String>{};

    // Scansione per Android SAF (Schede SD esterne, USB OTG, content://)
    if (dirPathOrUri.startsWith('content://')) {
      try {
        final files = await SafService.listRawFiles(dirPathOrUri);
        for (final item in files) {
          final uri = item['uri'] as String;
          final displayName = item['displayName'] as String;
          final isAlreadyCopied = existingTargetFiles.contains(displayName.toLowerCase());

          rafList.add(RafPhoto(
            path: uri,
            fileName: displayName,
            isCopied: isAlreadyCopied,
          ));
        }

        rafList.sort((a, b) => a.fileName.compareTo(b.fileName));

        state = state.copyWith(
          photos: rafList,
          currentIndex: 0,
          isLoadingFolder: false,
          statusMessage: rafList.isEmpty
              ? 'Nessun file RAW trovato nella cartella selezionata.'
              : '${rafList.length} file RAW trovati sulla scheda SD.',
        );

        _syncCache();
        return;
      } catch (e) {
        state = state.copyWith(
          isLoadingFolder: false,
          statusMessage: 'Errore accesso scheda SD: $e',
        );
        return;
      }
    }

    // Scansione Standard POSIX (Linux, Windows, Storage Interno Android)
    final dir = Directory(dirPathOrUri);
    if (!await dir.exists()) {
      state = state.copyWith(
        isLoadingFolder: false,
        statusMessage: 'Cartella non trovata: $dirPathOrUri',
      );
      return;
    }

    if (state.targetPath != null && !state.targetPath!.startsWith('content://')) {
      final targetDir = Directory(state.targetPath!);
      if (await targetDir.exists()) {
        await for (final entity in targetDir.list(recursive: true, followLinks: false)) {
          if (entity is File) {
            existingTargetFiles.add(p.basename(entity.path).toLowerCase());
          }
        }
      }
    }

    try {
      // recursive: true per trovare automaticamente le sottocartelle DCIM/100_FUJI
      await for (final entity in dir.list(recursive: true, followLinks: false)) {
        if (entity is File) {
          final ext = p.extension(entity.path).toLowerCase();
          if (RafExtractor.supportedExtensions.contains(ext)) {
            final fileName = p.basename(entity.path);
            final isAlreadyCopied = existingTargetFiles.contains(fileName.toLowerCase());
            rafList.add(RafPhoto(
              path: entity.path,
              fileName: fileName,
              isCopied: isAlreadyCopied,
            ));
          }
        }
      }
    } catch (e) {
      state = state.copyWith(
        isLoadingFolder: false,
        statusMessage: 'Errore scansione cartella: $e',
      );
      return;
    }

    // Ordina alfabeticamente per nome file
    rafList.sort((a, b) => a.fileName.compareTo(b.fileName));

    state = state.copyWith(
      photos: rafList,
      currentIndex: 0,
      isLoadingFolder: false,
      statusMessage: rafList.isEmpty
          ? 'Nessun file RAW (.RAF, .DNG, ecc.) trovato.'
          : '${rafList.length} file RAW trovati.',
    );

    _syncCache();
  }

  Future<void> setTargetFolder(String dirPathOrUri) async {
    state = state.copyWith(targetPath: dirPathOrUri);

    if (dirPathOrUri.startsWith('content://')) {
      // In SAF la verifica di copia avviene ad ogni operazione
      return;
    }

    // Ricalcola lo stato di isCopied per tutte le foto
    final targetDir = Directory(dirPathOrUri);
    if (await targetDir.exists()) {
      final existingTargetFiles = <String>{};
      await for (final entity in targetDir.list(recursive: true, followLinks: false)) {
        if (entity is File) {
          existingTargetFiles.add(p.basename(entity.path).toLowerCase());
        }
      }

      final updatedPhotos = state.photos.map((photo) {
        final isCopied = existingTargetFiles.contains(photo.fileName.toLowerCase());
        return photo.copyWith(isCopied: isCopied);
      }).toList();

      state = state.copyWith(photos: updatedPhotos);
    }
  }

  void nextPhoto() {
    if (state.photos.isEmpty) return;
    if (state.currentIndex < state.photos.length - 1) {
      state = state.copyWith(currentIndex: state.currentIndex + 1);
      _syncCache();
    }
  }

  void prevPhoto() {
    if (state.photos.isEmpty) return;
    if (state.currentIndex > 0) {
      state = state.copyWith(currentIndex: state.currentIndex - 1);
      _syncCache();
    }
  }

  void goToIndex(int index) {
    if (state.photos.isEmpty) return;
    final clamped = index.clamp(0, state.photos.length - 1);
    if (clamped != state.currentIndex) {
      state = state.copyWith(currentIndex: clamped);
      _syncCache();
    }
  }

  void selectCurrentPhoto() {
    final photo = state.currentPhoto;
    if (photo == null) return;

    if (state.targetPath == null || state.targetPath!.isEmpty) {
      state = state.copyWith(
        statusMessage: 'Seleziona prima una cartella di destinazione!',
      );
      return;
    }

    // 1. Accoda la copia del file .RAF nella cartella target
    queue.enqueueCopy(photo.path, state.targetPath!);

    // 2. Aggiorna lo stato della foto a isCopied = true
    final updatedList = List<RafPhoto>.from(state.photos);
    updatedList[state.currentIndex] = photo.copyWith(isCopied: true);
    state = state.copyWith(photos: updatedList);

    // 3. Auto-Advance immediato senza attendere I/O su disco
    if (state.autoAdvance) {
      nextPhoto();
    }
  }

  void deleteCurrentPhoto() {
    final photo = state.currentPhoto;
    if (photo == null) return;

    // 1. Accoda l'eliminazione fisica dal disco
    queue.enqueueDelete(photo.path);

    // 2. Rimuovi immediatamente dalla lista in memoria
    final updatedList = List<RafPhoto>.from(state.photos);
    final removeIdx = state.currentIndex;
    updatedList.removeAt(removeIdx);

    int nextIdx = removeIdx;
    if (nextIdx >= updatedList.length) {
      nextIdx = updatedList.isNotEmpty ? updatedList.length - 1 : 0;
    }

    state = state.copyWith(
      photos: updatedList,
      currentIndex: nextIdx,
      statusMessage: 'File eliminato: ${photo.fileName}',
    );

    _syncCache();
  }

  void toggleHud() {
    state = state.copyWith(isHudVisible: !state.isHudVisible);
  }

  void toggleAutoAdvance() {
    state = state.copyWith(autoAdvance: !state.autoAdvance);
  }

  void _syncCache() {
    if (state.photos.isEmpty) {
      cacheManager.clear();
      return;
    }
    final paths = state.photos.map((p) => p.path).toList();
    cacheManager.updateActiveIndex(state.currentIndex, paths);
  }
}

// Providers Riverpod
final cacheManagerProvider = ChangeNotifierProvider<ImageCacheManager>((ref) {
  return ImageCacheManager();
});

final fileOpsQueueProvider = ChangeNotifierProvider<FileOperationsQueue>((ref) {
  return FileOperationsQueue();
});

final cullerProvider = StateNotifierProvider<CullerNotifier, CullerState>((ref) {
  // IMPORTANTE: ref.read e non ref.watch. Con ref.watch su un ChangeNotifierProvider,
  // ogni notifyListeners() della cache o della coda I/O ricreava il CullerNotifier
  // da zero, azzerando la lista foto subito dopo il caricamento della prima anteprima.
  final cache = ref.read(cacheManagerProvider);
  final queue = ref.read(fileOpsQueueProvider);
  return CullerNotifier(cacheManager: cache, queue: queue);
});
