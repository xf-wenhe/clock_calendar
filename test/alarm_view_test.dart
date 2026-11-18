import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:clock_calendar_app/timing/alarm_core.dart';
import 'package:clock_calendar_app/timing/alarm_controller.dart';
import 'package:clock_calendar_app/widgets/alarm_view.dart';

void main() {
  testWidgets('新建闹钟并验证时间输入', (tester) async {
    final c =
        AlarmController(now: () => DateTime(2026, 1, 5, 6), autoTick: false);
    addTearDown(c.dispose);
    await tester.pumpWidget(
        MaterialApp(home: Scaffold(body: AlarmView(controller: c))));
    await tester.tap(find.text('新建闹钟'));
    await tester.pumpAndSettle();
    await tester.enterText(find.widgetWithText(TextField, '名称'), '提醒');
    await tester.enterText(find.widgetWithText(TextField, '时'), '7');
    await tester.enterText(find.widgetWithText(TextField, '分'), '30');
    await tester.tap(find.text('保存'));
    await tester.pumpAndSettle();
    expect(c.alarms.single.name, '提醒');
    expect(c.alarms.single.nextFireAt, DateTime(2026, 1, 5, 7, 30));
  });
  testWidgets('闹钟列表显示名称、重复规则并可停用', (tester) async {
    final c =
        AlarmController(now: () => DateTime(2026, 1, 5, 6), autoTick: false);
    addTearDown(c.dispose);
    c.add('起床', AlarmRule(hour: 7, minute: 30, repeat: AlarmRepeat.daily));
    await tester.pumpWidget(
        MaterialApp(home: Scaffold(body: AlarmView(controller: c))));
    expect(find.textContaining('起床'), findsOneWidget);
    expect(find.textContaining('每天'), findsOneWidget);
    await tester.tap(find.byType(Switch));
    await tester.pump();
    expect(c.alarms.single.enabled, false);
  });
}
