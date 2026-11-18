import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:clock_calendar_app/services/countdown_store.dart';

void main() {
  test('倒计时状态按顺序保存并恢复', () async {
    final dir = await Directory.systemTemp.createTemp('countdown-test-');
    addTearDown(() => dir.delete(recursive: true));
    final store = CountdownStore(File('${dir.path}/timer.json'));
    store.save({'durationMs': 3000, 'remainingMs': 2000, 'status': 'paused'});
    store.save({'durationMs': 3000, 'remainingMs': 1000, 'status': 'paused'});
    await store.flush();
    expect((await store.load())?['remainingMs'], 1000);
  });
  test('损坏文件安全回退', () async {
    final dir = await Directory.systemTemp.createTemp('countdown-test-');
    addTearDown(() => dir.delete(recursive: true));
    final file = File('${dir.path}/timer.json');
    await file.writeAsString('{bad');
    expect(await CountdownStore(file).load(), isNull);
  });
}
