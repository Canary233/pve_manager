import 'dart:convert';
import 'dart:io';

import 'package:pve_manager/data/models/guest_action.dart';
import 'package:pve_manager/data/models/guest_config.dart';
import 'package:pve_manager/data/models/guest_rrd_point.dart';
import 'package:pve_manager/data/models/node_log_entry.dart';
import 'package:pve_manager/data/models/node_power_action.dart';
import 'package:pve_manager/data/models/node_rrd_point.dart';
import 'package:pve_manager/data/models/node_status.dart';
import 'package:pve_manager/data/models/node_task.dart';
import 'package:pve_manager/data/models/node_terminal_session.dart';
import 'package:pve_manager/data/models/paged_result.dart';
import 'package:pve_manager/data/models/pve_node.dart';
import 'package:pve_manager/data/models/pve_resource.dart';

import 'package:pve_manager/data/services/error_messages.dart';
import 'package:pve_manager/data/services/proxmox_api_exception.dart';

class ProxmoxClient {
  ProxmoxClient({
    required this.origin,
    required this.username,
    required this.password,
    this.realm = 'pam',
    this.ignoreCertificateErrors = false,
  }) : _httpClient = HttpClient() {
    _httpClient.connectionTimeout = const Duration(seconds: 15);
    _httpClient.badCertificateCallback =
        (X509Certificate cert, String host, int port) =>
            ignoreCertificateErrors;
  }

  final String origin;
  final String username;
  final String password;
  final String realm;
  final bool ignoreCertificateErrors;
  final HttpClient _httpClient;
  String? _ticket;
  String? _csrfToken;

  static const Duration _requestTimeout = Duration(seconds: 12);

  String get displayHost => Uri.parse(origin).host;
  bool get hasActiveSession => _ticket != null;
  String get host => Uri.parse(origin).host;

  ProxmoxClient forkSession() {
    if (_ticket == null) {
      throw const ProxmoxApiException(ProxmoxErrorCode.sessionExpired);
    }

    return ProxmoxClient(
        origin: origin,
        username: username,
        password: password,
        realm: realm,
        ignoreCertificateErrors: ignoreCertificateErrors,
      )
      .._ticket = _ticket
      .._csrfToken = _csrfToken;
  }

  String get authCookieValue {
    final ticket = _ticket;
    if (ticket == null) {
      throw const ProxmoxApiException(ProxmoxErrorCode.sessionExpired);
    }

    return ticket;
  }

  Uri nodeShellConsoleUri(String node) {
    return _consoleUri('/', {
      'console': 'shell',
      'node': node,
      'novnc': '1',
      'resize': 'scale',
      'cmd': 'login',
    });
  }

  Uri guestConsoleUri(PveResource guest) {
    if (!guest.isGuest) {
      throw const ProxmoxApiException(ProxmoxErrorCode.guestConsoleOnly);
    }

    final console = switch (guest.type) {
      'qemu' => 'kvm',
      'lxc' => 'lxc',
      _ => throw const ProxmoxApiException(
        ProxmoxErrorCode.unsupportedResourceType,
      ),
    };

    return _consoleUri('/', {
      'console': console,
      'node': guest.node,
      'vmid': '${guest.vmid}',
      'vmname': guest.name,
      'novnc': '1',
      'resize': 'scale',
    });
  }

  Future<void> login({String? tfaChallenge, String? tfaResponse}) async {
    final response = await _request(
      'POST',
      '/access/ticket',
      body: {
        'username': username.contains('@') ? username : '$username@$realm',
        'password': _ticketPassword(tfaResponse),
        if (tfaChallenge?.trim().isNotEmpty ?? false)
          'tfa-challenge': tfaChallenge!.trim(),
      },
      needsAuth: false,
    );

    final data = _loginData(response);

    if (_boolValue(data['NeedTFA']) || _isTicketChallenge(data['ticket'])) {
      throw ProxmoxTfaRequiredException(challenge: Map.of(data));
    }

    _storeLoginData(data);
  }

