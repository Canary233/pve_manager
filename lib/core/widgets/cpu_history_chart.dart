import 'package:flutter/material.dart';

import 'package:pve_manager/core/l10n/l10n_extensions.dart';
import 'package:pve_manager/data/models/node_rrd_point.dart';
import 'package:pve_manager/core/utils/formatters.dart';

class CpuHistoryChart extends StatelessWidget {
  const CpuHistoryChart({required this.points, super.key});

  final List<NodeRrdPoint> points;

  @override
  Widget build(BuildContext context) {
    final maxValue = points
        .map((point) => point.cpu)
        .fold<double>(0, (max, value) => value > max ? value : max)
        .clamp(0.08, 1)
        .toDouble();

    return MetricHistoryChart(
      values: points.map((point) => point.cpu).toList(),
      maxValue: maxValue,
      valueLabelBuilder: percent,
    );
  }
}

class MetricHistoryChart extends StatelessWidget {
  const MetricHistoryChart({
    required this.values,
    required this.valueLabelBuilder,
    this.maxValue,
    this.lineColor,
    this.fillColor,
    super.key,
  });

  final List<double> values;
  final String Function(double value) valueLabelBuilder;
  final double? maxValue;
  final Color? lineColor;
  final Color? fillColor;

  @override
  Widget build(BuildContext context) {
    if (values.isEmpty) {
      return SizedBox(
        height: 180,
        child: Center(
          child: Text(
            context.l10n.noData,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      );
    }

    final computedMaxValue = values.fold<double>(
      0,
      (max, value) => value > max ? value : max,
    );
    final visibleMaxValue = (maxValue ?? computedMaxValue).clamp(
      0.0001,
      double.infinity,
    );
    final colorScheme = Theme.of(context).colorScheme;

    return SizedBox(
      width: double.infinity,
      height: 210,
      child: CustomPaint(
        painter: _MetricHistoryPainter(
          values: values,
          maxValue: visibleMaxValue,
          valueLabelBuilder: valueLabelBuilder,
          lineColor: lineColor ?? colorScheme.primary,
          fillColor:
              fillColor ??
              (lineColor ?? colorScheme.primary).withValues(alpha: 0.2),
          gridColor: colorScheme.outlineVariant.withValues(alpha: 0.8),
          labelColor: colorScheme.onSurfaceVariant,
          textStyle: Theme.of(context).textTheme.labelSmall,
        ),
      ),
    );
  }
}

class _MetricHistoryPainter extends CustomPainter {
  const _MetricHistoryPainter({
    required this.values,
    required this.maxValue,
    required this.valueLabelBuilder,
    required this.lineColor,
    required this.fillColor,
    required this.gridColor,
    required this.labelColor,
    required this.textStyle,
  });

  final List<double> values;
  final double maxValue;
  final String Function(double value) valueLabelBuilder;
  final Color lineColor;
  final Color fillColor;
  final Color gridColor;
  final Color labelColor;
  final TextStyle? textStyle;

  @override
  void paint(Canvas canvas, Size size) {
    const leftPadding = 76.0;
    const bottomPadding = 24.0;
    const topPadding = 12.0;
    const rightPadding = 10.0;

    final chartRect = Rect.fromLTWH(
      leftPadding,
      topPadding,
      size.width - leftPadding - rightPadding,
      size.height - topPadding - bottomPadding,
    );
    if (chartRect.width <= 0 || chartRect.height <= 0) {
      return;
    }

    final gridPaint = Paint()
      ..color = gridColor
      ..strokeWidth = 1;

    const horizontalLines = 4;
    for (var i = 0; i <= horizontalLines; i++) {
      final y = chartRect.top + chartRect.height * i / horizontalLines;
      canvas.drawLine(
        Offset(chartRect.left, y),
        Offset(chartRect.right, y),
        gridPaint,
      );

      final value = maxValue * (1 - i / horizontalLines);
      _drawYAxisLabel(
        canvas,
        chartRect,
        y,
        valueLabelBuilder(value),
        leftPadding - 10,
      );
    }

    for (var i = 0; i <= 6; i++) {
      final x = chartRect.left + chartRect.width * i / 6;
      canvas.drawLine(
        Offset(x, chartRect.top),
        Offset(x, chartRect.bottom),
        gridPaint,
      );
    }

    final path = Path();
    final fillPath = Path();
    final singlePoint = values.length == 1;
    for (var i = 0; i < values.length; i++) {
      final x = singlePoint
          ? (i == 0 ? chartRect.left : chartRect.right)
          : chartRect.left + chartRect.width * i / (values.length - 1);
      final ratio = (values[i] / maxValue).clamp(0, 1).toDouble();
      final y = chartRect.bottom - ratio * chartRect.height;
      final point = Offset(x, y);

      if (i == 0) {
        path.moveTo(point.dx, point.dy);
        fillPath.moveTo(point.dx, chartRect.bottom);
        fillPath.lineTo(point.dx, point.dy);
      } else {
        path.lineTo(point.dx, point.dy);
        fillPath.lineTo(point.dx, point.dy);
      }
    }

    if (singlePoint) {
      final y = path.getBounds().top;
      path.lineTo(chartRect.right, y);
      fillPath.lineTo(chartRect.right, y);
    }

    fillPath.lineTo(chartRect.right, chartRect.bottom);
    fillPath.close();

    canvas.save();
    canvas.clipRect(chartRect);
    canvas.drawPath(fillPath, Paint()..color = fillColor);
    canvas.drawPath(
      path,
      Paint()
        ..color = lineColor
        ..strokeWidth = 2.5
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );
    canvas.restore();
  }

  void _drawYAxisLabel(
    Canvas canvas,
    Rect chartRect,
    double centerY,
    String text,
    double maxWidth,
  ) {
    final painter = TextPainter(
      text: TextSpan(
        text: text,
        style:
            textStyle?.copyWith(color: labelColor) ??
            TextStyle(color: labelColor, fontSize: 11),
      ),
      textDirection: TextDirection.ltr,
      maxLines: 1,
    )..layout(maxWidth: maxWidth);
    final y = (centerY - painter.height / 2).clamp(
      0,
      chartRect.bottom - painter.height,
    );
    final offset = Offset(chartRect.left - 8 - painter.width, y.toDouble());
    painter.paint(canvas, offset);
  }

  @override
  bool shouldRepaint(covariant _MetricHistoryPainter oldDelegate) {
    return oldDelegate.values != values ||
        oldDelegate.maxValue != maxValue ||
        oldDelegate.lineColor != lineColor ||
        oldDelegate.fillColor != fillColor ||
        oldDelegate.gridColor != gridColor;
  }
}
