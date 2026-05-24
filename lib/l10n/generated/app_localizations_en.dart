// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'PVE Manager';

  @override
  String get addServer => 'Add server';

  @override
  String get switchLanguage => 'Switch language';

  @override
  String get settings => 'Settings';

  @override
  String get language => 'Language';

  @override
  String get selectLanguage => 'Select language';

  @override
  String get autoRefreshInterval => 'Auto refresh interval';

  @override
  String get selectAutoRefreshInterval => 'Select auto refresh interval';

  @override
  String secondsInterval(int seconds) {
    return '${seconds}s';
  }

  @override
  String get languageChineseSimplified => 'Simplified Chinese';

  @override
  String get languageEnglish => 'English';

  @override
  String get editServer => 'Edit server';

  @override
  String get edit => 'Edit';

  @override
  String get delete => 'Delete';

  @override
  String get cancel => 'Cancel';

  @override
  String get save => 'Save';

  @override
  String get add => 'Add';

  @override
  String get confirm => 'Confirm';

  @override
  String get retry => 'Retry';

  @override
  String get refresh => 'Refresh';

  @override
  String get back => 'Back';

  @override
  String get power => 'Power';

  @override
  String get terminal => 'Terminal';

  @override
  String get tasksAndLogs => 'Tasks and logs';

  @override
  String get tasks => 'Tasks';

  @override
  String get logs => 'Logs';

  @override
  String get loadTasks => 'Load tasks';

  @override
  String get loadLogs => 'Load logs';

  @override
  String get loadMore => 'Load more';

  @override
  String get noTasks => 'No tasks';

  @override
  String get noLogs => 'No logs';

  @override
  String get noData => 'No data';

  @override
  String get noServers => 'No servers yet';

  @override
  String get emptyServersHint =>
      'Tap the add button in the bottom right to add a Proxmox server.';

  @override
  String get serverName => 'Name';

  @override
  String get serverNameHint => 'PVE Home';

  @override
  String get proxmoxAddress => 'Proxmox address';

  @override
  String get username => 'Username';

  @override
  String get password => 'Password';

  @override
  String get realm => 'Realm';

  @override
  String get allowSelfSignedCertificate => 'Allow self-signed certificate';

  @override
  String get enterProxmoxAddress => 'Enter the Proxmox address';

  @override
  String get invalidAddress => 'Invalid address';

  @override
  String get unsupportedScheme => 'Only http or https is supported';

  @override
  String get enterUsername => 'Enter username';

  @override
  String get enterRealm => 'Enter realm';

  @override
  String get enterPassword => 'Enter password';

  @override
  String get neverConnected => 'Never connected';

  @override
  String lastLogin(Object time) {
    return 'Last login: $time';
  }

  @override
  String get nodes => 'Nodes';

  @override
  String get guests => 'VMs and containers';

  @override
  String get storage => 'Storage';

  @override
  String nodesCount(int count) {
    return '$count nodes';
  }

  @override
  String itemsCount(int count) {
    return '$count items';
  }

  @override
  String get noNodes => 'No nodes found.';

  @override
  String get noGuests => 'No VMs or containers found.';

  @override
  String get noStorage => 'No storage resources found.';

  @override
  String get nodeDetails => 'Node details';

  @override
  String get systemInfo => 'System information';

  @override
  String get resourceUsage => 'Resource usage';

  @override
  String get cpuUsage => 'CPU usage';

  @override
  String get memoryHistory => 'Memory usage';

  @override
  String processor(Object model) {
    return 'Processor $model';
  }

  @override
  String get cpuCores => 'CPU cores';

  @override
  String cpuCoresValue(int cpus, int sockets) {
    return '$cpus cores $sockets sockets';
  }

  @override
  String get pveVersion => 'PVE version';

  @override
  String get kernelVersion => 'Kernel version';

  @override
  String get uptime => 'Uptime';

  @override
  String get loadAverage => 'Load average';

  @override
  String get memory => 'Memory';

  @override
  String get disk => 'Disk';

  @override
  String get swap => 'Swap';

  @override
  String get rootPartition => 'Root partition';

  @override
  String get capacity => 'Capacity';

  @override
  String get powerActions => 'Power actions';

  @override
  String get openVnc => 'Open VNC';

  @override
  String get openTerminal => 'Open terminal';

  @override
  String get openRemoteVnc => 'Open remote VNC';

  @override
  String get openRemoteTerminal => 'Open remote terminal';

  @override
  String vncTitle(Object name) {
    return '$name VNC';
  }

  @override
  String terminalTitle(Object name) {
    return '$name terminal';
  }

  @override
  String guestActionSent(Object name, Object action) {
    return '$name $action request sent';
  }

  @override
  String nodePowerConfirm(Object node, Object action) {
    return 'Run $action on node $node?';
  }

  @override
  String powerRequestSent(Object action) {
    return '$action request sent';
  }

  @override
  String get start => 'Start';

  @override
  String get shutdown => 'Shutdown';

  @override
  String get reboot => 'Reboot';

  @override
  String get stop => 'Stop';

  @override
  String get rebootNode => 'Reboot node';

  @override
  String get shutdownNode => 'Shutdown node';

  @override
  String get online => 'Online';

  @override
  String get running => 'Running';

  @override
  String get stopped => 'Stopped';

  @override
  String get node => 'Node';

  @override
  String get storageType => 'Storage';

  @override
  String get timeframeHour => '1 hour';

  @override
  String get timeframeDay => '1 day';

  @override
  String get timeframeWeek => '1 week';

  @override
  String get timeframeMonth => '1 month';

  @override
  String get timeframeYear => '1 year';

  @override
  String get onlineNodes => 'Online nodes';

  @override
  String get runningGuests => 'Running guests';

  @override
  String get totalResources => 'Total resources';

  @override
  String get webConsoleUnsupported =>
      'Remote console is not supported in Web mode.';

  @override
  String get nativeConsoleMissing =>
      'The native remote console module is not loaded. Stop the app and run it again, or install the latest APK; hot restart cannot load new Android native code.';

  @override
  String get consoleOpenFailed => 'Failed to open remote console.';

  @override
  String get consoleFallbackTitle => 'Console';

  @override
  String get consoleInvalidArguments => 'Console arguments are incomplete.';

  @override
  String consoleLoadFailed(Object description) {
    return 'Console failed to load: $description';
  }

  @override
  String get unknownError => 'Unknown error';

  @override
  String get consoleCertificateError =>
      'Console certificate verification failed. Trust the PVE certificate, or enable ignoring certificate errors in the server settings.';

  @override
  String get consoleErrorHint =>
      'Tap the title bar to return, or use the system back button.';

  @override
  String get platformConsoleUnsupported =>
      'The built-in remote console is not supported on this platform yet.';

  @override
  String get socketError =>
      'Cannot connect to the Proxmox host. Check the address and network.';

  @override
  String get handshakeError =>
      'TLS certificate verification failed. Enable the self-signed certificate option and retry.';

  @override
  String get timeoutError =>
      'Request timed out. Check whether the Proxmox API is reachable.';

  @override
  String get formatError =>
      'The response is not valid JSON. Check that the address points to the Proxmox API.';

  @override
  String get sessionExpired => 'Session expired. Log in again.';

  @override
  String get guestConsoleOnly => 'Console can only be opened for VMs or CTs.';

  @override
  String get unsupportedResourceType => 'Unsupported resource type.';

  @override
  String get loginResponseInvalid =>
      'Unexpected login response. Check that the address points to the Proxmox API.';

  @override
  String get loginTicketMissing =>
      'Login response is missing a ticket. Check the account or permissions.';

  @override
  String get nodeStatusInvalid => 'Unexpected node status response.';

  @override
  String get terminalSessionInvalid => 'Unexpected terminal session response.';

  @override
  String get guestActionOnly => 'This action can only be run on a VM or CT.';

  @override
  String apiFormatInvalid(int statusCode) {
    return 'Unexpected API response format: HTTP $statusCode';
  }

  @override
  String requestFailed(int statusCode) {
    return 'Request failed: HTTP $statusCode';
  }

  @override
  String redirectResponse(int statusCode, Object location) {
    return 'The Proxmox API returned a redirect: HTTP $statusCode$location.\nUse an address like https://host:8006 instead of a web page or redirecting reverse proxy.';
  }

  @override
  String nonJsonResponse(
    Object uri,
    int statusCode,
    Object contentType,
    Object preview,
    Object hints,
  ) {
    return 'The response is not valid JSON.\nRequest: $uri\nStatus: HTTP $statusCode\nType: $contentType\nPreview: $preview\n$hints';
  }

  @override
  String get nonJsonHintApiAddress =>
      'Use the Proxmox API address, for example https://192.168.1.10:8006';

  @override
  String get nonJsonHintHtml =>
      'If the response preview starts with <!doctype html> or <html, the address points to a web page or reverse proxy page';

  @override
  String get nonJsonHintWeb =>
      'If you are running Flutter Web, switch to Android or Windows';

  @override
  String get emptyResponsePreview => '<empty>';

  @override
  String durationDaysHoursMinutes(int days, int hours, int minutes) {
    return '${days}d ${hours}h ${minutes}m';
  }

  @override
  String durationHoursMinutes(int hours, int minutes) {
    return '${hours}h ${minutes}m';
  }

  @override
  String durationMinutes(int minutes) {
    return '${minutes}m';
  }
}
