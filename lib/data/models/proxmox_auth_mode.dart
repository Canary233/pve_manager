enum ProxmoxAuthMode {
  password('password'),
  apiToken('api_token');

  const ProxmoxAuthMode(this.storageValue);

  final String storageValue;

  static ProxmoxAuthMode fromStorage(Object? value) {
    final normalized = value?.toString().trim().toLowerCase();
    return ProxmoxAuthMode.values.firstWhere(
      (mode) => mode.storageValue == normalized,
      orElse: () => ProxmoxAuthMode.password,
    );
  }
}

class ProxmoxApiTokenCredentials {
  const ProxmoxApiTokenCredentials({
    required this.userId,
    required this.tokenId,
    required this.secret,
  });

  factory ProxmoxApiTokenCredentials.fromInput({
    required String username,
    required String realm,
    required String tokenId,
    required String tokenSecret,
  }) {
    final tokenCredentials = ProxmoxApiTokenCredentials.fromTokenInput(
      tokenId: tokenId,
      tokenSecret: tokenSecret,
    );
    if (tokenCredentials.userId.isNotEmpty) {
      return tokenCredentials;
    }

    final configuredUserId = username.contains('@')
        ? username.trim()
        : '${username.trim()}@${realm.trim()}';
    return ProxmoxApiTokenCredentials(
      userId: configuredUserId,
      tokenId: tokenCredentials.tokenId,
      secret: tokenCredentials.secret,
    );
  }

  factory ProxmoxApiTokenCredentials.fromTokenInput({
    required String tokenId,
    required String tokenSecret,
  }) {
    var effectiveUserId = '';
    var effectiveTokenId = tokenId.trim();
    var effectiveSecret = tokenSecret.trim();

    final tokenIdParts = _parseApiToken(
      effectiveTokenId,
      allowIdentityOnly: true,
    );
    if (tokenIdParts != null) {
      effectiveUserId = tokenIdParts.userId;
      effectiveTokenId = tokenIdParts.tokenId;
      if (effectiveSecret.isEmpty && tokenIdParts.secret != null) {
        effectiveSecret = tokenIdParts.secret!;
      }
    }

    final secretParts = _parseApiToken(effectiveSecret);
    if (secretParts != null) {
      effectiveUserId = secretParts.userId;
      effectiveTokenId = secretParts.tokenId;
      effectiveSecret = secretParts.secret ?? '';
    }

    return ProxmoxApiTokenCredentials(
      userId: effectiveUserId,
      tokenId: effectiveTokenId,
      secret: effectiveSecret,
    );
  }

  final String userId;
  final String tokenId;
  final String secret;

  String get username {
    final separator = userId.lastIndexOf('@');
    return separator <= 0 ? userId : userId.substring(0, separator);
  }

  String get realm {
    final separator = userId.lastIndexOf('@');
    return separator == -1 || separator == userId.length - 1
        ? 'pam'
        : userId.substring(separator + 1);
  }

  String get accountLabel => '$userId!$tokenId';
  String get authorizationValue => 'PVEAPIToken=$accountLabel=$secret';
}

_ParsedApiToken? _parseApiToken(
  String input, {
  bool allowIdentityOnly = false,
}) {
  var normalized = input.trim();
  const prefix = 'PVEAPIToken=';
  if (normalized.startsWith(prefix)) {
    normalized = normalized.substring(prefix.length);
  }

  final separator = normalized.indexOf('!');
  if (separator <= 0 || separator == normalized.length - 1) {
    return null;
  }

  final secretSeparator = normalized.indexOf('=', separator + 1);
  if (secretSeparator == -1 && !allowIdentityOnly) {
    return null;
  }

  final userId = normalized.substring(0, separator).trim();
  final tokenId =
      (secretSeparator == -1
              ? normalized.substring(separator + 1)
              : normalized.substring(separator + 1, secretSeparator))
          .trim();
  final secret = secretSeparator == -1
      ? null
      : normalized.substring(secretSeparator + 1).trim();
  if (userId.isEmpty || tokenId.isEmpty) {
    return null;
  }
  return _ParsedApiToken(userId: userId, tokenId: tokenId, secret: secret);
}

class _ParsedApiToken {
  const _ParsedApiToken({
    required this.userId,
    required this.tokenId,
    required this.secret,
  });

  final String userId;
  final String tokenId;
  final String? secret;
}
