// Adapted from pomodoro-focus lib/core/updates/timer_update_handoff.dart.
// Copyright (c) 2026 Pomodoro Focus Contributors; MIT.
// See third_party/pomodoro-focus/LICENSE.
import 'pomodoro_phase.dart';
import 'pomodoro_timer_state.dart';

Map<String, Object?> encodePomodoroState(PomodoroTimerState state) => {
      'phase': state.phase.index,
      'running': state.isRunning,
      'paused': state.isPaused,
      'total': state.totalDuration.inMilliseconds,
      'remaining': state.remainingDuration.inMilliseconds,
      'cycle': state.completedPomodorosInCycle,
      'completed': state.totalCompletedPomodoros,
      'task': state.currentTaskName,
    };

PomodoroTimerState? decodePomodoroState(Map<dynamic, dynamic> value,
    {required int interval}) {
  try {
    final rawPhase = value['phase'];
    final PomodoroPhase phase;
    if (rawPhase is int) {
      if (rawPhase < 0 || rawPhase >= PomodoroPhase.values.length) return null;
      phase = PomodoroPhase.values[rawPhase];
    } else if (rawPhase is String) {
      phase = PomodoroPhase.values.firstWhere((p) => p.name == rawPhase);
    } else {
      return null;
    }
    final running = value['running'] as bool, paused = value['paused'] as bool;
    final total = (value['total'] ?? value['totalMs']) as int;
    final remaining = (value['remaining'] ?? value['remainingMs']) as int;
    final cycle = value['cycle'] as int, completed = value['completed'] as int;
    final task = (value['task'] ?? '') as String;
    if (total <= 0 ||
        total > const Duration(days: 1).inMilliseconds ||
        remaining < 0 ||
        remaining > total ||
        interval < 1 ||
        cycle < 0 ||
        cycle >= interval ||
        completed < 0 ||
        cycle > completed ||
        task.length > 10000 ||
        (running && paused)) return null;
    // A process restart cannot retain a monotonic deadline; resume explicitly.
    return PomodoroTimerState(
        phase: phase,
        isPaused: running || paused,
        totalDuration: Duration(milliseconds: total),
        remainingDuration: Duration(milliseconds: remaining),
        completedPomodorosInCycle: cycle,
        totalCompletedPomodoros: completed,
        currentTaskName: task);
  } catch (_) {
    return null;
  }
}
