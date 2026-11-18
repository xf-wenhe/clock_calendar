// Reduced from pomodoro-focus settings_state.dart; MIT. See third_party/pomodoro-focus/LICENSE.
class SettingsState {
  final int workDurationMinutes,
      shortBreakDurationMinutes,
      longBreakDurationMinutes,
      sessionsBeforeLongBreak;
  final bool autoStartBreaks, autoStartPomodoros;
  const SettingsState(
      {this.workDurationMinutes = 25,
      this.shortBreakDurationMinutes = 5,
      this.longBreakDurationMinutes = 15,
      this.sessionsBeforeLongBreak = 4,
      this.autoStartBreaks = false,
      this.autoStartPomodoros = false});
}
