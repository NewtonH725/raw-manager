import 'dart:async';
import 'dart:io';
import 'dart:isolate';
import 'dart:typed_data';
import 'package:exif/exif.dart';
import 'saf_service.dart';

/// Eccezioni per il parsing dei formati RAW (Fujifilm RAF, Adobe DNG, Sony ARW, Nikon NEF, Canon CR2/CR3).
class RawException implements Exception {
  final String message;
  const RawException(this.message);
  @override
  String toString() => 'RawException: $message';
}

class RawInvalidHeaderException extends RawException {
  const RawInvalidHeaderException(super.message);
}

class RawCorruptedException extends RawException {
  const RawCorruptedException(super.message);
}

class RawTruncatedException extends RawException {
  const RawTruncatedException(super.message);
}

// Alias per compatibilità con test esistenti
typedef RafException = RawException;
typedef RafInvalidHeaderException = RawInvalidHeaderException;
typedef RafCorruptedException = RawCorruptedException;
typedef RafTruncatedException = RawTruncatedException;

/// Dati estratti da un file RAW
class ExtractedRafData {
  final Uint8List jpegBytes;
  final Map<String, IfdTag> exifData;
  final String exifSummary;

  const ExtractedRafData({
    required this.jpegBytes,
    required this.exifData,
    required this.exifSummary,
  });
}

class RafExtractor {
  static const List<int> fujiMagicBytes = [
    0x46, 0x55, 0x4A, 0x49, 0x46, 0x49, 0x4C, 0x4D, // "FUJIFILM"
    0x43, 0x43, 0x44, 0x2D, 0x52, 0x41, 0x57, 0x20  // "CCD-RAW "
  ];

  static const Set<String> supportedExtensions = {
    '.raf',
    '.dng',
    '.arw',
    '.nef',
    '.cr2',
    '.cr3',
    '.rw2',
    '.orf',
    '.pef',
  };

  /// Estrae il JPEG incorporato e i metadati EXIF da qualunque file RAW supportato su un Isolate separato.
  /// Supporta sia file standard via path locale, sia URI content:// su Android tramite SAF.
  static Future<ExtractedRafData> extractRaf(String filePathOrUri) async {
    if (filePathOrUri.startsWith('content://')) {
      final bytes = await SafService.extractRawBytes(filePathOrUri);
      if (bytes != null) {
        return await _buildResult(bytes);
      }
      throw const RawCorruptedException('Impossibile estrarre anteprima da URI SAF');
    }
    return await Isolate.run(() => _extractSync(filePathOrUri));
  }

  static Future<ExtractedRafData> _extractSync(String filePath) async {
    final file = File(filePath);
    if (!file.existsSync()) {
      throw RawCorruptedException('File non trovato: $filePath');
    }

    final fileLength = file.lengthSync();
    if (fileLength < 92) {
      throw RawInvalidHeaderException(
        'File troppo piccolo per contenere un header RAW standard ($fileLength byte)',
      );
    }

    final lowerPath = filePath.toLowerCase();
    if (lowerPath.endsWith('.raf')) {
      return await _extractFujifilmRaf(file, fileLength);
    } else {
      // DNG, ARW, NEF, CR2 (TIFF-based) o fallback
      return await _extractTiffOrGenericRaw(file, fileLength);
    }
  }

  /// Estrazione specializzata ad altissima velocità (< 5ms) per Fujifilm .RAF
  static Future<ExtractedRafData> _extractFujifilmRaf(File file, int fileLength) async {
    final raf = file.openSync(mode: FileMode.read);
    try {
      final headerBytes = raf.readSync(92);
      if (headerBytes.length < 92) {
        throw RawInvalidHeaderException('Header .RAF incompleto o illeggibile');
      }

      for (int i = 0; i < 16; i++) {
        if (headerBytes[i] != fujiMagicBytes[i]) {
          throw RawInvalidHeaderException(
            'Magic string non valida: il file non è un formato RAW Fujifilm (.RAF)',
          );
        }
      }

      final byteData = ByteData.sublistView(headerBytes);
      final jpegOffset = byteData.getUint32(0x54, Endian.big);
      final jpegLength = byteData.getUint32(0x58, Endian.big);

      if (jpegOffset < 92 || jpegOffset >= fileLength || jpegLength == 0) {
        throw RawCorruptedException(
          'Puntatori JPEG non validi: offset=0x${jpegOffset.toRadixString(16)}, length=$jpegLength, fileSize=$fileLength',
        );
      }

      if (jpegOffset + jpegLength > fileLength) {
        throw RawTruncatedException(
          'File .RAF troncato: jpegOffset ($jpegOffset) + jpegLength ($jpegLength) supera fileSize ($fileLength)',
        );
      }

      raf.setPositionSync(jpegOffset);
      final jpegBytes = raf.readSync(jpegLength);
      if (jpegBytes.length < jpegLength) {
        throw RawTruncatedException('Impossibile leggere l\'intero stream JPEG dichiarato');
      }

      _validateJpegMarkers(jpegBytes);

      return await _buildResult(jpegBytes);
    } finally {
      raf.closeSync();
    }
  }

