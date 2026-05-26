import 'package:pve_manager/data/models/pve_node.dart';
import 'package:pve_manager/data/models/pve_resource.dart';

class PveSnapshot {
  const PveSnapshot({
    required this.nodes,
    required this.resources,
    required this.clusterStatus,
    this.nodePermissionDenied = false,
    this.storagePermissionDenied = false,
  });

  final List<PveNode> nodes;
  final List<PveResource> resources;
  final Map<String, dynamic> clusterStatus;
  final bool nodePermissionDenied;
  final bool storagePermissionDenied;

  int get runningGuests => resources
      .where((item) => item.isGuest && item.status == 'running')
      .length;

  int get totalGuests => resources.where((item) => item.isGuest).length;

  String get clusterName =>
      clusterStatus['name']?.toString().trim().isNotEmpty == true
      ? clusterStatus['name'].toString()
      : 'Proxmox VE';
}
