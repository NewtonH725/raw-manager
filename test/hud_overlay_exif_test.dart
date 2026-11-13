import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raw_manager/models/raf_photo.dart';
import 'package:raw_manager/services/raf_extractor.dart';
import 'package:raw_manager/ui/widgets/hud_overlay.dart';

void main() {
  Widget buildHudHarness({
    required Size size,
    required RafPhoto photo,
    required ExtractedRafData extractedData,
  }) {
    return ProviderScope(
      child: MaterialApp(
        home: MediaQuery(
          data: MediaQueryData(size: size),
          child: Scaffold(
            backgroundColor: Colors.black,
            body: Stack(
              children: [
                HudOverlay(
                  currentPhoto: photo,
                  extractedData: extractedData,
                  onPickSource: () {},
                  onPickTarget: () {},
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  testWidgets('Smartphone layout (412x915) mostra tutti i dati EXIF senza tagliare ISO', (tester) async {
    const size = Size(412, 915);
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final photo = RafPhoto(
      path: '/storage/emulated/0/DCIM/R0000188.DNG',
      fileName: 'R0000188.DNG',
      isCopied: true,
    );
    final extractedData = ExtractedRafData(
      jpegBytes: Uint8List(0),
      exifData: const {},
      exifSummary: 'RICOH GR IIIx • 1/320s • f/2.8 • ISO 5000 • 26.1mm',
    );

    await tester.pumpWidget(
      buildHudHarness(size: size, photo: photo, extractedData: extractedData),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);

    for (final expected in ['R0000188.DNG', 'RICOH GR IIIx', '1/320s', 'f/2.8', 'ISO 5000', '26.1mm']) {
      final finder = find.text(expected);
      expect(finder, findsOneWidget, reason: 'Manca il campo "$expected" nella HUD smartphone');

      final textWidget = tester.widget<Text>(finder);
      expect(textWidget.overflow, isNot(TextOverflow.ellipsis),
          reason: 'Il campo "$expected" non deve usare ellissi in vista smartphone');

      final rect = tester.getRect(finder);
      expect(rect.left, greaterThanOrEqualTo(0.0));
      expect(rect.right, lessThanOrEqualTo(size.width));
    }
  });

  testWidgets('Tablet layout (1480x920) mostra riepilogo EXIF completo senza overflow', (tester) async {
    const size = Size(1480, 920);
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final photo = RafPhoto(
      path: '/storage/emulated/0/DCIM/R0000188.DNG',
      fileName: 'R0000188.DNG',
      isCopied: false,
    );
    final extractedData = ExtractedRafData(
      jpegBytes: Uint8List(0),
      exifData: const {},
      exifSummary: 'RICOH GR IIIx • 1/320s • f/2.8 • ISO 5000 • 26.1mm',
    );

    await tester.pumpWidget(
      buildHudHarness(size: size, photo: photo, extractedData: extractedData),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('RICOH GR IIIx • 1/320s • f/2.8 • ISO 5000 • 26.1mm'), findsOneWidget);
  });
}
