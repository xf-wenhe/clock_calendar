import 'package:flutter_test/flutter_test.dart';
import 'package:clock_calendar_app/timing/stopwatch_core.dart';

void main() {
  test('upstream: running, pause and resume accumulate elapsed time', () {
    var state = StopwatchState.initial().start(1000);
    expect(state.elapsed(5321), 4321);
    state = state.pause(4000);
    expect(state.elapsed(900000), 3000);
    state = state.start(100000);
    expect(state.elapsed(102000), 5000);
  });
  test('upstream: laps preserve splits and derive lap durations', () {
    var state = StopwatchState.initial().start(0);
    state = state.lap(1000).lap(2500).lap(6000);
    expect(state.laps, [1000, 2500, 6000]);
    expect(state.lapDurations, [1000, 1500, 3500]);
    expect(state.reset().laps, isEmpty);
  });
  test('upstream: idle laps ignored and paused lap stays fixed', () {
    final idle = StopwatchState.initial();
    expect(idle.lap(500).laps, isEmpty);
    final paused = idle.start(0).pause(5000).lap(9000);
    expect(paused.laps, [5000]);
  });
  test('上游边界：长时间未刷新仍按时间源计算', () {
    final state = StopwatchState.initial().start(0);
    expect(state.elapsed(7200000), 7200000);
  });
  test('休眠规则：运行中的秒表按单调时钟计入休眠跳变', () {
    // GetTickCount64 advances across sleep on Windows; a jump of 8 hours in
    // the injectable clock models a machine resuming from hibernation.
    var state = StopwatchState.initial().start(1000);
    state = state.lap(2000); // 1s before sleep
    expect(state.elapsed(2000), 1000);
    final afterSleep = 2000 + const Duration(hours: 8).inMilliseconds;
    expect(state.elapsed(afterSleep),
        1000 + const Duration(hours: 8).inMilliseconds);
    // Pausing at resume freezes the accumulated value including the sleep.
    final paused = state.pause(afterSleep);
    expect(paused.elapsed(afterSleep + 999999),
        1000 + const Duration(hours: 8).inMilliseconds);
  });
  test('休眠期间暂停的秒表不累计', () {
    final paused = StopwatchState.initial().start(0).pause(1000);
    expect(paused.elapsed(0 + const Duration(hours: 8).inMilliseconds), 1000);
  });
}
