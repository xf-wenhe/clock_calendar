import 'package:flutter_test/flutter_test.dart';
import 'package:clock_calendar_app/services/sound_controller.dart';

class FakeSound implements SoundBackend {
  final events = <String>[];
  @override
  Future<void> setVolume(double volume) async {}
  @override
  Future<void> play(String id, double volume, {required bool loop}) async =>
      events.add('$id:$volume:$loop');
  @override
  Future<void> stop() async => events.add('stop');
  @override
  Future<void> dispose() async {}
}

void main() {
  test('静音、音量和循环响铃正确传给播放器', () async {
    final backend = FakeSound();
    final c = SoundController(backend: backend);
    c.configure(sound: 'glass', volume: 0.4, muted: false);
    await c.play(loop: true);
    expect(backend.events, ['glass:0.4:true']);
    c.configure(sound: 'wood', volume: 0.8, muted: true);
    await c.play();
    expect(backend.events, ['glass:0.4:true', 'stop']);
  });
  test('配置恢复验证范围，损坏数据保留默认设置', () {
    final c = SoundController(backend: FakeSound());
    c.restore({'sound': 'invalid', 'volume': 2, 'muted': 'bad'});
    expect(c.sound, 'soft-chime');
    expect(c.volume, 0.7);
    expect(c.muted, false);
    c.configure(sound: 'wood', volume: 0.5, muted: true);
    final r = SoundController(backend: FakeSound());
    r.restore(c.snapshot());
    expect(r.sound, 'wood');
    expect(r.volume, 0.5);
    expect(r.muted, true);
  });
}
