import 'dart:async';
import 'dart:io';
import 'dart:isolate';
import 'dart:typed_data';
import 'package:exif/exif.dart';
import 'saf_service.dart';

/// Eccezioni per il parsing dei formati RAW (Fujifilm RAF, Adobe DNG, Ricoh, Sony ARW, Nikon NEF, Canon CR2/CR3).
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

class _JpegCandidate {
  final int offset;
  final int length;
  final int width;
  final int height;

  const _JpegCandidate({
    required this.offset,
    required this.length,
    required this.width,
    required this.height,
  });

  int get pixelArea => width * height;

  bool isBetterThan(_JpegCandidate? other) {
    if (other == null) return true;
    if (pixelArea > 0 && other.pixelArea > 0 && pixelArea != other.pixelArea) {
      return pixelArea > other.pixelArea;
    }
    return length > other.length;
  }
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
      // DNG (Ricoh GR IIIx, Adobe, Leica), ARW, NEF, CR2 (TIFF-based) o fallback
      return await _extractTiffOrGenericRaw(file, fileLength);
    }
  }

  /// Verifica se un buffer inizia con un JPEG standard decodificabile (SOF0/SOF1/SOF2)
  /// ed esclude gli stream DNG Lossless RAW (SOF3 0xC3) che farebbero fallire Image.memory.
  static (bool isDecodable, int width, int height) inspectJpegHeader(Uint8List bytes) {
    if (bytes.length < 10 || bytes[0] != 0xFF || bytes[1] != 0xD8 || bytes[2] != 0xFF) {
      return (false, 0, 0);
    }
    int pos = 2;
    final limit = bytes.length;
    while (pos + 3 < limit) {
      if (bytes[pos] != 0xFF) {
        pos++;
        continue;
      }
      while (pos < limit && bytes[pos] == 0xFF) {
        pos++;
      }
      if (pos >= limit) break;
      final marker = bytes[pos];
      pos++;

      // Marker senza payload (RST, SOI, EOI, TEM)
      if (marker == 0x00 || marker == 0x01 || (marker >= 0xD0 && marker <= 0xD9)) {
        if (marker == 0xD9) break;
        continue;
      }

      if (pos + 1 >= limit) break;
      final segLen = (bytes[pos] << 8) | bytes[pos + 1];
      if (segLen < 2) break;

      // SOF0 (0xC0), SOF1 (0xC1), SOF2 (0xC2): Baseline / Extended / Progressive DCT
      if (marker == 0xC0 || marker == 0xC1 || marker == 0xC2) {
        int h = 0, w = 0;
        if (pos + 7 < limit) {
          final precision = bytes[pos + 2];
          h = (bytes[pos + 3] << 8) | bytes[pos + 4];
          w = (bytes[pos + 5] << 8) | bytes[pos + 6];
          final components = bytes[pos + 7];
          if (precision != 8 || w <= 0 || h <= 0 || (components != 1 && components != 3)) {
            return (false, 0, 0);
          }
        }
        return (true, w, h);
      }

      // SOF3 (0xC3) Lossless JPEG (usato dai dati RAW dei sensori DNG!) o altri SOF non standard
      if (marker == 0xC3 ||
          marker == 0xC5 ||
          marker == 0xC6 ||
          marker == 0xC7 ||
          marker == 0xC9 ||
          marker == 0xCA ||
          marker == 0xCB ||
          marker == 0xCD ||
          marker == 0xCE ||
          marker == 0xCF) {
        return (false, 0, 0);
      }

      if (marker == 0xDA) break; // SOS
      pos += segLen;
    }
    return (false, 0, 0);
  }

  /// Estrazione specializzata ad altissima velocità (< 5ms) per Fujifilm .RAF
  static Future<ExtractedRafData> _extractFujifilmRaf(File file, int fileLength) async {
    final raf = file.openSync(mode: FileMode.read);
    try {
      final headerBytes = raf.readSync(92);
      if (headerBytes.length < 92) {
        throw const RawInvalidHeaderException('Header .RAF incompleto (< 92 byte)');
      }

      for (int i = 0; i < fujiMagicBytes.length; i++) {
        if (headerBytes[i] != fujiMagicBytes[i]) {
          throw const RawInvalidHeaderException('Magic string "FUJIFILMCCD-RAW " non valida.');
        }
      }

      final byteData = ByteData.sublistView(headerBytes);
      final jpegOffset = byteData.getUint32(0x54, Endian.big);
      final jpegLength = byteData.getUint32(0x58, Endian.big);

      if (jpegOffset < 92 || jpegLength == 0) {
        throw const RawCorruptedException('Puntatori offset/lunghezza JPEG nel .RAF non validi.');
      }

      if (jpegOffset + jpegLength > fileLength) {
        throw RawTruncatedException(
          'File .RAF troncato: estensione JPEG ($jpegOffset + $jpegLength) oltre fine file ($fileLength).',
        );
      }

      raf.setPositionSync(jpegOffset);
      final jpegBytes = raf.readSync(jpegLength);
      if (jpegBytes.length != jpegLength) {
        throw const RawTruncatedException('Impossibile leggere tutti i byte del JPEG incorporato.');
      }

      _validateJpegMarkers(jpegBytes);
      return await _buildResult(jpegBytes);
    } finally {
      raf.closeSync();
    }
  }

  /// Estrazione universale TIFF / DNG (Ricoh GR IIIx, Adobe, Leica) / ARW / NEF / CR2
  static Future<ExtractedRafData> _extractTiffOrGenericRaw(File file, int fileLength) async {
    final raf = file.openSync(mode: FileMode.read);
    try {
      final headerBytes = raf.readSync(16);
      if (headerBytes.length < 8) {
        throw const RawInvalidHeaderException('Header file troppo piccolo');
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

        final visitedIfds = <int>{};
        final best = _findBestTiffPreview(raf, firstIfdOffset, endian, fileLength, visitedIfds);
        if (best != null) {
          raf.setPositionSync(best.offset);
          final rawJpegBytes = raf.readSync(best.length);
          if (rawJpegBytes.length == best.length) {
            final cleaned = _trimAndValidateJpeg(rawJpegBytes);
            if (cleaned != null) {
              return await _buildResult(cleaned);
            }
          }
        }
      }

      // 2. Fallback scanning intelligente (filtra Lossless SOF3 e gestisce APP1 EXIF annidati)
      final fallbackBytes = _scanForEmbeddedJpeg(raf, fileLength);
      if (fallbackBytes != null) {
        return await _buildResult(fallbackBytes);
      }

      throw const RawCorruptedException('Nessuna anteprima JPEG decodificabile trovata nel file RAW');
    } finally {
      raf.closeSync();
    }
  }

  static List<int> _readTiffIntValues(
    RandomAccessFile raf,
    ByteData bd,
    int entryStart,
    Endian endian,
    int fileLength,
  ) {
    final type = bd.getUint16(entryStart + 2, endian);
    final count = bd.getUint32(entryStart + 4, endian);
    final valFieldOffset = entryStart + 8;

    if (count == 0 || count > 200) return const [];

    if (count == 1) {
      if (type == 3) {
        // SHORT (2 bytes)
        return [bd.getUint16(valFieldOffset, endian)];
      }
      return [bd.getUint32(valFieldOffset, endian)];
    }

    if (count == 2 && type == 3) {
      return [
        bd.getUint16(valFieldOffset, endian),
        bd.getUint16(valFieldOffset + 2, endian),
      ];
    }

    final valOffset = bd.getUint32(valFieldOffset, endian);
    final elemSize = (type == 3) ? 2 : 4;
    if (valOffset <= 0 || valOffset + count * elemSize > fileLength) return const [];

    try {
      raf.setPositionSync(valOffset);
      final data = raf.readSync(count * elemSize);
      if (data.length < count * elemSize) return const [];
      final vbd = ByteData.sublistView(data);
      return List<int>.generate(
        count,
        (i) => (type == 3) ? vbd.getUint16(i * 2, endian) : vbd.getUint32(i * 4, endian),
      );
    } catch (_) {
      return const [];
    }
  }

  /// Valuta un candidato JPEG controllandone i header SOF per escludere dati RAW Lossless (SOF3)
  static _JpegCandidate? _validateCandidate(
    RandomAccessFile raf,
    int offset,
    int length,
    int fileLength,
  ) {
    if (offset < 8 || length <= 50 || offset + length > fileLength) return null;
    try {
      final probeLen = length < 65536 ? length : 65536;
      raf.setPositionSync(offset);
      final probe = raf.readSync(probeLen);
      final (isDecodable, w, h) = inspectJpegHeader(probe);
      if (!isDecodable) return null;

      return _JpegCandidate(offset: offset, length: length, width: w, height: h);
    } catch (_) {
      return null;
    }
  }

  /// Attraversa ricorsivamente IFD0, IFD1/nextIfd, SubIFDs e ExifIFD alla ricerca
  /// della reale anteprima JPEG decodificabile (SOF0/SOF2) con risoluzione massima.
  static _JpegCandidate? _findBestTiffPreview(
    RandomAccessFile raf,
    int ifdOffset,
    Endian endian,
    int fileLength,
    Set<int> visitedIfds, [
    int depth = 0,
  ]) {
    if (depth > 8 || ifdOffset <= 0 || ifdOffset >= fileLength - 6) return null;
    if (!visitedIfds.add(ifdOffset)) return null;

    try {
      raf.setPositionSync(ifdOffset);
      final countBytes = raf.readSync(2);
      if (countBytes.length < 2) return null;

      final numEntries = ByteData.sublistView(countBytes).getUint16(0, endian);
      if (numEntries <= 0 || numEntries > 1000) return null;

      final entryBytes = raf.readSync(numEntries * 12);
      if (entryBytes.length < numEntries * 12) return null;

      // Posizione esatta del puntatore al prossimo IFD (IFD1, IFD2...)
      final nextIfdPtrPos = ifdOffset + 2 + numEntries * 12;
      int nextIfdOffset = 0;
      if (nextIfdPtrPos + 4 <= fileLength) {
        raf.setPositionSync(nextIfdPtrPos);
        final nextBytes = raf.readSync(4);
        if (nextBytes.length == 4) {
          nextIfdOffset = ByteData.sublistView(nextBytes).getUint32(0, endian);
        }
      }

      int? jpegInterchangeOffset;
      int? jpegInterchangeLength;
      List<int> stripOffsets = const [];
      List<int> stripByteCounts = const [];
      int compression = 0;
      int photometric = -1;
      int bitsPerSample = 8;
      bool hasJpegTables = false;
      final List<int> childIfds = [];

      final bd = ByteData.sublistView(entryBytes);
      for (int i = 0; i < numEntries; i++) {
        final entryStart = i * 12;
        final tag = bd.getUint16(entryStart, endian);
        final valOffset = bd.getUint32(entryStart + 8, endian);

        switch (tag) {
          case 0x0102: // BitsPerSample
            final vals = _readTiffIntValues(raf, bd, entryStart, endian, fileLength);
            if (vals.isNotEmpty) bitsPerSample = vals.first;
            break;
          case 0x0103: // Compression
            final vals = _readTiffIntValues(raf, bd, entryStart, endian, fileLength);
            if (vals.isNotEmpty) compression = vals.first;
            break;
          case 0x0106: // PhotometricInterpretation
            final vals = _readTiffIntValues(raf, bd, entryStart, endian, fileLength);
            if (vals.isNotEmpty) photometric = vals.first;
            break;
          case 0x0111: // StripOffsets (usato dai DNG Ricoh GR IIIx per Preview JPEG in SubIFD!)
            stripOffsets = _readTiffIntValues(raf, bd, entryStart, endian, fileLength);
            break;
          case 0x0117: // StripByteCounts
            stripByteCounts = _readTiffIntValues(raf, bd, entryStart, endian, fileLength);
            break;
          case 0x015B: // JPEGTables
            hasJpegTables = true;
            break;
          case 0x0201: // JPEGInterchangeFormat (Thumbnail / JpgFromRaw)
            jpegInterchangeOffset = valOffset;
            break;
          case 0x0202: // JPEGInterchangeFormatLength
            jpegInterchangeLength = valOffset;
            break;
          case 0x014A: // SubIFDs
            childIfds.addAll(_readTiffIntValues(raf, bd, entryStart, endian, fileLength));
            break;
          case 0x8769: // ExifIFD
            if (valOffset > 0 && valOffset < fileLength) {
              childIfds.add(valOffset);
            }
            break;
        }
      }

      _JpegCandidate? best;

      // Escludi esplicitamente array RAW a 10/12/14/16 bit o fotometrica CFA / LinearRaw
      final isRawSensorData =
          bitsPerSample > 8 || photometric == 32803 || photometric == 34892;

      // 1. Verifica candidato standard JPEGInterchangeFormat (0x0201 / 0x0202)
      if (!isRawSensorData && jpegInterchangeOffset != null && jpegInterchangeLength != null) {
        final cand = _validateCandidate(raf, jpegInterchangeOffset, jpegInterchangeLength, fileLength);
        if (cand != null && cand.isBetterThan(best)) {
          best = cand;
        }
      }

      // 2. Verifica candidato StripOffsets / StripByteCounts (DNG Preview SubIFDs con Compression 6 o 7)
      if (!isRawSensorData &&
          (compression == 6 || compression == 7 || compression == 0) &&
          stripOffsets.isNotEmpty &&
          stripByteCounts.isNotEmpty) {
        if (stripOffsets.length == 1) {
          final cand = _validateCandidate(raf, stripOffsets.first, stripByteCounts.first, fileLength);
          if (cand != null && cand.isBetterThan(best)) {
            best = cand;
          }
        } else if (!hasJpegTables && stripOffsets.length == stripByteCounts.length) {
          // Controlla se le strip formano un singolo blocco JPEG contiguo
          bool contiguous = true;
          int totalLen = stripByteCounts[0];
          for (int s = 1; s < stripOffsets.length; s++) {
            if (stripOffsets[s] != stripOffsets[s - 1] + stripByteCounts[s - 1]) {
              contiguous = false;
              break;
            }
            totalLen += stripByteCounts[s];
          }
          if (contiguous) {
            final cand = _validateCandidate(raf, stripOffsets.first, totalLen, fileLength);
            if (cand != null && cand.isBetterThan(best)) {
              best = cand;
            }
          }
        }
      }

      // 3. Esplora TUTTI i SubIFDs ed ExifIFD
      for (final childOffset in childIfds) {
        final subCand = _findBestTiffPreview(raf, childOffset, endian, fileLength, visitedIfds, depth + 1);
        if (subCand != null && subCand.isBetterThan(best)) {
          best = subCand;
        }
      }

      // 4. Prosegue SEMPRE verso nextIfdOffset (IFD1, IFD2...) anche se IFD0 aveva una piccola thumbnail!
      if (nextIfdOffset > 0) {
        final nextCand = _findBestTiffPreview(raf, nextIfdOffset, endian, fileLength, visitedIfds, depth + 1);
        if (nextCand != null && nextCand.isBetterThan(best)) {
          best = nextCand;
        }
      }

      return best;
    } catch (_) {
      return null;
    }
  }

  /// Scansione avanzata di sicurezza: legge i marker JPEG per evitare di troncarsi sui
  /// thumbnail APP1 annidati ed esclude stream RAW Lossless (SOF3).
  static Uint8List? _scanForEmbeddedJpeg(RandomAccessFile raf, int fileLength) {
    try {
      const headChunkSize = 25 * 1024 * 1024;
      const tailChunkSize = 20 * 1024 * 1024;

      raf.setPositionSync(0);
      final headLen = fileLength > headChunkSize ? headChunkSize : fileLength;
      final headBuf = raf.readSync(headLen);
      var best = _scanBufferForBestJpeg(headBuf);

      // Se il DNG è grande (> 25MB) e nella testa non abbiamo trovato una preview HD (> 320px di lato),
      // scansioniamo anche gli ultimi 20MB dove alcune fotocamere/DNG salvano la PreviewImage.
      if (fileLength > headChunkSize && (best == null || best.$2 * best.$3 < 320 * 240)) {
        final tailStart = fileLength > tailChunkSize ? fileLength - tailChunkSize : 0;
        raf.setPositionSync(tailStart);
        final tailBuf = raf.readSync(fileLength - tailStart);
        final tailBest = _scanBufferForBestJpeg(tailBuf);
        if (tailBest != null &&
            (best == null ||
                tailBest.$2 * tailBest.$3 > best.$2 * best.$3 ||
                (tailBest.$2 * tailBest.$3 == best.$2 * best.$3 && tailBest.$1.length > best.$1.length))) {
          best = tailBest;
        }
      }

      return best?.$1;
    } catch (_) {}
    return null;
  }

  static (Uint8List bytes, int width, int height)? _scanBufferForBestJpeg(Uint8List buffer) {
    int bestStart = -1;
    int bestEnd = -1;
    int bestArea = -1;
    int bestLen = 0;
    int bestW = 0;
    int bestH = 0;

    int i = 0;
    while (i < buffer.length - 10) {
      if (buffer[i] == 0xFF && buffer[i + 1] == 0xD8 && buffer[i + 2] == 0xFF) {
        final parsed = _measureJpegStream(buffer, i);
        if (parsed != null) {
          final (endOffset, w, h) = parsed;
          final len = endOffset - i;
          final area = w * h;
          if (len > 50 &&
              ((area > 0 && area > bestArea) || (area == bestArea && len > bestLen))) {
            bestStart = i;
            bestEnd = endOffset;
            bestArea = area;
            bestLen = len;
            bestW = w;
            bestH = h;
          }
          i = endOffset;
          continue;
        }
      }
      i++;
    }

    if (bestStart >= 0 && bestEnd > bestStart) {
      return (Uint8List.sublistView(buffer, bestStart, bestEnd), bestW, bestH);
    }
    return null;
  }

  /// Valida inizio FF D8 e taglia eventuale zero-padding dopo l'ultimo FF D9 in coda (alcuni DNG allineano a 4/512 byte).
  static Uint8List? _trimAndValidateJpeg(Uint8List bytes) {
    if (bytes.length < 4 || bytes[0] != 0xFF || bytes[1] != 0xD8) return null;
    if (bytes[bytes.length - 2] == 0xFF && bytes[bytes.length - 1] == 0xD9) {
      return bytes;
    }
    // Tollera fino a 64 byte di padding nullo in coda dopo EOI FF D9
    final searchStart = bytes.length > 66 ? bytes.length - 66 : 2;
    for (int i = bytes.length - 2; i >= searchStart; i--) {
      if (bytes[i] == 0xFF && bytes[i + 1] == 0xD9) {
        return Uint8List.sublistView(bytes, 0, i + 2);
      }
    }
    return null;
  }

  /// Cammina nei segmenti di un JPEG a partire da [startPos] (FF D8) fino al vero EOI (FF D9).
  /// Restituisce (endOffset, width, height) solo se è un JPEG decodificabile (SOF0/SOF1/SOF2).
  static (int endOffset, int width, int height)? _measureJpegStream(Uint8List buf, int startPos) {
    int pos = startPos + 2;
    final limit = buf.length;
    bool decodableSof = false;
    int width = 0;
    int height = 0;
    bool seenSos = false;

    while (pos + 1 < limit) {
      if (!seenSos) {
        if (buf[pos] != 0xFF) return null;
        while (pos < limit && buf[pos] == 0xFF) {
          pos++;
        }
        if (pos >= limit) return null;
        final marker = buf[pos];
        pos++;

        if (marker == 0xD9) {
          return decodableSof ? (pos, width, height) : null;
        }
        if (marker == 0x00 || marker == 0x01 || (marker >= 0xD0 && marker <= 0xD8)) {
          continue;
        }
        if (pos + 1 >= limit) return null;
        final segLen = (buf[pos] << 8) | buf[pos + 1];
        if (segLen < 2 || pos + segLen > limit) return null;

        if (marker == 0xC0 || marker == 0xC1 || marker == 0xC2) {
          decodableSof = true;
          if (pos + 6 < limit) {
            height = (buf[pos + 3] << 8) | buf[pos + 4];
            width = (buf[pos + 5] << 8) | buf[pos + 6];
          }
        } else if (marker == 0xC3 ||
            marker == 0xC5 ||
            marker == 0xC6 ||
            marker == 0xC7 ||
            marker == 0xC9 ||
            marker == 0xCA ||
            marker == 0xCB ||
            marker == 0xCD ||
            marker == 0xCE ||
            marker == 0xCF) {
          // Stream Lossless JPEG (es. DNG RAW) -> Rifiuta subito!
          return null;
        }

        pos += segLen;
        if (marker == 0xDA) {
          if (!decodableSof) return null;
          seenSos = true;
        }
      } else {
        // Dentro lo stream SOS compresso: cerca FF D9 (ignorando byte-stuffing FF 00 e RST FF D0..D7)
        if (buf[pos] == 0xFF) {
          final next = buf[pos + 1];
          if (next == 0xD9) {
            return (pos + 2, width, height);
          }
          if (next == 0x00 || (next >= 0xD0 && next <= 0xD7) || next == 0xFF) {
            pos += (next == 0xFF) ? 1 : 2;
            continue;
          }
          // Altri marker validi dopo EOI mancante o marker restart
          pos += 2;
          continue;
        }
        pos++;
      }
    }
    return null;
  }

  static void _validateJpegMarkers(Uint8List bytes) {
    if (bytes.length < 4 ||
        bytes[0] != 0xFF ||
        bytes[1] != 0xD8 ||
        bytes[bytes.length - 2] != 0xFF ||
        bytes[bytes.length - 1] != 0xD9) {
      throw const RawCorruptedException('Marcatori JPEG (0xFFD8 o 0xFFD9) non corrispondenti');
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
