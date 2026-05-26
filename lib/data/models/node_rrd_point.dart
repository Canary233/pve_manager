import 'package:pve_manager/core/utils/formatters.dart';

class NodeRrdPoint {
  const NodeRrdPoint({
    required this.time,
    required this.cpu,
    required this.memoryUsed,
    required this.memoryTotal,
    required this.netIn,
    required this.netOut,
    required this.diskRead,
    required this.diskWrite,
  });

  factory NodeRrdPoint.fromJson(Map<String, dynamic> json) {
    return NodeRrdPoint(
      time: asInt(json['time']),
      cpu: asDouble(json['cpu']).clamp(0, 1),
      memoryUsed: asInt(json['memused'] ?? json['mem']),
      memoryTotal: asInt(json['memtotal'] ?? json['maxmem']),
      netIn: asDouble(json['netin']),
      netOut: asDouble(json['netout']),
      diskRead: asDouble(json['diskread']),
      diskWrite: asDouble(json['diskwrite']),
    );
  }

  final int time;
  final double cpu;
  final int memoryUsed;
  final int memoryTotal;
  final double netIn;
  final double netOut;
  final double diskRead;
  final double diskWrite;
}
