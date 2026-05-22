import 'package:pve_manager/core/utils/formatters.dart';

class PveNode {
  const PveNode({
    required this.name,
    required this.status,
    required this.cpu,
    required this.memoryUsed,
    required this.memoryTotal,
  });

  factory PveNode.fromJson(Map<String, dynamic> json) {
    return PveNode(
      name: json['node']?.toString() ?? '-',
      status: json['status']?.toString() ?? 'unknown',
      cpu: asDouble(json['cpu']),
      memoryUsed: asInt(json['mem']),
      memoryTotal: asInt(json['maxmem']),
    );
  }

  final String name;
  final String status;
  final double cpu;
  final int memoryUsed;
  final int memoryTotal;

  double get memoryRatio =>
      memoryTotal == 0 ? 0 : (memoryUsed / memoryTotal).clamp(0, 1);
}
