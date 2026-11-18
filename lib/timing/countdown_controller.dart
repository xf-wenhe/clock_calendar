import 'dart:async';
import 'dart:ffi';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'countdown_core.dart';

typedef _TickNative = Uint64 Function();
typedef _TickDart = int Function();

class CountdownController extends ChangeNotifier {
  CountdownController(
      {int Function()? now,
      this.onComplete,
      this.onChanged,
      bool autoTick = true}) {
    _fallback.start();
    _now = now ??
        (Platform.isWindows
            ? DynamicLibrary.open('kernel32.dll')
                .lookupFunction<_TickNative, _TickDart>('GetTickCount64')
            : () => _fallback.elapsedMilliseconds);
    if (autoTick) {
      _timer =
          Timer.periodic(const Duration(milliseconds: 250), (_) => check());
    }
  }
  final Stopwatch _fallback = Stopwatch();
  late final int Function() _now;
  final VoidCallback? onComplete;
  final void Function(Map<String, Object>)? onChanged;
  Timer? _timer;
  int? _lastCheckpoint;
  CountdownState _state = CountdownState.initial(1500000);
  List<int> _presets = [5, 10, 25];
  CountdownState get state => _state;
  List<int> get presets => List.unmodifiable(_presets);
  int get remainingMs => _state.remaining(_now());
  void _change(CountdownState next) {
    if (identical(next, _state)) return;
    _state = next;
    notifyListeners();
    onChanged?.call(snapshot());
  }

  void setDuration(int duration) => _change(_state.withDuration(duration));
  void setPresets(List<int> values) {
    if (values.length != 3 || values.any((v) => v < 1 || v > 1439)) return;
    _presets = List.of(values);
    notifyListeners();
    onChanged?.call(snapshot());
  }

  void start() => _change(_state.start(_now()));
  void pause() {
    check();
    _change(_state.pause(_now()));
  }

  void resume() => _change(_state.resume(_now()));
  void reset() => _change(_state.reset());
  void check() {
    final previous = _state.status;
    _change(_state.tick(_now()));
    if (previous == CountdownStatus.running &&
        _state.status == CountdownStatus.completed) onComplete?.call();
    final now = _now();
    if (_state.status == CountdownStatus.running &&
        (_lastCheckpoint == null || now - _lastCheckpoint! >= 1000)) {
      _lastCheckpoint = now;
      onChanged?.call(snapshot());
    }
  }

  Map<String, Object> snapshot() => {
        'durationMs': _state.durationMs,
        'remainingMs': remainingMs,
        'status': _state.status.name,
        'presets': _presets,
      };
  void restore(Map<String, dynamic> data) {
    final duration = data['durationMs'];
    final remaining = data['remainingMs'];
    final status = data['status'];
    final rawPresets = data['presets'];
    if (rawPresets != null &&
        (rawPresets is! List ||
            rawPresets.length != 3 ||
            rawPresets.any((v) => v is! int || v < 1 || v > 1439))) return;
    if (duration is! int ||
        remaining is! int ||
        duration < 0 ||
        duration > 86399000 ||
        remaining < 0 ||
        remaining > duration ||
        !['idle', 'running', 'paused', 'completed'].contains(status)) return;
    var restored = CountdownState.initial(duration);
    if (status == 'running' || status == 'paused') {
      restored = restored.start(0).pause(duration - remaining);
    }
    if (status == 'completed') restored = restored.start(0).tick(duration);
    _state = restored;
    if (rawPresets is List) _presets = rawPresets.cast<int>().toList();
    notifyListeners();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _fallback.stop();
    super.dispose();
  }
}
