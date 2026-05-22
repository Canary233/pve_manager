import 'dart:async';

import 'package:flutter/material.dart';

import 'package:pve_manager/core/l10n/l10n_extensions.dart';
import 'package:pve_manager/data/models/guest_action.dart';
import 'package:pve_manager/data/models/guest_rrd_point.dart';
import 'package:pve_manager/data/models/node_rrd_point.dart';
import 'package:pve_manager/data/models/pve_resource.dart';
import 'package:pve_manager/data/services/proxmox_client.dart';
import 'package:pve_manager/data/services/remote_console_launcher.dart';
import 'package:pve_manager/core/utils/formatters.dart';
import 'package:pve_manager/core/widgets/status_pill.dart';
import 'package:pve_manager/core/widgets/usage_line.dart';
import 'package:pve_manager/core/widgets/cpu_history_chart.dart';

class GuestDetailScreen extends StatefulWidget {
  const GuestDetailScreen({
    required this.client,
    required this.guest,
    super.key,
  });

  final ProxmoxClient client;
  final PveResource guest;

  @override
  State<GuestDetailScreen> createState() => _GuestDetailScreenState();
}

class _GuestDetailScreenState extends State<GuestDetailScreen> {
  late PveResource _guest;
  late Future<List<GuestRrdPoint>> _historyFuture;
  Timer? _refreshTimer;
  bool _isRefreshing = false;
  bool _isActionRunning = false;
  List<GuestRrdPoint>? _lastHistory;
  String _timeframe = 'hour';

  static const _timeframes = <String>['hour', 'day', 'week', 'month', 'year'];
  static const Duration _autoRefreshInterval = Duration(seconds: 5);

