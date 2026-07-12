// ignore_for_file: deprecated_member_use

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_color_utilities/material_color_utilities.dart';
import 'package:pve_manager/core/theme/platform_dynamic_color.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('loads Android system colors into light and dark schemes', () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    addTearDown(() {
      debugDefaultTargetPlatformOverride = null;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
            const MethodChannel('pve_manager/dynamic_color'),
            null,
          );
    });

    final palette = CorePalette.of(0xffb55b66);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('pve_manager/dynamic_color'),
          (call) async {
            expect(call.method, 'getCorePalette');
            return palette.asList();
          },
        );

    final schemes = await loadPlatformColorSchemes();

    expect(schemes, isNotNull);
    expect(schemes!.light.brightness, Brightness.light);
    expect(schemes.dark.brightness, Brightness.dark);
    expect(schemes.light.primary, isNot(schemes.dark.primary));
  });

  test('uses the Windows accent color as the theme seed', () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.windows;
    addTearDown(() {
      debugDefaultTargetPlatformOverride = null;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
            const MethodChannel('pve_manager/dynamic_color'),
            null,
          );
    });

    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('pve_manager/dynamic_color'),
          (call) async {
            expect(call.method, 'getAccentColor');
            return 0xffb55b66;
          },
        );

    final schemes = await loadPlatformColorSchemes();

    expect(schemes, isNotNull);
    expect(schemes!.light.brightness, Brightness.light);
    expect(schemes.dark.brightness, Brightness.dark);
  });
}
