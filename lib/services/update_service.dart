import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'saf_service.dart';

/// Informazioni su un aggiornamento disponibile su GitHub Releases.
class UpdateInfo {
  final String currentVersion;
  final String latestVersion;
  final String releaseNotes;
  final String assetName;
  final String downloadUrl;
  final int assetSize;
  final String htmlUrl;

  const UpdateInfo({
    required this.currentVersion,
    required this.latestVersion,
    required this.releaseNotes,
    required this.assetName,
    required this.downloadUrl,
    required this.assetSize,
    required this.htmlUrl,
  });
}

class UpdateService {
  /// Deve rimanere allineata alla versione definita in pubspec.yaml (senza +build).
  static const String appVersion = '1.2.2';
  static const String repoOwner = 'NewtonH725';
  static const String repoName = 'raw-manager';
  static const String latestReleaseEndpoint =
      'https://api.github.com/repos/$repoOwner/$repoName/releases/latest';

  /// Restituisce la versione corrente dell'app installata.
  static Future<String> getCurrentVersion() async {
    if (!kIsWeb && Platform.isAndroid) {
      final info = await SafService.getAppInfo();
      if (info != null && info['version'] != null && info['version']!.isNotEmpty) {
        return info['version']!;
      }
    }
    return appVersion;
  }

  /// Confronta due stringhe SemVer (es. "v1.2.0" > "1.1.0").
  static bool isNewerVersion(String remoteTag, String localVersion) {
    final remoteParts = _parseVersion(remoteTag);
    final localParts = _parseVersion(localVersion);

    final maxLen = remoteParts.length > localParts.length ? remoteParts.length : localParts.length;
    for (int i = 0; i < maxLen; i++) {
      final r = i < remoteParts.length ? remoteParts[i] : 0;
      final l = i < localParts.length ? localParts[i] : 0;
      if (r > l) return true;
      if (r < l) return false;
    }
    return false;
  }

  static List<int> _parseVersion(String versionStr) {
    var clean = versionStr.trim();
    if (clean.startsWith('v') || clean.startsWith('V')) {
      clean = clean.substring(1);
    }
    // Rimuove eventuali suffissi build (+1) o pre-release (-beta)
    clean = clean.split('+').first.split('-').first;
    return clean.split('.').map((part) => int.tryParse(part) ?? 0).toList();
  }

  /// Controlla silenziosamente se esiste una release più recente su GitHub.
  /// Restituisce null in caso di assenza di rete, timeout o nessuna nuova versione.
  static Future<UpdateInfo?> checkForUpdates() async {
    if (kIsWeb || Platform.environment.containsKey('FLUTTER_TEST')) return null;

    final client = HttpClient()..connectionTimeout = const Duration(seconds: 4);
    try {
      final current = await getCurrentVersion();
      final request = await client
          .getUrl(Uri.parse(latestReleaseEndpoint))
          .timeout(const Duration(seconds: 5));

      request.headers.set(HttpHeaders.userAgentHeader, 'RAW-Manager-Updater/$current');
      request.headers.set(HttpHeaders.acceptHeader, 'application/vnd.github+json');

      final response = await request.close().timeout(const Duration(seconds: 5));
      if (response.statusCode != 200) {
        return null;
      }

      final bodyStr = await response.transform(utf8.decoder).join().timeout(const Duration(seconds: 5));
      final Map<String, dynamic> data = jsonDecode(bodyStr) as Map<String, dynamic>;

      final tagName = (data['tag_name'] as String?) ?? '';
      if (tagName.isEmpty || !isNewerVersion(tagName, current)) {
        return null;
      }

      final assets = (data['assets'] as List<dynamic>?) ?? const [];
      final matchedAsset = _selectPlatformAsset(assets);
      if (matchedAsset == null) {
        return null;
      }

      return UpdateInfo(
        currentVersion: current,
        latestVersion: tagName.startsWith('v') ? tagName.substring(1) : tagName,
        releaseNotes: ((data['body'] as String?) ?? '').trim(),
        assetName: matchedAsset['name'] as String,
        downloadUrl: matchedAsset['browser_download_url'] as String,
        assetSize: (matchedAsset['size'] as int?) ?? 0,
        htmlUrl: (data['html_url'] as String?) ?? '',
      );
    } catch (e) {
      debugPrint('Controllo aggiornamenti saltato (offline/errore): $e');
      return null;
    } finally {
      client.close(force: true);
    }
  }

