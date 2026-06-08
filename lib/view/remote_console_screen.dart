import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:webview_windows/webview_windows.dart';

import 'package:pve_manager/core/l10n/l10n_extensions.dart';

class RemoteConsoleScreen extends StatefulWidget {
  const RemoteConsoleScreen({
    required this.title,
    required this.uri,
    required this.authCookie,
    required this.ignoreCertificateErrors,
    required this.loadFailedTemplate,
    required this.unknownErrorMessage,
    required this.certificateErrorMessage,
    required this.errorHint,
    super.key,
  });

  final String title;
  final Uri uri;
  final String authCookie;
  final bool ignoreCertificateErrors;
  final String loadFailedTemplate;
  final String unknownErrorMessage;
  final String certificateErrorMessage;
  final String errorHint;

  @override
  State<RemoteConsoleScreen> createState() => _RemoteConsoleScreenState();
}

class _RemoteConsoleScreenState extends State<RemoteConsoleScreen> {
  final WebviewController _controller = WebviewController();
  final List<StreamSubscription<Object?>> _subscriptions = [];

  bool _controllerInitializeStarted = false;
  bool _isInitialized = false;
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    unawaited(_initialize());
  }

  Future<void> _initialize() async {
    try {
      await _initializeCertificatePolicy();
      if (!mounted) {
        return;
      }

      _controllerInitializeStarted = true;
      await _controller.initialize();
      if (!mounted) {
        return;
      }

      _subscriptions.add(
        _controller.loadingState.listen((state) {
          if (!mounted) {
            return;
          }
          setState(() {
            _isLoading = state == LoadingState.loading;
            if (_isLoading) {
              _errorMessage = null;
            }
          });
        }),
      );
      _subscriptions.add(_controller.onLoadError.listen(_handleLoadError));

      await _controller.setBackgroundColor(Colors.black);
      await _controller.setPopupWindowPolicy(
        WebviewPopupWindowPolicy.sameWindow,
      );
      await _controller.addScriptToExecuteOnDocumentCreated(
        _buildAuthenticationBootstrapScript(),
      );

      if (!mounted) {
        return;
      }
      setState(() {
        _isInitialized = true;
      });
      await _loadConsole();
    } on PlatformException catch (error) {
      _showLoadFailure(error.message ?? error.code);
    } on Object catch (error) {
      _showLoadFailure(error.toString());
    }
  }

  Future<void> _initializeCertificatePolicy() async {
    if (!widget.ignoreCertificateErrors) {
      return;
    }

    try {
      await WebviewController.initializeEnvironment(
        additionalArguments: '--ignore-certificate-errors',
      );
    } on PlatformException catch (error) {
      if (error.code != 'environment_already_initialized') {
        rethrow;
      }
    }
  }

  Future<void> _loadConsole() async {
    if (!mounted) {
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      await _controller.loadUrl(widget.uri.toString());
    } on PlatformException catch (error) {
      _showLoadFailure(error.message ?? error.code);
    } on Object catch (error) {
      _showLoadFailure(error.toString());
    }
  }

  String _buildAuthenticationBootstrapScript() {
    final cookie = [
      'PVEAuthCookie=${widget.authCookie}',
      'Path=/',
      if (widget.uri.scheme == 'https') 'Secure',
    ].join('; ');
    final host = _hostWithPort(widget.uri).toLowerCase();
    final marker =
        '${widget.uri.toString().hashCode}:${widget.authCookie.hashCode}';

    return '''
(() => {
  if (window.top !== window.self) {
    return;
  }
  if (location.host.toLowerCase() !== ${jsonEncode(host)}) {
    return;
  }

  document.cookie = ${jsonEncode(cookie)};

  const key = '__pve_manager_console_cookie_loaded';
  const marker = ${jsonEncode(marker)};
  if (sessionStorage.getItem(key) !== marker) {
    sessionStorage.setItem(key, marker);
    location.replace(${jsonEncode(widget.uri.toString())});
  }
})();
''';
  }

  void _handleLoadError(WebErrorStatus status) {
    if (status == WebErrorStatus.WebErrorStatusOperationCanceled) {
      return;
    }

    if (_isCertificateError(status)) {
      _setError(widget.certificateErrorMessage);
      return;
    }

    _showLoadFailure(_describeWebError(status));
  }

  bool _isCertificateError(WebErrorStatus status) {
    return switch (status) {
      WebErrorStatus.WebErrorStatusCertificateCommonNameIsIncorrect ||
      WebErrorStatus.WebErrorStatusCertificateExpired ||
      WebErrorStatus.WebErrorStatusClientCertificateContainsErrors ||
      WebErrorStatus.WebErrorStatusCertificateRevoked ||
      WebErrorStatus.WebErrorStatusCertificateIsInvalid => true,
      _ => false,
    };
  }

  String _describeWebError(WebErrorStatus status) {
    if (status == WebErrorStatus.WebErrorStatusUnknown ||
        status == WebErrorStatus.WebErrorStatusUnexpectedError) {
      return widget.unknownErrorMessage;
    }

    final raw = status.name.replaceFirst('WebErrorStatus', '');
    return raw
        .replaceAllMapped(
          RegExp(r'([a-z0-9])([A-Z])'),
          (match) => '${match[1]} ${match[2]}',
        )
        .replaceAll('HTTP', 'HTTP ');
  }

  void _showLoadFailure(String description) {
    _setError(
      widget.loadFailedTemplate.replaceAll('{description}', description),
    );
  }

  void _setError(String message) {
    if (!mounted) {
      return;
    }
    setState(() {
      _errorMessage = message;
      _isLoading = false;
    });
  }

  Future<WebviewPermissionDecision> _handlePermissionRequest(
    String url,
    WebviewPermissionKind kind,
    bool isUserInitiated,
  ) async {
    if (kind == WebviewPermissionKind.clipboardRead && isUserInitiated) {
      return WebviewPermissionDecision.allow;
    }
    return WebviewPermissionDecision.deny;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: Text(widget.title),
        actions: [
          IconButton(
            tooltip: l10n.refresh,
            onPressed: _isInitialized ? _loadConsole : null,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: ColoredBox(
        color: Colors.black,
        child: Column(
          children: [
            SizedBox(
              height: 3,
              child: _isLoading ? const LinearProgressIndicator() : null,
            ),
            Expanded(
              child: Stack(
                children: [
                  if (_isInitialized)
                    Positioned.fill(
                      child: Webview(
                        _controller,
                        permissionRequested: _handlePermissionRequest,
                      ),
                    )
                  else if (_errorMessage == null)
                    const Center(child: CircularProgressIndicator()),
                  if (_errorMessage != null)
                    Positioned.fill(
                      child: _ConsoleErrorOverlay(
                        message: _errorMessage!,
                        hint: widget.errorHint,
                        onRetry: _isInitialized ? _loadConsole : _initialize,
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    for (final subscription in _subscriptions) {
      unawaited(subscription.cancel());
    }
    if (_controllerInitializeStarted) {
      unawaited(_disposeController());
    }
    super.dispose();
  }

  Future<void> _disposeController() async {
    try {
      await _controller.dispose();
    } on Object {
      // The controller may be mid-initialization when the route is closed.
    }
  }
}

class _ConsoleErrorOverlay extends StatelessWidget {
  const _ConsoleErrorOverlay({
    required this.message,
    required this.hint,
    required this.onRetry,
  });

  final String message;
  final String hint;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return ColoredBox(
      color: Colors.black,
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.desktop_access_disabled_rounded,
                  color: colorScheme.error,
                  size: 48,
                ),
                const SizedBox(height: 14),
                Text(
                  message,
                  textAlign: TextAlign.center,
                  style: TextStyle(color: colorScheme.onInverseSurface),
                ),
                const SizedBox(height: 8),
                Text(
                  hint,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: colorScheme.onInverseSurface.withValues(alpha: 0.7),
                  ),
                ),
                const SizedBox(height: 18),
                FilledButton.icon(
                  onPressed: onRetry,
                  icon: const Icon(Icons.refresh_rounded),
                  label: Text(context.l10n.retry),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

String _hostWithPort(Uri uri) {
  if (!uri.hasPort) {
    return uri.host;
  }
  return '${uri.host}:${uri.port}';
}
