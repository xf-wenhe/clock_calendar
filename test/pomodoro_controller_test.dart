import 'package:flutter_test/flutter_test.dart';
import 'package:clock_calendar_app/pomodoro/app_clock.dart';
import 'package:clock_calendar_app/pomodoro/pomodoro_controller.dart';
import 'package:clock_calendar_app/pomodoro/settings_state.dart';

void main() {
  test('降低长休息间隔后，配置和计数仍可恢复', () {
    final clock = TestClock(DateTime(2026, 1, 1));
    final c = PomodoroController(clock: clock, autoTick: false);
    addTearDown(c.dispose);
    for (var i = 0; i < 3; i++) {
      c.start();
      clock.advance(const Duration(minutes: 25));
      c.tick();
      c.start();
      clock.advance(const Duration(minutes: 5));
      c.tick();
    }
    c.configure(const SettingsState(sessionsBeforeLongBreak: 2));
    final restored = PomodoroController(clock: clock, autoTick: false);
    addTearDown(restored.dispose);
    restored.restore(c.snapshot());
    expect(restored.settings.sessionsBeforeLongBreak, 2);
    expect(restored.state.totalCompletedPomodoros, 3);
    expect(restored.state.completedPomodorosInCycle, lessThan(2));
  });
  test('任务增改完成删除及选择保存恢复', () {
    final clock = TestClock(DateTime(2026, 1, 1));
    final c = PomodoroController(clock: clock, autoTick: false);
    addTearDown(c.dispose);
    c.addTask('写作');
    final id = c.tasks.single.id;
    c.renameTask(id, '读书');
    c.selectTask(id);
    c.setTaskCompleted(id, true);
    final saved = c.snapshot();
    final r = PomodoroController(clock: clock, autoTick: false);
    addTearDown(r.dispose);
    r.restore(saved);
    expect(r.tasks.single.title, '读书');
    expect(r.tasks.single.completed, true);
    expect(r.selectedTaskId, id);
    r.deleteTask(id);
    expect(r.tasks, isEmpty);
    expect(r.selectedTaskId, isNull);
  });
  test('Hive 任务替换校正选中项，重复 id 被拒绝', () {
    final clock = TestClock(DateTime(2026, 1, 1));
    final c = PomodoroController(clock: clock, autoTick: false);
    addTearDown(c.dispose);
    c.replaceTasksFromHive([
      PomodoroTask(
          id: 'x', title: '写作', completed: false, createdAt: DateTime(2026)),
    ], selectedId: 'x');
    expect(c.tasks.single.title, '写作');
    expect(c.selectedTaskId, 'x');
    expect(c.state.currentTaskName, '写作');
    // 选中项不存在时清空，避免指向已删除任务。
    c.replaceTasksFromHive([
      PomodoroTask(
          id: 'y', title: '读书', completed: false, createdAt: DateTime(2026)),
    ], selectedId: 'x');
    expect(c.selectedTaskId, isNull);
    expect(c.state.currentTaskName, '');
    final before = c.tasks.single.title;
    c.replaceTasksFromHive([
      PomodoroTask(
          id: 'dup', title: '一', completed: false, createdAt: DateTime(2026)),
      PomodoroTask(
          id: 'dup', title: '二', completed: false, createdAt: DateTime(2026)),
    ]);
    expect(c.tasks.single.title, before);
  });

  test('配置和运行状态恢复为暂停，剩余时长保留', () {
    final clock = TestClock(DateTime(2026, 1, 1));
    final c = PomodoroController(clock: clock, autoTick: false);
    addTearDown(c.dispose);
    c.configure(const SettingsState(
        workDurationMinutes: 20,
        shortBreakDurationMinutes: 3,
        longBreakDurationMinutes: 10,
        sessionsBeforeLongBreak: 2,
        autoStartBreaks: true,
        autoStartPomodoros: true));
    c.start();
    clock.advance(const Duration(minutes: 4));
    c.tick();
    final saved = c.snapshot();
    final r = PomodoroController(clock: clock, autoTick: false);
    addTearDown(r.dispose);
    r.restore(saved);
    expect(r.state.isPaused, true);
    expect(r.state.remainingDuration, const Duration(minutes: 16));
    expect(r.settings.sessionsBeforeLongBreak, 2);
    expect(r.settings.autoStartBreaks, true);
  });
}
