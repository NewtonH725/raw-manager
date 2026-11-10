import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raw_manager/main.dart';

void main() {
  testWidgets('Smoke test per inizializzazione RawManagerApp', (WidgetTester tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: RawManagerApp(),
      ),
    );

    // Verifica che il titolo dell'app o la UI principale vengano renderizzati
    expect(find.text('RAW Manager'), findsOneWidget);
  });
}
