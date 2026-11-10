import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raw_manager/models/raf_photo.dart';
import 'package:raw_manager/ui/screens/culler_screen.dart';
import 'package:raw_manager/ui/widgets/hud_overlay.dart';
import 'package:raw_manager/ui/widgets/info_dialog.dart';

Future<void> saveRepaintBoundary(GlobalKey key, String outputPath) async {
  RenderRepaintBoundary boundary =
      key.currentContext!.findRenderObject() as RenderRepaintBoundary;
  ui.Image img = await boundary.toImage(pixelRatio: 1.0);
  ByteData? byteData = await img.toByteData(format: ui.ImageByteFormat.png);
  File(outputPath).writeAsBytesSync(byteData!.buffer.asUint8List());
  print('[OK] Creato $outputPath');
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('Screenshot 1 - Schermata Iniziale', (tester) async {
    tester.view.physicalSize = const Size(1920, 1080);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.resetPhysicalSize());

    final key = GlobalKey();
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: ThemeData.dark().copyWith(
            scaffoldBackgroundColor: const Color(0xFF121212),
            colorScheme: const ColorScheme.dark(primary: Colors.amber),
          ),
          home: Scaffold(
            backgroundColor: const Color(0xFF121212),
            body: RepaintBoundary(key: key, child: const CullerScreen()),
          ),
        ),
      ),
    );
    await tester.pump();
    await saveRepaintBoundary(key, 'docs/images/01_schermata_iniziale.png');
  });

  testWidgets('Screenshot 2 - Schermata Culling Foto', (tester) async {
    tester.view.physicalSize = const Size(1920, 1080);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.resetPhysicalSize());

    final key = GlobalKey();
    const photo = RafPhoto(
      path: '/storage/DCIM/101_FUJI/DSCF2341.RAF',
      fileName: 'DSCF2341.RAF',
      isCopied: false,
    );

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: ThemeData.dark().copyWith(
            scaffoldBackgroundColor: const Color(0xFF121212),
            colorScheme: const ColorScheme.dark(primary: Colors.amber),
          ),
          home: Scaffold(
            backgroundColor: const Color(0xFF121212),
            body: RepaintBoundary(
              key: key,
              child: Column(
                children: [
                  HudOverlay(
                    currentPhoto: photo,
                    extractedData: null,
                    onPickSource: () {},
                    onPickTarget: () {},
                  ),
                  Expanded(
                    child: Stack(
                      children: [
                        Positioned.fill(
                          child: Container(
                            color: const Color(0xFF181818),
                            child: Center(
                              child: Container(
                                margin: const EdgeInsets.all(24),
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: Colors.white10),
                                  gradient: const LinearGradient(
                                    begin: Alignment.topCenter,
                                    end: Alignment.bottomCenter,
                                    colors: [Color(0xFF2C3E50), Color(0xFF1A1A1A)],
                                  ),
                                ),
                                child: const Center(
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(Icons.camera_alt_outlined, size: 96, color: Colors.white24),
                                      SizedBox(height: 16),
                                      Text(
                                        'FUJIFILM X-T5 • 40.2 MP (DSCF2341.RAF)',
                                        style: TextStyle(color: Colors.white54, fontSize: 22, fontWeight: FontWeight.bold),
                                      ),
                                      SizedBox(height: 8),
                                      Text(
                                        'Anteprima estratta in 6ms con decodifica hardware ad alta fedeltà',
                                        style: TextStyle(color: Colors.white30, fontSize: 14),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                        // Bottom control bar
                        Positioned(
                          bottom: 24,
                          left: 0,
                          right: 0,
                          child: Center(
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                              decoration: BoxDecoration(
                                color: const Color(0xDD1E1E1E),
                                borderRadius: BorderRadius.circular(32),
                                border: Border.all(color: Colors.white12),
                                boxShadow: const [
                                  BoxShadow(color: Colors.black45, blurRadius: 12, offset: Offset(0, 4)),
                                ],
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  IconButton(
                                    icon: const Icon(Icons.arrow_back_ios_new, size: 20),
                                    color: Colors.white70,
                                    onPressed: () {},
                                  ),
                                  const SizedBox(width: 12),
                                  IconButton(
                                    icon: const Icon(Icons.delete_outline, color: Colors.redAccent, size: 24),
                                    onPressed: () {},
                                  ),
                                  const SizedBox(width: 12),
                                  FloatingActionButton.small(
                                    backgroundColor: Colors.green.shade700,
                                    foregroundColor: Colors.white,
                                    onPressed: () {},
                                    child: const Icon(Icons.check, size: 24),
                                  ),
                                  const SizedBox(width: 12),
                                  IconButton(
                                    icon: const Icon(Icons.zoom_in, color: Colors.white70, size: 24),
                                    onPressed: () {},
                                  ),
                                  const SizedBox(width: 12),
                                  IconButton(
                                    icon: const Icon(Icons.arrow_forward_ios, size: 20),
                                    color: Colors.white70,
                                    onPressed: () {},
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    await saveRepaintBoundary(key, 'docs/images/02_schermata_culling.png');
  });

  testWidgets('Screenshot 3 - Foto Selezionata', (tester) async {
    tester.view.physicalSize = const Size(1920, 1080);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.resetPhysicalSize());

    final key = GlobalKey();
    const photoSelected = RafPhoto(
      path: '/storage/DCIM/101_FUJI/DSCF2341.RAF',
      fileName: 'DSCF2341.RAF',
      isCopied: true,
    );

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: ThemeData.dark().copyWith(
            scaffoldBackgroundColor: const Color(0xFF121212),
            colorScheme: const ColorScheme.dark(primary: Colors.amber),
          ),
          home: Scaffold(
            backgroundColor: const Color(0xFF121212),
            body: RepaintBoundary(
              key: key,
              child: Column(
                children: [
                  HudOverlay(
                    currentPhoto: photoSelected,
                    extractedData: null,
                    onPickSource: () {},
                    onPickTarget: () {},
                  ),
                  Expanded(
                    child: Container(
                      color: const Color(0xFF181818),
                      child: Center(
                        child: Container(
                          margin: const EdgeInsets.all(24),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.green.shade700, width: 3),
                            gradient: const LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [Color(0xFF1E3A2A), Color(0xFF121E17)],
                            ),
                          ),
                          child: Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.check_circle_rounded, size: 96, color: Colors.green.shade400),
                                const SizedBox(height: 16),
                                const Text(
                                  'FILE RAW SELEZIONATO PER LA COPIA',
                                  style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold),
                                ),
                                const SizedBox(height: 8),
                                const Text(
                                  'DSCF2341.RAF accodato per il trasferimento ad alta velocità nella cartella Target',
                                  style: TextStyle(color: Colors.white60, fontSize: 14),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    await saveRepaintBoundary(key, 'docs/images/03_foto_selezionata.png');
  });

  testWidgets('Screenshot 4 - Info Dialog', (tester) async {
    tester.view.physicalSize = const Size(1920, 1080);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.resetPhysicalSize());

    final key = GlobalKey();
    await tester.pumpWidget(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: ThemeData.dark().copyWith(
          scaffoldBackgroundColor: const Color(0xFF121212),
          colorScheme: const ColorScheme.dark(primary: Colors.amber),
        ),
        home: Scaffold(
          backgroundColor: const Color(0xFF121212),
          body: RepaintBoundary(
            key: key,
            child: const Center(
              child: SizedBox(
                width: 580,
                child: InfoDialog(),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    await saveRepaintBoundary(key, 'docs/images/04_dialog_informazioni.png');
  });
}
