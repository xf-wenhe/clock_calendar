import 'package:flutter_test/flutter_test.dart';
import 'package:clock_calendar_app/utils/time_format.dart';

void main() {
  test('12 小时制正确显示午夜、正午及秒开关', () {
    expect(
        formatClock(DateTime(2026, 1, 1, 0, 5, 9),
            use24Hour: false, showSeconds: false),
        '上午 12:05');
    expect(
        formatClock(DateTime(2026, 1, 1, 12, 5, 9),
            use24Hour: false, showSeconds: true),
        '下午 12:05:09');
    expect(
        formatClock(DateTime(2026, 1, 1, 23, 5, 9),
            use24Hour: true, showSeconds: false),
        '23:05');
  });
}
