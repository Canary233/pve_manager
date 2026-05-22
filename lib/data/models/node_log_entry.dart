import 'package:pve_manager/core/utils/formatters.dart';

class NodeLogEntry {
  const NodeLogEntry({required this.lineNumber, required this.text});

  factory NodeLogEntry.fromJson(Map<String, dynamic> json) {
    return NodeLogEntry(
      lineNumber: asInt(json['n']),
      text: json['t']?.toString() ?? '',
    );
  }

  final int lineNumber;
  final String text;
}
