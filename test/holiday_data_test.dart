import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:clock_calendar_app/services/holiday_data.dart';

String data(int year, List<Map<String, Object>> days) =>
    jsonEncode({'year': year, 'days': days});
void main() {
  test('内置年度数据均可解析，周末补班使用官方标记', () async {
    final store = HolidayData();
    for (var year = 2007; year <= 2027; year++) {
      store.addJson(await File('assets/holidays/$year.json').readAsString());
      expect(store.hasYear(year), isTrue);
    }
    expect(DateTime(2026, 10, 10).weekday, DateTime.saturday);
    expect(store.lookup(DateTime(2026, 10, 10))?.isOffDay, false);
  });
  test('跨年文件与补班标记', () {
    final store = HolidayData();
    store.addJson(data(2026, [
      {'date': '2027-01-02', 'name': '元旦', 'isOffDay': false}
    ]));
    expect(store.lookup(DateTime(2027, 1, 2))?.isOffDay, false);
    expect(store.hasYear(2027), false);
  });
  test('无效更新不覆盖已加载数据', () {
    final store = HolidayData();
    store.addJson(data(2026, [
      {'date': '2026-01-04', 'name': '元旦', 'isOffDay': false}
    ]));
    expect(() => store.addJson('{bad'), throwsFormatException);
    expect(store.lookup(DateTime(2026, 1, 4))?.isOffDay, false);
  });
  test('损坏缓存回退内置数据，下载失败保留数据', () async {
    final dir = await Directory.systemTemp.createTemp('holiday-test-');
    addTearDown(() => dir.delete(recursive: true));
    await File('${dir.path}/2026.json').writeAsString('{bad');
    final store = HolidayData();
    await store.loadYear(
        2026,
        data(2026, [
          {'date': '2026-01-04', 'name': '元旦', 'isOffDay': false}
        ]),
        dir);
    expect(store.lookup(DateTime(2026, 1, 4))?.isOffDay, false);
    final result = await store.updateYear(2026, dir, (_) async => '{bad');
    expect(result, false);
    expect(store.lookup(DateTime(2026, 1, 4))?.isOffDay, false);
    expect(await File('${dir.path}/2026.json').readAsString(), '{bad');
  });
}
