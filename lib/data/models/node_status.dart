import 'dart:convert';

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
    this.thermalState = const NodeThermalState.empty(),
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
      thermalState: NodeThermalState.fromJson(json['thermalstate']),
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
  final NodeThermalState thermalState;

  double get memoryRatio =>
      memoryTotal == 0 ? 0 : (memoryUsed / memoryTotal).clamp(0, 1);

  double get swapRatio =>
      swapTotal == 0 ? 0 : (swapUsed / swapTotal).clamp(0, 1);

  double get rootRatio =>
      rootTotal == 0 ? 0 : (rootUsed / rootTotal).clamp(0, 1);
}

class NodeThermalState {
  const NodeThermalState({
    required this.sensors,
    this.diskInfos = const <NodeDiskInfo>[],
  });

  const NodeThermalState.empty()
    : sensors = const <NodeTemperatureSensor>[],
      diskInfos = const <NodeDiskInfo>[];

  factory NodeThermalState.fromJson(Object? value) {
    final sensors = <NodeTemperatureSensor>[];
    final diskInfos = <NodeDiskInfo>[];
    _collectTemperatureSensors(value, sensors, diskInfos);
    sensors.sort((a, b) {
      final rankCompare = a.rank.compareTo(b.rank);
      if (rankCompare != 0) {
        return rankCompare;
      }
      return b.celsius.compareTo(a.celsius);
    });
    return NodeThermalState(sensors: sensors, diskInfos: diskInfos);
  }

  final List<NodeTemperatureSensor> sensors;
  final List<NodeDiskInfo> diskInfos;

  bool get isEmpty => sensors.isEmpty;

  List<NodeTemperatureSensor> get cpuSensors {
    final result = sensors
        .where((sensor) => sensor.isCpuTemperatureSensor)
        .toList();
    result.sort((a, b) {
      final rankCompare = a.cpuRank.compareTo(b.cpuRank);
      if (rankCompare != 0) {
        return rankCompare;
      }
      return b.celsius.compareTo(a.celsius);
    });
    return result;
  }

  List<NodeTemperatureSensor> get cpuCoreSensors {
    return cpuSensors
        .where((sensor) => _isCpuCoreTemperatureSensor(sensor))
        .toList();
  }

  NodeTemperatureSensor? get cpuPackageSensor {
    final packageSensors = cpuSensors
        .where((sensor) => _isCpuPackageTemperatureSensor(sensor))
        .toList();
    final packageSensor = _hottestTemperatureSensor(packageSensors);
    if (packageSensor != null) {
      return packageSensor;
    }

    return _hottestTemperatureSensor(
      cpuSensors.where((sensor) => _isCpuPrimaryTemperatureSensor(sensor)),
    );
  }

  NodeTemperatureSensor? get primaryCpuSensor {
    return cpuPackageSensor ?? _hottestTemperatureSensor(cpuSensors);
  }

  List<NodeDiskTemperature> get diskTemperatures {
    return _buildDiskTemperatures(sensors, diskInfos);
  }

  NodeTemperatureSensor? get hottest {
    return _hottestTemperatureSensor(sensors);
  }

  String format({required String fallbackLabel}) {
    final hottestSensor = hottest;
    if (hottestSensor == null) {
      return '-';
    }

    final primary = hottestSensor.format(fallbackLabel: fallbackLabel);
    final notableSensors = sensors
        .where((sensor) => sensor != hottestSensor)
        .take(2)
        .map((sensor) => sensor.format(fallbackLabel: fallbackLabel))
        .toList();

    if (notableSensors.isEmpty) {
      return primary;
    }
    return '$primary · ${notableSensors.join(' · ')}';
  }
}

class NodeDiskInfo {
  const NodeDiskInfo({required this.source, required this.model});

  final String source;
  final String model;
}

enum NodeDiskTemperatureType { nvme, sata, ssd }

class NodeDiskTemperature {
  const NodeDiskTemperature({
    required this.type,
    required this.index,
    required this.celsius,
    this.source,
    this.model,
  });

