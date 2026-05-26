import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'package:pve_manager/core/l10n/l10n_extensions.dart';
import 'package:pve_manager/data/models/node_power_action.dart';
import 'package:pve_manager/data/models/node_rrd_point.dart';
import 'package:pve_manager/data/models/node_status.dart';
import 'package:pve_manager/data/models/pve_node.dart';
import 'package:pve_manager/data/services/proxmox_client.dart';
import 'package:pve_manager/data/services/remote_console_launcher.dart';
import 'package:pve_manager/core/utils/formatters.dart';
import 'package:pve_manager/core/widgets/error_state.dart';
import 'package:pve_manager/core/widgets/usage_line.dart';
import 'package:pve_manager/core/widgets/performance_history_card.dart';
import 'package:pve_manager/view/node/node_tasks_logs_screen.dart';

class NodeDetailScreen extends StatefulWidget {
  const NodeDetailScreen({
    required this.client,
    required this.node,
    required this.autoRefreshIntervalListenable,
    this.embedded = false,
    super.key,
  });

  final ProxmoxClient client;
  final PveNode node;
  final ValueListenable<Duration> autoRefreshIntervalListenable;
  final bool embedded;

  @override
  State<NodeDetailScreen> createState() => _NodeDetailScreenState();
}

class _NodeDetailScreenState extends State<NodeDetailScreen> {
  late Future<_NodeDetailData> _detailFuture;
  Timer? _refreshTimer;
  bool _isDetailLoading = false;
  _NodeDetailData? _lastDetailData;
  String _timeframe = 'hour';

  static const _timeframes = <String>['hour', 'day', 'week', 'month', 'year'];

  @override
  void initState() {
    super.initState();
    _detailFuture = _loadDetailTracked();
    widget.autoRefreshIntervalListenable.addListener(_startRefreshTimer);
    _startRefreshTimer();
  }

  @override
  void didUpdateWidget(NodeDetailScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.autoRefreshIntervalListenable !=
        widget.autoRefreshIntervalListenable) {
      oldWidget.autoRefreshIntervalListenable.removeListener(
        _startRefreshTimer,
      );
      widget.autoRefreshIntervalListenable.addListener(_startRefreshTimer);
      _startRefreshTimer();
    }
  }

  @override
  void dispose() {
    widget.autoRefreshIntervalListenable.removeListener(_startRefreshTimer);
    _refreshTimer?.cancel();
    super.dispose();
  }

  void _startRefreshTimer() {
    _refreshTimer?.cancel();
    _refreshTimer = Timer.periodic(widget.autoRefreshIntervalListenable.value, (
      _,
    ) {
      if (mounted && (ModalRoute.of(context)?.isCurrent ?? true)) {
        _refresh();
      }
    });
  }

  Future<_NodeDetailData> _loadDetail() async {
    final results = await Future.wait<Object>([
      widget.client.getNodeStatus(widget.node.name),
      widget.client.getNodeRrdData(widget.node.name, timeframe: _timeframe),
    ]);

    final detail = _NodeDetailData(
      status: results[0] as NodeStatus,
      rrdPoints: results[1] as List<NodeRrdPoint>,
    );
    _lastDetailData = detail;
    return detail;
  }

  Future<_NodeDetailData> _loadDetailTracked() async {
    _isDetailLoading = true;
    try {
      return await _loadDetail();
    } finally {
      _isDetailLoading = false;
    }
  }

  Future<void> _refresh() async {
    if (_isDetailLoading) {
      return;
    }

    final future = _loadDetailTracked();
    setState(() {
      _detailFuture = future;
    });

    try {
      await future;
    } on Object {
      // FutureBuilder renders the error state when there is no cached detail.
    }
  }

  void _setTimeframe(String value) {
    if (_timeframe == value) {
      return;
    }

    setState(() {
      _timeframe = value;
      _detailFuture = _loadDetailTracked();
    });
  }

  Future<void> _openTasksLogs() async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) =>
            NodeTasksLogsScreen(client: widget.client, node: widget.node),
      ),
    );
    if (mounted) {
      await _refresh();
    }
  }

  Future<void> _openTerminal() async {
    try {
      await RemoteConsoleLauncher.open(
        title: context.l10n.terminalTitle(widget.node.name),
        client: widget.client,
        uri: widget.client.nodeShellConsoleUri(widget.node.name),
        l10n: context.l10n,
      );
      if (mounted) {
        await _refresh();
      }
    } on Object catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(localizedError(context.l10n, error))),
      );
    }
  }

  Future<void> _showPowerActions() async {
    final action = await showModalBottomSheet<NodePowerAction>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: NodePowerAction.values.map((action) {
            final label = action.localizedLabel(context.l10n);
            return ListTile(
              leading: Icon(action.icon),
              title: Text(label),
              onTap: () => Navigator.of(context).pop(action),
            );
          }).toList(),
        ),
      ),
    );

    if (action == null || !mounted) {
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        final label = action.localizedLabel(context.l10n);
        return AlertDialog(
          title: Text(label),
          content: Text(context.l10n.nodePowerConfirm(widget.node.name, label)),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: Text(context.l10n.cancel),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: Text(context.l10n.confirm),
            ),
          ],
        );
      },
    );

    if (confirmed != true || !mounted) {
      return;
    }

    try {
      await widget.client.executeNodePowerAction(widget.node.name, action);
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            context.l10n.powerRequestSent(action.localizedLabel(context.l10n)),
          ),
        ),
      );
      await _refresh();
    } on Object catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(localizedError(context.l10n, error))),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: !widget.embedded,
        title: Text(l10n.nodeDetails),
        actions: [
          IconButton(
            tooltip: l10n.tasksAndLogs,
            onPressed: _openTasksLogs,
            icon: const Icon(Icons.list_rounded),
          ),
          IconButton(
            tooltip: l10n.terminal,
            onPressed: _openTerminal,
            icon: const Icon(Icons.terminal_rounded),
          ),
          IconButton(
            tooltip: l10n.power,
            onPressed: _showPowerActions,
            icon: const Icon(Icons.power_settings_new_rounded),
          ),
        ],
      ),
      body: FutureBuilder<_NodeDetailData>(
        future: _detailFuture,
        builder: (context, snapshot) {
          final data = snapshot.data ?? _lastDetailData;
          if (snapshot.connectionState == ConnectionState.waiting &&
              data == null) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError && data == null) {
            return ErrorState(
              message: localizedError(l10n, snapshot.error!),
              onRetry: _refresh,
            );
          }

          final detailData = data!;
          return RefreshIndicator(
            onRefresh: _refresh,
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _SystemInfoCard(status: detailData.status),
                const SizedBox(height: 16),
                _ResourceUsageCard(status: detailData.status),
                const SizedBox(height: 16),
                _TimeframeSelector(
                  values: _timeframes,
                  selected: _timeframe,
                  onSelected: _setTimeframe,
                ),
                const SizedBox(height: 16),
                PerformanceHistoryCard(
                  showDiskIo: false,
                  points: detailData.rrdPoints
                      .map(
                        (point) => PerformanceHistoryPoint(
                          time: point.time,
                          cpu: point.cpu,
                          memoryUsed: point.memoryUsed,
                          memoryTotal: point.memoryTotal,
                          netIn: point.netIn,
                          netOut: point.netOut,
                          diskRead: point.diskRead,
                          diskWrite: point.diskWrite,
                        ),
                      )
                      .toList(),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _NodeDetailData {
  const _NodeDetailData({required this.status, required this.rrdPoints});

  final NodeStatus status;
  final List<NodeRrdPoint> rrdPoints;
}

class _SystemInfoCard extends StatelessWidget {
  const _SystemInfoCard({required this.status});

  final NodeStatus status;

  @override
  Widget build(BuildContext context) {
    final cpuInfo = status.cpuInfo;
    final l10n = context.l10n;
    final cpuModel = cpuInfo?.model;
    final loadAverage = status.loadAverage.isEmpty
        ? '-'
        : status.loadAverage
              .take(3)
              .map((value) => value.toStringAsFixed(2))
              .join('  ');

    return _DetailCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _CardTitle(title: l10n.systemInfo),
          const Divider(height: 24),
          if (cpuModel != null)
            _InfoRow(label: l10n.processor, value: cpuModel),
          _InfoRow(
            label: l10n.cpuCores,
            value: l10n.cpuCoresValue(
              cpuInfo?.cpus ?? 0,
              cpuInfo?.sockets ?? 0,
            ),
          ),
          _InfoRow(label: l10n.pveVersion, value: status.pveVersion ?? '-'),
          _InfoRow(
            label: l10n.kernelVersion,
            value: status.kernelVersion ?? '-',
          ),
          _InfoRow(label: l10n.uptime, value: uptime(l10n, status.uptime)),
          _InfoRow(label: l10n.loadAverage, value: loadAverage),
        ],
      ),
    );
  }
}

