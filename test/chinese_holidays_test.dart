import 'package:clock_calendar_app/utils/chinese_holidays.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Chinese holidays utilities return expected holidays', () {
    final january = ChineseHolidaysUtil.getMonthHolidays(2026, 1);
    expect(january.map((holiday) => holiday.name), contains('元旦'));
    expect(
      ChineseHolidaysUtil.getHoliday(DateTime(2026, 1, 1))?.name,
      '元旦',
    );
  });
}