  final NodeDiskTemperatureType type;
  final int index;
  final double celsius;
  final String? source;
  final String? model;

  String formatTemperature() {
    return _formatCelsius(celsius);
  }
}

class NodeTemperatureSensor {
  const NodeTemperatureSensor({
    required this.label,
    required this.celsius,
    this.source,
  });

  final String label;
  final double celsius;
  final String? source;

  String get searchableText =>
      [if (source != null) source, label].join(' ').toLowerCase();

  int get rank {
    final normalized = searchableText;
    if (normalized.contains('package') ||
        normalized.contains('cpu') ||
        _containsSensorName(normalized, 'tctl') ||
        _containsSensorName(normalized, 'tdie')) {
      return 0;
    }
    if (normalized.contains('core')) {
      return 1;
    }
    if (normalized.contains('temp')) {
      return 2;
    }
    return 3;
  }

  int get cpuRank {
    if (_isCpuPackageTemperatureSensor(this)) {
      return 0;
    }
    if (_isCpuPrimaryTemperatureSensor(this)) {
      return 1;
    }
    if (_isCpuCoreTemperatureSensor(this)) {
      return 2;
    }
    return 3;
  }

  bool get isCpuTemperatureSensor {
    final text = searchableText;
    return text.contains('coretemp') ||
        text.contains('k10temp') ||
        text.contains('zenpower') ||
        text.contains('package') ||
        text.contains('pkg temp') ||
        _containsSensorName(text, 'tctl') ||
        _containsSensorName(text, 'tdie') ||
        RegExp(r'\bcpu\b').hasMatch(text) ||
        RegExp(r'\bcore\s*\d+\b').hasMatch(text);
  }

  bool get isDiskTemperatureSensor {
    final text = searchableText;
    return text.contains('smartctl') ||
        text.contains('/dev/nvme') ||
        text.contains('/dev/sd') ||
        text.contains('/dev/hd') ||
        text.contains('/dev/disk/by') ||
        text.contains('nvme') ||
        text.contains('sata') ||
        text.contains(' ata ') ||
        text.contains('drivetemp') ||
        text.contains('drive temperature') ||
        text.contains('scsi') ||
        text.contains('disk') ||
        text.contains('ssd') ||
        text.contains('hdd');
  }

  bool get isSmartDiskTemperatureSensor {
    final text = searchableText;
    return text.contains('smartctl') ||
        text.contains('/dev/disk/by') ||
        text.contains('/dev/nvme') ||
        text.contains('/dev/sd') ||
        text.contains('/dev/hd');
  }

  bool get isNvmeDiskTemperatureSensor {
    final text = searchableText;
    return text.contains('nvme');
  }

  bool get isSataDiskTemperatureSensor {
    final text = searchableText;
    return text.contains('/dev/sd') ||
        text.contains('/dev/hd') ||
        text.contains('/dev/disk/by') ||
        text.contains('sata') ||
        RegExp(r'\bata\b').hasMatch(text) ||
        text.contains('drivetemp') ||
        text.contains('smartctl') && !isNvmeDiskTemperatureSensor;
  }

  String format({required String fallbackLabel}) {
    if (_isGenericTemperatureKey(label) || label == fallbackLabel) {
      return formatTemperature();
    }
    return '$label ${formatTemperature()}';
  }

  String formatTemperature() {
    return _formatCelsius(celsius);
  }
}

class CpuInfo {
  const CpuInfo({
    required this.cores,
    required this.cpus,
    required this.sockets,
    this.model,
    this.mhz,
  });

  factory CpuInfo.fromJson(Map<String, dynamic> json) {
    if (json.isEmpty) {
      return const CpuInfo(cores: 0, cpus: 0, sockets: 0);
    }

    return CpuInfo(
      cores: asInt(json['cores']),
      cpus: asInt(json['cpus']),
      sockets: asInt(json['sockets']),
      model: json['model']?.toString(),
      mhz: asDouble(json['mhz']),
    );
  }