  Future<void> completeTwoFactor(
    ProxmoxTfaRequiredException challenge,
    String response,
  ) async {
    if (challenge.usesTicketChallenge) {
      await login(tfaChallenge: challenge.ticket, tfaResponse: response);
      return;
    }

    final temporaryTicket = challenge.ticket;
    if (temporaryTicket == null || temporaryTicket.isEmpty) {
      throw const ProxmoxApiException(ProxmoxErrorCode.loginTicketMissing);
    }

    final result = await _request(
      'POST',
      '/access/tfa',
      body: {'response': response.trim()},
      authTicket: temporaryTicket,
      csrfToken: challenge.csrfToken,
    );

    final data = _loginData(result);
    data['CSRFPreventionToken'] ??= challenge.csrfToken;
    _storeLoginData(data);
  }

  String _ticketPassword(String? tfaResponse) {
    final response = tfaResponse?.trim();
    if (response == null || response.isEmpty) {
      return password;
    }
    if (response.contains(':')) {
      return response;
    }
    return 'totp:$response';
  }

  Future<List<PveResource>> getResources({String? type}) async {
    final response = await _request(
      'GET',
      '/cluster/resources',
      queryParameters: type == null ? null : {'type': type},
    );
    final data = response['data'];

    if (data is! List) {
      return <PveResource>[];
    }

    return data
        .whereType<Map<String, dynamic>>()
        .map(PveResource.fromJson)
        .toList()
      ..sort((a, b) {
        final typeOrder = _typeRank(a.type).compareTo(_typeRank(b.type));
        if (typeOrder != 0) {
          return typeOrder;
        }
        if (a.isGuest && b.isGuest) {
          return (a.vmid ?? 0).compareTo(b.vmid ?? 0);
        }
        return a.name.compareTo(b.name);
      });
  }

  Future<List<PveNode>> getNodes() async {
    final response = await _request('GET', '/nodes');
    final data = response['data'];

    if (data is! List) {
      return <PveNode>[];
    }

    return data.whereType<Map<String, dynamic>>().map(PveNode.fromJson).toList()
      ..sort((a, b) => a.name.compareTo(b.name));
  }

  Future<Map<String, dynamic>> getClusterStatus() async {
    final response = await _request('GET', '/cluster/status');
    final data = response['data'];

    if (data is List) {
      final cluster = data.whereType<Map<String, dynamic>>().firstWhere(
        (item) => item['type'] == 'cluster',
        orElse: () => <String, dynamic>{},
      );
      return cluster;
    }

    return <String, dynamic>{};
  }

  Future<bool> canReadStorageConfig() async {
    await _request('GET', '/storage');
    return true;
  }

  Future<NodeStatus> getNodeStatus(String node) async {
    final response = await _request('GET', '/nodes/$node/status');
    final data = response['data'];

    if (data is! Map<String, dynamic>) {
      throw const ProxmoxApiException(ProxmoxErrorCode.nodeStatusInvalid);
    }

    return NodeStatus.fromJson(data);
  }

  Future<List<NodeRrdPoint>> getNodeRrdData(
    String node, {
    String timeframe = 'hour',
  }) async {
    final response = await _request(
      'GET',
      '/nodes/$node/rrddata',
      queryParameters: {'timeframe': timeframe, 'cf': 'AVERAGE'},
    );
    final data = response['data'];

    if (data is! List) {
      return <NodeRrdPoint>[];
    }

    return data
        .whereType<Map<String, dynamic>>()
        .map(NodeRrdPoint.fromJson)
        .toList()
      ..sort((a, b) => a.time.compareTo(b.time));
  }

  Future<List<GuestRrdPoint>> getGuestRrdData(
    PveResource guest, {
    String timeframe = 'hour',
  }) async {
    if (!guest.isGuest) {
      throw const ProxmoxApiException(ProxmoxErrorCode.guestActionOnly);
    }

    final guestPath = switch (guest.type) {
      'qemu' => 'qemu',
      'lxc' => 'lxc',
      _ => throw const ProxmoxApiException(
        ProxmoxErrorCode.unsupportedResourceType,
      ),
    };

    final response = await _request(
      'GET',
      '/nodes/${guest.node}/$guestPath/${guest.vmid}/rrddata',
      queryParameters: {'timeframe': timeframe, 'cf': 'AVERAGE'},
    );
    final data = response['data'];

    if (data is! List) {
      return <GuestRrdPoint>[];
    }

    return data
        .whereType<Map<String, dynamic>>()
        .map(GuestRrdPoint.fromJson)
        .toList()
      ..sort((a, b) => a.time.compareTo(b.time));
  }

