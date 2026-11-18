// Task fields adapted from turboc/pomodoro lib/models/task.dart, MIT.
// Licenses: third_party/pomodoro-focus/LICENSE, third_party/turboc-pomodoro/LICENSE.
import 'dart:async';
import 'dart:ffi';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'app_clock.dart';
import 'settings_state.dart';
import 'pomodoro_engine.dart';
import 'pomodoro_persistence.dart';
import 'pomodoro_timer_state.dart';

typedef _TickNative = Uint64 Function();
typedef _TickDart = int Function();

class _MonotonicClock implements AppClock {
  final Stopwatch _fallback = Stopwatch()..start();
  late final int Function() _ticks = Platform.isWindows
      ? DynamicLibrary.open('kernel32.dll')
          .lookupFunction<_TickNative, _TickDart>('GetTickCount64')
      : () => _fallback.elapsedMilliseconds;
  @override
  DateTime now() => DateTime.utc(2000).add(Duration(milliseconds: _ticks()));
  void dispose() => _fallback.stop();
}

class PomodoroTask {
  final String id, title;
  final bool completed;
  final DateTime createdAt;
  const PomodoroTask(
      {required this.id,
      required this.title,
      required this.completed,
      required this.createdAt});
}

class PomodoroController extends ChangeNotifier {
  PomodoroController(
      {AppClock? clock, this.onChanged, this.onCompleted, bool autoTick = true})
      : _clock = clock ?? _MonotonicClock() {
    _engine = _makeEngine();
    if (autoTick) {
      _timer = Timer.periodic(const Duration(seconds: 1), (_) => tick());
    }
  }
  final AppClock _clock;
  final void Function(Map<String, Object?>)? onChanged;
  final VoidCallback? onCompleted;
  SettingsState _settings = const SettingsState();
  late PomodoroEngine _engine;
  final List<PomodoroTask> _tasks = [];
  String? _selectedTaskId;
  Timer? _timer;
  int _counter = 0;
  SettingsState get settings => _settings;
  PomodoroTimerState get state => _engine.state;
  List<PomodoroTask> get tasks => List.unmodifiable(_tasks);
  String? get selectedTaskId => _selectedTaskId;
  PomodoroEngine _makeEngine([PomodoroTimerState? initial]) => PomodoroEngine(
      clock: _clock,
      settings: _settings,
      initialState: initial,
      onStateChanged: (_) => _changed(),
      onSessionCompleted: (
              {required phase,
              required startTime,
              required endTime,
              required duration,
              required taskName}) =>
          onCompleted?.call());
  void _changed() {
    notifyListeners();
    onChanged?.call(snapshot());
  }

  void start() => _engine.start();
  void pause() => _engine.pause();
  void reset() => _engine.reset();
  void tick() => _engine.tick();
  void configure(SettingsState value) {
    if (value.workDurationMinutes < 1 ||
        value.workDurationMinutes > 1440 ||
        value.shortBreakDurationMinutes < 1 ||
        value.shortBreakDurationMinutes > 1440 ||
        value.longBreakDurationMinutes < 1 ||
        value.longBreakDurationMinutes > 1440 ||
        value.sessionsBeforeLongBreak < 1 ||
        value.sessionsBeforeLongBreak > 20) throw ArgumentError('时长或周期无效');
    _settings = value;
    final normalized = _engine.state.copyWith(
      completedPomodorosInCycle: _engine.state.completedPomodorosInCycle %
          value.sessionsBeforeLongBreak,
    );
    _engine = _makeEngine(normalized);
    _engine.updateSettings(value);
    _changed();
  }

  void addTask(String title) {
    final clean = title.trim();
    if (clean.isEmpty) return;
    _tasks.add(PomodoroTask(
        id: '${DateTime.now().microsecondsSinceEpoch}-${_counter++}',
        title: clean,
        completed: false,
        createdAt: DateTime.now()));
    _changed();
  }

  void renameTask(String id, String title) {
    final clean = title.trim();
    if (clean.isEmpty) return;
    final i = _tasks.indexWhere((t) => t.id == id);
    if (i < 0) return;
    final t = _tasks[i];
    _tasks[i] = PomodoroTask(
        id: t.id, title: clean, completed: t.completed, createdAt: t.createdAt);
    if (_selectedTaskId == id) _engine.setTaskName(clean);
    _changed();
  }

