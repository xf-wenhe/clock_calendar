import 'package:clock_calendar_app/utils/chinese_holidays.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('春节和农历日期来自历法', () {
    final info = ChineseHolidaysUtil.getDayInfo(DateTime(2026, 2, 17));
    expect(info.lunarDate, contains('正月初一'));
    expect(info.events.map((event) => event.name), contains('春节'));
  });
  test('同日多个节日均保留', () {
    final info = ChineseHolidaysUtil.getDayInfo(DateTime(2020, 10, 1));
    expect(info.events.map((event) => event.name), contains('中秋节'));
    expect(info.events.length, greaterThanOrEqualTo(2));
  });
  test('节气正确显示', () {
    final info = ChineseHolidaysUtil.getDayInfo(DateTime(2024, 4, 4));
    expect(info.events.map((event) => event.name), contains('清明'));
  });
  test('闰月正确显示', () {
    final info = ChineseHolidaysUtil.getDayInfo(DateTime(2023, 3, 22));
    expect(info.lunarDate, contains('闰二月初一'));
  });
}
