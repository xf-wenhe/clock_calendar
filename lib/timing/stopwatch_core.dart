// Adapted from tempo-app src/core/stopwatch.ts, MIT, Copyright (c) 2026 Fernando Halim.
// License: third_party/tempo/LICENSE.
import 'dart:math' as math;

enum StopwatchStatus { idle, running, paused }

class StopwatchState {
  final int elapsedMs;
  final StopwatchStatus status;
  final List<int> laps;
  final int? startedAt;
  const StopwatchState._(
      this.elapsedMs, this.status, this.laps, this.startedAt);
  factory StopwatchState.initial() =>
      const StopwatchState._(0, StopwatchStatus.idle, [], null);
  int elapsed(int now) => status == StopwatchStatus.running && startedAt != null
      ? elapsedMs + math.max(0, now - startedAt!)
      : elapsedMs;
  StopwatchState start(int now) => status == StopwatchStatus.running
      ? this
      : StopwatchState._(elapsedMs, StopwatchStatus.running, laps, now);
  StopwatchState pause(int now) => status != StopwatchStatus.running
      ? this
      : StopwatchState._(elapsed(now), StopwatchStatus.paused, laps, null);
  StopwatchState reset() => StopwatchState.initial();
  StopwatchState lap(int now) => status == StopwatchStatus.idle
      ? this
      : StopwatchState._(elapsedMs, status,
          List.unmodifiable([...laps, elapsed(now)]), startedAt);
  List<int> get lapDurations => [
        for (var i = 0; i < laps.length; i++)
          laps[i] - (i == 0 ? 0 : laps[i - 1])
      ];
}
