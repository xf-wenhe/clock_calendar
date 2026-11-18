// Sound IDs and assets from tempo-app src/core/sounds.ts and assets/sounds, MIT.
import 'dart:async';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';

abstract class SoundBackend {
  Future<void> play(String id, double volume, {required bool loop});
  Future<void> setVolume(double volume);
  Future<void> stop();
  Future<void> dispose();
}

class AudioPlayersBackend implements SoundBackend {
  AudioPlayer? _notice;
  AudioPlayer? _alarm;
  Future<void> _pending = Future.value();
  Future<void> _enqueue(Future<void> Function() action) {
    _pending = _pending.then((_) => action()).catchError((_) {});
    return _pending;
  }

  @override
  Future<void> play(String id, double volume, {required bool loop}) =>
      _enqueue(() async {
        final player =
            loop ? (_alarm ??= AudioPlayer()) : (_notice ??= AudioPlayer());
        await player
            .setReleaseMode(loop ? ReleaseMode.loop : ReleaseMode.release);
        await player.play(AssetSource('sounds/$id.wav'), volume: volume);
      });
  @override
  Future<void> stop() => _enqueue(() async {
        await _alarm?.stop();
        await _notice?.stop();
      });
  @override
  Future<void> setVolume(double volume) => _enqueue(() async {
        await _alarm?.setVolume(volume);
        await _notice?.setVolume(volume);
      });
  @override
  Future<void> dispose() => _enqueue(() async {
        await _alarm?.dispose();
        await _notice?.dispose();
      });
}

class SoundController extends ChangeNotifier {
  SoundController({SoundBackend? backend})
      : _backend = backend ?? AudioPlayersBackend();
  static const sounds = {
    'soft-chime': '柔和铃声',
    'low-bell': '低音铃',
    'glass': '清脆铃',
    'wood': '木声'
  };
  final SoundBackend _backend;
  String _sound = 'soft-chime';
  double _volume = 0.7;
  bool _muted = false;
  String get sound => _sound;
  double get volume => _volume;
  bool get muted => _muted;
  void configure(
      {required String sound, required double volume, required bool muted}) {
    if (!sounds.containsKey(sound) ||
        !volume.isFinite ||
        volume < 0 ||
        volume > 1) return;
    _sound = sound;
    _volume = volume;
    _muted = muted;
    if (muted) {
      unawaited(stop());
    } else {
      unawaited(_applyVolume());
    }
    notifyListeners();
  }

  Future<void> play({bool loop = false}) async {
    if (_muted || _volume == 0) return;
    try {
      await _backend.play(_sound, _volume, loop: loop);
    } catch (_) {}
  }

  Future<void> stop() async {
    try {
      await _backend.stop();
    } catch (_) {}
  }

  Future<void> _applyVolume() async {
    try {
      await _backend.setVolume(_volume);
    } catch (_) {}
  }

  Future<void> _disposeBackend() async {
    try {
      await _backend.dispose();
    } catch (_) {}
  }

  Map<String, Object> snapshot() =>
      {'sound': _sound, 'volume': _volume, 'muted': _muted};
  void restore(Map<String, dynamic> data) {
    final sound = data['sound'], volume = data['volume'], muted = data['muted'];
    if (sound is! String ||
        volume is! num ||
        muted is! bool ||
        !sounds.containsKey(sound) ||
        !volume.isFinite ||
        volume < 0 ||
        volume > 1) return;
    configure(sound: sound, volume: volume.toDouble(), muted: muted);
  }

  @override
  void dispose() {
    unawaited(_disposeBackend());
    super.dispose();
  }
}
