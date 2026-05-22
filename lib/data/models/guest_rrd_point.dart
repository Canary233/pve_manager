import 'package:pve_manager/core/utils/formatters.dart';

class GuestRrdPoint {
  const GuestRrdPoint({
    required this.time,
    required this.cpu,
    required this.memoryUsed,
    required this.memoryTotal,
  });

  factory GuestRrdPoint.fromJson(Map<String, dynamic> json) {
    return GuestRrdPoint(
      time: asInt(json['time']),
      cpu: asDouble(json['cpu']).clamp(0, 1),
      memoryUsed: asInt(json['mem']),
      memoryTotal: asInt(json['maxmem']),
    );
  }

  final int time;
  final double cpu;
  final int memoryUsed;
  final int memoryTotal;
}
