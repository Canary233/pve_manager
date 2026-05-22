import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:pve_manager/app/pve_manager_app.dart';

void main() {
  testWidgets('shows the server list home screen', (WidgetTester tester) async {
    await tester.pumpWidget(const PveManagerApp());
    await tester.pump();

    expect(find.text('PVE Manager'), findsOneWidget);
    expect(find.byIcon(Icons.add_rounded), findsWidgets);
  });
}