class _ResourceUsageCard extends StatelessWidget {
  const _ResourceUsageCard({required this.status});

  final NodeStatus status;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    return _DetailCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _CardTitle(title: l10n.resourceUsage),
          const SizedBox(height: 20),
          UsageLine(label: 'CPU', value: status.cpu, text: percent(status.cpu)),
          const SizedBox(height: 18),
          UsageLine(
            label: l10n.memory,
            value: status.memoryRatio,
            text: '${bytes(status.memoryUsed)} / ${bytes(status.memoryTotal)}',
          ),
          const SizedBox(height: 18),
          UsageLine(
            label: l10n.swap,
            value: status.swapRatio,
            text: '${bytes(status.swapUsed)} / ${bytes(status.swapTotal)}',
          ),
          const SizedBox(height: 18),
          UsageLine(
            label: l10n.rootPartition,
            value: status.rootRatio,
            text: '${bytes(status.rootUsed)} / ${bytes(status.rootTotal)}',
          ),
        ],
      ),
    );
  }
}

class _TimeframeSelector extends StatelessWidget {
  const _TimeframeSelector({
    required this.values,
    required this.selected,
    required this.onSelected,
  });

  final List<String> values;
  final String selected;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    return _DetailCard(
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: values.map((value) {
          final active = value == selected;
          final label = _timeframeLabel(context, value);
          return SizedBox(
            width: 92,
            child: active
                ? FilledButton.tonal(
                    onPressed: () => onSelected(value),
                    child: Text(label),
                  )
                : OutlinedButton(
                    onPressed: () => onSelected(value),
                    child: Text(label),
                  ),
          );
        }).toList(),
      ),
    );
  }

  String _timeframeLabel(BuildContext context, String value) {
    final l10n = context.l10n;
    return switch (value) {
      'hour' => l10n.timeframeHour,
      'day' => l10n.timeframeDay,
      'week' => l10n.timeframeWeek,
      'month' => l10n.timeframeMonth,
      'year' => l10n.timeframeYear,
      _ => value,
    };
  }
}

class _DetailCard extends StatelessWidget {
  const _DetailCard({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Card(
      color: Theme.of(context).colorScheme.surfaceContainerLowest,
      child: Padding(padding: const EdgeInsets.all(18), child: child),
    );
  }
}

class _CardTitle extends StatelessWidget {
  const _CardTitle({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: Theme.of(
        context,
      ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(
        children: [
          Text(
            label,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }
}
