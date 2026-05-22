import 'package:flutter/material.dart';
import 'package:dynamic_color/dynamic_color.dart';

import 'package:pve_manager/l10n/generated/app_localizations.dart';
import 'package:pve_manager/view/home/home_screen.dart';

class PveManagerApp extends StatefulWidget {
  const PveManagerApp({super.key});

  @override
  State<PveManagerApp> createState() => _PveManagerAppState();
}

class _PveManagerAppState extends State<PveManagerApp> {
  static const Locale _chineseLocale = Locale('zh');

  Locale _locale = _chineseLocale;

  void _setLocale(Locale locale) {
    if (_locale == locale) {
      return;
    }
    setState(() {
      _locale = locale;
    });
  }

  @override
  Widget build(BuildContext context) {
    return DynamicColorBuilder(
      builder: (lightDynamic, darkDynamic) {
        final lightScheme =
            lightDynamic ??
            ColorScheme.fromSeed(
              seedColor: const Color(0xff256f78),
              brightness: Brightness.light,
            );
        final darkScheme =
            darkDynamic ??
            ColorScheme.fromSeed(
              seedColor: const Color(0xff256f78),
              brightness: Brightness.dark,
            );

        return MaterialApp(
          onGenerateTitle: (context) => AppLocalizations.of(context).appTitle,
          debugShowCheckedModeBanner: false,
          locale: _locale,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          theme: _buildTheme(lightScheme),
          darkTheme: _buildTheme(darkScheme),
          home: HomeScreen(locale: _locale, onLocaleChanged: _setLocale),
        );
      },
    );
  }

  ThemeData _buildTheme(ColorScheme colorScheme) {
    return ThemeData(
      colorScheme: colorScheme,
      useMaterial3: true,
      scaffoldBackgroundColor: colorScheme.surface,
      cardTheme: const CardThemeData(
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(8)),
        ),
      ),
      inputDecorationTheme: const InputDecorationTheme(
        border: OutlineInputBorder(
          borderRadius: BorderRadius.all(Radius.circular(8)),
        ),
      ),
    );
  }
}
