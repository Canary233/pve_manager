import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'package:pve_manager/l10n/generated/app_localizations.dart';
import 'package:pve_manager/data/services/proxmox_client.dart';
import 'package:pve_manager/data/services/proxmox_api_exception.dart';

class RemoteConsoleLauncher {
  const RemoteConsoleLauncher._();

  static const MethodChannel _channel = MethodChannel(
    'pve_manager/remote_console',
  );

  static Future<void> open({
    required String title,
    required Uri uri,
    required ProxmoxClient client,
    required AppLocalizations l10n,
  }) async {
    if (kIsWeb) {
      throw const ProxmoxApiException(ProxmoxErrorCode.webConsoleUnsupported);
    }

    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        try {
          await _channel.invokeMethod<void>('open', {
            'title': title,
            'url': uri.toString(),
            'cookieDomain': client.host,
            'authCookie': client.authCookieValue,
            'ignoreCertificateErrors': client.ignoreCertificateErrors,
            'fallbackTitle': l10n.consoleFallbackTitle,
            'invalidArgumentsMessage': l10n.consoleInvalidArguments,
            'loadFailedTemplate': l10n.consoleLoadFailed('{description}'),
            'unknownErrorMessage': l10n.unknownError,
            'certificateErrorMessage': l10n.consoleCertificateError,
            'errorHint': l10n.consoleErrorHint,
          });
        } on MissingPluginException {
          throw const ProxmoxApiException(
            ProxmoxErrorCode.nativeConsoleMissing,
          );
        } on PlatformException catch (error) {
          throw ProxmoxApiException(
            ProxmoxErrorCode.consoleOpenFailed,
            message: error.message,
          );
        }
      case TargetPlatform.iOS:
      case TargetPlatform.macOS:
      case TargetPlatform.linux:
      case TargetPlatform.windows:
      case TargetPlatform.fuchsia:
        throw const ProxmoxApiException(
          ProxmoxErrorCode.platformConsoleUnsupported,
        );
    }
  }
}
