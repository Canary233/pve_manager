import 'package:shared_preferences/shared_preferences.dart';

import 'package:pve_manager/core/settings/auto_refresh_settings.dart';

class AppSettingsRepository {
  AppSettingsRepository._();

  static final AppSettingsRepository instance = AppSettingsRepository._();

  static const _autoRefreshSecondsKey = 'auto_refresh_seconds';

  Future<Duration> getAutoRefreshInterval() async {
    final preferences = await SharedPreferences.getInstance();
    final seconds = preferences.getInt(_autoRefreshSecondsKey);
    if (seconds == null) {
      return defaultAutoRefreshInterval;
    }

    final interval = Duration(seconds: seconds);
    if (!autoRefreshIntervalOptions.contains(interval)) {
      return defaultAutoRefreshInterval;
    }

    return interval;
  }

  Future<void> setAutoRefreshInterval(Duration interval) async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setInt(_autoRefreshSecondsKey, interval.inSeconds);
  }
}