  final int cores;
  final int cpus;
  final int sockets;
  final String? model;
  final double? mhz;
}

NodeTemperatureSensor? _hottestTemperatureSensor(
  Iterable<NodeTemperatureSensor> sensors,
) {
  NodeTemperatureSensor? result;
  for (final sensor in sensors) {
    if (result == null || sensor.celsius > result.celsius) {
      result = sensor;
    }
  }
  return result;
}

bool _isCpuPackageTemperatureSensor(NodeTemperatureSensor sensor) {
  final text = sensor.searchableText;
  return text.contains('package') ||
      text.contains('pkg temp') ||
      _containsSensorName(text, 'tctl') ||
      _containsSensorName(text, 'tdie');
}

bool _containsSensorName(String text, String name) {
  return RegExp('(?:^|[^a-z0-9])$name(?:[^a-z0-9]|\$)').hasMatch(text);
}

bool _isCpuPrimaryTemperatureSensor(NodeTemperatureSensor sensor) {
  final text = sensor.searchableText;
  return _isCpuPackageTemperatureSensor(sensor) ||
      RegExp(r'\bcpu\b').hasMatch(text);
}

bool _isCpuCoreTemperatureSensor(NodeTemperatureSensor sensor) {
  final text = sensor.searchableText;
  return RegExp(r'\bcore\s*\d+\b').hasMatch(text);
}

List<NodeDiskTemperature> _buildDiskTemperatures(
  List<NodeTemperatureSensor> sensors,
  List<NodeDiskInfo> diskInfos,
) {
  final smartSensors = sensors
      .where((sensor) => sensor.isDiskTemperatureSensor)
      .where((sensor) => sensor.isSmartDiskTemperatureSensor)
      .toList();
  final hasSmartNvme = smartSensors.any(
    (sensor) => sensor.isNvmeDiskTemperatureSensor,
  );

  final groups = <_DiskTemperatureGroup>[];
  for (final sensor in sensors.where(
    (sensor) => sensor.isDiskTemperatureSensor,
  )) {
    if (!sensor.isSmartDiskTemperatureSensor) {
      if (hasSmartNvme && sensor.isNvmeDiskTemperatureSensor) {
        continue;
      }
    }

    final key = _diskTemperatureGroupKey(sensor);
    final existingIndex = groups.indexWhere((group) => group.key == key);
    if (existingIndex == -1) {
      groups.add(_DiskTemperatureGroup(key: key, sensors: [sensor]));
    } else {
      groups[existingIndex].sensors.add(sensor);
    }
  }

  groups.sort((a, b) {
    final typeCompare = a.type.index.compareTo(b.type.index);
    if (typeCompare != 0) {
      return typeCompare;
    }
    return a.key.compareTo(b.key);
  });

  var nvmeIndex = 0;
  var sataIndex = 0;
  var ssdIndex = 0;
  final result = <NodeDiskTemperature>[];
  for (final group in groups) {
    final sensor = group.primarySensor;
    final index = switch (group.type) {
      NodeDiskTemperatureType.nvme => nvmeIndex++,
      NodeDiskTemperatureType.sata => sataIndex++,
      NodeDiskTemperatureType.ssd => ssdIndex++,
    };
    result.add(
      NodeDiskTemperature(
        type: group.type,
        index: index,
        celsius: sensor.celsius,
        source: sensor.source,
        model:
            _diskModelForGroup(group, diskInfos) ??
            _diskModelFromSensor(sensor),
      ),
    );
  }

  return result;
}

String? _diskModelForGroup(
  _DiskTemperatureGroup group,
  List<NodeDiskInfo> diskInfos,
) {
  for (final info in diskInfos) {
    if (info.source.toLowerCase() == group.key) {
      return info.model;
    }
  }
  return null;
}

String _diskTemperatureGroupKey(NodeTemperatureSensor sensor) {
  final source = sensor.source;
  if (source != null && source.isNotEmpty) {
    return source.toLowerCase();
  }
  final label = sensor.label.toLowerCase();
  final smartMatch = RegExp(r'(?:smartctl\s+)?(/dev/\S+)').firstMatch(label);
  if (smartMatch != null) {
    return smartMatch.group(1)!;
  }
  return label;
}

