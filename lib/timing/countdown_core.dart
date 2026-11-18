// Adapted from tempo-app src/core/timer.ts, MIT, Copyright (c) 2026 Fernando Halim.
// License: third_party/tempo/LICENSE.
import 'dart:math' as math;

enum CountdownStatus { idle, running, paused, completed }

class CountdownState {
  final int durationMs;
  final int remainingMs;
  final CountdownStatus status;
  final int? endsAt;
  const CountdownState._(
      this.durationMs, this.remainingMs, this.status, this.endsAt);
  factory CountdownState.initial(int milliseconds) {
    final safe = math.max(0, milliseconds);
    return CountdownState._(safe, safe, CountdownStatus.idle, null);
  }
  int remaining(int now) => status == CountdownStatus.running && endsAt != null
      ? math.max(0, endsAt! - now)
      : remainingMs;
  double progress(int now) => durationMs == 0
      ? 0
      : ((durationMs - remaining(now)) / durationMs).clamp(0, 1);
  CountdownState withDuration(int milliseconds) =>
      status == CountdownStatus.running || status == CountdownStatus.paused
          ? this
          : CountdownState.initial(milliseconds);
  CountdownState start(int now) => status == CountdownStatus.running ||
          durationMs <= 0
      ? this
      : CountdownState._(
          durationMs, durationMs, CountdownStatus.running, now + durationMs);
  CountdownState pause(int now) =>
      status != CountdownStatus.running || endsAt == null
          ? this
          : CountdownState._(
              durationMs, remaining(now), CountdownStatus.paused, null);
  CountdownState resume(int now) => status != CountdownStatus.paused
      ? this
      : CountdownState._(
          durationMs, remainingMs, CountdownStatus.running, now + remainingMs);
  CountdownState reset() => CountdownState.initial(durationMs);
  CountdownState tick(int now) =>
      status != CountdownStatus.running || endsAt == null || endsAt! > now
          ? this
          : CountdownState._(durationMs, 0, CountdownStatus.completed, null);
}
