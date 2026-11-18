// Adapted from tempo-app src/core/alarm.ts, MIT, Copyright (c) 2026 Fernando Halim.
// License: third_party/tempo/LICENSE.

enum AlarmRepeat { once, daily, weekdays }

class AlarmRule {
  final int hour, minute;
  final AlarmRepeat repeat;
  final Set<int> weekdays; // DateTime.weekday: Monday=1, Sunday=7.
  AlarmRule(
      {required this.hour,
      required this.minute,
      required this.repeat,
      Set<int> weekdays = const {}})
      : weekdays = Set.unmodifiable(weekdays);
  DateTime? nextOccurrence(DateTime from) {
    if (hour < 0 ||
        hour > 23 ||
        minute < 0 ||
        minute > 59 ||
        (repeat == AlarmRepeat.weekdays &&
            (weekdays.isEmpty || weekdays.any((day) => day < 1 || day > 7)))) {
      return null;
    }
    for (var offset = 0; offset <= 7; offset++) {
      final candidate =
          DateTime(from.year, from.month, from.day + offset, hour, minute);
      if (!candidate.isAfter(from)) continue;
      if (repeat == AlarmRepeat.weekdays &&
          !weekdays.contains(candidate.weekday)) continue;
      return candidate;
    }
    return null;
  }
}

class AlarmEntry {
  final String id, name;
  final AlarmRule rule;
  final bool enabled;
  final DateTime? nextFireAt;
  const AlarmEntry(
      {required this.id,
      required this.name,
      required this.rule,
      required this.enabled,
      required this.nextFireAt});
  AlarmEntry scheduled(DateTime now) => AlarmEntry(
      id: id,
      name: name,
      rule: rule,
      enabled: enabled,
      nextFireAt: enabled ? rule.nextOccurrence(now) : null);
  AlarmEntry withState(bool enabled, DateTime? next) => AlarmEntry(
      id: id, name: name, rule: rule, enabled: enabled, nextFireAt: next);
}

class AlarmSweep {
  final List<AlarmEntry> alarms, fired, missed;
  const AlarmSweep(this.alarms, this.fired, this.missed);
}

AlarmSweep sweepAlarms(List<AlarmEntry> alarms, DateTime now,
    {Duration grace = const Duration(minutes: 5)}) {
  final updated = <AlarmEntry>[],
      fired = <AlarmEntry>[],
      missed = <AlarmEntry>[];
  for (final alarm in alarms) {
    if (!alarm.enabled) {
      updated.add(alarm.withState(false, null));
      continue;
    }
    final scheduled = alarm.nextFireAt ?? alarm.rule.nextOccurrence(now);
    if (scheduled == null || scheduled.isAfter(now)) {
      updated.add(alarm.withState(true, scheduled));
      continue;
    }
    if (now.difference(scheduled) <= grace) {
      fired.add(alarm);
    } else {
      missed.add(alarm);
    }
    if (alarm.rule.repeat == AlarmRepeat.once) {
      updated.add(alarm.withState(false, null));
    } else {
      updated.add(alarm.withState(true, alarm.rule.nextOccurrence(now)));
    }
  }
  return AlarmSweep(updated, fired, missed);
}
