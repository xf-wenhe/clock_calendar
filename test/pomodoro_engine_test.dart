import 'package:flutter_test/flutter_test.dart';
import 'package:clock_calendar_app/pomodoro/app_clock.dart';
import 'package:clock_calendar_app/pomodoro/settings_state.dart';
import 'package:clock_calendar_app/pomodoro/pomodoro_engine.dart';
import 'package:clock_calendar_app/pomodoro/pomodoro_phase.dart';

void main() {
  test('上游：暂停恢复和休眠后阶段切换', () {
    final clock = TestClock(DateTime(2026, 1, 1, 10));
    final engine =
        PomodoroEngine(clock: clock, settings: const SettingsState());
    engine.start();
    clock.advance(const Duration(minutes: 5));
    engine.pause();
    clock.advance(const Duration(hours: 1));
    engine.tick();
    expect(engine.state.remainingDuration, const Duration(minutes: 20));
    engine.start();
    clock.advance(const Duration(minutes: 20));
    engine.tick();
    expect(engine.state.phase, PomodoroPhase.shortBreak);
    expect(engine.state.completedPomodorosInCycle, 1);
  });
  test('上游：第四次专注后进入长休息', () {
    final clock = TestClock(DateTime(2026, 1, 1));
    final engine =
        PomodoroEngine(clock: clock, settings: const SettingsState());
    for (var i = 0; i < 4; i++) {
      engine.start();
      clock.advance(const Duration(minutes: 25));
      engine.tick();
      if (i < 3) {
        expect(engine.state.phase, PomodoroPhase.shortBreak);
        engine.start();
        clock.advance(const Duration(minutes: 5));
        engine.tick();
      }
    }
    expect(engine.state.phase, PomodoroPhase.longBreak);
    expect(engine.state.completedPomodorosInCycle, 0);
    expect(engine.state.totalCompletedPomodoros, 4);
  });
  test('上游：自动进入下一阶段', () {
    final clock = TestClock(DateTime(2026, 1, 1));
    final engine = PomodoroEngine(
        clock: clock, settings: const SettingsState(autoStartBreaks: true));
    engine.start();
    clock.advance(const Duration(minutes: 25));
    engine.tick();
    expect(engine.state.phase, PomodoroPhase.shortBreak);
    expect(engine.state.isRunning, isTrue);
  });
}
