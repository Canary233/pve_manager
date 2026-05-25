import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'package:pve_manager/core/l10n/l10n_extensions.dart';
import 'package:pve_manager/core/settings/auto_refresh_settings.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({
    super.key,
    required this.locale,
    required this.onLocaleChanged,
    required this.autoRefreshIntervalListenable,
    required this.onAutoRefreshIntervalChanged,
    this.embedded = false,
  });

  final Locale locale;
  final ValueChanged<Locale> onLocaleChanged;
  final ValueListenable<Duration> autoRefreshIntervalListenable;
  final ValueChanged<Duration> onAutoRefreshIntervalChanged;
  final bool embedded;

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  static const Locale _zhLocale = Locale('zh');
  static const Locale _enLocale = Locale('en');

  late Duration _autoRefreshInterval;

  @override
  void initState() {
    super.initState();
    _autoRefreshInterval = widget.autoRefreshIntervalListenable.value;
    widget.autoRefreshIntervalListenable.addListener(_syncAutoRefreshInterval);
  }

  @override
  void didUpdateWidget(SettingsScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.autoRefreshIntervalListenable !=
        widget.autoRefreshIntervalListenable) {
      oldWidget.autoRefreshIntervalListenable.removeListener(
        _syncAutoRefreshInterval,
      );
      _autoRefreshInterval = widget.autoRefreshIntervalListenable.value;
      widget.autoRefreshIntervalListenable.addListener(
        _syncAutoRefreshInterval,
      );
    }
  }

  @override
  void dispose() {
    widget.autoRefreshIntervalListenable.removeListener(
      _syncAutoRefreshInterval,
    );
    super.dispose();
  }

  void _syncAutoRefreshInterval() {
    if (_autoRefreshInterval == widget.autoRefreshIntervalListenable.value) {
      return;
    }
    setState(() {
      _autoRefreshInterval = widget.autoRefreshIntervalListenable.value;
    });
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final l10n = context.l10n;

    final body = SafeArea(
      child: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Card(
                color: colorScheme.surfaceContainer,
                child: ListTile(
                  leading: const Icon(Icons.language_rounded),
                  title: Text(l10n.language),
                  subtitle: Text(
                    _languageName(context, _currentLocale(context)),
                  ),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () => _showLanguagePicker(context),
                ),
              ),
              const SizedBox(height: 12),
              Card(
                color: colorScheme.surfaceContainer,
                child: ListTile(
                  leading: const Icon(Icons.sync_rounded),
                  title: Text(l10n.autoRefreshInterval),
                  subtitle: Text(
                    _refreshIntervalLabel(context, _autoRefreshInterval),
                  ),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () => _showRefreshIntervalPicker(context),
                ),
              ),
            ],
          ),
        ),
      ),
    );

    if (widget.embedded) {
      return Material(
        color: colorScheme.surfaceContainerLow,
        child: Column(
          children: [
            SafeArea(
              bottom: false,
              child: SizedBox(
                height: kToolbarHeight,
                child: Row(
                  children: [
                    const SizedBox(width: 16),
                    Expanded(
                      child: Text(
                        l10n.settings,
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                    ),
                    IconButton(
                      tooltip: l10n.close,
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.close_rounded),
                    ),
                    const SizedBox(width: 8),
                  ],
                ),
              ),
            ),
            Expanded(child: body),
          ],
        ),
      );
    }

    return Scaffold(
      backgroundColor: colorScheme.surfaceContainerLow,
      appBar: AppBar(
        title: Text(l10n.settings),
        backgroundColor: colorScheme.surfaceContainerLow,
        surfaceTintColor: Colors.transparent,
      ),
      body: body,
    );
  }

  Future<void> _showLanguagePicker(BuildContext context) async {
    final currentLocale = _currentLocale(context);
    final selectedLocale = await showModalBottomSheet<Locale>(
      context: context,
      showDragHandle: true,
      builder: (context) {
        final colorScheme = Theme.of(context).colorScheme;
        final l10n = context.l10n;
        final languages = <Locale>[_zhLocale, _enLocale];

        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(4, 0, 4, 10),
                  child: Text(
                    l10n.selectLanguage,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                ...languages.map((languageLocale) {
                  final isSelected = _sameLanguage(
                    languageLocale,
                    currentLocale,
                  );
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: ListTile(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                        side: BorderSide(
                          color: isSelected
                              ? colorScheme.primary
                              : colorScheme.outlineVariant,
                        ),
                      ),
                      tileColor: isSelected
                          ? colorScheme.primaryContainer.withValues(alpha: 0.45)
                          : colorScheme.surfaceContainerHighest.withValues(
                              alpha: 0.55,
                            ),
                      title: Text(_languageName(context, languageLocale)),
                      trailing: isSelected
                          ? Icon(
                              Icons.check_circle_rounded,
                              color: colorScheme.primary,
                            )
                          : null,
                      onTap: () => Navigator.of(context).pop(languageLocale),
                    ),
                  );
                }),
              ],
            ),
          ),
        );
      },
    );

    if (selectedLocale == null ||
        _sameLanguage(selectedLocale, currentLocale)) {
      return;
    }

    widget.onLocaleChanged(selectedLocale);
  }

  Future<void> _showRefreshIntervalPicker(BuildContext context) async {
    final selectedInterval = await showModalBottomSheet<Duration>(
      context: context,
      showDragHandle: true,
      builder: (context) {
        final colorScheme = Theme.of(context).colorScheme;
        final l10n = context.l10n;

        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(4, 0, 4, 10),
                  child: Text(
                    l10n.selectAutoRefreshInterval,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                ...autoRefreshIntervalOptions.map((interval) {
                  final isSelected = interval == _autoRefreshInterval;
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: ListTile(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                        side: BorderSide(
                          color: isSelected
                              ? colorScheme.primary
                              : colorScheme.outlineVariant,
                        ),
                      ),
                      tileColor: isSelected
                          ? colorScheme.primaryContainer.withValues(alpha: 0.45)
                          : colorScheme.surfaceContainerHighest.withValues(
                              alpha: 0.55,
                            ),
                      title: Text(_refreshIntervalLabel(context, interval)),
                      trailing: isSelected
                          ? Icon(
                              Icons.check_circle_rounded,
                              color: colorScheme.primary,
                            )
                          : null,
                      onTap: () => Navigator.of(context).pop(interval),
                    ),
                  );
                }),
              ],
            ),
          ),
        );
      },
    );

    if (selectedInterval == null || selectedInterval == _autoRefreshInterval) {
      return;
    }

    setState(() {
      _autoRefreshInterval = selectedInterval;
    });
    widget.onAutoRefreshIntervalChanged(selectedInterval);
  }

  String _languageName(BuildContext context, Locale languageLocale) {
    final l10n = context.l10n;
    return switch (languageLocale.languageCode) {
      'zh' => l10n.languageChineseSimplified,
      'en' => l10n.languageEnglish,
      _ => languageLocale.toLanguageTag(),
    };
  }

  Locale _currentLocale(BuildContext context) {
    final locale = Localizations.localeOf(context);
    return switch (locale.languageCode) {
      'zh' => _zhLocale,
      'en' => _enLocale,
      _ => widget.locale,
    };
  }

  bool _sameLanguage(Locale first, Locale second) {
    return first.languageCode == second.languageCode;
  }

  String _refreshIntervalLabel(BuildContext context, Duration interval) {
    return context.l10n.secondsInterval(interval.inSeconds);
  }
}
