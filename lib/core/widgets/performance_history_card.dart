import 'package:flutter/material.dart';

import 'package:pve_manager/core/l10n/l10n_extensions.dart';
import 'package:pve_manager/core/utils/formatters.dart';
import 'package:pve_manager/core/widgets/cpu_history_chart.dart';

class PerformanceHistoryPoint {
  const PerformanceHistoryPoint({
    required this.time,
    required this.cpu,
    required this.memoryUsed,
    required this.memoryTotal,
    required this.netIn,
    required this.netOut,
    required this.diskRead,
    required this.diskWrite,
  });

  final int time;
  final double cpu;
  final int memoryUsed;
  final int memoryTotal;
  final double netIn;
  final double netOut;
  final double diskRead;
  final double diskWrite;
}

class PerformanceHistoryCard extends StatelessWidget {
  const PerformanceHistoryCard({
    required this.points,
    this.showDiskIo = true,
    super.key,
  });

  final List<PerformanceHistoryPoint> points;
  final bool showDiskIo;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final compact = MediaQuery.sizeOf(context).width < 360;
    final memoryTotal = points.fold<int>(
      0,
      (max, point) => point.memoryTotal > max ? point.memoryTotal : max,
    );
    final cpuValues = points.map((point) => point.cpu).toList();
    final timestamps = points.map((point) => point.time).toList();
    final cpuMax = _visibleMax(cpuValues, minimum: 0.08, maximum: 1);
    final memoryRatios = points.map((point) {
      if (point.memoryTotal <= 0) {
        return 0.0;
      }
      return (point.memoryUsed / point.memoryTotal).clamp(0, 1).toDouble();
    }).toList();
    final memoryMax = _visibleMax(memoryRatios, minimum: 0.08, maximum: 1);
    final networkValues = points
        .map((point) => point.netIn + point.netOut)
        .toList();
    final diskIoValues = points
        .map((point) => point.diskRead + point.diskWrite)
        .toList();
    final networkMax = _visibleMax(networkValues, minimum: 1);
    final diskIoMax = _visibleMax(diskIoValues, minimum: 1);

    return Card(
      color: colorScheme.surfaceContainerLowest,
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: compact ? 12 : 18,
          vertical: 18,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _PerformanceTitle(title: context.l10n.cpuUsage),
            const SizedBox(height: 16),
            MetricHistoryChart(
              values: cpuValues,
              timestamps: timestamps,
              maxValue: cpuMax,
              valueLabelBuilder: percent,
            ),
            const SizedBox(height: 24),
            _PerformanceTitle(
              title: context.l10n.memoryHistory,
              trailing: context.l10n.totalMemory(bytes(memoryTotal)),
            ),
            const SizedBox(height: 16),
            MetricHistoryChart(
              values: memoryRatios,
              timestamps: timestamps,
              maxValue: memoryMax,
              valueLabelBuilder: percent,
              lineColor: colorScheme.secondary,
            ),
            const SizedBox(height: 24),
            _PerformanceTitle(title: context.l10n.networkIo),
            const SizedBox(height: 16),
            MetricHistoryChart(
              values: networkValues,
              timestamps: timestamps,
              maxValue: networkMax,
              valueLabelBuilder: _bytesPerSecond,
              lineColor: colorScheme.tertiary,
            ),
            if (showDiskIo) ...[
              const SizedBox(height: 24),
              _PerformanceTitle(title: context.l10n.diskIo),
              const SizedBox(height: 16),
              MetricHistoryChart(
                values: diskIoValues,
                timestamps: timestamps,
                maxValue: diskIoMax,
                valueLabelBuilder: _bytesPerSecond,
                lineColor: colorScheme.error,
                fillColor: colorScheme.error.withValues(alpha: 0.14),
              ),
            ],
          ],
        ),
      ),
    );
  }

  static double _visibleMax(
    List<double> values, {
    required double minimum,
    double? maximum,
  }) {
    final maxValue = values.fold<double>(
      0,
      (max, value) => value > max ? value : max,
    );
    return maxValue.clamp(minimum, maximum ?? double.infinity).toDouble();
  }

  static String _bytesPerSecond(double value) {
    final text = bytes(value.round());
    return text == '-' ? '0 B/s' : '$text/s';
  }
}

class _PerformanceTitle extends StatelessWidget {
  const _PerformanceTitle({required this.title, this.trailing});

  final String title;
  final String? trailing;

  @override
  Widget build(BuildContext context) {
    final trailing = this.trailing;
    final titleStyle = Theme.of(
      context,
    ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800);

    return Row(
      children: [
        Expanded(child: Text(title, style: titleStyle)),
        if (trailing != null) ...[
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              trailing,
              textAlign: TextAlign.right,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ],
    );
  }
}
