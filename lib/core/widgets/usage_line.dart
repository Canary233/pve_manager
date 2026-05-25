import 'package:flutter/material.dart';

class UsageLine extends StatelessWidget {
  const UsageLine({
    required this.label,
    required this.value,
    required this.text,
    super.key,
  });

  final String label;
  final double value;
  final String text;

  static const double _edgeTextWidth = 128;
  static const double _rightAlignedBreakpoint = 520;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final alignRight = constraints.maxWidth < _rightAlignedBreakpoint;

        return Column(
          children: [
            Row(
              children: [
                SizedBox(
                  width: alignRight ? null : _edgeTextWidth,
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    text,
                    textAlign: alignRight ? TextAlign.right : TextAlign.center,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (!alignRight) const SizedBox(width: _edgeTextWidth),
              ],
            ),
            const SizedBox(height: 5),
            LinearProgressIndicator(value: value.clamp(0, 1)),
          ],
        );
      },
    );
  }
}
