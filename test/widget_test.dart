import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:supreme_trade_checker/main.dart';

void main() {
  testWidgets('Supreme Trade Checker starts and shows its app header',
      (WidgetTester tester) async {
    await tester.pumpWidget(const SupremeTradeCheckerApp());

    expect(find.byType(MaterialApp), findsOneWidget);
    expect(find.text('SUPREME TRADE CHECKER'), findsOneWidget);
  });
}
