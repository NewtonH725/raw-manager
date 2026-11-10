import 'dart:async';
import 'dart:collection';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'saf_service.dart';

enum FileOpType { copy, delete }

class FileOpTask {
  final String id;
  final FileOpType type;
  final String sourcePath;
  final String? targetDirPath;
  final DateTime createdAt;

  FileOpTask({
    required this.id,
    required this.type,
    required this.sourcePath,
    this.targetDirPath,
  }) : createdAt = DateTime.now();

  String get targetFilePath {
    if (targetDirPath == null) return '';
    return p.join(targetDirPath!, p.basename(sourcePath));
  }
}

class FileOperationsQueue extends ChangeNotifier {
  final Queue<FileOpTask> _pendingQueue = Queue<FileOpTask>();
  bool _isProcessing = false;
  int _completedCount = 0;
  String? _lastError;
  String? _currentTaskDescription;

  int get pendingCount => _pendingQueue.length;
  int get completedCount => _completedCount;
  bool get isProcessing => _isProcessing;
  String? get lastError => _lastError;
  String? get currentTaskDescription => _currentTaskDescription;

  /// Accoda la copia di un file .RAF nella cartella di destinazione.
  void enqueueCopy(String sourcePath, String targetDirPath) {
    final task = FileOpTask(
      id: '${DateTime.now().microsecondsSinceEpoch}_copy',
      type: FileOpType.copy,
      sourcePath: sourcePath,
      targetDirPath: targetDirPath,
    );
    _pendingQueue.add(task);
    notifyListeners();
    _processNext();
  }

  /// Accoda l'eliminazione di un file .RAF dalla cartella sorgente.
  void enqueueDelete(String sourcePath) {
    final task = FileOpTask(
      id: '${DateTime.now().microsecondsSinceEpoch}_delete',
      type: FileOpType.delete,
      sourcePath: sourcePath,
    );
    _pendingQueue.add(task);
    notifyListeners();
    _processNext();
  }

  Future<void> _processNext() async {
    if (_isProcessing || _pendingQueue.isEmpty) return;

    _isProcessing = true;
    final task = _pendingQueue.removeFirst();
    _currentTaskDescription = task.type == FileOpType.copy
        ? 'Copia di ${p.basename(task.sourcePath)}...'
        : 'Eliminazione di ${p.basename(task.sourcePath)}...';
    notifyListeners();

    try {
      if (task.type == FileOpType.copy) {
        await _executeCopy(task);
      } else {
        await _executeDelete(task);
      }
      _completedCount++;
      _lastError = null;
    } catch (e) {
      _lastError = 'Errore ${task.type == FileOpType.copy ? "copia" : "eliminazione"}: $e';
      debugPrint(_lastError);
    } finally {
      _isProcessing = false;
      _currentTaskDescription = null;
      notifyListeners();
      // Esegui il prossimo task in coda
      _processNext();
    }
  }

  Future<void> _executeCopy(FileOpTask task) async {
    // Supporto Android SAF (URI content://)
    if (task.sourcePath.startsWith('content://') || (task.targetDirPath?.startsWith('content://') ?? false)) {
      final success = await SafService.copyRawFile(
        sourceUri: task.sourcePath,
        targetTreeUri: task.targetDirPath!,
        fileName: p.basename(task.sourcePath).isNotEmpty ? p.basename(task.sourcePath) : 'RAW_${DateTime.now().millisecondsSinceEpoch}',
      );
      if (!success) {
        throw Exception('Copia SAF non riuscita per ${task.sourcePath}');
      }
      return;
    }

    final src = File(task.sourcePath);
    if (!await src.exists()) {
      throw FileSystemException('File sorgente non esistente: ${task.sourcePath}');
    }

    final targetDir = Directory(task.targetDirPath!);
    if (!await targetDir.exists()) {
      await targetDir.create(recursive: true);
    }

    final dst = File(task.targetFilePath);
    // Copia atomica tramite streaming asincrono
    await src.copy(dst.path);
  }

  Future<void> _executeDelete(FileOpTask task) async {
    if (task.sourcePath.startsWith('content://')) {
      final success = await SafService.deleteRawFile(task.sourcePath);
      if (!success) {
        throw Exception('Eliminazione SAF non riuscita per ${task.sourcePath}');
      }
      return;
    }

    final file = File(task.sourcePath);
    if (await file.exists()) {
      await file.delete();
    }
  }
}
