import 'package:flutter_test/flutter_test.dart';
import 'package:clock_calendar_app/pomodoro/pomodoro_persistence.dart';
import 'package:clock_calendar_app/pomodoro/pomodoro_phase.dart';
import 'package:clock_calendar_app/pomodoro/pomodoro_timer_state.dart';

void main() {
  test('上游状态序列化字段重启时恢复为暂停', () {
    const state = PomodoroTimerState(
        phase: PomodoroPhase.shortBreak,
        isRunning: true,
        totalDuration: Duration(minutes: 5),
        remainingDuration: Duration(minutes: 3),
        completedPomodorosInCycle: 1,
        totalCompletedPomodoros: 1,
        currentTaskName: '写作');
    final encoded = encodePomodoroState(state);
    final result = decodePomodoroState(encoded, interval: 4);
    expect(result!.phase, PomodoroPhase.shortBreak);
    expect(result.isRunning, false);
    expect(result.isPaused, true);
    expect(result.remainingDuration, const Duration(minutes: 3));
    expect(result.currentTaskName, '写作');
  });
  test('旧版本状态可以迁移，损坏值拒绝', () {
    final old = {
      'phase': 'work',
      'running': true,
      'paused': false,
      'totalMs': 1500000,
      'remainingMs': 900000,
      'cycle': 0,
      'completed': 1
    };
    expect(decodePomodoroState(old, interval: 4)!.remainingDuration,
        const Duration(minutes: 15));
    expect(
        decodePomodoroState({...old, 'remainingMs': -1}, interval: 4), isNull);
  });
}
