import 'dart:convert';
import 'dart:io';

class HolidayDay {
  final DateTime date;
  final String name;
  final bool isOffDay;
  const HolidayDay(this.date, this.name, this.isOffDay);
}

class _YearData {
  final int year;
  final Map<String, HolidayDay> days;
  _YearData(this.year, this.days);
}

class HolidayData {
  final Map<int, _YearData> _years = {};
  final Map<int, DateTime> updatedAt = {};
  static String _key(DateTime date) =>
      '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  bool hasYear(int year) => _years.containsKey(year);
  HolidayDay? lookup(DateTime date) {
    final key = _key(date);
    for (final year in [date.year, date.year - 1, date.year + 1]) {
      final day = _years[year]?.days[key];
      if (day != null) return day;
    }
    return null;
  }

  _YearData _parse(String json, [int? expectedYear]) {
    try {
      final decoded = jsonDecode(json);
      if (decoded is! Map ||
          decoded['year'] is! int ||
          decoded['days'] is! List) throw const FormatException('无效数据');
      final year = decoded['year'] as int;
      if (year < 1900 ||
          year > 2100 ||
          (expectedYear != null && year != expectedYear)) {
        throw const FormatException('年份不匹配');
      }
      final days = <String, HolidayDay>{};
      for (final entry in decoded['days'] as List) {
        if (entry is! Map ||
            entry['date'] is! String ||
            entry['name'] is! String ||
            (entry['name'] as String).trim().isEmpty ||
            entry['isOffDay'] is! bool) throw const FormatException('日期条目无效');
        final dateString = entry['date'] as String;
        if (!RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(dateString)) {
          throw const FormatException('日期格式无效');
        }
        final date = DateTime.parse(dateString);
        if (_key(date) != dateString ||
            (date.year - year).abs() > 1 ||
            days.containsKey(dateString)) {
          throw const FormatException('日期无效或重复');
        }
        days[dateString] = HolidayDay(
            date, entry['name'] as String, entry['isOffDay'] as bool);
      }
      if (days.isEmpty) throw const FormatException('数据为空');
      return _YearData(year, days);
    } catch (_) {
      throw const FormatException('调休数据无效');
    }
  }

  void addJson(String json) {
    final parsed = _parse(json);
    _years[parsed.year] = parsed;
  }

  Future<void> loadCachedYear(int year, Directory cache) async {
    try {
      final file = File('${cache.path}/$year.json');
      _years[year] = _parse(await file.readAsString(), year);
      updatedAt[year] = await file.lastModified();
    } catch (_) {
      // No usable cache.
    }
  }

  Future<void> loadYear(int year, String bundled, Directory cache) async {
    final fallback = _parse(bundled, year);
    _years[year] = fallback;
    try {
      final file = File('${cache.path}/$year.json');
      final parsed = _parse(await file.readAsString(), year);
      _years[year] = parsed;
      updatedAt[year] = await file.lastModified();
    } catch (_) {/* Keep bundled data when cache is missing or corrupt. */}
  }

  Future<bool> updateYear(
      int year, Directory cache, Future<String> Function(int) fetch) async {
    try {
      final body = await fetch(year);
      final parsed = _parse(body, year);
      await cache.create(recursive: true);
      final temp = File('${cache.path}/$year.json.tmp');
      await temp.writeAsString(body, flush: true);
      final target = File('${cache.path}/$year.json');
      await temp.rename(target.path);
      _years[year] = parsed;
      updatedAt[year] = DateTime.now();
      return true;
    } catch (_) {
      return false;
    }
  }
}
