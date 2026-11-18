import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:clock_calendar_app/timing/countdown_controller.dart';
import 'package:clock_calendar_app/widgets/countdown_view.dart';

void main() {
  testWidgets('可以编辑快捷预设', (tester) async {
    final c = CountdownController(autoTick: false);
    addTearDown(c.dispose);
    await tester.pumpWidget(
        MaterialApp(home: Scaffold(body: CountdownView(controller: c))));
    await tester.tap(find.byTooltip('编辑预设'));
    await tester.pumpAndSettle();
    await tester.enterText(find.widgetWithText(TextField, '预设 1（分钟）'), '8');
    await tester.tap(find.text('保存'));
    await tester.pumpAndSettle();
    expect(c.presets.first, 8);
    expect(find.text('8 分钟'), findsOneWidget);
  });
  testWidgets('选择预设并开始、暂停、继续、重置', (tester) async {
    var now = 0;
    final c = CountdownController(now: () => now, autoTick: false);
    addTearDown(c.dispose);
    await tester.pumpWidget(
        MaterialApp(home: Scaffold(body: CountdownView(controller: c))));
    await tester.tap(find.text('5 分钟'));
    await tester.pump();
    expect(c.remainingMs, 300000);
    await tester.tap(find.text('开始'));
    await tester.pump();
    now = 1000;
    await tester.tap(find.text('暂停'));
    await tester.pump();
    expect(c.remainingMs, 299000);
    await tester.tap(find.text('继续'));
    await tester.pump();
    now = 2000;
    expect(c.remainingMs, 298000);
    await tester.tap(find.text('重置'));
    await tester.pump();
    expect(c.remainingMs, 300000);
  });
}
