import 'app_clock.dart';
import 'settings_state.dart';
import 'pomodoro_phase.dart';
import 'pomodoro_timer_state.dart';

typedef SessionCompletedCallback = void Function({
  required PomodoroPhase phase,
  required DateTime startTime,
  required DateTime endTime,
  required Duration duration,
  required String taskName,
});

class PomodoroEngine {
  final AppClock _clock;
  SettingsState _settings;
  PomodoroTimerState _state;
  final SessionCompletedCallback? onSessionCompleted;
  final void Function(PomodoroTimerState state)? onStateChanged;

  PomodoroEngine({
    required AppClock clock,
    required SettingsState settings,
    this.onSessionCompleted,
    this.onStateChanged,
    PomodoroTimerState? initialState,
  })  : _clock = clock,
        _settings = settings,
        _state = initialState ??
            PomodoroTimerState(
              phase: PomodoroPhase.work,
              totalDuration: Duration(minutes: settings.workDurationMinutes),
              remainingDuration:
                  Duration(minutes: settings.workDurationMinutes),
            );

  PomodoroTimerState get state => _state;

  void _setState(PomodoroTimerState newState) {
    _state = newState;
    onStateChanged?.call(_state);
  }

  Duration getDurationForPhase(PomodoroPhase phase) {
    switch (phase) {
      case PomodoroPhase.work:
        return Duration(minutes: _settings.workDurationMinutes.clamp(1, 1440));
      case PomodoroPhase.shortBreak:
        return Duration(
          minutes: _settings.shortBreakDurationMinutes.clamp(1, 1440),
        );
      case PomodoroPhase.longBreak:
        return Duration(
          minutes: _settings.longBreakDurationMinutes.clamp(1, 1440),
        );
    }
  }

  void start() {
    if (_state.isRunning) return;

    final now = _clock.now();
    final DateTime targetEnd;
    final DateTime startTime;

    if (_state.isPaused) {
      targetEnd = now.add(_state.remainingDuration);
      startTime = _state.sessionStartTime ?? now;
    } else {
      final total = getDurationForPhase(_state.phase);
      targetEnd = now.add(total);
      startTime = now;
      _setState(
        _state.copyWith(
          totalDuration: total,
          remainingDuration: total,
          sessionStartTime: startTime,
        ),
      );
    }

    _setState(
      _state.copyWith(
        isRunning: true,
        isPaused: false,
        targetEndTime: targetEnd,
        sessionStartTime: startTime,
      ),
    );
  }

  void pause() {
    if (!_state.isRunning) return;

    tick();
    if (!_state.isRunning) return;
    final now = _clock.now();
    final remaining = _state.targetEndTime != null
        ? _state.targetEndTime!.difference(now)
        : _state.remainingDuration;

    final safeRemaining = remaining.isNegative ? Duration.zero : remaining;

    _setState(
      _state.copyWith(
        isRunning: false,
        isPaused: true,
        remainingDuration: safeRemaining,
        clearTargetEndTime: true,
      ),
    );
  }

  void reset() {
    final defaultDuration = getDurationForPhase(_state.phase);
    _setState(
      _state.copyWith(
        isRunning: false,
        isPaused: false,
        totalDuration: defaultDuration,
        remainingDuration: defaultDuration,
        clearTargetEndTime: true,
        clearSessionStartTime: true,
      ),
    );
  }

  void skip() {
    _transitionToNextPhase(autoStartOverride: false);
  }

  void setTaskName(String name) {
    _setState(_state.copyWith(currentTaskName: name));
  }

  void updateSettings(SettingsState newSettings) {
    _settings = newSettings;
    if (_state.isInitial) {
      final duration = getDurationForPhase(_state.phase);
      _setState(
        _state.copyWith(totalDuration: duration, remainingDuration: duration),
      );
    }
  }

  void tick() {
    if (!_state.isRunning || _state.targetEndTime == null) return;
    final now = _clock.now();
    // Advance from deadlines, including auto-started phases elapsed during sleep.
    while (_state.isRunning && !_state.targetEndTime!.isAfter(now)) {
      _handlePhaseCompletion();
    }
    if (_state.isRunning) {
      _setState(
        _state.copyWith(
          remainingDuration: _state.targetEndTime!.difference(now),
        ),
      );
    }
  }

  void _handlePhaseCompletion() {
    final completedPhase = _state.phase;
    final startTime =
        _state.sessionStartTime ?? _clock.now().subtract(_state.totalDuration);
    final endTime = _state.targetEndTime ?? _clock.now();

    onSessionCompleted?.call(
      phase: completedPhase,
      startTime: startTime,
      endTime: endTime,
      duration: _state.totalDuration,
      taskName: _state.currentTaskName,
    );

    int newCompletedInCycle = _state.completedPomodorosInCycle;
    int newTotalCompleted = _state.totalCompletedPomodoros;

    if (completedPhase == PomodoroPhase.work) {
      newCompletedInCycle++;
      newTotalCompleted++;
    }

    final bool shouldTakeLongBreak = completedPhase == PomodoroPhase.work &&
        newCompletedInCycle >= _settings.sessionsBeforeLongBreak;

    final PomodoroPhase nextPhase;
    if (completedPhase == PomodoroPhase.work) {
      nextPhase = shouldTakeLongBreak
          ? PomodoroPhase.longBreak
          : PomodoroPhase.shortBreak;
      if (shouldTakeLongBreak) {
        newCompletedInCycle = 0;
      }
    } else {
      nextPhase = PomodoroPhase.work;
    }

    final nextDuration = getDurationForPhase(nextPhase);
    final bool shouldAutoStart = nextPhase.isBreak
        ? _settings.autoStartBreaks
        : _settings.autoStartPomodoros;

    _setState(
      _state.copyWith(
        phase: nextPhase,
        totalDuration: nextDuration,
        remainingDuration: nextDuration,
        completedPomodorosInCycle: newCompletedInCycle,
        totalCompletedPomodoros: newTotalCompleted,
        isRunning: shouldAutoStart,
        isPaused: false,
        targetEndTime: shouldAutoStart ? endTime.add(nextDuration) : null,
        clearTargetEndTime: !shouldAutoStart,
        sessionStartTime: shouldAutoStart ? endTime : null,
        clearSessionStartTime: !shouldAutoStart,
      ),
    );
  }

  void _transitionToNextPhase({required bool autoStartOverride}) {
    final nextPhase = _state.phase == PomodoroPhase.work
        ? PomodoroPhase.shortBreak
        : PomodoroPhase.work;

    final nextDuration = getDurationForPhase(nextPhase);
    final now = _clock.now();

    _setState(
      _state.copyWith(
        phase: nextPhase,
        totalDuration: nextDuration,
        remainingDuration: nextDuration,
        isRunning: autoStartOverride,
        isPaused: false,
        targetEndTime: autoStartOverride ? now.add(nextDuration) : null,
        clearTargetEndTime: !autoStartOverride,
        sessionStartTime: autoStartOverride ? now : null,
        clearSessionStartTime: !autoStartOverride,
      ),
    );
  }
}