  void setTaskCompleted(String id, bool done) {
    final i = _tasks.indexWhere((t) => t.id == id);
    if (i < 0) return;
    final t = _tasks[i];
    _tasks[i] = PomodoroTask(
        id: t.id, title: t.title, completed: done, createdAt: t.createdAt);
    _changed();
  }

  void deleteTask(String id) {
    _tasks.removeWhere((t) => t.id == id);
    if (_selectedTaskId == id) {
      _selectedTaskId = null;
      _engine.setTaskName('');
    }
    _changed();
  }

  void selectTask(String? id) {
    final match = _tasks.where((t) => t.id == id).toList();
    _selectedTaskId = match.isEmpty ? null : id;
    _engine.setTaskName(match.isEmpty ? '' : match.first.title);
    _changed();
  }

  /// 用 Hive 中已迁移的任务替换内存任务列表，并校正选中状态。
  /// 与 restore() 不同：这里任务来自上游 Hive 持久化，而非旧 JSON。
  void replaceTasksFromHive(List<PomodoroTask> tasks, {String? selectedId}) {
    final ids = <String>{};
    for (final t in tasks) {
      if (t.id.isEmpty || t.title.trim().isEmpty || !ids.add(t.id)) return;
    }
    _tasks
      ..clear()
      ..addAll(tasks);
    final selected =
        selectedId != null && ids.contains(selectedId) ? selectedId : null;
    _selectedTaskId = selected;
    final title =
        selected == null ? '' : tasks.firstWhere((t) => t.id == selected).title;
    _engine.setTaskName(title);
    notifyListeners();
  }

  Map<String, Object?> snapshot() => {
        'settings': {
          'work': _settings.workDurationMinutes,
          'short': _settings.shortBreakDurationMinutes,
          'long': _settings.longBreakDurationMinutes,
          'interval': _settings.sessionsBeforeLongBreak,
          'autoBreak': _settings.autoStartBreaks,
          'autoWork': _settings.autoStartPomodoros
        },
        'state': encodePomodoroState(state),
        'tasks': [
          for (final t in _tasks)
            {
              'id': t.id,
              'title': t.title,
              'completed': t.completed,
              'createdAt': t.createdAt.toIso8601String()
            }
        ],
        'selected': _selectedTaskId,
      };
  void restore(Map<String, dynamic> data) {
    try {
      final cfg = data['settings'] as Map;
      final s = data['state'] as Map;
      final rows = data['tasks'] as List;
      final work = cfg['work'] as int,
          short = cfg['short'] as int,
          long = cfg['long'] as int,
          interval = cfg['interval'] as int;
      final autoBreak = cfg['autoBreak'] as bool,
          autoWork = cfg['autoWork'] as bool;
      if ([work, short, long].any((n) => n < 1 || n > 1440) ||
          interval < 1 ||
          interval > 20) return;
      final restoredState = decodePomodoroState(s, interval: interval);
      if (restoredState == null) return;
      final tasks = <PomodoroTask>[], ids = <String>{};
      for (final row in rows) {
        final m = row as Map;
        final id = m['id'] as String,
            title = m['title'] as String,
            done = m['completed'] as bool;
        final created = DateTime.parse(m['createdAt'] as String);
        if (id.isEmpty || title.trim().isEmpty || !ids.add(id)) return;
        tasks.add(PomodoroTask(
            id: id, title: title, completed: done, createdAt: created));
      }
      final selected = data['selected'];
      if (selected != null &&
          (selected is! String || !ids.contains(selected))) {
        return;
      }
      final selectedTitle = selected == null
          ? ''
          : tasks.firstWhere((t) => t.id == selected).title;
      _settings = SettingsState(
          workDurationMinutes: work,
          shortBreakDurationMinutes: short,
          longBreakDurationMinutes: long,
          sessionsBeforeLongBreak: interval,
          autoStartBreaks: autoBreak,
          autoStartPomodoros: autoWork);
      _tasks
        ..clear()
        ..addAll(tasks);
      _selectedTaskId = selected as String?;
      _engine =
          _makeEngine(restoredState.copyWith(currentTaskName: selectedTitle));
      notifyListeners();
    } catch (_) {
      return;
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    if (_clock is _MonotonicClock) _clock.dispose();
    super.dispose();
  }
}
