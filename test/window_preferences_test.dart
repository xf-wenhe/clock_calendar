import 'dart:ui';
import 'package:flutter_test/flutter_test.dart';
import 'package:clock_calendar_app/services/window_preferences.dart';

void main() {
  test('窗口配置保存恢复', () {
    const prefs = WindowPreferences(
        closeToTray: true,
        alwaysOnTop: true,
        holidayAutoUpdate: false,
        use24Hour: false,
        showSeconds: false,
        mini: false,
        bounds: Rect.fromLTWH(10, 20, 1000, 700),
        fullBounds: Rect.fromLTWH(10, 20, 1000, 700));
    final copy = WindowPreferences.fromMap(prefs.toMap());
    expect(copy.closeToTray, true);
    expect(copy.alwaysOnTop, true);
    expect(copy.holidayAutoUpdate, false);
    expect(copy.use24Hour, false);
    expect(copy.showSeconds, false);
    expect(copy.bounds, prefs.bounds);
  });
  test('损坏配置回退默认值', () {
    final prefs = WindowPreferences.fromMap({
      'closeToTray': 'bad',
      'bounds': {'x': double.nan, 'y': 0, 'w': -1, 'h': 8}
    });
    expect(prefs.closeToTray, false);
    expect(prefs.bounds, isNull);
  });
}
