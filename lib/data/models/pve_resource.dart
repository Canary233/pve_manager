import 'package:pve_manager/core/utils/formatters.dart';

class PveResource {
  const PveResource({
    required this.id,
    required this.type,
    required this.name,
    required this.node,
    required this.status,
    required this.cpu,
    required this.memoryUsed,
    required this.memoryTotal,
    required this.diskUsed,
    required this.diskTotal,
    this.vmid,
  });

  factory PveResource.fromJson(Map<String, dynamic> json) {
    final type = json['type']?.toString() ?? 'unknown';
    final vmid = asNullableInt(json['vmid']);
    final fallbackName = vmid == null ? type : '$type $vmid';
    final id = json['id']?.toString() ?? fallbackName;
    final configuredName = json['name']?.toString().trim();
    final storageName = json['storage']?.toString().trim();
    final name = configuredName?.isNotEmpty == true
        ? configuredName!
        : type == 'storage' && storageName?.isNotEmpty == true
        ? storageName!
        : type == 'storage' && id.contains('/')
        ? id.split('/').last
        : fallbackName;

    return PveResource(
      id: id,
      type: type,
      name: name,
      node: json['node']?.toString() ?? '-',
      status: json['status']?.toString() ?? 'unknown',
      cpu: asDouble(json['cpu']),
      memoryUsed: asInt(json['mem']),
      memoryTotal: asInt(json['maxmem']),
      diskUsed: asInt(json['disk']),
      diskTotal: asInt(json['maxdisk']),
      vmid: vmid,
    );
  }

  final String id;
  final String type;
  final String name;
  final String node;
  final String status;
  final double cpu;
  final int memoryUsed;
  final int memoryTotal;
  final int diskUsed;
  final int diskTotal;
  final int? vmid;

  bool get isGuest => (type == 'qemu' || type == 'lxc') && vmid != null;

  double get memoryRatio =>
      memoryTotal == 0 ? 0 : (memoryUsed / memoryTotal).clamp(0, 1);

  double get diskRatio =>
      diskTotal == 0 ? 0 : (diskUsed / diskTotal).clamp(0, 1);

  PveResource copyWith({
    String? status,
    double? cpu,
    int? memoryUsed,
    int? memoryTotal,
    int? diskUsed,
    int? diskTotal,
  }) {
    return PveResource(
      id: id,
      type: type,
      name: name,
      node: node,
      status: status ?? this.status,
      cpu: cpu ?? this.cpu,
      memoryUsed: memoryUsed ?? this.memoryUsed,
      memoryTotal: memoryTotal ?? this.memoryTotal,
      diskUsed: diskUsed ?? this.diskUsed,
      diskTotal: diskTotal ?? this.diskTotal,
      vmid: vmid,
    );
  }

  PveResource mergeStatus(Map<String, dynamic> json) {
    return copyWith(
      status: json['status']?.toString(),
      cpu: json.containsKey('cpu')
          ? asDouble(json['cpu']).clamp(0, 1).toDouble()
          : null,
      memoryUsed: json.containsKey('mem') ? asInt(json['mem']) : null,
      memoryTotal: json.containsKey('maxmem') ? asInt(json['maxmem']) : null,
      diskUsed: json.containsKey('disk') ? asInt(json['disk']) : null,
      diskTotal: json.containsKey('maxdisk') ? asInt(json['maxdisk']) : null,
    );
  }
}
