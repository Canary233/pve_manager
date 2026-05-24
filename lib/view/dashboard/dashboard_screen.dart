import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'package:pve_manager/core/l10n/l10n_extensions.dart';
import 'package:pve_manager/data/models/node_status.dart';
import 'package:pve_manager/data/models/pve_node.dart';
import 'package:pve_manager/data/models/pve_resource.dart';
import 'package:pve_manager/data/models/pve_snapshot.dart';
import 'package:pve_manager/data/services/proxmox_client.dart';
import 'package:pve_manager/core/widgets/error_state.dart';
import 'package:pve_manager/view/guest/guest_detail_screen.dart';
import 'package:pve_manager/view/dashboard/widgets/guest_panel.dart';
import 'package:pve_manager/view/node/node_detail_screen.dart';
import 'package:pve_manager/view/dashboard/widgets/node_grid.dart';
import 'package:pve_manager/view/dashboard/widgets/section_header.dart';
import 'package:pve_manager/view/dashboard/widgets/storage_list.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({
    required this.client,
    required this.serverName,
    required this.autoRefreshIntervalListenable,
    super.key,
  });

  final ProxmoxClient client;
  final String serverName;
  final ValueListenable<Duration> autoRefreshIntervalListenable;

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  late Future<PveSnapshot> _snapshotFuture;
  Timer? _refreshTimer;
  bool _isSnapshotLoading = false;
  PveSnapshot? _lastSnapshot;

  @override
  void initState() {
    super.initState();
    _snapshotFuture = _loadSnapshotTracked();
    widget.autoRefreshIntervalListenable.addListener(_startRefreshTimer);
    _startRefreshTimer();
  }

  @override
  void didUpdateWidget(DashboardScreen oldWidget) {
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
    widget.client.close();
    super.dispose();
  }

  void _startRefreshTimer() {
    _refreshTimer?.cancel();
    _refreshTimer = Timer.periodic(widget.autoRefreshIntervalListenable.value, (
      _,
    ) {
      if (mounted && (ModalRoute.of(context)?.isCurrent ?? true)) {
        _refreshSnapshot();
      }
    });
  }

  Future<PveSnapshot> _loadSnapshot() async {
    final results = await Future.wait<Object>([
      widget.client.getNodes(),
      widget.client.getResources(),
      widget.client.getClusterStatus(),
    ]);

    final snapshot = PveSnapshot(
      nodes: results[0] as List<PveNode>,
      resources: results[1] as List<PveResource>,
      clusterStatus: results[2] as Map<String, dynamic>,
    );
    final nodes = await _loadNodeUsage(snapshot.nodes);
    final snapshotWithNodeUsage = PveSnapshot(
      nodes: nodes,
      resources: snapshot.resources,
      clusterStatus: snapshot.clusterStatus,
    );
    _lastSnapshot = snapshotWithNodeUsage;
    return snapshotWithNodeUsage;
  }

  Future<List<PveNode>> _loadNodeUsage(List<PveNode> nodes) async {
    if (nodes.isEmpty) {
      return nodes;
    }

    final statuses = await Future.wait<NodeStatus?>(
      nodes.map((node) async {
        try {
          return await widget.client.getNodeStatus(node.name);
        } on Object {
          return null;
        }
      }),
    );

    return [
      for (var index = 0; index < nodes.length; index++)
        if (statuses[index] case final status?)
          nodes[index].copyWith(
            cpu: status.cpu,
            memoryUsed: status.memoryUsed,
            memoryTotal: status.memoryTotal,
          )
        else
          nodes[index],
    ];
  }

  Future<PveSnapshot> _loadSnapshotTracked() async {
    _isSnapshotLoading = true;
    try {
      return await _loadSnapshot();
    } finally {
      _isSnapshotLoading = false;
    }
  }

  Future<void> _refreshSnapshot() async {
    if (_isSnapshotLoading) {
      return;
    }

    final future = _loadSnapshotTracked();
    setState(() {
      _snapshotFuture = future;
    });

    try {
      await future;
    } on Object {
      // FutureBuilder renders the error state when there is no cached snapshot.
    }
  }

  Future<void> _openGuest(PveResource guest) async {
    final shouldRefresh = await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        builder: (_) => GuestDetailScreen(
          client: widget.client,
          guest: guest,
          autoRefreshIntervalListenable: widget.autoRefreshIntervalListenable,
        ),
      ),
    );

    if (shouldRefresh == true && mounted) {
      await _refreshSnapshot();
    }
  }

  Future<void> _openNode(PveNode node) async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => NodeDetailScreen(
          client: widget.client,
          node: node,
          autoRefreshIntervalListenable: widget.autoRefreshIntervalListenable,
        ),
      ),
    );
    if (mounted) {
      await _refreshSnapshot();
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    return Scaffold(
      appBar: AppBar(title: Text(widget.serverName)),
      body: FutureBuilder<PveSnapshot>(
        future: _snapshotFuture,
        builder: (context, snapshot) {
          final data = snapshot.data ?? _lastSnapshot;
          if (snapshot.connectionState == ConnectionState.waiting &&
              data == null) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError && data == null) {
            return ErrorState(
              message: localizedError(l10n, snapshot.error!),
              onRetry: _refreshSnapshot,
            );
          }

          final snapshotData = data!;
          final guests = snapshotData.resources
              .where((item) => item.isGuest)
              .toList();
          final storages = snapshotData.resources
              .where((item) => item.type == 'storage')
              .toList();

          return RefreshIndicator(
            onRefresh: _refreshSnapshot,
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                SectionHeader(
                  title: l10n.nodes,
                  trailing: l10n.nodesCount(snapshotData.nodes.length),
                ),
                const SizedBox(height: 8),
                NodeGrid(nodes: snapshotData.nodes, onNodeTap: _openNode),
                const SizedBox(height: 16),
                SectionHeader(
                  title: l10n.guests,
                  trailing: l10n.itemsCount(guests.length),
                ),
                const SizedBox(height: 8),
                GuestPanel(guests: guests, onSelect: _openGuest),
                const SizedBox(height: 16),
                SectionHeader(
                  title: l10n.storage,
                  trailing: l10n.itemsCount(storages.length),
                ),
                const SizedBox(height: 8),
                StorageList(storages: storages),
              ],
            ),
          );
        },
      ),
    );
  }
}