  Future<PveResource> getGuestCurrentStatus(PveResource guest) async {
    if (!guest.isGuest) {
      throw const ProxmoxApiException(ProxmoxErrorCode.guestActionOnly);
    }

    final guestPath = switch (guest.type) {
      'qemu' => 'qemu',
      'lxc' => 'lxc',
      _ => throw const ProxmoxApiException(
        ProxmoxErrorCode.unsupportedResourceType,
      ),
    };

    final response = await _request(
      'GET',
      '/nodes/${guest.node}/$guestPath/${guest.vmid}/status/current',
    );
    final data = response['data'];
    if (data is! Map<String, dynamic>) {
      return guest;
    }

    return guest.mergeStatus(data);
  }

  Future<GuestConfig> getGuestConfig(PveResource guest) async {
    if (!guest.isGuest) {
      throw const ProxmoxApiException(ProxmoxErrorCode.guestActionOnly);
    }

    final guestPath = _guestApiPath(guest);
    final path = '/nodes/${guest.node}/$guestPath/${guest.vmid}/config';
    final response = await _request('GET', path);
    final data = response['data'];

    var editSchema = const GuestConfigEditSchema.unavailable();
    try {
      final optionsResponse = await _request('OPTIONS', path);
      editSchema = GuestConfigEditSchema.fromOptions(optionsResponse['data']);
    } on ProxmoxApiException {
      editSchema = const GuestConfigEditSchema.unavailable();
    }

    if (data is! Map<String, dynamic>) {
      return GuestConfig(
        values: const <String, String>{},
        editSchema: editSchema,
      );
    }

    final config = <String, String>{};
    for (final entry in data.entries) {
      if (entry.key == 'digest') {
        continue;
      }
      config[entry.key] = entry.value?.toString() ?? '';
    }
    return GuestConfig(values: config, editSchema: editSchema);
  }

  Future<void> updateGuestConfig(
    PveResource guest,
    String key,
    String value,
  ) async {
    await updateGuestConfigValues(guest, {key: value});
  }

  Future<void> updateGuestConfigValues(
    PveResource guest,
    Map<String, String> values,
  ) async {
    if (!guest.isGuest) {
      throw const ProxmoxApiException(ProxmoxErrorCode.guestActionOnly);
    }
    if (values.isEmpty) {
      return;
    }

    final guestPath = _guestApiPath(guest);
    await _request(
      'PUT',
      '/nodes/${guest.node}/$guestPath/${guest.vmid}/config',
      body: values,
    );
  }

  Future<PagedResult<NodeTask>> getNodeTasks(
    String node, {
    int start = 0,
    int limit = 20,
  }) async {
    final response = await _getWithParameterFallback(
      '/nodes/$node/tasks',
      queryParameters: {'start': '$start', 'limit': '$limit'},
    );
    final data = response.body['data'];

    if (data is! List) {
      return const PagedResult<NodeTask>(items: <NodeTask>[], hasMore: false);
    }

    final items = data
        .whereType<Map<String, dynamic>>()
        .map(NodeTask.fromJson)
        .toList();
    final visibleItems = response.usedFallback
        ? items.take(limit).toList()
        : items;

    return PagedResult<NodeTask>(
      items: visibleItems,
      hasMore: !response.usedFallback && items.length >= limit,
      nextStart: !response.usedFallback ? start + visibleItems.length : null,
    );
  }

  Future<PagedResult<NodeLogEntry>> getNodeSyslog(
    String node, {
    int? start,
    int limit = 30,
  }) async {
    if (start == null) {
      return _getLatestNodeSyslog(node, limit: limit);
    }

    return _getNodeSyslogPage(node, start: start, limit: limit);
  }

  Future<PagedResult<NodeLogEntry>> _getLatestNodeSyslog(
    String node, {
    required int limit,
  }) async {
    final response = await _getWithParameterFallback(
      '/nodes/$node/syslog',
      queryParameters: {'start': '0', 'limit': '1'},
    );
    final data = response.body['data'];

    if (data is! List) {
      return const PagedResult<NodeLogEntry>(
        items: <NodeLogEntry>[],
        hasMore: false,
      );
    }

    if (response.usedFallback) {
      final items =
          data
              .whereType<Map<String, dynamic>>()
              .map(NodeLogEntry.fromJson)
              .toList()
            ..sort((a, b) => b.lineNumber.compareTo(a.lineNumber));
      return PagedResult<NodeLogEntry>(
        items: items.take(limit).toList(),
        hasMore: false,
      );
    }

    final total = _intValue(response.body['total']);
    if (total <= 0) {
      return const PagedResult<NodeLogEntry>(
        items: <NodeLogEntry>[],
        hasMore: false,
      );
    }

    final start = total > limit ? total - limit : 0;
    return _getNodeSyslogPage(node, start: start, limit: limit);
  }

