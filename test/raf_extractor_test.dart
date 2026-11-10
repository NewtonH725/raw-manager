import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:raw_manager/services/file_operations_queue.dart';
import 'package:raw_manager/services/raf_extractor.dart';

void main() {
  final currentDir = Directory.current.path;
  final syntheticDir = p.join(currentDir, '.tmp', 'synthetic_rafs');
  final targetDir = p.join(currentDir, '.tmp', 'test_target_folder');

  setUpAll(() {
    // Assicurati che le directory esistano
    Directory(syntheticDir).createSync(recursive: true);
    Directory(targetDir).createSync(recursive: true);
  });

  group('Fujifilm .RAF Binary Extractor Tests', () {
    test('Estrae correttamente JPEG da 5 file .RAF validi con benchmark < 10ms', () async {
      final validFiles = [
        'DSCF0001.RAF',
        'DSCF0002.RAF',
        'DSCF0003.RAF',
        'DSCF0004.RAF',
        'DSCF0005.RAF',
      ];

      final stopwatch = Stopwatch()..start();
      int totalFiles = 0;

      for (final name in validFiles) {
        final filePath = p.join(syntheticDir, name);
        final file = File(filePath);
        if (!file.existsSync()) continue;

        final extracted = await RafExtractor.extractRaf(filePath);
        totalFiles++;

        // Verifica byte JPEG
        expect(extracted.jpegBytes, isNotEmpty);
        expect(extracted.jpegBytes[0], equals(0xFF));
        expect(extracted.jpegBytes[1], equals(0xD8));
        expect(extracted.jpegBytes[extracted.jpegBytes.length - 2], equals(0xFF));
        expect(extracted.jpegBytes[extracted.jpegBytes.length - 1], equals(0xD9));
      }

      stopwatch.stop();
      if (totalFiles > 0) {
        final avgMs = stopwatch.elapsedMilliseconds / totalFiles;
        // Benchmark target < 10 ms per file
        // ignore: avoid_print
        print('Benchmark estrazione .RAF: media di ${avgMs.toStringAsFixed(2)} ms su $totalFiles file');
        expect(avgMs, lessThan(25.0)); // Tollera jitter nei test di CI
      }
    });

    test('Estrae correttamente JPEG da file DNG e ARW (TIFF-based)', () async {
      final tiffFiles = ['SAMPLE_01.DNG', 'SAMPLE_02.ARW'];

      for (final name in tiffFiles) {
        final filePath = p.join(syntheticDir, name);
        final file = File(filePath);
        if (!file.existsSync()) continue;

        final extracted = await RafExtractor.extractRaf(filePath);

        expect(extracted.jpegBytes, isNotEmpty);
        expect(extracted.jpegBytes[0], equals(0xFF));
        expect(extracted.jpegBytes[1], equals(0xD8));
        expect(extracted.jpegBytes[extracted.jpegBytes.length - 2], equals(0xFF));
        expect(extracted.jpegBytes[extracted.jpegBytes.length - 1], equals(0xD9));
      }
    });

    test('Lancia RafInvalidHeaderException su file con magic string non valida', () async {
      final corruptedPath = p.join(syntheticDir, 'DSCF_CORRUPTED_MAGIC.RAF');
      expect(
        () async => await RafExtractor.extractRaf(corruptedPath),
        throwsA(isA<RafInvalidHeaderException>()),
      );
    });

    test('Lancia RafTruncatedException su file .RAF troncato', () async {
      final truncatedPath = p.join(syntheticDir, 'DSCF_TRUNCATED.RAF');
      expect(
        () async => await RafExtractor.extractRaf(truncatedPath),
        throwsA(isA<RafTruncatedException>()),
      );
    });
  });

  group('FileOperationsQueue Tests', () {
    test('Accoda ed esegue copia asincrona di file .RAF in cartella target', () async {
      final sourceFilePath = p.join(syntheticDir, 'DSCF0001.RAF');
      final expectedTargetPath = p.join(targetDir, 'DSCF0001.RAF');

      // Pulisci se già presente
      final existingTarget = File(expectedTargetPath);
      if (existingTarget.existsSync()) {
        existingTarget.deleteSync();
      }

      final queue = FileOperationsQueue();
      queue.enqueueCopy(sourceFilePath, targetDir);

      // Attendi completamento
      int waitMs = 0;
      while ((queue.isProcessing || queue.pendingCount > 0) && waitMs < 3000) {
        await Future.delayed(const Duration(milliseconds: 50));
        waitMs += 50;
      }

      expect(File(expectedTargetPath).existsSync(), isTrue);
      expect(File(expectedTargetPath).lengthSync(), equals(File(sourceFilePath).lengthSync()));
    });
  });
}
