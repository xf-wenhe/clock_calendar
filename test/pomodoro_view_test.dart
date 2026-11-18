import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:clock_calendar_app/pomodoro/app_clock.dart';
import 'package:clock_calendar_app/pomodoro/pomodoro_controller.dart';
import 'package:clock_calendar_app/widgets/pomodoro_view.dart';

void main() {
  testWidgets('新增和选择任务并操作计时', (tester) async {
    final clock = TestClock(DateTime(2026, 1, 1));
    final c = PomodoroController(clock: clock, autoTick: false);
    addTearDown(c.dispose);
    await tester.pumpWidget(
        MaterialApp(home: Scaffold(body: PomodoroView(controller: c))));
    await tester.enterText(find.widgetWithText(TextField, '新任务'), '写作');
    await tester.tap(find.byTooltip('新增任务'));
    await tester.pump();
    expect(find.text('写作'), findsOneWidget);
    await tester.tap(find.text('写作'));
    await tester.pump();
    expect(c.selectedTaskId, c.tasks.single.id);
    await tester.tap(find.text('开始'));
    await tester.pump();
    clock.advance(const Duration(minutes: 2));
    c.tick();
    await tester.pump();
    expect(find.text('23:00'), findsOneWidget);
    await tester.tap(find.text('暂停'));
    await tester.pump();
    expect(c.state.isPaused, true);
  });
}
