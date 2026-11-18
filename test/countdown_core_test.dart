import 'package:flutter_test/flutter_test.dart';
import 'package:clock_calendar_app/timing/countdown_core.dart';

void main() {
  test('上游：倒计时基于目标时间，休眠过期只完成一次', () {
    final running = CountdownState.initial(300000).start(1000);
    expect(running.remaining(1500), 299500);
    final finished = running.tick(3601000);
    expect(finished.status, CountdownStatus.completed);
    expect(finished.remaining(3601000), 0);
    expect(identical(finished.tick(3602000), finished), isTrue);
  });
  test('上游：暂停冻结剩余时间，继续精确恢复', () {
    final paused = CountdownState.initial(300000).start(1000).pause(101500);
    expect(paused.remaining(900000), 199500);
    final resumed = paused.resume(900000);
    expect(resumed.remaining(901000), 198500);
  });
  test('上游：运行中不可改时长，重置恢复初始值', () {
    final running = CountdownState.initial(60000).start(0);
    expect(identical(running.withDuration(90000), running), isTrue);
    expect(running.pause(1500).reset().remaining(10000), 60000);
  });
  test('启动零时长或重复启动不改变状态', () {
    final zero = CountdownState.initial(0);
    expect(identical(zero.start(100), zero), isTrue);
    final running = CountdownState.initial(1000).start(0);
    expect(identical(running.start(20), running), isTrue);
  });
}
