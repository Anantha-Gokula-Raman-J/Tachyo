import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'src/app_info.dart';
import 'src/platform/meter_platform.dart';
import 'src/platform/native_bridge.dart';
import 'src/speedtest/speed_test_controller.dart';
import 'src/state/meter_controller.dart';
import 'src/ui/app.dart';

void main(List<String> args) {
  WidgetsFlutterBinding.ensureInitialized();
  LicenseRegistry.addLicense(() async* {
    yield const LicenseEntryWithLineBreaks(['Astryx design tokens'], astryxLicense);
  });

  final bridge = NativeBridge();
  final MeterPlatform platform = Platform.isWindows
      ? WindowsMeterPlatform(bridge, WindowsMeterPlatform.defaultDataDir())
      : AndroidMeterPlatform(bridge);

  // Windows sign-in entry passes --background (windows/runner/main.cpp).
  final controller = MeterController(platform)..start(background: args.contains('--background'));
  final speedTest = SpeedTestController(history: platform.speedTests);
  runApp(TachyoApp(controller: controller, speedTest: speedTest));
}
