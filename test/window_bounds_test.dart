import 'dart:ui';
import 'package:flutter_test/flutter_test.dart';
import 'package:clock_calendar_app/services/window_bounds.dart';

void main() {
  test('拔除显示器后窗口移回主工作区', () {
    final result = keepWindowVisible(const Rect.fromLTWH(2000, 50, 900, 700),
        [const Rect.fromLTWH(0, 0, 1920, 1040)]);
    expect(result, const Rect.fromLTWH(1020, 50, 900, 700));
  });
  test('缩小工作区时限制窗口尺寸和位置', () {
    final result = keepWindowVisible(const Rect.fromLTWH(-200, -100, 1200, 900),
        [const Rect.fromLTWH(0, 0, 800, 600)]);
    expect(result, const Rect.fromLTWH(0, 0, 800, 600));
  });
  test('保留其他显示器的有效位置', () {
    const bounds = Rect.fromLTWH(-1500, 40, 800, 600);
    final result = keepWindowVisible(bounds, [
      const Rect.fromLTWH(0, 0, 1920, 1040),
      const Rect.fromLTWH(-1920, 0, 1920, 1040)
    ]);
    expect(result, bounds);
  });
}
