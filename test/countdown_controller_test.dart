import 'package:flutter_test/flutter_test.dart';
import 'package:clock_calendar_app/timing/countdown_controller.dart';
import 'package:clock_calendar_app/timing/countdown_core.dart';

void main() {
  test('自定义快捷预设保存恢复，损坏值不替换默认值', () {
    final c = CountdownController(autoTick: false);
    addTearDown(c.dispose);
    c.setPresets([3, 12, 45]);
    final saved = c.snapshot();
    final restored = CountdownController(autoTick: false);
    addTearDown(restored.dispose);
    restored.restore(saved);
    expect(restored.presets, [3, 12, 45]);
    restored.setPresets([0, 12, 45]);
    expect(restored.presets, [3, 12, 45]);
  });
  test('到期回调只触发一次，暂停时不触发', () {
    var now = 0;
    var completions = 0;
    final c = CountdownController(
        now: () => now, onComplete: () => completions++, autoTick: false);
    addTearDown(c.dispose);
    c.setDuration(1000);
    c.start();
    now = 500;
    c.pause();
    now = 5000;
    c.check();
    expect(completions, 0);
    c.resume();
    now = 5501;
    c.check();
    c.check();
    expect(c.state.status, CountdownStatus.completed);
    expect(completions, 1);
  });
  test('重启时恢复为暂停，且不重复提醒', () {
    var now = 0;
    var completions = 0;
    final c = CountdownController(now: () => now, autoTick: false);
    addTearDown(c.dispose);
    c.setDuration(10000);
    c.start();
    now = 3000;
    final saved = c.snapshot();
    final restored = CountdownController(
        now: () => 900000, onComplete: () => completions++, autoTick: false);
    addTearDown(restored.dispose);
    restored.restore(saved);
    expect(restored.state.status, CountdownStatus.paused);
    expect(restored.remainingMs, 7000);
    restored.check();
    expect(completions, 0);
  });
  test('损坏配置恢复默认时长', () {
    final c = CountdownController(autoTick: false);
    addTearDown(c.dispose);
    c.restore({'durationMs': -1, 'remainingMs': 'bad'});
    expect(c.state.status, CountdownStatus.idle);
    expect(c.remainingMs, 1500000);
  });
}
