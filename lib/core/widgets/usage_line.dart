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

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          children: [
            SizedBox(width: 42, child: Text(label)),
            Expanded(
              child: Text(
                text,
                textAlign: TextAlign.right,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        const SizedBox(height: 5),
        LinearProgressIndicator(value: value.clamp(0, 1)),
      ],
    );
  }
}
