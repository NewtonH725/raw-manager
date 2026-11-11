import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

class SafService {
  static const MethodChannel _channel = MethodChannel('com.example.raw_manager/saf');

  static bool get isAndroid => !kIsWeb && Platform.isAndroid;

  /// Apre il selettore di cartella nativo di Android (SAF) con supporto completo a schede SD e USB OTG.
  static Future<String?> pickDirectoryUri() async {
    if (!isAndroid) return null;
    try {
      final String? treeUri = await _channel.invokeMethod('openDocumentTree');
      return treeUri;
    } on PlatformException catch (e) {
      debugPrint('Errore pickDirectoryUri SAF: $e');
      return null;
    }
  }

  /// Scansiona ricorsivamente tutti i file RAW (.raf, .dng, .arw, ecc.) all'interno dell'URI SAF.
  static Future<List<Map<String, dynamic>>> listRawFiles(String treeUri) async {
    if (!isAndroid) return [];
    try {
      final List<dynamic>? result = await _channel.invokeMethod('listRawFiles', {
        'treeUri': treeUri,
      });
      if (result == null) return [];
      return result.map((item) => Map<String, dynamic>.from(item as Map)).toList();
    } on PlatformException catch (e) {
      debugPrint('Errore listRawFiles SAF: $e');
      rethrow;
    }
  }

  /// Estrae i byte dell'anteprima JPEG dal file RAW puntato dall'URI SAF direttamente via FileDescriptor.
  static Future<Uint8List?> extractRawBytes(String fileUri) async {
    if (!isAndroid) return null;
    try {
      final Uint8List? bytes = await _channel.invokeMethod('extractRawBytes', {
        'uri': fileUri,
      });
      return bytes;
    } on PlatformException catch (e) {
      debugPrint('Errore extractRawBytes SAF: $e');
      return null;
    }
  }

  /// Copia un file RAW sorgente nella cartella target specificata via SAF.
  static Future<bool> copyRawFile({
    required String sourceUri,
    required String targetTreeUri,
    required String fileName,
  }) async {
    if (!isAndroid) return false;
    try {
      final bool? success = await _channel.invokeMethod('copyRawFile', {
        'sourceUri': sourceUri,
        'targetTreeUri': targetTreeUri,
        'fileName': fileName,
      });
      return success ?? false;
    } on PlatformException catch (e) {
      debugPrint('Errore copyRawFile SAF: $e');
      return false;
    }
  }

  /// Elimina un file RAW dato il suo URI SAF.
  static Future<bool> deleteRawFile(String fileUri) async {
    if (!isAndroid) return false;
    try {
      final bool? success = await _channel.invokeMethod('deleteRawFile', {
        'uri': fileUri,
      });
      return success ?? false;
    } on PlatformException catch (e) {
      debugPrint('Errore deleteRawFile SAF: $e');
      return false;
    }
  }

  /// Restituisce versione app installata e directory cache scrivibile su Android.
  static Future<Map<String, String>?> getAppInfo() async {
    if (!isAndroid) return null;
    try {
      final Map<dynamic, dynamic>? info = await _channel.invokeMethod('getAppInfo');
      if (info == null) return null;
      return info.map((k, v) => MapEntry(k.toString(), v.toString()));
    } catch (e) {
      debugPrint('Errore getAppInfo: $e');
      return null;
    }
  }

  /// Avvia l'installer nativo di Android per un file APK scaricato localmente.
  static Future<bool> installApk(String filePath) async {
    if (!isAndroid) return false;
    try {
      final bool? launched = await _channel.invokeMethod('installApk', {
        'filePath': filePath,
      });
      return launched ?? false;
    } catch (e) {
      debugPrint('Errore installApk: $e');
      return false;
    }
  }

  /// Estrae il riepilogo EXIF nativo (utile per DNG Ricoh la cui anteprima interna non contiene APP1 EXIF).
  static Future<String?> extractExifSummary(String fileUri) async {
    if (!isAndroid) return null;
    try {
      final String? summary = await _channel.invokeMethod('extractExifSummary', {
        'uri': fileUri,
      });
      return summary;
    } catch (e) {
      debugPrint('Errore extractExifSummary SAF: $e');
      return null;
    }
  }
}
