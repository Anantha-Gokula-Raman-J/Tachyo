// Renders the Tachyo logo (lib/src/ui/widgets/app_logo.dart) to PNG masters.
// Run: flutter test tool/render_icon_test.dart   then   tool/make_icons.ps1
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tachyo/src/ui/widgets/app_logo.dart';

Future<void> _render(String path, int size, LogoPainter painter, {Color? background}) async {
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder);
  if (background != null) {
    canvas.drawRect(Rect.fromLTWH(0, 0, size.toDouble(), size.toDouble()), Paint()..color = background);
  }
  painter.paint(canvas, Size.square(size.toDouble()));
  final image = await recorder.endRecording().toImage(size, size);
  final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
  final file = File(path)..createSync(recursive: true);
  file.writeAsBytesSync(bytes!.buffer.asUint8List());
}

void main() {
  test('render icon masters', () async {
    // Full icon with rounded tile (Windows, legacy Android, store listing).
    await _render('assets/icon/tachyo_icon.png', 1024, const LogoPainter());
    // Adaptive icon foreground: mark only, inside the 66% safe zone.
    await _render('assets/icon/tachyo_foreground.png', 432, const LogoPainter(withTile: false, contentScale: 0.62));
    expect(File('assets/icon/tachyo_icon.png').existsSync(), isTrue);
  });
}