String? _diskModelFromSensor(NodeTemperatureSensor sensor) {
  final label = sensor.label.trim();
  if (label.isEmpty || _isGenericTemperatureKey(label)) {
    return null;
  }
  final normalized = label.toLowerCase();
  if (normalized == 'composite' ||
      normalized.startsWith('sensor ') ||
      normalized.contains('temperature')) {
    return null;
  }
  return label;
}

String _formatCelsius(double celsius) {
  final value = celsius == celsius.roundToDouble()
      ? celsius.toStringAsFixed(0)
      : celsius.toStringAsFixed(1);
  return '$value°C';
}

class _DiskTemperatureGroup {
  _DiskTemperatureGroup({required this.key, required this.sensors});

  final String key;
  final List<NodeTemperatureSensor> sensors;

  NodeDiskTemperatureType get type {
    return sensors.any((sensor) => sensor.isNvmeDiskTemperatureSensor)
        ? NodeDiskTemperatureType.nvme
        : sensors.any((sensor) => sensor.isSataDiskTemperatureSensor)
        ? NodeDiskTemperatureType.sata
        : NodeDiskTemperatureType.ssd;
  }

  NodeTemperatureSensor get primarySensor {
    final exactPrimary = sensors.where((sensor) {
      final normalized = sensor.label.toLowerCase();
      return normalized == 'temperature' ||
          normalized == 'composite' ||
          normalized == 'temperature celsius' ||
          normalized == 'airflow temperature cel' ||
          normalized == 'current drive temperature';
    }).toList();
    if (exactPrimary.isNotEmpty) {
      return _hottestTemperatureSensor(exactPrimary)!;
    }

    final primary = sensors.where((sensor) {
      final text = sensor.searchableText;
      return text.contains('composite') || text.contains('temperature');
    }).toList();
    return _hottestTemperatureSensor(primary) ??
        _hottestTemperatureSensor(sensors)!;
  }
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

void _collectTemperatureSensors(
  Object? value,
  List<NodeTemperatureSensor> sensors, [
  List<NodeDiskInfo>? diskInfos,
  String? label,
  String? source,
  bool temperatureHint = false,
]) {
  diskInfos ??= <NodeDiskInfo>[];
  switch (value) {
    case null:
      return;
    case num():
      if (temperatureHint || label == null) {
        _addTemperatureSensor(
          sensors,
          label ?? 'Temperature',
          value.toDouble(),
          source: source,
        );
      }
    case String():
      final decoded = _tryDecodeTemperatureJson(value);
      if (decoded != null) {
        _collectTemperatureSensors(
          decoded,
          sensors,
          diskInfos,
          label,
          source,
          temperatureHint,
        );
        return;
      }

      diskInfos.addAll(_parseDiskInfoText(value));
      final lineSensors = _parseSensorsText(value);
      if (lineSensors.isNotEmpty) {
        sensors.addAll(lineSensors);
        return;
      }

      if (temperatureHint || label == null) {
        final parsed = _parseTemperatureText(value);
        if (parsed != null) {
          _addTemperatureSensor(
            sensors,
            label ?? 'Temperature',
            parsed,
            source: source,
          );
        }
      }
    case List():
      for (var index = 0; index < value.length; index += 1) {
        _collectTemperatureSensors(
          value[index],
          sensors,
          diskInfos,
          label,
          source,
          temperatureHint,
        );
      }
    case Map():
      for (final entry in value.entries) {
        final key = entry.key.toString();
        if (_shouldSkipTemperatureKey(key)) {
          continue;
        }
        final hardwareSource = _isHardwareSourceKey(key);
        final childLabel = hardwareSource
            ? label
            : _temperatureLabel(label, key);
        final childSource = hardwareSource
            ? _temperatureLabel(source, key)
            : source;
        _collectTemperatureSensors(
          entry.value,
          sensors,
          diskInfos,
          childLabel,
          childSource,
          temperatureHint ||
              _isTemperatureReadingKey(key) ||
              _isTemperatureReadingKey(label),
        );
      }
  }
}

void _addTemperatureSensor(
  List<NodeTemperatureSensor> sensors,
  String label,
  double celsius, {
  String? source,
}) {
  if (celsius > 1000) {
    celsius = celsius / 1000;
  }
  if (celsius < 5 || celsius > 150) {
    return;
  }
  sensors.add(
    NodeTemperatureSensor(
      label: _cleanTemperatureLabel(label),
      celsius: celsius,
      source: source == null ? null : _cleanTemperatureSource(source),
    ),
  );
}

String _temperatureLabel(String? parent, String key) {
  final normalizedKey = _cleanTemperatureLabel(key);
  if (parent == null || parent.isEmpty) {
    return normalizedKey;
  }
  if (_isGenericTemperatureKey(normalizedKey)) {
    return parent;
  }
  return '$parent $normalizedKey';
}

bool _isHardwareSourceKey(String value) {
  final normalized = value.toLowerCase().trim();
  return normalized.startsWith('/dev/') ||
      normalized.startsWith('sysfs ') ||
      normalized.startsWith('hwmon ') ||
      normalized.startsWith('smartctl ') ||
      normalized.contains('coretemp') ||
      normalized.contains('k10temp') ||
      normalized.contains('zenpower') ||
      normalized.contains('nvme') ||
      normalized.contains('sata') ||
      normalized.contains(' ata ') ||
      normalized.contains('drivetemp') ||
      normalized.contains('acpitz') ||
      normalized.contains('-isa-') ||
      normalized.contains('-pci-');
}

String _cleanTemperatureLabel(String value) {
  final text = value
      .replaceAll(RegExp(r'[_-]+'), ' ')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
  if (text.isEmpty || _isGenericTemperatureKey(text)) {
    return 'Temperature';
  }
  return text;
}

String? _cleanTemperatureSource(String value) {
  final text = _stripTerminalControl(
    value,
  ).replaceAll(RegExp(r'\s+'), ' ').trim();
  return text.isEmpty ? null : text;
}

bool _isGenericTemperatureKey(String value) {
  final normalized = value.toLowerCase().trim();
  final compact = normalized.replaceAll(RegExp(r'\s+'), '');
  return normalized == 'temp' ||
      normalized == 'temperature' ||
      normalized == 'celsius' ||
      normalized == 'value' ||
      normalized == 'current' ||
      normalized == 'input' ||
      RegExp(r'^temp\d*input?$').hasMatch(compact);
}

bool _isTemperatureReadingKey(String? value) {
  final normalized = value?.toLowerCase() ?? '';
  if (normalized.isEmpty) {
    return false;
  }
  return normalized.contains('temp') ||
      normalized.contains('temperature') ||
      normalized.contains('package') ||
      normalized.contains('core') ||
      normalized.contains('tctl') ||
      normalized.contains('tdie') ||
      normalized.contains('composite');
}

bool _shouldSkipTemperatureKey(String value) {
  final normalized = value.toLowerCase();
  return normalized.contains('max') ||
      normalized.contains('crit') ||
      normalized.contains('min') ||
      normalized.contains('high') ||
      normalized.contains('low') ||
      normalized.contains('threshold') ||
      normalized.contains('warning') ||
      normalized.contains('trip') ||
      normalized.contains('limit') ||
      normalized.contains('recommended') ||
      normalized.contains('throttle') ||
      normalized.contains('hyst') ||
      normalized.contains('alarm') ||
      normalized.contains('fault') ||
      normalized.contains('offset') ||
      normalized.contains('beep');
}

Object? _tryDecodeTemperatureJson(String value) {
  final text = value.trim();
  if (!text.startsWith('{') && !text.startsWith('[')) {
    return null;
  }
  try {
    return jsonDecode(text);
  } on FormatException {
    return null;
  }
}

String _stripTerminalControl(String value) {
  var text = value
      .replaceAll(RegExp(r'\x1B\][^\x07]*(?:\x07|\x1B\\)'), '')
      .replaceAll(RegExp(r'\x1B\[[0-?]*[ -/]*[@-~]'), '')
      .replaceAll('\r', '');

  while (text.contains('\b')) {
    final next = text.replaceAll(RegExp(r'.?\x08'), '');
    if (next == text) {
      break;
    }
    text = next;
  }

  return text;
}

List<NodeDiskInfo> _parseDiskInfoText(String value) {
  final infos = <NodeDiskInfo>[];
  String? source;
  for (final line in value.split('\n')) {
    final trimmedLine = _stripTerminalControl(line).trim();
    if (trimmedLine.isEmpty) {
      continue;
    }

    if (_isSensorsSourceLine(trimmedLine)) {
      source = trimmedLine;
      continue;
    }

    final model = _parseSmartDiskModelLine(trimmedLine);
    if (model == null || source == null) {
      continue;
    }

    final cleanSource = _cleanTemperatureSource(source);
    if (cleanSource == null) {
      continue;
    }
    infos.add(NodeDiskInfo(source: cleanSource, model: model));
  }
  return infos;
}

String? _parseSmartDiskModelLine(String line) {
  final match = RegExp(
    r'^\s*(?:Device Model|Model Number|Product|Model):\s*(.+)$',
    caseSensitive: false,
  ).firstMatch(line);
  if (match == null) {
    return null;
  }

  final model = match.group(1)?.trim();
  if (model == null || model.isEmpty) {
    return null;
  }
  return model.replaceAll(RegExp(r'\s+'), ' ');
}

List<NodeTemperatureSensor> _parseSensorsText(String value) {
  final sensors = <NodeTemperatureSensor>[];
  String? source;
  for (final line in value.split('\n')) {
    final cleanLine = _stripTerminalControl(line);
    final trimmedLine = cleanLine.trim();
    if (trimmedLine.isEmpty) {
      continue;
    }

    if (_isSensorsSourceLine(trimmedLine)) {
      source = trimmedLine;
      continue;
    }

    final sysfsMatch = RegExp(
      r'^\s*((?:sysfs|hwmon)\s+[^:]+):\s*([-+]?\d+(?:[\.,]\d+)?)\s*$',
      caseSensitive: false,
    ).firstMatch(cleanLine);
    if (sysfsMatch != null) {
      final celsius = double.tryParse(
        sysfsMatch.group(2)!.replaceAll(',', '.'),
      );
      if (celsius != null) {
        final label = sysfsMatch.group(1)!;
        _addTemperatureSensor(
          sensors,
          _labelWithoutInlineSource(label),
          celsius,
          source: _sourceFromTemperatureLabel(label),
        );
      }
      continue;
    }

    final smartReading = _parseSmartTemperatureLine(cleanLine);
    if (smartReading != null) {
      _addTemperatureSensor(
        sensors,
        smartReading.label,
        smartReading.celsius,
        source: source,
      );
      continue;
    }

    final celsiusMatch = RegExp(
      r'^\s*([^:]+):\s*([-+]?\d+(?:[\.,]\d+)?)\s*(?:°?\s*C(?:elsius)?)?\b',
      caseSensitive: false,
    ).firstMatch(cleanLine);
    if (celsiusMatch != null) {
      final celsius = double.tryParse(
        celsiusMatch.group(2)!.replaceAll(',', '.'),
      );
      if (celsius != null &&
          !_shouldSkipTemperatureKey(celsiusMatch.group(1)!)) {
        final label = celsiusMatch.group(1)!;
        final sensorSource = _sourceFromTemperatureLabel(label) ?? source;
        _addTemperatureSensor(
          sensors,
          _labelWithoutInlineSource(label),
          celsius,
          source: sensorSource,
        );
      }
      continue;
    }
  }
  return sensors;
}

bool _isSensorsSourceLine(String value) {
  final normalized = value.toLowerCase();
  if (normalized.startsWith('smartctl /dev/')) {
    return true;
  }
  if (value.startsWith('Adapter:') || value.startsWith('(')) {
    return false;
  }
  if (value.contains(':') || RegExp(r'\s').hasMatch(value)) {
    return false;
  }
  return normalized.contains('-isa-') ||
      normalized.contains('-pci-') ||
      normalized.contains('nvme') ||
      normalized.contains('coretemp') ||
      normalized.contains('k10temp') ||
      normalized.contains('zenpower') ||
      normalized.contains('drivetemp') ||
      normalized.contains('acpitz');
}

_SmartTemperatureReading? _parseSmartTemperatureLine(String line) {
  final normalized = line.toLowerCase();
  if (!normalized.contains('temp')) {
    return null;
  }

  final colonMatch = RegExp(
    r'^\s*([^:]*temp[^:]*):\s*(.+)$',
    caseSensitive: false,
  ).firstMatch(line);
  if (colonMatch != null) {
    final label = colonMatch.group(1)!.trim();
    if (_shouldSkipTemperatureKey(label)) {
      return null;
    }
    final celsius = _parseTemperatureText(colonMatch.group(2)!);
    if (celsius != null) {
      return _SmartTemperatureReading(label: label, celsius: celsius);
    }
  }

  final attributeMatch = RegExp(
    r'^\s*(?:\d+\s+)?([A-Za-z0-9_-]*temp[A-Za-z0-9_-]*)\s+(.+)$',
    caseSensitive: false,
  ).firstMatch(line);
  if (attributeMatch == null) {
    return null;
  }

  final label = attributeMatch.group(1)!.trim();
  if (_shouldSkipTemperatureKey(label)) {
    return null;
  }
  final rawValueMatch = RegExp(
    r'\s-\s+([-+]?\d+(?:[\.,]\d+)?)',
  ).firstMatch(attributeMatch.group(2)!);
  if (rawValueMatch != null) {
    final celsius = double.tryParse(
      rawValueMatch.group(1)!.replaceAll(',', '.'),
    );
    if (celsius != null) {
      return _SmartTemperatureReading(label: label, celsius: celsius);
    }
  }

  final numbers = RegExp(r'[-+]?\d+(?:[\.,]\d+)?')
      .allMatches(attributeMatch.group(2)!.replaceAll(',', '.'))
      .map((match) => double.tryParse(match.group(0)!))
      .whereType<double>()
      .toList();
  if (numbers.isEmpty) {
    return null;
  }
  return _SmartTemperatureReading(label: label, celsius: numbers.last);
}

class _SmartTemperatureReading {
  const _SmartTemperatureReading({required this.label, required this.celsius});