  static Map<String, dynamic>? _selectPlatformAsset(List<dynamic> assets) {
    final parsed = assets.whereType<Map>().map((m) => Map<String, dynamic>.from(m)).toList();

    if (Platform.isAndroid) {
      for (final a in parsed) {
        final name = (a['name'] as String? ?? '').toLowerCase();
        if (name.endsWith('.apk')) return a;
      }
    } else if (Platform.isWindows) {
      // Preferisce sempre il file di Setup installabile
      for (final a in parsed) {
        final name = (a['name'] as String? ?? '').toLowerCase();
        if (name.endsWith('setup.exe') || name.endsWith('.exe')) return a;
      }
      for (final a in parsed) {
        final name = (a['name'] as String? ?? '').toLowerCase();
        if (name.contains('windows') && name.endsWith('.zip')) return a;
      }
    } else if (Platform.isLinux) {
      for (final a in parsed) {
        final name = (a['name'] as String? ?? '').toLowerCase();
        if (name.endsWith('.tar.gz') && (name.contains('linux') || name.contains('ubuntu'))) {
          return a;
        }
      }
    }
    return null;
  }

  /// Determina il percorso locale appropriato dove scaricare il file aggiornato.
  static Future<String> _resolveDownloadPath(String fileName) async {
    if (Platform.isAndroid) {
      final info = await SafService.getAppInfo();
      final cacheDir = info?['cacheDir'];
      if (cacheDir != null && cacheDir.isNotEmpty) {
        return p.join(cacheDir, fileName);
      }
      return p.join(Directory.systemTemp.path, fileName);
    }

    final home = Platform.environment['USERPROFILE'] ?? Platform.environment['HOME'];
    if (home != null) {
      for (final sub in ['Scaricati', 'Downloads']) {
        final candidate = Directory(p.join(home, sub));
        if (await candidate.exists()) {
          return p.join(candidate.path, fileName);
        }
      }
    }
    return p.join(Directory.systemTemp.path, fileName);
  }

  /// Scarica l'aggiornamento con notifica progressiva di avanzamento (0.0 -> 1.0).
  static Future<String> downloadUpdate(
    UpdateInfo info,
    void Function(double progress, int receivedBytes, int totalBytes) onProgress,
  ) async {
    final targetPath = await _resolveDownloadPath(info.assetName);
    final file = File(targetPath);
    if (await file.exists()) {
      await file.delete();
    }

    final client = HttpClient()..autoUncompress = false;
    try {
      final request = await client.getUrl(Uri.parse(info.downloadUrl));
      request.headers.set(HttpHeaders.userAgentHeader, 'RAW-Manager-Updater/${info.currentVersion}');
      final response = await request.close();

      if (response.statusCode < 200 || response.statusCode >= 400) {
        throw HttpException('Download fallito (HTTP ${response.statusCode})');
      }

      final totalBytes = response.contentLength > 0 ? response.contentLength : info.assetSize;
      int received = 0;

      final sink = file.openWrite();
      try {
        await for (final chunk in response) {
          sink.add(chunk);
          received += chunk.length;
          final progress = totalBytes > 0 ? (received / totalBytes).clamp(0.0, 1.0) : 0.0;
          onProgress(progress, received, totalBytes);
        }
        await sink.flush();
      } finally {
        await sink.close();
      }

      return targetPath;
    } finally {
      client.close(force: true);
    }
  }

  /// Applica o avvia l'aggiornamento scaricato in base al sistema operativo.
  /// Restituisce un messaggio descrittivo sull'esito dell'operazione.
  static Future<String> applyUpdate(String downloadedPath) async {
    if (Platform.isAndroid) {
      final ok = await SafService.installApk(downloadedPath);
      if (ok) {
        return 'Procedura di installazione avviata su Android.';
      }
      throw Exception('Impossibile aprire l\'installer Android per il pacchetto.');
    }

    if (Platform.isWindows) {
      if (downloadedPath.toLowerCase().endsWith('.exe')) {
        await Process.start(downloadedPath, [], mode: ProcessStartMode.detached);
        // Chiude l'app attuale per permettere al Setup di sostituire i file
        Future.delayed(const Duration(milliseconds: 500), () => exit(0));
        return 'Setup avviato! Chiusura di RAW Manager in corso...';
      } else {
        await Process.start('explorer.exe', ['/select,', downloadedPath], mode: ProcessStartMode.detached);
        return 'Pacchetto scaricato in: $downloadedPath';
      }
    }

    if (Platform.isLinux) {
      final home = Platform.environment['HOME'];
      if (home != null) {
        final installDir = Directory(p.join(home, '.local', 'share', 'raw-manager'));
        if (await installDir.exists() && downloadedPath.endsWith('.tar.gz')) {
          final res = await Process.run(
            'tar',
            ['-xzf', downloadedPath, '--strip-components=1', '-C', installDir.path],
          );
          if (res.exitCode == 0) {
            final exePath = p.join(installDir.path, 'raw_manager');
            await Process.start(exePath, [], mode: ProcessStartMode.detached);
            Future.delayed(const Duration(milliseconds: 500), () => exit(0));
            return 'Aggiornamento completato! Riavvio dell\'applicazione in corso...';
          }
        }
      }
      // Fallback: apre la cartella Download
      await Process.start('xdg-open', [p.dirname(downloadedPath)], mode: ProcessStartMode.detached);
      return 'Archivio scaricato in: $downloadedPath';
    }

    return 'File scaricato in: $downloadedPath';
  }
}
