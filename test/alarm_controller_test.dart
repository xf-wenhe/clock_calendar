import 'package:flutter_test/flutter_test.dart';
import 'package:clock_calendar_app/timing/alarm_core.dart';
import 'package:clock_calendar_app/timing/alarm_controller.dart';

void main() {
  test('同时触发的闹钟排队，贪睡不会覆盖另一个提醒', () {
    var now = DateTime(2026, 1, 5, 7, 0);
    var signals = 0;
    final c = AlarmController(
        now: () => now, onRing: () => signals++, autoTick: false);
    addTearDown(c.dispose);
    c.add('一', AlarmRule(hour: 7, minute: 30, repeat: AlarmRepeat.once));
    c.add('二', AlarmRule(hour: 7, minute: 30, repeat: AlarmRepeat.once));
    now = DateTime(2026, 1, 5, 7, 30);
    c.check();
    expect(c.queue.map((a) => a.name), ['一', '二']);
    expect(signals, 1);
    c.snooze();
    expect(c.queue.single.name, '二');
    c.stop();
    expect(c.queue, isEmpty);
    now = now.add(const Duration(minutes: 9));
    c.check();
    expect(c.queue.single.name, '一');
    expect(signals, 2);
  });
  test('保存恢复一次闹钟及贪睡计划', () {
    var now = DateTime(2026, 1, 5, 7, 0);
    final c = AlarmController(now: () => now, autoTick: false);
    addTearDown(c.dispose);
    c.add('起床', AlarmRule(hour: 7, minute: 30, repeat: AlarmRepeat.once));
    now = DateTime(2026, 1, 5, 7, 30);
    c.check();
    c.snooze();
    final saved = c.snapshot();
    final restored = AlarmController(now: () => now, autoTick: false);
    addTearDown(restored.dispose);
    restored.restore(saved);
    now = now.add(const Duration(minutes: 9));
    restored.check();
    expect(restored.queue.single.name, '起床');
  });
  test('恢复超时贪睡不会响铃', () {
    var now = DateTime(2026, 1, 5, 7, 0);
    final c = AlarmController(now: () => now, autoTick: false);
    addTearDown(c.dispose);
    c.add('起床', AlarmRule(hour: 7, minute: 30, repeat: AlarmRepeat.once));
    now = DateTime(2026, 1, 5, 7, 30);
    c.check();
    c.snooze();
    now = now.add(const Duration(hours: 2));
    c.check();
    expect(c.queue, isEmpty);
  });
}
