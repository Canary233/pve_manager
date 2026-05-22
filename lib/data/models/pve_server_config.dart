import 'package:pve_manager/data/services/proxmox_client.dart';

class PveServerConfig {
  const PveServerConfig({
    this.id,
    required this.name,
    required this.origin,
    required this.username,
    required this.password,
    required this.realm,
    required this.ignoreCertificateErrors,
    this.lastConnectedAt,
  });

  final int? id;
  final String name;
  final String origin;
  final String username;
  final String password;
  final String realm;
  final bool ignoreCertificateErrors;
  final int? lastConnectedAt;

  String get host => Uri.parse(origin).host;

  PveServerConfig copyWith({
    int? id,
    String? name,
    String? origin,
    String? username,
    String? password,
    String? realm,
    bool? ignoreCertificateErrors,
    int? lastConnectedAt,
  }) {
    return PveServerConfig(
      id: id ?? this.id,
      name: name ?? this.name,
      origin: origin ?? this.origin,
      username: username ?? this.username,
      password: password ?? this.password,
      realm: realm ?? this.realm,
      ignoreCertificateErrors:
          ignoreCertificateErrors ?? this.ignoreCertificateErrors,
      lastConnectedAt: lastConnectedAt ?? this.lastConnectedAt,
    );
  }

  factory PveServerConfig.fromMap(Map<String, Object?> map) {
    return PveServerConfig(
      id: map['id'] as int?,
      name: map['name']?.toString() ?? '',
      origin: map['origin']?.toString() ?? '',
      username: map['username']?.toString() ?? '',
      password: map['password']?.toString() ?? '',
      realm: map['realm']?.toString() ?? 'pam',
      ignoreCertificateErrors:
          (map['ignore_certificate_errors'] as int? ?? 1) == 1,
      lastConnectedAt: map['last_connected_at'] as int?,
    );
  }

  Map<String, Object?> toMap() {
    return <String, Object?>{
      'id': id,
      'name': name,
      'origin': origin,
      'username': username,
      'password': password,
      'realm': realm,
      'ignore_certificate_errors': ignoreCertificateErrors ? 1 : 0,
      'last_connected_at': lastConnectedAt,
    };
  }

  ProxmoxClient createClient() {
    return ProxmoxClient(
      origin: origin,
      username: username,
      password: password,
      realm: realm,
      ignoreCertificateErrors: ignoreCertificateErrors,
    );
  }
}
