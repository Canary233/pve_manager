import 'package:pve_manager/core/utils/formatters.dart';

class NodeTask {
  const NodeTask({
    required this.upid,
    required this.node,
    required this.type,
    required this.user,
    required this.status,
    required this.startTime,
    required this.endTime,
  });

  factory NodeTask.fromJson(Map<String, dynamic> json) {
    final upid = json['upid']?.toString() ?? '';
    return NodeTask(
      upid: upid,
      node: json['node']?.toString() ?? _nodeFromUpid(upid),
      type: json['type']?.toString() ?? '-',
      user: json['user']?.toString() ?? '-',
      status: json['status']?.toString() ?? 'running',
      startTime: asInt(json['starttime']),
      endTime: asInt(json['endtime']),
    );
  }

  final String upid;
  final String node;
  final String type;
  final String user;
  final String status;
  final int startTime;
  final int endTime;

  bool get isRunning => endTime == 0 || status == 'running';
}

String _nodeFromUpid(String upid) {
  final parts = upid.split(':');
  if (parts.length > 1) {
    return parts[1];
  }
  return '';
}
