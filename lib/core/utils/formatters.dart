import 'package:pve_manager/l10n/generated/app_localizations.dart';

double asDouble(Object? value) {
  if (value is num) {
    return value.toDouble();
  }
  return double.tryParse(value?.toString() ?? '') ?? 0;
}

int asInt(Object? value) {
  if (value is num) {
    return value.round();
  }
  return int.tryParse(value?.toString() ?? '') ?? 0;
}

int? asNullableInt(Object? value) {
  if (value is num) {
    return value.round();
  }
  return int.tryParse(value?.toString() ?? '');
}

String percent(double value) {
  return '${(value.clamp(0, 1) * 100).toStringAsFixed(1)}%';
}

String bytes(int value) {
  if (value <= 0) {
    return '-';
  }

  const units = ['B', 'KiB', 'MiB', 'GiB', 'TiB', 'PiB'];
  var size = value.toDouble();
  var index = 0;

  while (size >= 1024 && index < units.length - 1) {
    size /= 1024;
    index++;
  }

  return '${size.toStringAsFixed(index == 0 ? 0 : 1)} ${units[index]}';
}

String uptime(AppLocalizations l10n, int seconds) {
  if (seconds <= 0) {
    return '-';
  }

  final days = seconds ~/ Duration.secondsPerDay;
  final hours = (seconds % Duration.secondsPerDay) ~/ Duration.secondsPerHour;
  final minutes =
      (seconds % Duration.secondsPerHour) ~/ Duration.secondsPerMinute;

  if (days > 0) {
    return l10n.durationDaysHoursMinutes(days, hours, minutes);
  }
  if (hours > 0) {
    return l10n.durationHoursMinutes(hours, minutes);
  }
  return l10n.durationMinutes(minutes);
}

String timestamp(int seconds) {
  if (seconds <= 0) {
    return '-';
  }

  final dateTime = DateTime.fromMillisecondsSinceEpoch(seconds * 1000);
  String twoDigits(int value) => value.toString().padLeft(2, '0');
  return '${dateTime.year}-${twoDigits(dateTime.month)}-${twoDigits(dateTime.day)} '
      '${twoDigits(dateTime.hour)}:${twoDigits(dateTime.minute)}';
}

String timestampFromMilliseconds(AppLocalizations l10n, int? milliseconds) {
  if (milliseconds == null || milliseconds <= 0) {
    return l10n.neverConnected;
  }

  final dateTime = DateTime.fromMillisecondsSinceEpoch(milliseconds);
  String twoDigits(int value) => value.toString().padLeft(2, '0');
  return '${dateTime.year}-${twoDigits(dateTime.month)}-${twoDigits(dateTime.day)} '
      '${twoDigits(dateTime.hour)}:${twoDigits(dateTime.minute)}';
}
