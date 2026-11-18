import 'dart:async';
import 'package:flutter/foundation.dart';
import 'alarm_core.dart';

class AlarmRing {
  final String id, name;
  const AlarmRing(this.id, this.name);
}

class _Snooze {
  final AlarmRing ring;
  final DateTime due;
  const _Snooze(this.ring, this.due);
}

class AlarmController extends ChangeNotifier {
  AlarmController(
      {DateTime Function()? now,
      this.onRing,
      this.onChanged,
      bool autoTick = true})
      : _now = now ?? DateTime.now {
    if (autoTick) {
      _timer = Timer.periodic(const Duration(seconds: 1), (_) => check());
    }
  }
  final DateTime Function() _now;
  final VoidCallback? onRing;
  final void Function(Map<String, Object>)? onChanged;
  Timer? _timer;
  List<AlarmEntry> _alarms = [];
  final List<AlarmRing> _queue = [];
  List<_Snooze> _snoozes = [];
  int _counter = 0;
  List<AlarmEntry> get alarms => List.unmodifiable(_alarms);
  List<AlarmRing> get queue => List.unmodifiable(_queue);
  void _changed() {
    notifyListeners();
    onChanged?.call(snapshot());
  }

  void add(String name, AlarmRule rule) {
    if (rule.nextOccurrence(_now()) == null) throw ArgumentError('闹钟时间或星期无效');
    final id = '${DateTime.now().microsecondsSinceEpoch}-${_counter++}';
    _alarms.add(AlarmEntry(
        id: id,
        name: name.trim().isEmpty ? '闹钟' : name.trim(),
        rule: rule,
        enabled: true,
        nextFireAt: rule.nextOccurrence(_now())));
    _changed();
  }

  void update(String id, String name, AlarmRule rule) {
    if (rule.nextOccurrence(_now()) == null) throw ArgumentError('闹钟时间或星期无效');
    _alarms = [
      for (final a in _alarms)
        if (a.id == id)
          AlarmEntry(
              id: id,
              name: name.trim().isEmpty ? '闹钟' : name.trim(),
              rule: rule,
              enabled: a.enabled,
              nextFireAt: a.enabled ? rule.nextOccurrence(_now()) : null)
        else
          a
    ];
    _changed();
  }

  void setEnabled(String id, bool enabled) {
    _alarms = [
      for (final a in _alarms)
        if (a.id == id)
          a.withState(enabled, enabled ? a.rule.nextOccurrence(_now()) : null)
        else
          a
    ];
    if (!enabled) _snoozes.removeWhere((s) => s.ring.id == id);
    _changed();
  }

  void delete(String id) {
    _alarms.removeWhere((a) => a.id == id);
    _snoozes.removeWhere((s) => s.ring.id == id);
    _changed();
  }

  void check() {
    final now = _now();
    final wasEmpty = _queue.isEmpty;
    final result = sweepAlarms(_alarms, now);
    var modified = result.fired.isNotEmpty || result.missed.isNotEmpty;
    _alarms = result.alarms;
    for (final a in result.fired) {
      _queue.add(AlarmRing(a.id, a.name));
    }
    final remaining = <_Snooze>[];
    for (final s in _snoozes) {
      if (s.due.isAfter(now)) {
        remaining.add(s);
        continue;
      }
      modified = true;
      if (now.difference(s.due) <= const Duration(minutes: 5)) {
        _queue.add(s.ring);
      }
    }
    _snoozes = remaining;
    if (modified) _changed();
    if (wasEmpty && _queue.isNotEmpty) onRing?.call();
  }

  void stop() {
    if (_queue.isEmpty) return;
    _queue.removeAt(0);
    _changed();
  }

  void snooze({Duration duration = const Duration(minutes: 9)}) {
    if (_queue.isEmpty) return;
    _snoozes.add(_Snooze(_queue.removeAt(0), _now().add(duration)));
    _changed();
  }

  Map<String, Object> snapshot() => {
        'alarms': [
          for (final a in _alarms)
            {
              'id': a.id,
              'name': a.name,
              'hour': a.rule.hour,
              'minute': a.rule.minute,
              'repeat': a.rule.repeat.name,
              'weekdays': a.rule.weekdays.toList(),
              'enabled': a.enabled,
              'nextFireAt': a.nextFireAt?.toIso8601String()
            }
        ],
        'snoozes': [
          for (final s in _snoozes)
            {
              'id': s.ring.id,
              'name': s.ring.name,
              'due': s.due.toIso8601String()
            }
        ],
      };
  void restore(Map<String, dynamic> data) {
    try {
      final rows = data['alarms'];
      final snoozes = data['snoozes'];
      if (rows is! List || snoozes is! List) return;
      final alarms = <AlarmEntry>[], delayed = <_Snooze>[];
      final ids = <String>{};
      for (final row in rows) {
        if (row is! Map ||
            row['id'] is! String ||
            row['name'] is! String ||
            row['hour'] is! int ||
            row['minute'] is! int ||
            row['enabled'] is! bool ||
            row['weekdays'] is! List ||
            !ids.add(row['id'])) return;
        final repeat =
            AlarmRepeat.values.firstWhere((v) => v.name == row['repeat']);
        final days = (row['weekdays'] as List).map((v) => v as int).toSet();
        final rule = AlarmRule(
            hour: row['hour'],
            minute: row['minute'],
            repeat: repeat,
            weekdays: days);
        if (rule.nextOccurrence(_now()) == null) return;
        final rawNext = row['nextFireAt'];
        if (rawNext != null && rawNext is! String) return;
        final next = rawNext == null ? null : DateTime.tryParse(rawNext);
        if (rawNext != null && next == null) return;
        alarms.add(AlarmEntry(
            id: row['id'],
            name: row['name'],
            rule: rule,
            enabled: row['enabled'],
            nextFireAt: next));
      }
      for (final row in snoozes) {
        if (row is! Map ||
            row['id'] is! String ||
            row['name'] is! String ||
            row['due'] is! String ||
            !ids.contains(row['id'])) return;
        final due = DateTime.tryParse(row['due']);
        if (due == null) return;
        delayed.add(_Snooze(AlarmRing(row['id'], row['name']), due));
      }
      _alarms = alarms;
      _snoozes = delayed;
      notifyListeners();
      check();
    } catch (_) {
      return;
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}