  Future<PagedResult<NodeLogEntry>> _getNodeSyslogPage(
    String node, {
    required int start,
    required int limit,
  }) async {
    final response = await _getWithParameterFallback(
      '/nodes/$node/syslog',
      queryParameters: {'start': '$start', 'limit': '$limit'},
    );
    final data = response.body['data'];

    if (data is! List) {
      return const PagedResult<NodeLogEntry>(
        items: <NodeLogEntry>[],
        hasMore: false,
      );
    }

    final items =
        data
            .whereType<Map<String, dynamic>>()
            .map(NodeLogEntry.fromJson)
            .toList()
          ..sort((a, b) => b.lineNumber.compareTo(a.lineNumber));
    final visibleItems = response.usedFallback
        ? items.take(limit).toList()
        : items;

    return PagedResult<NodeLogEntry>(
      items: visibleItems,
      hasMore: !response.usedFallback && start > 0,
      nextStart: !response.usedFallback && start > 0
          ? (start - limit).clamp(0, start)
          : null,
    );
  }

  Future<NodeTerminalSession> createNodeTerminalSession(String node) async {
    final response = await _request('POST', '/nodes/$node/termproxy');
    final data = response['data'];

    if (data is! Map<String, dynamic>) {
      throw const ProxmoxApiException(ProxmoxErrorCode.terminalSessionInvalid);
    }

    return NodeTerminalSession.fromJson(data);
  }

  Future<void> executeNodePowerAction(
    String node,
    NodePowerAction action,
  ) async {
    await _request(
      'POST',
      '/nodes/$node/status',
      body: {'command': action.command},
    );
  }

  Future<void> executeGuestAction(PveResource guest, GuestAction action) async {
    if (!guest.isGuest) {
      throw const ProxmoxApiException(ProxmoxErrorCode.guestActionOnly);
    }

    final path = switch (guest.type) {
      'qemu' => '/nodes/${guest.node}/qemu/${guest.vmid}/status/${action.api}',
      'lxc' => '/nodes/${guest.node}/lxc/${guest.vmid}/status/${action.api}',
      _ => throw const ProxmoxApiException(
        ProxmoxErrorCode.unsupportedResourceType,
      ),
    };

    await _request('POST', path);
  }

  String _guestApiPath(PveResource guest) {
    return switch (guest.type) {
      'qemu' => 'qemu',
      'lxc' => 'lxc',
      _ => throw const ProxmoxApiException(
        ProxmoxErrorCode.unsupportedResourceType,
      ),
    };
  }

  Future<_ApiResponse> _getWithParameterFallback(
    String path, {
    Map<String, String>? queryParameters,
  }) async {
    try {
      final body = await _request(
        'GET',
        path,
        queryParameters: queryParameters,
      );
      return _ApiResponse(body: body, usedFallback: false);
    } on ProxmoxApiException catch (error) {
      if (queryParameters == null || !_isParameterVerificationFailure(error)) {
        rethrow;
      }
      final body = await _request('GET', path);
      return _ApiResponse(body: body, usedFallback: true);
    }
  }

  void close() {
    _httpClient.close(force: true);
  }

