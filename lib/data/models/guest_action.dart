import 'package:flutter/material.dart';

enum GuestAction {
  start('start', Icons.play_arrow_rounded),
  shutdown('shutdown', Icons.power_settings_new_rounded),
  reboot('reboot', Icons.restart_alt_rounded),
  stop('stop', Icons.stop_rounded);

  const GuestAction(this.api, this.icon);

  final String api;
  final IconData icon;
}
