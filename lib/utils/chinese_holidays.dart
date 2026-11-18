import 'package:lunar/lunar.dart';

class ChineseHoliday {
  final DateTime date;
  final String name;
  final HolidayType type;
  final int? duration;

  const ChineseHoliday(
      {required this.date,
      required this.name,
      required this.type,
      this.duration});
}

enum HolidayType { festival, solarTerm, holiday }

class ChineseDayInfo {
  final String lunarDate;
  final String zodiac;
  final List<ChineseHoliday> events;
  const ChineseDayInfo(this.lunarDate, this.zodiac, this.events);
}

class ChineseHolidaysUtil {
  // Conservative supported interval for this application's calendar display.
  static ChineseDayInfo getDayInfo(DateTime date) {
    if (date.year < 1900 || date.year > 2100) {
      return const ChineseDayInfo('超出支持范围', '', []);
    }
    final solar = Solar.fromDate(date);
    final lunar = solar.getLunar();
    final events = <ChineseHoliday>[];
    for (final name in [...solar.getFestivals(), ...lunar.getFestivals()]) {
      events.add(ChineseHoliday(
          date: date,
          name: name == '元旦节' ? '元旦' : name,
          type: HolidayType.festival));
    }
    final term = lunar.getJieQi();
    if (term.isNotEmpty) {
      events.add(
          ChineseHoliday(date: date, name: term, type: HolidayType.solarTerm));
    }
    return ChineseDayInfo(lunar.toString(), lunar.getYearShengXiao(), events);
  }

  static ChineseHoliday? getHoliday(DateTime date) {
    final events = getDayInfo(date).events;
    return events.isEmpty ? null : events.first;
  }

  static List<ChineseHoliday> getMonthHolidays(int year, int month) {
    final count = DateTime(year, month + 1, 0).day;
    return [
      for (var day = 1; day <= count; day++)
        ...getDayInfo(DateTime(year, month, day)).events
    ];
  }

  static String getTypeDisplayText(HolidayType type) {
    switch (type) {
      case HolidayType.festival:
        return '节日';
      case HolidayType.solarTerm:
        return '节气';
      case HolidayType.holiday:
        return '放假';
    }
  }
}
