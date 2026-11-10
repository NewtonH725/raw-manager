import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:raw_manager/providers/culler_provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('Lo stato del culler sopravvive al caricamento delle anteprime in cache', () async {
    final syntheticDir = p.join(Directory.current.path, '.tmp', 'synthetic_rafs');
    final container = ProviderContainer();
    addTearDown(container.dispose);

    // Mantiene vivo il provider come farebbe la UI
    final sub = container.listen(cullerProvider, (_, _) {});
    addTearDown(sub.close);

    await container.read(cullerProvider.notifier).setSourceFolder(syntheticDir);
    final foundCount = container.read(cullerProvider).photos.length;
    expect(foundCount, greaterThan(0));

    // Attende che la cache estragga le anteprime (provoca notifyListeners)
    await Future.delayed(const Duration(seconds: 2));

    expect(container.read(cullerProvider).photos.length, equals(foundCount),
        reason: 'La lista foto non deve azzerarsi quando la cache notifica');
  });
}
