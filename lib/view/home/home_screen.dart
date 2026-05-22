import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'package:pve_manager/core/l10n/l10n_extensions.dart';
import 'package:pve_manager/data/models/pve_server_config.dart';
import 'package:pve_manager/view/dashboard/dashboard_screen.dart';
import 'package:pve_manager/data/repositories/server_repository.dart';
import 'package:pve_manager/core/widgets/inline_message.dart';
import 'package:pve_manager/view/home/widgets/empty_servers.dart';
import 'package:pve_manager/view/home/widgets/server_card.dart';
import 'package:pve_manager/view/home/widgets/server_form_dialog.dart';

enum _ServerAction { edit, delete }

class _LanguageOption {
  const _LanguageOption({
    required this.locale,
    required this.label,
    required this.iconText,
  });

  final Locale locale;
  final String label;
  final String iconText;
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({
    super.key,
    required this.locale,
    required this.onLocaleChanged,
  });

  final Locale locale;
  final ValueChanged<Locale> onLocaleChanged;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final List<PveServerConfig> _servers = <PveServerConfig>[];
  final ServerRepository _repository = ServerRepository.instance;
  bool _isInitializing = true;
  bool _isLoading = false;
  String? _connectingOrigin;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadServers();
  }

  Future<void> _loadServers() async {
    try {
      final servers = await _repository.getServers();
      if (!mounted) {
        return;
      }
      setState(() {
        _servers
          ..clear()
          ..addAll(servers);
        _isInitializing = false;
      });
    } on Object catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _error = localizedError(context.l10n, error);
        _isInitializing = false;
      });
    }
  }

  Future<void> _openServerForm({PveServerConfig? server, int? index}) async {
    final result = await showDialog<PveServerConfig>(
      context: context,
      builder: (context) => ServerFormDialog(server: server),
    );

    if (result == null) {
      return;
    }

    try {
      final serverToSave = index == null
          ? result
          : result.copyWith(
              id: server?.id,
              lastConnectedAt: server?.lastConnectedAt,
            );
      final saved = await _repository.saveServer(serverToSave);
      if (!mounted) {
        return;
      }
      setState(() {
        _error = null;
        if (index == null) {
          _servers.insert(0, saved);
        } else {
          _servers[index] = saved;
        }
      });
    } on Object catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _error = localizedError(context.l10n, error);
      });
    }
  }

  Future<void> _showServerActions(int index) async {
    final server = _servers[index];
    final action = await showModalBottomSheet<_ServerAction>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.edit_rounded),
              title: Text(context.l10n.edit),
              subtitle: Text(server.name),
              onTap: () => Navigator.of(context).pop(_ServerAction.edit),
            ),
            ListTile(
              leading: Icon(
                Icons.delete_outline_rounded,
                color: Theme.of(context).colorScheme.error,
              ),
              title: Text(
                context.l10n.delete,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
              onTap: () => Navigator.of(context).pop(_ServerAction.delete),
            ),
          ],
        ),
      ),
    );

    if (!mounted || action == null) {
      return;
    }

    switch (action) {
      case _ServerAction.edit:
        await _openServerForm(server: server, index: index);
      case _ServerAction.delete:
        try {
          final id = server.id;
          if (id != null) {
            await _repository.deleteServer(id);
          }
          if (!mounted) {
            return;
          }
          setState(() {
            _servers.removeAt(index);
            _error = null;
          });
        } on Object catch (error) {
          if (!mounted) {
            return;
          }
          setState(() {
            _error = localizedError(context.l10n, error);
          });
        }
    }
  }

  Future<void> _showLanguagePicker() async {
    final l10n = context.l10n;
    final selected = await showModalBottomSheet<Locale>(
      context: context,
      showDragHandle: true,
      builder: (context) {
        final options = [
          _LanguageOption(
            locale: const Locale('zh'),
            label: l10n.languageChineseSimplified,
            iconText: '中',
          ),
          _LanguageOption(
            locale: const Locale('en'),
            label: l10n.languageEnglish,
            iconText: 'EN',
          ),
        ];
        return _LanguagePickerSheet(
          options: options,
          selectedLocale: widget.locale,
        );
      },
    );

    if (selected != null && mounted) {
      widget.onLocaleChanged(selected);
    }
  }

  Future<void> _connect(PveServerConfig server) async {
    if (_isLoading) {
      return;
    }

    if (kIsWeb) {
      setState(() {
        _error = context.l10n.webConsoleUnsupported;
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _connectingOrigin = server.origin;
      _error = null;
    });

    final client = server.createClient();

    try {
      await client.login();
      if (!mounted) {
        client.close();
        return;
      }
      final connectedServer = await _repository.markConnected(server);
      setState(() {
        final index = _servers.indexWhere((item) => item.id == server.id);
        if (index != -1) {
          _servers[index] = connectedServer;
        }
        _isLoading = false;
        _connectingOrigin = null;
      });
      if (!mounted) {
        client.close();
        return;
      }
      await Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) =>
              DashboardScreen(client: client, serverName: server.name),
        ),
      );
    } on Object catch (error) {
      client.close();
      if (!mounted) {
        return;
      }
      setState(() {
        _error = localizedError(context.l10n, error);
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _connectingOrigin = null;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final l10n = context.l10n;

    return Scaffold(
      backgroundColor: colorScheme.surfaceContainerLow,
      appBar: AppBar(
        backgroundColor: colorScheme.surfaceContainerLow,
        surfaceTintColor: Colors.transparent,
        title: Text(l10n.appTitle),
        centerTitle: false,
        actions: [
          IconButton(
            tooltip: l10n.switchLanguage,
            onPressed: _showLanguagePicker,
            icon: const Icon(Icons.language_rounded),
          ),
        ],
      ),
      body: SafeArea(
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                mainAxisAlignment: _isInitializing || _servers.isEmpty
                    ? MainAxisAlignment.center
                    : MainAxisAlignment.start,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (_isInitializing)
                    const Center(child: CircularProgressIndicator())
                  else if (_servers.isEmpty)
                    EmptyServers(onAdd: () => _openServerForm())
                  else
                    Flexible(
                      child: ListView.separated(
                        padding: const EdgeInsets.only(top: 8),
                        shrinkWrap: true,
                        itemCount: _servers.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 12),
                        itemBuilder: (context, index) {
                          final server = _servers[index];
                          return ServerCard(
                            server: server,
                            isConnecting:
                                _isLoading &&
                                _connectingOrigin == server.origin,
                            onTap: () => _connect(server),
                            onLongPress: () => _showServerActions(index),
                          );
                        },
                      ),
                    ),
                  if (_error != null) ...[
                    const SizedBox(height: 16),
                    InlineMessage(
                      icon: Icons.error_outline_rounded,
                      text: _error!,
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        tooltip: l10n.addServer,
        onPressed: () => _openServerForm(),
        child: const Icon(Icons.add_rounded),
      ),
    );
  }
}

class _LanguagePickerSheet extends StatelessWidget {
  const _LanguagePickerSheet({
    required this.options,
    required this.selectedLocale,
  });

  final List<_LanguageOption> options;
  final Locale selectedLocale;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              context.l10n.switchLanguage,
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 14),
            ...options.map((option) {
              final selected =
                  option.locale.languageCode == selectedLocale.languageCode;
              return Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Material(
                  color: selected
                      ? colorScheme.primaryContainer.withValues(alpha: 0.72)
                      : colorScheme.surfaceContainerHighest.withValues(
                          alpha: 0.62,
                        ),
                  borderRadius: BorderRadius.circular(14),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(14),
                    onTap: () => Navigator.of(context).pop(option.locale),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 12,
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 40,
                            height: 40,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: selected
                                  ? colorScheme.primary
                                  : colorScheme.surface,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              option.iconText,
                              style: Theme.of(context).textTheme.labelLarge
                                  ?.copyWith(
                                    color: selected
                                        ? colorScheme.onPrimary
                                        : colorScheme.onSurfaceVariant,
                                    fontWeight: FontWeight.w800,
                                  ),
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Text(
                              option.label,
                              style: Theme.of(context).textTheme.titleMedium
                                  ?.copyWith(fontWeight: FontWeight.w700),
                            ),
                          ),
                          AnimatedSwitcher(
                            duration: const Duration(milliseconds: 160),
                            child: selected
                                ? Icon(
                                    Icons.check_circle_rounded,
                                    key: const ValueKey('selected'),
                                    color: colorScheme.primary,
                                  )
                                : Icon(
                                    Icons.circle_outlined,
                                    key: const ValueKey('unselected'),
                                    color: colorScheme.outline,
                                  ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            }),
          ],
        ),
      ),
    );
  }
}
