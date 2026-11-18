// Stopwatch monotonic source: Windows GetTickCount64. Per Microsoft's Windows
// Time documentation this source includes time spent in sleep/hibernation, so
// a running stopwatch keeps counting across sleep. Application restart clears
// to zero. The clock is injectable (`now`) so sleep jumps are covered in tests
// without putting the machine to sleep.
import 'dart:ffi';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'stopwatch_core.dart';

typedef _TickNative = Uint64 Function();
typedef _TickDart = int Function();

class StopwatchController extends ChangeNotifier {
  StopwatchController({int Function()? now}) : _fallback = Stopwatch() {
    if (now == null) {
      _fallback.start();
      _now = _resolveClock(_fallback);
    } else {
      _now = now;
    }
  }

  final Stopwatch _fallback;
  late final int Function() _now;

  static int Function() _resolveClock(Stopwatch fallback) {
    if (Platform.isWindows) {
      try {
        final ticks = DynamicLibrary.open('kernel32.dll')
            .lookupFunction<_TickNative, _TickDart>('GetTickCount64');
        return ticks;
      } catch (_) {
        // Fall through to the Dart monotonic clock if FFI is unavailable.
      }
    }
    return () => fallback.elapsedMilliseconds;
  }

  StopwatchState _state = StopwatchState.initial();
  StopwatchState get state => _state;
  int get elapsedMs => _state.elapsed(_now());
  void start() {
    _state = _state.start(_now());
    notifyListeners();
  }

  void pause() {
    _state = _state.pause(_now());
    notifyListeners();
  }

  void reset() {
    _state = _state.reset();
    notifyListeners();
  }

  void lap() {
    _state = _state.lap(_now());
    notifyListeners();
  }

  @override
  void dispose() {
    _fallback.stop();
    super.dispose();
  }
}
