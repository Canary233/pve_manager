class NodeTerminalSession {
  const NodeTerminalSession({
    required this.user,
    required this.ticket,
    required this.port,
  });

  factory NodeTerminalSession.fromJson(Map<String, dynamic> json) {
    return NodeTerminalSession(
      user: json['user']?.toString() ?? '',
      ticket: json['ticket']?.toString() ?? '',
      port: json['port'] is num
          ? (json['port'] as num).round()
          : int.tryParse(json['port']?.toString() ?? '') ?? 0,
    );
  }

  final String user;
  final String ticket;
  final int port;
}
