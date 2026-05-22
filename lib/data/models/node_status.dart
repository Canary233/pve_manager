import 'package:pve_manager/core/utils/formatters.dart';

class NodeStatus {
  const NodeStatus({
    required this.cpu,
    required this.memoryUsed,
    required this.memoryTotal,
    required this.swapUsed,
    required this.swapTotal,
    required this.rootUsed,
    required this.rootTotal,
    required this.uptime,
    required this.loadAverage,
    this.cpuInfo,
    this.pveVersion,
    this.kernelVersion,
  });

  factory NodeStatus.fromJson(Map<String, dynamic> json) {
    final cpuInfo = json['cpuinfo'] is Map<String, dynamic>
        ? json['cpuinfo'] as Map<String, dynamic>
        : <String, dynamic>{};
    final memory = json['memory'] is Map<String, dynamic>
        ? json['memory'] as Map<String, dynamic>
        : <String, dynamic>{};
    final swap = json['swap'] is Map<String, dynamic>
        ? json['swap'] as Map<String, dynamic>
        : <String, dynamic>{};
    final rootfs = json['rootfs'] is Map<String, dynamic>
        ? json['rootfs'] as Map<String, dynamic>
        : <String, dynamic>{};

    return NodeStatus(
      cpu: asDouble(json['cpu']).clamp(0, 1),
      memoryUsed: asInt(memory['used']),
      memoryTotal: asInt(memory['total']),
      swapUsed: asInt(swap['used']),
      swapTotal: asInt(swap['total']),
      rootUsed: asInt(rootfs['used']),
      rootTotal: asInt(rootfs['total']),
      uptime: asInt(json['uptime']),
      loadAverage: _parseLoadAverage(json['loadavg']),
      cpuInfo: CpuInfo.fromJson(cpuInfo),
      pveVersion: _parsePveVersion(json['pveversion']),
      kernelVersion: json['kversion']?.toString(),
    );
  }

  final double cpu;
  final int memoryUsed;
  final int memoryTotal;
  final int swapUsed;
  final int swapTotal;
  final int rootUsed;
  final int rootTotal;
  final int uptime;
  final List<double> loadAverage;
  final CpuInfo? cpuInfo;
  final String? pveVersion;
  final String? kernelVersion;

  double get memoryRatio =>
      memoryTotal == 0 ? 0 : (memoryUsed / memoryTotal).clamp(0, 1);

  double get swapRatio =>
      swapTotal == 0 ? 0 : (swapUsed / swapTotal).clamp(0, 1);

  double get rootRatio =>
      rootTotal == 0 ? 0 : (rootUsed / rootTotal).clamp(0, 1);
}

class CpuInfo {
  const CpuInfo({
    required this.cpus,
    required this.sockets,
    this.model,
    this.mhz,
  });

  factory CpuInfo.fromJson(Map<String, dynamic> json) {
    if (json.isEmpty) {
      return const CpuInfo(cpus: 0, sockets: 0);
    }

    return CpuInfo(
      cpus: asInt(json['cpus']),
      sockets: asInt(json['sockets']),
      model: json['model']?.toString(),
      mhz: asDouble(json['mhz']),
    );
  }

  final int cpus;
  final int sockets;
  final String? model;
  final double? mhz;
}

List<double> _parseLoadAverage(Object? value) {
  if (value is List) {
    return value.map(asDouble).toList();
  }
  if (value is String) {
    return value.split(RegExp(r'\s+')).map(asDouble).toList();
  }
  return const <double>[];
}

String? _parsePveVersion(Object? value) {
  final text = value?.toString();
  if (text == null || text.isEmpty) {
    return null;
  }
  final match = RegExp(r'pve-manager/([^\s/]+)').firstMatch(text);
  return match?.group(1) ?? text;
}
