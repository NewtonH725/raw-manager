import 'dart:async';
import 'package:flutter/foundation.dart';
import 'raf_extractor.dart';

/// Gestore di memoria a finestra scorrevole [i-2, i+3] per immagini .RAF Fujifilm.
class ImageCacheManager extends ChangeNotifier {
  static const int backwardWindow = 2;
  static const int forwardWindow = 3;

  final Map<int, ExtractedRafData> _cache = {};
  final Map<int, Future<ExtractedRafData>> _inFlight = {};
  int _currentIndex = -1;

  Map<int, ExtractedRafData> get cache => _cache;
  int get currentIndex => _currentIndex;

  ExtractedRafData? getCached(int index) => _cache[index];

  /// Aggiorna l'indice corrente e ricalcola la finestra attiva [i-2, i+3].
  Future<void> updateActiveIndex(int index, List<String> allFilePaths) async {
    if (allFilePaths.isEmpty) {
      clear();
      return;
    }

    _currentIndex = index.clamp(0, allFilePaths.length - 1);
    final minIndex = (_currentIndex - backwardWindow).clamp(0, allFilePaths.length - 1);
    final maxIndex = (_currentIndex + forwardWindow).clamp(0, allFilePaths.length - 1);

    final activeIndices = <int>{};
    for (int i = minIndex; i <= maxIndex; i++) {
      activeIndices.add(i);
    }

    // 1. Eviction: Rimuovi elementi fuori dalla finestra attiva
    _cache.removeWhere((idx, _) => !activeIndices.contains(idx));
    _inFlight.removeWhere((idx, _) => !activeIndices.contains(idx));

    // 2. Priorità di caricamento: prima l'indice corrente, poi +1, poi -1, poi +2, +3, -2
    final loadOrder = <int>[];
    if (activeIndices.contains(_currentIndex)) loadOrder.add(_currentIndex);
    for (int offset = 1; offset <= forwardWindow; offset++) {
      final fwd = _currentIndex + offset;
      if (activeIndices.contains(fwd)) loadOrder.add(fwd);
      final bwd = _currentIndex - offset;
      if (activeIndices.contains(bwd)) loadOrder.add(bwd);
    }

    // 3. Pre-fetching asincrono parallelo
    for (final idx in loadOrder) {
      if (!_cache.containsKey(idx) && !_inFlight.containsKey(idx)) {
        _fetchIndex(idx, allFilePaths[idx]);
      }
    }
  }

  void _fetchIndex(int index, String filePath) {
    final future = RafExtractor.extractRaf(filePath);
    _inFlight[index] = future;

    future.then((data) {
      final wasInFlight = _inFlight.remove(index) != null;
      if (!wasInFlight) return;

      // Salva in cache solo se l'indice è ancora compreso nella finestra attiva
      final minIndex = (_currentIndex - backwardWindow);
      final maxIndex = (_currentIndex + forwardWindow);
      if (index >= minIndex && index <= maxIndex) {
        _cache[index] = data;
        notifyListeners();
      }
    }).catchError((error) {
      _inFlight.remove(index);
      debugPrint('Errore estrazione RAF su indice $index ($filePath): $error');
      notifyListeners();
    });
  }

  void clear() {
    _cache.clear();
    _inFlight.clear();
    _currentIndex = -1;
    notifyListeners();
  }

  @override
  void dispose() {
    clear();
    super.dispose();
  }
}