  /// Estrazione universale TIFF / DNG / ARW / NEF / CR2
  static Future<ExtractedRafData> _extractTiffOrGenericRaw(File file, int fileLength) async {
    final raf = file.openSync(mode: FileMode.read);
    try {
      final headerBytes = raf.readSync(16);
      if (headerBytes.length < 8) {
        throw RawInvalidHeaderException('Header file troppo piccolo');
      }

      // 1. Verifica formato TIFF: "II*\0" (Little-Endian) o "MM\0*" (Big-Endian)
      Endian endian = Endian.little;
      bool isTiff = false;
      if (headerBytes[0] == 0x49 && headerBytes[1] == 0x49) {
        endian = Endian.little;
        final magic = ByteData.sublistView(headerBytes).getUint16(2, endian);
        if (magic == 42 || magic == 0x4F52) isTiff = true;
      } else if (headerBytes[0] == 0x4D && headerBytes[1] == 0x4D) {
        endian = Endian.big;
        final magic = ByteData.sublistView(headerBytes).getUint16(2, endian);
        if (magic == 42) isTiff = true;
      }

      if (isTiff) {
        final byteData = ByteData.sublistView(headerBytes);
        final firstIfdOffset = byteData.getUint32(4, endian);

        final previewInfo = _findTiffJpegPreview(raf, firstIfdOffset, endian, fileLength);
        if (previewInfo != null) {
          final offset = previewInfo.$1;
          final length = previewInfo.$2;

          raf.setPositionSync(offset);
          final jpegBytes = raf.readSync(length);
          if (jpegBytes.length == length) {
            _validateJpegMarkers(jpegBytes);
            return await _buildResult(jpegBytes);
          }
        }
      }

      // 2. Fallback scanning: Scansione dell'header e primi blocchi alla ricerca di marker JPEG (0xFF 0xD8 ... 0xFF 0xD9)
      final fallbackBytes = _scanForEmbeddedJpeg(raf, fileLength);
      if (fallbackBytes != null) {
        return await _buildResult(fallbackBytes);
      }

      throw RawCorruptedException('Nessuna anteprima JPEG incorporata valida trovata nel file RAW');
    } finally {
      raf.closeSync();
    }
  }

  /// Esplora ricorsivamente IFD primari e SubIFD per trovare il JPEG con risoluzione maggiore
  static (int, int)? _findTiffJpegPreview(
    RandomAccessFile raf,
    int ifdOffset,
    Endian endian,
    int fileLength, [
    int depth = 0,
  ]) {
    if (depth > 5 || ifdOffset <= 0 || ifdOffset >= fileLength - 6) return null;

    try {
      raf.setPositionSync(ifdOffset);
      final countBytes = raf.readSync(2);
      if (countBytes.length < 2) return null;

      final numEntries = ByteData.sublistView(countBytes).getUint16(0, endian);
      if (numEntries <= 0 || numEntries > 1000) return null;

      final entryBytes = raf.readSync(numEntries * 12);
      if (entryBytes.length < numEntries * 12) return null;

      int? jpegOffset;
      int? jpegLength;
      final List<int> subIfdOffsets = [];

      final bd = ByteData.sublistView(entryBytes);
      for (int i = 0; i < numEntries; i++) {
        final entryStart = i * 12;
        final tag = bd.getUint16(entryStart, endian);
        final count = bd.getUint32(entryStart + 4, endian);
        final valOffset = bd.getUint32(entryStart + 8, endian);

        // 0x0201: JPEGInterchangeFormat
        if (tag == 0x0201) {
          jpegOffset = valOffset;
        }
        // 0x0202: JPEGInterchangeFormatLength
        else if (tag == 0x0202) {
          jpegLength = valOffset;
        }
        // 0x014A: SubIFDs
        else if (tag == 0x014A) {
          if (count == 1) {
            subIfdOffsets.add(valOffset);
          } else if (count > 1 && count < 20) {
            // Leggi array di offset SubIFD
            try {
              raf.setPositionSync(valOffset);
              final subBytes = raf.readSync(count * 4);
              final sbd = ByteData.sublistView(subBytes);
              for (int j = 0; j < count; j++) {
                subIfdOffsets.add(sbd.getUint32(j * 4, endian));
              }
            } catch (_) {}
          }
        }
      }

      (int, int)? bestCandidate;
      if (jpegOffset != null && jpegLength != null && jpegLength > 50) {
        if (jpegOffset + jpegLength <= fileLength) {
          bestCandidate = (jpegOffset, jpegLength);
        }
      }

      // Esamina SubIFDs (spesso contengono l'anteprima Full-Res rispetto al thumbnail di IFD0)
      for (final subOffset in subIfdOffsets) {
        final subPreview = _findTiffJpegPreview(raf, subOffset, endian, fileLength, depth + 1);
        if (subPreview != null) {
          if (bestCandidate == null || subPreview.$2 > bestCandidate.$2) {
            bestCandidate = subPreview;
          }
        }
      }

      // Se non abbiamo trovato una preview valida, prova il prossimo IFD concatenato
      if (bestCandidate == null) {
        final nextIfdBytes = raf.readSync(4);
        if (nextIfdBytes.length == 4) {
          final nextIfdOffset = ByteData.sublistView(nextIfdBytes).getUint32(0, endian);
          if (nextIfdOffset > 0) {
            return _findTiffJpegPreview(raf, nextIfdOffset, endian, fileLength, depth + 1);
          }
        }
      }

      return bestCandidate;
    } catch (_) {
      return null;
    }
  }

