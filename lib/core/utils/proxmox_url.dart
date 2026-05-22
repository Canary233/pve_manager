import 'package:pve_manager/l10n/generated/app_localizations.dart';

String normalizeOrigin(String value) {
  final trimmed = value.trim();
  final withScheme =
      trimmed.startsWith('http://') || trimmed.startsWith('https://')
      ? trimmed
      : 'https://$trimmed';
  final uri = Uri.parse(withScheme);

  return Uri(
    scheme: uri.scheme,
    host: uri.host,
    port: uri.hasPort ? uri.port : 8006,
  ).toString();
}

String? validateOrigin(AppLocalizations l10n, String? value) {
  if (value == null || value.trim().isEmpty) {
    return l10n.enterProxmoxAddress;
  }

  final uri = Uri.tryParse(normalizeOrigin(value));
  if (uri == null || !uri.hasScheme || uri.host.isEmpty) {
    return l10n.invalidAddress;
  }

  if (uri.scheme != 'https' && uri.scheme != 'http') {
    return l10n.unsupportedScheme;
  }

  return null;
}

String? requiredField(String? value, String message) {
  return value == null || value.trim().isEmpty ? message : null;
}
