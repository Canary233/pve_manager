import 'package:flutter/material.dart';
import 'package:xterm/xterm.dart';

const double terminalShortcutCellExtent = 42;
const double terminalShortcutIconSize = 18;

const TextStyle terminalShortcutLabelStyle = TextStyle(
  fontSize: 12,
  fontWeight: FontWeight.w700,
  letterSpacing: 0,
  height: 1.0,
);

Color terminalScreenBackgroundColor(ColorScheme colorScheme) {
  return colorScheme.surfaceContainerLow;
}

Color terminalConsoleBackgroundColor(ColorScheme colorScheme) {
  return colorScheme.surfaceContainerLowest;
}

Color terminalShortcutBarBackgroundColor(ColorScheme colorScheme) {
  return colorScheme.surfaceContainerLow;
}

Color terminalShortcutTileForegroundColor(
  ColorScheme colorScheme, {
  required bool active,
}) {
  return active ? colorScheme.onPrimaryContainer : colorScheme.onSurfaceVariant;
}

Color terminalStatusBannerBackgroundColor(ColorScheme colorScheme) {
  return colorScheme.surfaceContainerHighest;
}

Color terminalStatusBannerForegroundColor(ColorScheme colorScheme) {
  return colorScheme.onSurface;
}

String terminalBackgroundCssColor(ColorScheme colorScheme) {
  return _toCssColor(terminalConsoleBackgroundColor(colorScheme));
}

TerminalTheme buildTerminalTheme(ColorScheme colorScheme) {
  final background = terminalConsoleBackgroundColor(colorScheme);
  final foreground = colorScheme.onSurface;

  return TerminalTheme(
    cursor: colorScheme.primary,
    selection: colorScheme.primary.withValues(alpha: 0.24),
    foreground: foreground,
    background: background,
    black: const Color(0xff141210),
    red: const Color(0xffe06c75),
    green: const Color(0xff98c379),
    yellow: const Color(0xffd19a66),
    blue: const Color(0xff61afef),
    magenta: const Color(0xffc678dd),
    cyan: const Color(0xff56b6c2),
    white: foreground,
    brightBlack: Color.alphaBlend(
      colorScheme.onSurface.withValues(alpha: 0.4),
      background,
    ),
    brightRed: const Color(0xffef7f8a),
    brightGreen: const Color(0xffb7d98a),
    brightYellow: const Color(0xffe5c07b),
    brightBlue: const Color(0xff89b4fa),
    brightMagenta: const Color(0xffd7a7eb),
    brightCyan: const Color(0xff7bd0d9),
    brightWhite: colorScheme.onSurface,
    searchHitBackground: colorScheme.tertiaryContainer,
    searchHitBackgroundCurrent: colorScheme.primaryContainer,
    searchHitForeground: colorScheme.onPrimaryContainer,
  );
}

String _toCssColor(Color color) {
  int component(double value) => (value * 255).round().clamp(0, 255).toInt();

  final r = component(color.r);
  final g = component(color.g);
  final b = component(color.b);
  final a = color.a;
  if (a >= 0.999) {
    return '#${r.toRadixString(16).padLeft(2, '0')}${g.toRadixString(16).padLeft(2, '0')}${b.toRadixString(16).padLeft(2, '0')}';
  }
  return 'rgba($r, $g, $b, ${a.toStringAsFixed(3)})';
}

class TerminalShortcutTile extends StatelessWidget {
  const TerminalShortcutTile.button({
    super.key,
    required this.label,
    required this.onPressed,
    this.active = false,
  }) : icon = null;

  const TerminalShortcutTile.icon({
    super.key,
    required this.icon,
    required this.onPressed,
  }) : label = null,
       active = false;

  final String? label;
  final IconData? icon;
  final VoidCallback? onPressed;
  final bool active;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final foreground = active
        ? colorScheme.primary
        : terminalShortcutTileForegroundColor(colorScheme, active: active);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onPressed,
        child: Center(
          child: icon != null
              ? Icon(icon, size: terminalShortcutIconSize, color: foreground)
              : FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    label!,
                    style: terminalShortcutLabelStyle.copyWith(
                      color: foreground,
                    ),
                  ),
                ),
        ),
      ),
    );
  }
}
