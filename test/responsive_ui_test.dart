import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raw_manager/ui/screens/culler_screen.dart';

void main() {
  testWidgets('UI Responsive - Google Pixel 9 Pro XL (412x915) senza overflow e con testo centrato', (tester) async {
    tester.view.physicalSize = const Size(412, 915);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.resetPhysicalSize());

    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(
          home: CullerScreen(),
        ),
      ),
    );
    await tester.pump();

    // Verifica presenza testi centrati
    final titleWidget = tester.widget<Text>(find.text('Nessun file RAW caricato'));
    expect(titleWidget.textAlign, TextAlign.center);

    final subtitleFinder = find.textContaining('Seleziona una cartella contenente file RAW');
    final subtitleWidget = tester.widget<Text>(subtitleFinder);
    expect(subtitleWidget.textAlign, TextAlign.center);

    // Verifica presenza controlli compatti della top bar (Auto chip al posto di Auto-Advance esteso)
    expect(find.text('Auto'), findsOneWidget);
    expect(find.text('Auto-Advance'), findsNothing);
    expect(find.text('Apri Cartella RAW'), findsOneWidget);
  });

  testWidgets('UI Responsive - Samsung Galaxy Tab S10 Ultra (1480x920) usa layout esteso', (tester) async {
    tester.view.physicalSize = const Size(1480, 920);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.resetPhysicalSize());

    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(
          home: CullerScreen(),
        ),
      ),
    );
    await tester.pump();

    // Verifica presenza layout esteso da tablet/desktop
    expect(find.text('Auto-Advance'), findsOneWidget);
    expect(find.text('Seleziona Target'), findsOneWidget);
  });
}
