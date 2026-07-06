import 'dart:async';
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
  final Map<String, NodeThermalState> _nodeThermalStateCache =
      <String, NodeThermalState>{};
  final Map<String, Future<NodeThermalState>> _nodeThermalStateRequests =
      <String, Future<NodeThermalState>>{};

  static const Duration _requestTimeout = Duration(seconds: 12);
  static const Duration _terminalCommandTimeout = Duration(seconds: 20);
  static const String _temperatureStartMarker = '__PVE_MANAGER_TEMP_START__';
  static const String _temperatureEndMarker = '__PVE_MANAGER_TEMP_END__';

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

  Future<NodeThermalState> getNodeThermalState(String node) async {
    final cached = _nodeThermalStateCache[node];
    if (cached != null && !cached.isEmpty) {
      return cached;
    }

    final pending = _nodeThermalStateRequests[node];
    if (pending != null) {
      return pending;
    }

    final request = _fetchNodeThermalState(node);
    _nodeThermalStateRequests[node] = request;
    return request;
  }

  NodeThermalState? cachedNodeThermalState(String node) {
    final cached = _nodeThermalStateCache[node];
    if (cached == null || cached.isEmpty) {
      return null;
    }
    return cached;
  }

  void preloadNodeThermalStates(Iterable<String> nodes) {
    final uniqueNodes = nodes
        .map((node) => node.trim())
        .where((node) => node.isNotEmpty)
        .toSet();

    for (final node in uniqueNodes) {
      if (_nodeThermalStateCache.containsKey(node) ||
          _nodeThermalStateRequests.containsKey(node)) {
        continue;
      }
      unawaited(
        getNodeThermalState(node).catchError((Object _) {
          return const NodeThermalState.empty();
        }),
      );
    }
  }

  Future<void> preloadClusterNodeThermalStates() async {
    try {
      final nodes = await getNodes();
      preloadNodeThermalStates(nodes.map((node) => node.name));
    } on Object {
      // SMART details are optional; connection should not wait on preloading.
    }
  }

  Future<NodeThermalState> _fetchNodeThermalState(String node) async {
    try {
      final output = await _runNodeShellCommand(
        node,
        _nodeTemperatureCommand(),
      );
      final thermalState = NodeThermalState.fromJson(output);
      if (!thermalState.isEmpty) {
        _nodeThermalStateCache[node] = thermalState;
      }
      return thermalState;
    } finally {
      _nodeThermalStateRequests.remove(node);
    }
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
    return _createTerminalSession(nodeTerminalApiPath(node));
  }

  Future<NodeTerminalSession> createGuestTerminalSession(
    PveResource guest,
  ) async {
    return _createTerminalSession(guestTerminalApiPath(guest));
  }

  String nodeTerminalApiPath(String node) {
    return '/nodes/$node';
  }

  String guestTerminalApiPath(PveResource guest) {
    if (!guest.isGuest || guest.type != 'lxc') {
      throw const ProxmoxApiException(ProxmoxErrorCode.guestActionOnly);
    }

    return '/nodes/${guest.node}/lxc/${guest.vmid}';
  }

  Future<ProxmoxTerminalConnection> connectTerminalWebSocket({
    required String apiPath,
    required NodeTerminalSession session,
  }) async {
    final client = _createHttpClient();
    try {
      final socket = await WebSocket.connect(
        _terminalWebSocketUri(apiPath, session).toString(),
        protocols: const <String>['binary'],
        headers: <String, dynamic>{
          HttpHeaders.cookieHeader: 'PVEAuthCookie=$authCookieValue',
        },
        customClient: client,
      ).timeout(_requestTimeout);

      return ProxmoxTerminalConnection(socket, client);
    } on Object {
      client.close(force: true);
      rethrow;
    }
  }

  Future<String> _runNodeShellCommand(String node, String command) async {
    final session = await createNodeTerminalSession(node);
    final connection = await connectTerminalWebSocket(
      apiPath: nodeTerminalApiPath(node),
      session: session,
    );
    StreamSubscription<dynamic>? subscription;

    try {
      final completer = Completer<String>();
      final output = StringBuffer();
      var authenticated = false;

      subscription = connection.socket.listen(
        (message) {
          final text = _decodeTerminalMessage(message);
          if (text.isEmpty || completer.isCompleted) {
            return;
          }

          if (!authenticated) {
            final okIndex = text.indexOf('OK');
            if (okIndex == -1) {
              return;
            }

            authenticated = true;
            final remaining = text.substring(okIndex + 2);
            if (remaining.isNotEmpty) {
              output.write(remaining);
            }
            connection.socket.add('1:160:40:');
            final input = '$command\r';
            connection.socket.add('0:${utf8.encode(input).length}:$input');
            return;
          }

          output.write(text);
          if (_hasTerminalMarkerLine(
            output.toString(),
            _temperatureEndMarker,
          )) {
            completer.complete(output.toString());
          }
        },
        onDone: () {
          if (!completer.isCompleted) {
            completer.complete(output.toString());
          }
        },
        onError: (Object error, StackTrace stackTrace) {
          if (!completer.isCompleted) {
            completer.completeError(error, stackTrace);
          }
        },
      );

      connection.socket.add('${session.user}:${session.ticket}\n');
      final rawOutput = await completer.future.timeout(_terminalCommandTimeout);
      return _extractMarkedTerminalOutput(rawOutput);
    } finally {
      await subscription?.cancel();
      await connection.close();
    }
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

  String _nodeTemperatureCommand() {
    return "LC_ALL=C; "
        "setopt nonomatch 2>/dev/null || true; "
        "printf '\\n%s\\n' '__PVE''_MANAGER''_TEMP''_START__'; "
        "if command -v sensors >/dev/null 2>&1; then "
        "sensors 2>/dev/null || true; "
        "else "
        "for h in /sys/class/hwmon/hwmon*; do "
        "[ -d \"\$h\" ] || continue; "
        "chip=\$(cat \"\$h/name\" 2>/dev/null || basename \"\$h\"); "
        "for f in \"\$h\"/temp*_input; do "
        "[ -r \"\$f\" ] || continue; "
        "base=\${f%_input}; "
        "label=\$(cat \"\${base}_label\" 2>/dev/null || basename \"\$base\"); "
        "value=\$(cat \"\$f\" 2>/dev/null); "
        "printf 'hwmon %s %s: %s\\n' \"\$chip\" \"\$label\" \"\$value\"; "
        "done; "
        "done; "
        "for z in /sys/class/thermal/thermal_zone*; do "
        "[ -r \"\$z/temp\" ] || continue; "
        "t=\$(cat \"\$z/type\" 2>/dev/null || basename \"\$z\"); "
        "v=\$(cat \"\$z/temp\" 2>/dev/null); "
        "printf 'sysfs %s: %s\\n' \"\$t\" \"\$v\"; "
        "done; "
        "fi; "
        "if command -v smartctl >/dev/null 2>&1; then "
        "scan=\$(smartctl --scan-open 2>/dev/null || smartctl --scan 2>/dev/null || true); "
        "if [ -n \"\$scan\" ]; then "
        "printf '%s\\n' \"\$scan\" | while read -r d opt dtype rest; do "
        "[ -n \"\$d\" ] || continue; "
        "case \"\$d\" in \\#*) continue;; esac; "
        "if [ \"\$opt\" = \"-d\" ] && [ -n \"\$dtype\" ] && [ \"\$dtype\" != \"#\" ]; then "
        "printf 'smartctl %s -d %s\\n' \"\$d\" \"\$dtype\"; "
        "{ smartctl -i -d \"\$dtype\" \"\$d\" 2>/dev/null; "
        "smartctl -A -d \"\$dtype\" \"\$d\" 2>/dev/null; "
        "smartctl -l scttempsts -d \"\$dtype\" \"\$d\" 2>/dev/null; } | "
        "sed -n '/^Device Model:/p;/^Model Number:/p;/^Product:/p;/^Model:/p;/[Tt]emp/p;/194 /p;/190 /p'; "
        "else "
        "printf 'smartctl %s\\n' \"\$d\"; "
        "{ smartctl -i \"\$d\" 2>/dev/null; "
        "smartctl -A \"\$d\" 2>/dev/null; "
        "smartctl -l scttempsts \"\$d\" 2>/dev/null; } | "
        "sed -n '/^Device Model:/p;/^Model Number:/p;/^Product:/p;/^Model:/p;/[Tt]emp/p;/194 /p;/190 /p'; "
        "fi; "
        "done; "
        "else "
        "for d in /dev/nvme[0-9] /dev/nvme*n1 /dev/sd? /dev/hd? /dev/disk/by-id/ata-*; do "
        "[ -e \"\$d\" ] || continue; "
        "case \"\$d\" in *-part*) continue;; esac; "
        "printf 'smartctl %s\\n' \"\$d\"; "
        "{ smartctl -i \"\$d\" 2>/dev/null || smartctl -i -d sat \"\$d\" 2>/dev/null; "
        "smartctl -A \"\$d\" 2>/dev/null || smartctl -A -d sat \"\$d\" 2>/dev/null; "
        "smartctl -l scttempsts \"\$d\" 2>/dev/null || smartctl -l scttempsts -d sat \"\$d\" 2>/dev/null; } | "
        "sed -n '/^Device Model:/p;/^Model Number:/p;/^Product:/p;/^Model:/p;/[Tt]emp/p;/194 /p;/190 /p'; "
        "done; "
        "fi; "
        "fi; "
        "printf '%s\\n' '__PVE''_MANAGER''_TEMP''_END__'; "
        "exit";
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

  Future<NodeTerminalSession> _createTerminalSession(String apiPath) async {
    final response = await _request('POST', '$apiPath/termproxy');
    final data = response['data'];

    if (data is! Map<String, dynamic>) {
      throw const ProxmoxApiException(ProxmoxErrorCode.terminalSessionInvalid);
    }

    return NodeTerminalSession.fromJson(data);
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

  Uri _terminalWebSocketUri(String apiPath, NodeTerminalSession session) {
    final base = Uri.parse(origin);
    final normalizedPath = apiPath.startsWith('/')
        ? apiPath.substring(1)
        : apiPath;
    return Uri(
      scheme: base.scheme == 'https' ? 'wss' : 'ws',
      host: base.host,
      port: base.hasPort ? base.port : null,
      pathSegments: [
        'api2',
        'json',
        ...normalizedPath.split('/').where((segment) => segment.isNotEmpty),
        'vncwebsocket',
      ],
      queryParameters: {'port': '${session.port}', 'vncticket': session.ticket},
    );
  }

  HttpClient _createHttpClient() {
    return HttpClient()
      ..connectionTimeout = const Duration(seconds: 15)
      ..badCertificateCallback =
          (X509Certificate cert, String host, int port) =>
              ignoreCertificateErrors;
  }

  static String _decodeTerminalMessage(dynamic message) {
    if (message is String) {
      return message;
    }
    if (message is List<int>) {
      return utf8.decode(message, allowMalformed: true);
    }
    return '';
  }

  static bool _hasTerminalMarkerLine(String output, String marker) {
    return output.contains(marker);
  }

  static String _extractMarkedTerminalOutput(String output) {
    final start = output.indexOf(_temperatureStartMarker);
    if (start == -1) {
      return '';
    }

    final contentStart = start + _temperatureStartMarker.length;
    final end = output.indexOf(_temperatureEndMarker, contentStart);
    if (end == -1) {
      return output.substring(contentStart);
    }
    return output.substring(contentStart, end);
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

class ProxmoxTerminalConnection {
  ProxmoxTerminalConnection(this.socket, this._httpClient);

  final WebSocket socket;
  final HttpClient _httpClient;

  Future<void> close([int? code, String? reason]) async {
    try {
      await socket.close(code, reason);
    } finally {
      _httpClient.close(force: true);
    }
  }

  void dispose() {
    _httpClient.close(force: true);
  }
}
