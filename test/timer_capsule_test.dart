import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:clock_calendar_app/timing/countdown_controller.dart';
import 'package:clock_calendar_app/widgets/timer_capsule.dart';

void main() {
  testWidgets('胶囊显示倒计时并支持暂停和展开', (tester) async {
    var now = 0;
    var expanded = false;
    final c = CountdownController(now: () => now, autoTick: false);
    addTearDown(c.dispose);
    c.setDuration(60000);
    c.start();
    now = 10000;
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: SizedBox(
                width: 360,
                height: 100,
                child: TimerCapsule(
                    countdown: c, onExpand: () => expanded = true)))));
    expect(find.text('00:50'), findsOneWidget);
    await tester.tap(find.byTooltip('暂停'));
    await tester.pump();
    expect(c.state.status.name, 'paused');
    await tester.tap(find.byTooltip('展开'));
    await tester.pump();
    expect(expanded, true);
  });
}
