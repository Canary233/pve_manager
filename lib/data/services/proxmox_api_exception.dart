import 'package:pve_manager/l10n/generated/app_localizations.dart';

enum ProxmoxErrorCode {
  sessionExpired,
  guestConsoleOnly,
  unsupportedResourceType,
  loginResponseInvalid,
  loginTicketMissing,
  nodeStatusInvalid,
  terminalSessionInvalid,
  guestActionOnly,
  apiFormatInvalid,
  requestFailed,
  redirectResponse,
  nonJsonResponse,
  webConsoleUnsupported,
  nativeConsoleMissing,
  consoleOpenFailed,
  platformConsoleUnsupported,
}

class ProxmoxApiException implements Exception {
  const ProxmoxApiException(this.code, {this.message, this.values = const {}});

  final ProxmoxErrorCode code;
  final String? message;
  final Map<String, Object?> values;

  String localizedMessage(AppLocalizations l10n) {
    if (message != null && message!.isNotEmpty) {
      return message!;
    }

    return switch (code) {
      ProxmoxErrorCode.sessionExpired => l10n.sessionExpired,
      ProxmoxErrorCode.guestConsoleOnly => l10n.guestConsoleOnly,
      ProxmoxErrorCode.unsupportedResourceType => l10n.unsupportedResourceType,
      ProxmoxErrorCode.loginResponseInvalid => l10n.loginResponseInvalid,
      ProxmoxErrorCode.loginTicketMissing => l10n.loginTicketMissing,
      ProxmoxErrorCode.nodeStatusInvalid => l10n.nodeStatusInvalid,
      ProxmoxErrorCode.terminalSessionInvalid => l10n.terminalSessionInvalid,
      ProxmoxErrorCode.guestActionOnly => l10n.guestActionOnly,
      ProxmoxErrorCode.apiFormatInvalid => l10n.apiFormatInvalid(
        _int('statusCode'),
      ),
      ProxmoxErrorCode.requestFailed => l10n.requestFailed(_int('statusCode')),
      ProxmoxErrorCode.redirectResponse => l10n.redirectResponse(
        _int('statusCode'),
        _string('location'),
      ),
      ProxmoxErrorCode.nonJsonResponse => l10n.nonJsonResponse(
        _string('uri'),
        _int('statusCode'),
        _string('contentType'),
        values['preview']?.toString() ?? l10n.emptyResponsePreview,
        [
          l10n.nonJsonHintApiAddress,
          l10n.nonJsonHintHtml,
          l10n.nonJsonHintWeb,
        ].join('\n'),
      ),
      ProxmoxErrorCode.webConsoleUnsupported => l10n.webConsoleUnsupported,
      ProxmoxErrorCode.nativeConsoleMissing => l10n.nativeConsoleMissing,
      ProxmoxErrorCode.consoleOpenFailed => l10n.consoleOpenFailed,
      ProxmoxErrorCode.platformConsoleUnsupported =>
        l10n.platformConsoleUnsupported,
    };
  }

  int _int(String key) {
    final value = values[key];
    if (value is num) {
      return value.round();
    }
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }

  String _string(String key) => values[key]?.toString() ?? '';

  @override
  String toString() => message ?? code.name;
}