  final String label;
  final double celsius;
}

String? _sourceFromTemperatureLabel(String label) {
  final text = label.trim();
  final smartMatch = RegExp(
    r'^(smartctl\s+/dev/\S+)',
    caseSensitive: false,
  ).firstMatch(text);
  if (smartMatch != null) {
    return smartMatch.group(1);
  }

  final sysfsMatch = RegExp(
    r'^((?:sysfs|hwmon)\s+\S+)(?:\s+.+)?$',
    caseSensitive: false,
  ).firstMatch(text);
  if (sysfsMatch != null) {
    return sysfsMatch.group(1);
  }

  return null;
}

String _labelWithoutInlineSource(String label) {
  var text = label.trim();
  text = text.replaceFirst(
    RegExp(r'^smartctl\s+/dev/\S+\s+', caseSensitive: false),
    '',
  );
  text = text.replaceFirst(
    RegExp(r'^(?:sysfs|hwmon)\s+\S+\s+', caseSensitive: false),
    '',
  );
  if (text.isEmpty) {
    return label;
  }
  return text;
}

double? _parseTemperatureText(String value) {
  final match = RegExp(
    r'[-+]?\d+(?:\.\d+)?',
  ).firstMatch(value.replaceAll(',', '.'));
  if (match == null) {
    return null;
  }
  return double.tryParse(match.group(0)!);
}
