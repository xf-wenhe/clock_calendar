import 'pomodoro_phase.dart';

class PomodoroTimerState {
  final PomodoroPhase phase;
  final bool isRunning;
  final bool isPaused;
  final Duration totalDuration;
  final Duration remainingDuration;
  final DateTime? targetEndTime;
  final DateTime? sessionStartTime;
  final int completedPomodorosInCycle;
  final int totalCompletedPomodoros;
  final String currentTaskName;

  const PomodoroTimerState({
    this.phase = PomodoroPhase.work,
    this.isRunning = false,
    this.isPaused = false,
    this.totalDuration = const Duration(minutes: 25),
    this.remainingDuration = const Duration(minutes: 25),
    this.targetEndTime,
    this.sessionStartTime,
    this.completedPomodorosInCycle = 0,
    this.totalCompletedPomodoros = 0,
    this.currentTaskName = '',
  });

  bool get isInitial => !isRunning && !isPaused;

  double get progress {
    if (totalDuration.inMilliseconds == 0) return 0.0;
    final elapsed = totalDuration - remainingDuration;
    final p = elapsed.inMilliseconds / totalDuration.inMilliseconds;
    return p.clamp(0.0, 1.0);
  }

  String get formattedTime {
    final seconds =
        (remainingDuration.inMilliseconds / 1000).ceil().clamp(0, 1 << 31);
    final m = (seconds ~/ 60).toString().padLeft(2, '0');
    final s = (seconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  PomodoroTimerState copyWith({
    PomodoroPhase? phase,
    bool? isRunning,
    bool? isPaused,
    Duration? totalDuration,
    Duration? remainingDuration,
    DateTime? targetEndTime,
    bool clearTargetEndTime = false,
    DateTime? sessionStartTime,
    bool clearSessionStartTime = false,
    int? completedPomodorosInCycle,
    int? totalCompletedPomodoros,
    String? currentTaskName,
  }) {
    return PomodoroTimerState(
      phase: phase ?? this.phase,
      isRunning: isRunning ?? this.isRunning,
      isPaused: isPaused ?? this.isPaused,
      totalDuration: totalDuration ?? this.totalDuration,
      remainingDuration: remainingDuration ?? this.remainingDuration,
      targetEndTime:
          clearTargetEndTime ? null : (targetEndTime ?? this.targetEndTime),
      sessionStartTime: clearSessionStartTime
          ? null
          : (sessionStartTime ?? this.sessionStartTime),
      completedPomodorosInCycle:
          completedPomodorosInCycle ?? this.completedPomodorosInCycle,
      totalCompletedPomodoros:
          totalCompletedPomodoros ?? this.totalCompletedPomodoros,
      currentTaskName: currentTaskName ?? this.currentTaskName,
    );
  }
}
