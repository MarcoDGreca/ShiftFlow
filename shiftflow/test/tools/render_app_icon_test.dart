// Generatore delle icone dell'app a partire dal logo CustomPaint.
//
// Non è un test di verifica: è uno strumento che sfrutta flutter_test per
// disegnare `ShiftFlowLogo` su un canvas e salvarlo come PNG. Così l'icona
// launcher, l'adaptive icon Android e il logo dello splash derivano tutti
// dallo STESSO disegno vettoriale, senza tool esterni.
//
// Uso:  flutter test test/tools/render_app_icon_test.dart
// Poi:  dart run flutter_launcher_icons && dart run flutter_native_splash:create
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shiftflow/core/branding/shiftflow_logo.dart';
import 'package:shiftflow/core/theme/app_colors.dart';

Future<void> _render(
  WidgetTester tester,
  Widget content,
  double size,
  String path,
) async {
  final key = GlobalKey();
  await tester.binding.setSurfaceSize(Size(size, size));
  tester.view.physicalSize = Size(size, size);
  tester.view.devicePixelRatio = 1.0;

  await tester.pumpWidget(
    Directionality(
      textDirection: TextDirection.ltr,
      child: Center(
        child: RepaintBoundary(
          key: key,
          child: SizedBox(width: size, height: size, child: content),
        ),
      ),
    ),
  );
  await tester.pump();

  final boundary =
      key.currentContext!.findRenderObject()! as RenderRepaintBoundary;

  // toImage/toByteData sono asincroni "veri": vanno eseguiti in runAsync,
  // fuori dal tempo finto dei test.
  await tester.runAsync(() async {
    final image = await boundary.toImage();
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    final file = File(path);
    file.parent.createSync(recursive: true);
    file.writeAsBytesSync(bytes!.buffer.asUint8List());
  });
}

void main() {
  testWidgets('genera le icone app e i loghi splash in assets/icon/', (
    tester,
  ) async {
    const gradient = LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [AppColors.emerald600, AppColors.emerald900],
    );

    // 1. Icona iOS / base: logo bianco su gradiente smeraldo, a tutto campo.
    await tester.runAsync(() async {});
    await _render(
      tester,
      const DecoratedBox(
        decoration: BoxDecoration(gradient: gradient),
        child: Center(child: ShiftFlowLogo(size: 716, monochrome: true)),
      ),
      1024,
      'assets/icon/app_icon.png',
    );

    // 2. Livello foreground dell'adaptive icon Android: solo il logo,
    //    al ~55% per restare nella "safe zone" (66/108 dp).
    await _render(
      tester,
      const Center(child: ShiftFlowLogo(size: 563, monochrome: true)),
      1024,
      'assets/icon/app_icon_foreground.png',
    );

    // 3. Sfondo dell'adaptive icon: solo il gradiente.
    await _render(
      tester,
      const DecoratedBox(decoration: BoxDecoration(gradient: gradient)),
      1024,
      'assets/icon/app_icon_bg.png',
    );

    // 4. Livello monochrome (icona "a tema" di Android 13+): silhouette.
    await _render(
      tester,
      const Center(child: ShiftFlowLogo(size: 563, monochrome: true)),
      1024,
      'assets/icon/app_icon_monochrome.png',
    );

    // 5. Logo per lo splash chiaro (colori del brand su sfondo trasparente).
    await _render(
      tester,
      const Center(child: ShiftFlowLogo(size: 640)),
      768,
      'assets/icon/splash_logo.png',
    );

    // 6. Logo per lo splash scuro: silhouette smeraldo chiara.
    await _render(
      tester,
      const Center(
        child: ShiftFlowLogo(
          size: 640,
          monochrome: true,
          monochromeColor: AppColors.emerald200,
        ),
      ),
      768,
      'assets/icon/splash_logo_dark.png',
    );

    // Ripristina la dimensione di default per eventuali altri test.
    await tester.binding.setSurfaceSize(null);
  });
}
