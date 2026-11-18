import 'package:flutter_test/flutter_test.dart';
import 'package:clock_calendar_app/services/display_topology.dart';

void main() {
  test('首次采样不移动，显示器配置变化后触发重新检查', () {
    final tracker = DisplayTopologyTracker();
    expect(tracker.update(['1:1920x1080:1.0', '2:2560x1440:1.5']), false);
    expect(tracker.update(['2:2560x1440:1.5', '1:1920x1080:1.0']), false);
    expect(tracker.update(['1:1920x1080:1.0']), true);
    expect(tracker.update(['1:1920x1080:1.25']), true);
  });
  test('暂时无法读取显示器不覆盖上次有效状态', () {
    final tracker = DisplayTopologyTracker();
    tracker.update(['a']);
    expect(tracker.update([]), false);
    expect(tracker.update(['b']), true);
  });
}