  /// Scansione rapida di sicurezza per marker JPEG 0xFFD8...0xFFD9
  static Uint8List? _scanForEmbeddedJpeg(RandomAccessFile raf, int fileLength) {
    try {
      raf.setPositionSync(0);
      final scanSize = fileLength > 20 * 1024 * 1024 ? 20 * 1024 * 1024 : fileLength;
      final buffer = raf.readSync(scanSize);

      int bestStart = -1;
      int bestLength = 0;

      for (int i = 0; i < buffer.length - 1; i++) {
        if (buffer[i] == 0xFF && buffer[i + 1] == 0xD8) {
          // Trovato inizio JPEG
          for (int j = i + 10; j < buffer.length - 1; j++) {
            if (buffer[j] == 0xFF && buffer[j + 1] == 0xD9) {
              final len = j - i + 2;
              if (len > bestLength && len > 50) {
                bestStart = i;
                bestLength = len;
              }
              break;
            }
          }
        }
      }

      if (bestStart >= 0 && bestLength > 0) {
        return Uint8List.sublistView(buffer, bestStart, bestStart + bestLength);
      }
    } catch (_) {}
    return null;
  }

  static void _validateJpegMarkers(Uint8List bytes) {
    if (bytes.length < 4 ||
        bytes[0] != 0xFF ||
        bytes[1] != 0xD8 ||
        bytes[bytes.length - 2] != 0xFF ||
        bytes[bytes.length - 1] != 0xD9) {
      throw RawCorruptedException('Marcatori JPEG (0xFFD8 o 0xFFD9) non corrispondenti');
    }
  }

  static Future<ExtractedRafData> _buildResult(Uint8List jpegBytes) async {
    Map<String, IfdTag> exifData = {};
    String summary = '';
    try {
      exifData = await readExifFromBytes(jpegBytes);
      summary = _buildExifSummary(exifData);
    } catch (_) {
      summary = 'EXIF N/D';
    }

    return ExtractedRafData(
      jpegBytes: jpegBytes,
      exifData: exifData,
      exifSummary: summary,
    );
  }

  static String _buildExifSummary(Map<String, IfdTag> tags) {
    if (tags.isEmpty) return 'EXIF N/D';

    final camera = tags['Image Model']?.printable ?? tags['Image Make']?.printable ?? '';
    final shutter = tags['EXIF ExposureTime']?.printable ?? '';
    final fNumber = tags['EXIF FNumber']?.printable ?? '';
    final iso = tags['EXIF ISOSpeedRatings']?.printable ?? tags['EXIF PhotographicSensitivity']?.printable ?? '';
    final focal = tags['EXIF FocalLength']?.printable ?? '';

    final parts = <String>[];
    if (camera.isNotEmpty) parts.add(camera);
    if (shutter.isNotEmpty) parts.add('${shutter}s');
    if (fNumber.isNotEmpty) parts.add('f/$fNumber');
    if (iso.isNotEmpty) parts.add('ISO $iso');
    if (focal.isNotEmpty) parts.add('${focal}mm');

    return parts.isEmpty ? 'EXIF N/D' : parts.join(' • ');
  }
}
