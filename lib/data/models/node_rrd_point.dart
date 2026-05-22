import 'package:pve_manager/core/utils/formatters.dart';

class NodeRrdPoint {
  const NodeRrdPoint({
    required this.time,
    required this.cpu,
    required this.memoryUsed,
    required this.memoryTotal,
  });

  factory NodeRrdPoint.fromJson(Map<String, dynamic> json) {
    return NodeRrdPoint(
      time: asInt(json['time']),
      cpu: asDouble(json['cpu']).clamp(0, 1),
      memoryUsed: asInt(json['memused'] ?? json['mem']),
      memoryTotal: asInt(json['memtotal'] ?? json['maxmem']),
    );
  }

  final int time;
  final double cpu;
  final int memoryUsed;
  final int memoryTotal;
}
