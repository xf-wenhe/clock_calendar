enum PomodoroPhase {
  work,
  shortBreak,
  longBreak;

  bool get isWork => this == PomodoroPhase.work;
  bool get isBreak => !isWork;
}
