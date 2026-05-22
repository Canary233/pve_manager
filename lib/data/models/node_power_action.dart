import 'package:flutter/material.dart';

enum NodePowerAction {
  reboot('reboot', Icons.restart_alt_rounded),
  shutdown('shutdown', Icons.power_settings_new_rounded);

  const NodePowerAction(this.command, this.icon);

  final String command;
  final IconData icon;
}
