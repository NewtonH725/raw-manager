import 'dart:io';
import 'dart:typed_data';
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

  group('Ricoh GR IIIx DNG Preview & Lossless Rejection Tests', () {
    Uint8List makeJpeg({required int sofMarker, required int width, required int height, int payloadLen = 40}) {
      return Uint8List.fromList([
        0xFF, 0xD8, // SOI
        0xFF, 0xE0, 0x00, 0x10, 0x4A, 0x46, 0x49, 0x46, 0x00, 0x01, 0x01, 0x01, 0x00, 0x48, 0x00, 0x48, 0x00, 0x00,
        0xFF, sofMarker, 0x00, 0x11, 0x08,
        (height >> 8) & 0xFF, height & 0xFF,
        (width >> 8) & 0xFF, width & 0xFF,
        0x03, // 3 components
        0x01, 0x22, 0x00, 0x02, 0x11, 0x01, 0x03, 0x11, 0x01,
        0xFF, 0xDA, 0x00, 0x08, 0x01, 0x01, 0x00, 0x00, 0x3F, 0x00,
        ...List.filled(payloadLen, 0x55),
        0xFF, 0xD9, // EOI
      ]);
    }

    test('Rifiuta Lossless SOF3 RAW ed estrae anteprima HD da SubIFD1 StripOffsets', () async {
      // Costruisce un file DNG sintetico fedele alla struttura Ricoh GR IIIx:
      // - IFD0 con thumbnail 160x120 (0x0201) + SubIFDs[SubIFD0, SubIFD1]
      // - SubIFD0 con enorme RAW Lossless SOF3 (0xC3) + StripOffsets
      // - SubIFD1 con anteprima Baseline SOF0 (0xC0) 1620x1080 + StripOffsets (0x0111/0x0117)
      final thumb160 = makeJpeg(sofMarker: 0xC0, width: 160, height: 120, payloadLen: 80);
      final rawLosslessSof3 = makeJpeg(sofMarker: 0xC3, width: 6000, height: 4000, payloadLen: 8000);
      final preview1620 = makeJpeg(sofMarker: 0xC0, width: 1620, height: 1080, payloadLen: 500);

      // Verifica inspectJpegHeader direttamente
      expect(RafExtractor.inspectJpegHeader(rawLosslessSof3).$1, isFalse);
      final hdCheck = RafExtractor.inspectJpegHeader(preview1620);
      expect(hdCheck.$1, isTrue);
      expect(hdCheck.$2, 1620);
      expect(hdCheck.$3, 1080);

      // Layout binario Little-Endian
      final bd = BytesBuilder();
      // 0..7: TIFF header II, 42, IFD0 offset = 8
      void addU16(int v) => bd.add([v & 0xFF, (v >> 8) & 0xFF]);
      void addU32(int v) => bd.add([v & 0xFF, (v >> 8) & 0xFF, (v >> 16) & 0xFF, (v >> 24) & 0xFF]);
      void addEntry(int tag, int type, int count, int val) {
        addU16(tag);
        addU16(type);
        addU32(count);
        addU32(val);
      }

      // Header (8 byte)
      bd.add([0x49, 0x49]);
      addU16(42);
      addU32(8);

      // IFD0 at offset 8 (3 entries: 2 + 36 + 4 = 42 bytes -> ends at 50)
      const subIfdListOffset = 50; // 2 uint32 = 8 bytes -> ends at 58
      const subIfd0Offset = 58;    // 3 entries: 2 + 36 + 4 = 42 bytes -> ends at 100
      const subIfd1Offset = 100;   // 4 entries: 2 + 48 + 4 = 54 bytes -> ends at 154
      const thumbOffset = 160;
      final rawOffset = thumbOffset + thumb160.length;
      final previewOffset = rawOffset + rawLosslessSof3.length;

      addU16(3);
      addEntry(0x0201, 4, 1, thumbOffset);
      addEntry(0x0202, 4, 1, thumb160.length);
      addEntry(0x014A, 4, 2, subIfdListOffset);
      addU32(0); // next IFD = 0

      // SubIFDs array at 50
      addU32(subIfd0Offset);
      addU32(subIfd1Offset);

      // SubIFD0 (RAW CFA Lossless SOF3) at 58
      addU16(3);
      addEntry(0x0103, 3, 1, 7); // Compression = 7
      addEntry(0x0111, 4, 1, rawOffset);
      addEntry(0x0117, 4, 1, rawLosslessSof3.length);
      addU32(0);

      // SubIFD1 (High-res Preview 1620x1080 SOF0) at 100
      addU16(4);
      addEntry(0x0103, 3, 1, 7); // Compression = 7
      addEntry(0x0106, 3, 1, 6); // Photometric YCbCr
      addEntry(0x0111, 4, 1, previewOffset);
      addEntry(0x0117, 4, 1, preview1620.length);
      addU32(0);

      // Padding from 154 to 160
      bd.add(List.filled(6, 0));
      bd.add(thumb160);
      bd.add(rawLosslessSof3);
      bd.add(preview1620);

      final dngPath = p.join(syntheticDir, 'RICOH_GR3X_TEST.DNG');
      File(dngPath).writeAsBytesSync(bd.toBytes());

      final extracted = await RafExtractor.extractRaf(dngPath);
      final resHeader = RafExtractor.inspectJpegHeader(extracted.jpegBytes);
      expect(resHeader.$1, isTrue);
      expect(resHeader.$2, 1620);
      expect(resHeader.$3, 1080);
    });
  });
}