  Future<Map<String, dynamic>> _request(
    String method,
    String path, {
    Map<String, String>? body,
    Map<String, String>? queryParameters,
    bool needsAuth = true,
    String? authTicket,
    String? csrfToken,
  }) async {
    final uri = _apiUri(path, queryParameters: queryParameters);
    final request = await _httpClient
        .openUrl(method, uri)
        .timeout(_requestTimeout);
    request.followRedirects = false;
    request.headers.set(HttpHeaders.acceptHeader, 'application/json');

    if (needsAuth) {
      final ticket = authTicket ?? _ticket;
      if (ticket == null) {
        throw const ProxmoxApiException(ProxmoxErrorCode.sessionExpired);
      }
      request.headers.set(HttpHeaders.cookieHeader, 'PVEAuthCookie=$ticket');
      final token = csrfToken ?? _csrfToken;
      if (method != 'GET' && token != null) {
        request.headers.set('CSRFPreventionToken', token);
      }
    }

    if (body != null) {
      final payload = Uri(queryParameters: body).query;
      final payloadBytes = utf8.encode(payload);
      request.headers.contentType = ContentType(
        'application',
        'x-www-form-urlencoded',
        charset: 'utf-8',
      );
      request.contentLength = payloadBytes.length;
      request.add(payloadBytes);
    } else if (method != 'GET') {
      request.contentLength = 0;
    }

    final response = await request.close().timeout(_requestTimeout);
    final content = await response
        .transform(utf8.decoder)
        .join()
        .timeout(_requestTimeout);

    if (response.isRedirect) {
      final location = response.headers.value(HttpHeaders.locationHeader);
      throw ProxmoxApiException(
        ProxmoxErrorCode.redirectResponse,
        values: {
          'statusCode': response.statusCode,
          'location': location == null ? '' : ' -> $location',
        },
      );
    }

    final Object decoded;
    try {
      decoded = content.isEmpty ? <String, dynamic>{} : jsonDecode(content);
    } on FormatException {
      throw nonJsonResponseException(uri, response, content);
    }

    if (decoded is! Map<String, dynamic>) {
      throw ProxmoxApiException(
        ProxmoxErrorCode.apiFormatInvalid,
        values: {'statusCode': response.statusCode},
      );
    }

    if (response.statusCode < 200 || response.statusCode >= 300) {
      final message = decoded['message']?.toString();
      throw ProxmoxApiException(
        ProxmoxErrorCode.requestFailed,
        message: message == null || message.isEmpty ? null : message,
        values: {'statusCode': response.statusCode},
      );
    }

    return decoded;
  }

  Map<String, dynamic> _loginData(Map<String, dynamic> response) {
    final data = response['data'];
    if (data is! Map<String, dynamic>) {
      throw const ProxmoxApiException(ProxmoxErrorCode.loginResponseInvalid);
    }
    return data;
  }

  void _storeLoginData(Map<String, dynamic> data) {
    _ticket = data['ticket']?.toString();
    _csrfToken = data['CSRFPreventionToken']?.toString();

    if (_ticket == null || _csrfToken == null) {
      throw const ProxmoxApiException(ProxmoxErrorCode.loginTicketMissing);
    }
  }

  Uri _apiUri(String path, {Map<String, String>? queryParameters}) {
    final base = Uri.parse(origin);
    final apiPath = path.startsWith('/') ? path.substring(1) : path;
    return Uri(
      scheme: base.scheme,
      host: base.host,
      port: base.hasPort ? base.port : null,
      pathSegments: [
        'api2',
        'json',
        ...apiPath.split('/').where((segment) => segment.isNotEmpty),
      ],
      queryParameters: queryParameters,
    );
  }

  Uri _consoleUri(String path, Map<String, String> queryParameters) {
    final base = Uri.parse(origin);
    return Uri(
      scheme: base.scheme,
      host: base.host,
      port: base.hasPort ? base.port : null,
      path: path,
      queryParameters: queryParameters,
    );
  }

  static int _typeRank(String type) {
    return switch (type) {
      'node' => 0,
      'qemu' => 1,
      'lxc' => 2,
      'storage' => 3,
      _ => 4,
    };
  }

  static bool _isParameterVerificationFailure(ProxmoxApiException error) {
    if (error.code != ProxmoxErrorCode.requestFailed) {
      return false;
    }
    return error.message?.toLowerCase().contains(
          'parameter verification failed',
        ) ??
        false;
  }

  static int _intValue(Object? value) {
    if (value is num) {
      return value.round();
    }
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }

  static bool _boolValue(Object? value) {
    if (value is bool) {
      return value;
    }
    if (value is num) {
      return value != 0;
    }
    final normalized = value?.toString().toLowerCase();
    return normalized == '1' || normalized == 'true' || normalized == 'yes';
  }

  static bool _isTicketChallenge(Object? value) {
    return value?.toString().contains(':!tfa!') ?? false;
  }
}

class _ApiResponse {
  const _ApiResponse({required this.body, required this.usedFallback});

  final Map<String, dynamic> body;
  final bool usedFallback;
}
