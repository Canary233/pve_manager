// ignore_for_file: deprecated_member_use

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:material_color_utilities/material_color_utilities.dart';

typedef PlatformColorSchemes = ({ColorScheme light, ColorScheme dark});

const _dynamicColorChannel = OptionalMethodChannel('pve_manager/dynamic_color');

Future<PlatformColorSchemes?> loadPlatformColorSchemes() async {
  if (kIsWeb) {
    return null;
  }

  try {
    if (defaultTargetPlatform == TargetPlatform.windows) {
      final value = await _dynamicColorChannel.invokeMethod<int>(
        'getAccentColor',
      );
      if (value == null) {
        return null;
      }
      final accent = Color(value);
      return (
        light: ColorScheme.fromSeed(
          seedColor: accent,
          brightness: Brightness.light,
        ),
        dark: ColorScheme.fromSeed(
          seedColor: accent,
          brightness: Brightness.dark,
        ),
      );
    }
    if (defaultTargetPlatform != TargetPlatform.android) {
      return null;
    }

    final values = await _dynamicColorChannel.invokeMethod<List<Object?>>(
      'getCorePalette',
    );
    if (values == null || values.length != 65) {
      return null;
    }

    final palette = CorePalette.fromList(
      values.map((value) => (value as num).toInt()).toList(),
    );
    return (
      light: _toColorScheme(palette, Brightness.light),
      dark: _toColorScheme(palette, Brightness.dark),
    );
  } on PlatformException {
    return null;
  }
}

ColorScheme _toColorScheme(CorePalette palette, Brightness brightness) {
  final scheme = brightness == Brightness.light
      ? Scheme.lightFromCorePalette(palette)
      : Scheme.darkFromCorePalette(palette);

  return ColorScheme(
    brightness: brightness,
    primary: Color(scheme.primary),
    onPrimary: Color(scheme.onPrimary),
    primaryContainer: Color(scheme.primaryContainer),
    onPrimaryContainer: Color(scheme.onPrimaryContainer),
    secondary: Color(scheme.secondary),
    onSecondary: Color(scheme.onSecondary),
    secondaryContainer: Color(scheme.secondaryContainer),
    onSecondaryContainer: Color(scheme.onSecondaryContainer),
    tertiary: Color(scheme.tertiary),
    onTertiary: Color(scheme.onTertiary),
    tertiaryContainer: Color(scheme.tertiaryContainer),
    onTertiaryContainer: Color(scheme.onTertiaryContainer),
    error: Color(scheme.error),
    onError: Color(scheme.onError),
    errorContainer: Color(scheme.errorContainer),
    onErrorContainer: Color(scheme.onErrorContainer),
    outline: Color(scheme.outline),
    outlineVariant: Color(scheme.outlineVariant),
    surface: Color(scheme.surface),
    onSurface: Color(scheme.onSurface),
    surfaceVariant: Color(scheme.surfaceVariant),
    onSurfaceVariant: Color(scheme.onSurfaceVariant),
    inverseSurface: Color(scheme.inverseSurface),
    onInverseSurface: Color(scheme.inverseOnSurface),
    inversePrimary: Color(scheme.inversePrimary),
    shadow: Color(scheme.shadow),
    scrim: Color(scheme.scrim),
    background: Color(scheme.background),
    onBackground: Color(scheme.onBackground),
  );
}
