import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:clock_calendar_app/timing/stopwatch_controller.dart';
import 'package:clock_calendar_app/widgets/stopwatch_view.dart';

void main() {
  testWidgets('页面移除后计时继续，新实例从零开始', (tester) async {
    var now = 0;
    final controller = StopwatchController(now: () => now);
    addTearDown(controller.dispose);
    await tester
        .pumpWidget(MaterialApp(home: StopwatchView(controller: controller)));
    await tester.tap(find.text('开始'));
    await tester.pumpWidget(const MaterialApp(home: SizedBox()));
    now = 120000;
    await tester
        .pumpWidget(MaterialApp(home: StopwatchView(controller: controller)));
    expect(find.text('00:02:00.00'), findsOneWidget);
    final restarted = StopwatchController(now: () => now);
    addTearDown(restarted.dispose);
    expect(restarted.elapsedMs, 0);
  });
  testWidgets('开始、计圈、暂停和继续', (tester) async {
    var now = 0;
    final controller = StopwatchController(now: () => now);
    addTearDown(controller.dispose);
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(body: StopwatchView(controller: controller))));
    await tester.tap(find.text('开始'));
    await tester.pump();
    now = 1250;
    await tester.tap(find.text('计圈'));
    await tester.pump();
    expect(find.text('00:00:01.25'), findsWidgets);
    await tester.tap(find.text('暂停'));
    await tester.pump();
    now = 10000;
    expect(controller.elapsedMs, 1250);
    await tester.tap(find.text('继续'));
    await tester.pump();
    now = 11000;
    expect(controller.elapsedMs, 2250);
    await tester.tap(find.text('重置'));
    await tester.pump();
    expect(controller.elapsedMs, 0);
  });
}
