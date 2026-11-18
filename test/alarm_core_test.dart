import 'package:flutter_test/flutter_test.dart';
import 'package:clock_calendar_app/timing/alarm_core.dart';

void main() {
  test('上游：跨午夜、跨周和指定星期', () {
    final daily = AlarmRule(hour: 7, minute: 30, repeat: AlarmRepeat.daily);
    expect(daily.nextOccurrence(DateTime(2026, 1, 5, 23, 59)),
        DateTime(2026, 1, 6, 7, 30));
    final weekly = AlarmRule(
        hour: 7, minute: 30, repeat: AlarmRepeat.weekdays, weekdays: {1, 3, 5});
    expect(weekly.nextOccurrence(DateTime(2026, 1, 5, 8)),
        DateTime(2026, 1, 7, 7, 30));
    final monday = AlarmRule(
        hour: 7, minute: 30, repeat: AlarmRepeat.weekdays, weekdays: {1});
    expect(monday.nextOccurrence(DateTime(2026, 1, 5, 8)),
        DateTime(2026, 1, 12, 7, 30));
  });
  test('上游：无效重复和超界时间不生成日期', () {
    expect(
        AlarmRule(hour: 25, minute: 0, repeat: AlarmRepeat.daily)
            .nextOccurrence(DateTime(2026)),
        isNull);
    expect(
        AlarmRule(hour: 7, minute: 0, repeat: AlarmRepeat.weekdays)
            .nextOccurrence(DateTime(2026)),
        isNull);
  });
  test('上游：多个同一时刻闹钟同时触发，各自向前调度', () {
    final due = DateTime(2026, 1, 5, 7, 30);
    final a = AlarmEntry(
        id: 'a',
        name: '一',
        rule: AlarmRule(hour: 7, minute: 30, repeat: AlarmRepeat.daily),
        enabled: true,
        nextFireAt: due);
    final b = AlarmEntry(
        id: 'b',
        name: '二',
        rule: AlarmRule(hour: 7, minute: 30, repeat: AlarmRepeat.once),
        enabled: true,
        nextFireAt: due);
    final result = sweepAlarms([a, b], due.add(const Duration(minutes: 1)));
    expect(result.fired.map((a) => a.id), ['a', 'b']);
    expect(result.alarms[0].nextFireAt, DateTime(2026, 1, 6, 7, 30));
    expect(result.alarms[1].enabled, false);
  });
  test('上游：超过五分钟的漏响不播放，重复闹钟重新安排', () {
    final due = DateTime(2026, 1, 5, 7, 30);
    final a = AlarmEntry(
        id: 'a',
        name: '一',
        rule: AlarmRule(hour: 7, minute: 30, repeat: AlarmRepeat.daily),
        enabled: true,
        nextFireAt: due);
    final result = sweepAlarms([a], due.add(const Duration(hours: 5)));
    expect(result.fired, isEmpty);
    expect(result.missed.single.id, 'a');
    expect(result.alarms.single.nextFireAt, DateTime(2026, 1, 6, 7, 30));
  });
}
