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

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          children: [
            SizedBox(
              width: _edgeTextWidth,
              child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis),
            ),
            Expanded(
              child: Text(
                text,
                textAlign: TextAlign.center,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: _edgeTextWidth),
          ],
        ),
        const SizedBox(height: 5),
        LinearProgressIndicator(value: value.clamp(0, 1)),
      ],
    );
  }
}