  @override
  void initState() {
    super.initState();
    _guest = widget.guest;
    _historyFuture = _loadHistory();
    _refreshTimer = Timer.periodic(_autoRefreshInterval, (_) {
      if (mounted && (ModalRoute.of(context)?.isCurrent ?? true)) {
        _refreshData();
      }
    });
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  Future<List<GuestRrdPoint>> _loadHistory() async {
    final history = await widget.client.getGuestRrdData(
      _guest,
      timeframe: _timeframe,
    );
    _lastHistory = history;
    return history;
  }

  Future<void> _refreshData() async {
    if (_isRefreshing) {
      return;
    }

    _isRefreshing = true;
    final historyFuture = _loadHistory();
    setState(() {
      _historyFuture = historyFuture;
    });

    try {
      final guest = await widget.client.getGuestCurrentStatus(_guest);
      if (mounted) {
        setState(() {
          _guest = guest;
        });
      }
    } on Object {
      // Keep the last visible resource usage if a refresh fails.
    }

    try {
      await historyFuture;
    } on Object {
      // FutureBuilder renders the error when there is no cached history.
    } finally {
      _isRefreshing = false;
    }
  }

  void _setTimeframe(String value) {
    if (_timeframe == value) {
      return;
    }

    setState(() {
      _timeframe = value;
      _historyFuture = _loadHistory();
    });
  }

  Future<void> _openConsole() async {
    final guest = widget.guest;
    final l10n = context.l10n;
    try {
      await RemoteConsoleLauncher.open(
        title: guest.type == 'qemu'
            ? l10n.vncTitle(guest.name)
            : l10n.terminalTitle(guest.name),
        client: widget.client,
        uri: widget.client.guestConsoleUri(guest),
        l10n: l10n,
      );
    } on Object catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(localizedError(l10n, error))));
    }
  }

  Future<void> _showPowerActions() async {
    final action = await showModalBottomSheet<GuestAction>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: GuestAction.values.map((action) {
            return ListTile(
              leading: Icon(action.icon),
              title: Text(action.localizedLabel(context.l10n)),
              onTap: () => Navigator.of(context).pop(action),
            );
          }).toList(),
        ),
      ),
    );

    if (action != null && mounted) {
      await _runAction(action);
    }
  }

  Future<void> _runAction(GuestAction action) async {
    setState(() {
      _isActionRunning = true;
    });

    try {
      await widget.client.executeGuestAction(widget.guest, action);
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            context.l10n.guestActionSent(
              widget.guest.name,
              action.localizedLabel(context.l10n),
            ),
          ),
        ),
      );
      Navigator.of(context).pop(true);
    } on Object catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(localizedError(context.l10n, error))),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isActionRunning = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final guest = _guest;
    final l10n = context.l10n;

    return Scaffold(
      appBar: AppBar(
        title: Text(guest.name),
        actions: [
          IconButton(
            tooltip: l10n.powerActions,
            onPressed: _isActionRunning ? null : _showPowerActions,
            icon: const Icon(Icons.power_settings_new_rounded),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            color: Theme.of(context).colorScheme.surfaceContainerLowest,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      CircleAvatar(
                        backgroundColor: Theme.of(
                          context,
                        ).colorScheme.primaryContainer,
                        child: Icon(
                          guest.type == 'qemu'
                              ? Icons.desktop_windows_rounded
                              : Icons.inventory_2_rounded,
                          color: Theme.of(
                            context,
                          ).colorScheme.onPrimaryContainer,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              guest.name,
                              style: Theme.of(context).textTheme.titleLarge
                                  ?.copyWith(fontWeight: FontWeight.w700),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '${localizedResourceType(l10n, guest.type)} '
                              '${guest.vmid} · ${guest.node}',
                              style: Theme.of(context).textTheme.bodyMedium
                                  ?.copyWith(
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.onSurfaceVariant,
                                  ),
                            ),
                          ],
                        ),
                      ),
                      StatusPill(status: guest.status),
                    ],
                  ),
                  const SizedBox(height: 20),
                  UsageLine(
                    label: 'CPU',
                    value: guest.cpu,
                    text: percent(guest.cpu),
                  ),
                  const SizedBox(height: 14),
                  UsageLine(
                    label: l10n.memory,
                    value: guest.memoryRatio,
                    text:
                        '${bytes(guest.memoryUsed)} / ${bytes(guest.memoryTotal)}',
                  ),
                  const SizedBox(height: 14),
                  UsageLine(
                    label: l10n.disk,
                    value: guest.diskRatio,
                    text:
                        '${bytes(guest.diskUsed)} / ${bytes(guest.diskTotal)}',
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Card(
            color: Theme.of(context).colorScheme.surfaceContainerLowest,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: FilledButton.tonalIcon(
                onPressed: _openConsole,
                icon: Icon(
                  guest.type == 'qemu'
                      ? Icons.desktop_windows_rounded
                      : Icons.terminal_rounded,
                ),
                label: Text(
                  guest.type == 'qemu'
                      ? l10n.openRemoteVnc
                      : l10n.openRemoteTerminal,
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          _GuestTimeframeSelector(
            values: _timeframes,
            selected: _timeframe,
            onSelected: _setTimeframe,
          ),
          const SizedBox(height: 16),
          FutureBuilder<List<GuestRrdPoint>>(
            future: _historyFuture,
            builder: (context, snapshot) {
              final points = snapshot.data ?? _lastHistory;
              if (snapshot.connectionState == ConnectionState.waiting &&
                  points == null) {
                return const _HistoryCard(
                  child: SizedBox(
                    height: 180,
                    child: Center(child: CircularProgressIndicator()),
                  ),
                );
              }

              if (snapshot.hasError && points == null) {
                return _HistoryCard(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text(localizedError(l10n, snapshot.error!)),
                  ),
                );
              }

              final historyPoints = points!;
              final memoryMax = _memoryMax(historyPoints, guest);
              return Column(
                children: [
                  _HistoryCard(
                    title: l10n.cpuUsage,
                    child: CpuHistoryChart(
                      points: historyPoints
                          .map(
                            (point) => NodeRrdPoint(
                              time: point.time,
                              cpu: point.cpu,
                              memoryUsed: point.memoryUsed,
                              memoryTotal: point.memoryTotal,
                            ),
                          )
                          .toList(),
                    ),
                  ),
                  const SizedBox(height: 16),
                  _HistoryCard(
                    title: l10n.memoryHistory,
                    child: MetricHistoryChart(
                      values: historyPoints
                          .map((point) => point.memoryUsed.toDouble())
                          .toList(),
                      maxValue: memoryMax > 0 ? memoryMax.toDouble() : null,
                      valueLabelBuilder: (value) => bytes(value.round()),
                      lineColor: Theme.of(context).colorScheme.secondary,
                    ),
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  int _memoryMax(List<GuestRrdPoint> points, PveResource guest) {
    return points.fold<int>(
      guest.memoryTotal,
      (max, point) => point.memoryTotal > max ? point.memoryTotal : max,
    );
  }
}

class _GuestTimeframeSelector extends StatelessWidget {
  const _GuestTimeframeSelector({
    required this.values,
    required this.selected,
    required this.onSelected,
  });

  final List<String> values;
  final String selected;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    return Card(
      color: Theme.of(context).colorScheme.surfaceContainerLowest,
      child: Padding(
        padding: const EdgeInsets.all(12),
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

class _HistoryCard extends StatelessWidget {
  const _HistoryCard({this.title, required this.child});

  final String? title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final title = this.title;
    return Card(
      color: Theme.of(context).colorScheme.surfaceContainerLowest,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (title != null) ...[
              Text(
                title,
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 12),
            ],
            child,
          ],
        ),
      ),
    );
  }
}
