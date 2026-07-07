import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:pve_manager/app/pve_manager_app.dart';
import 'package:pve_manager/data/models/pve_server_config.dart';
import 'package:pve_manager/l10n/generated/app_localizations.dart';
import 'package:pve_manager/view/home/widgets/server_card.dart';

void main() {
  testWidgets('shows the server list home screen', (WidgetTester tester) async {
    await tester.pumpWidget(const PveManagerApp());
    await tester.pump();

    expect(find.text('PVE Manager'), findsOneWidget);
    expect(find.byIcon(Icons.add_rounded), findsWidgets);
  });

  testWidgets('server card shows last login below username while connecting', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(720, 1280);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: const Locale('zh'),
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 360,
              child: ServerCard(
                server: const PveServerConfig(
                  name: '公网',
                  origin: 'https://canary233.eu.org:442',
                  username: 'root',
                  password: 'secret',
                  realm: 'pam',
                  ignoreCertificateErrors: true,
                  lastConnectedAt: 1783350000000,
                ),
                isConnecting: true,
                onTap: () {},
                onLongPress: () {},
              ),
            ),
          ),
        ),
      ),
    );

    await tester.pump();

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.text('root@pam'), findsOneWidget);
    expect(find.textContaining('上次登录：'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
