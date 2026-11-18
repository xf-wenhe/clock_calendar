import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:clock_calendar_app/pomodoro/pomodoro_controller.dart';
import 'package:clock_calendar_app/pomodoro/task_hive.dart';

void main() {
  late Directory dir;
  late TaskHiveStore store;

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('task-hive-test-');
    store = TaskHiveStore(dir.path);
    await store.open();
  });

  tearDown(() async {
    await store.close();
    if (dir.existsSync()) dir.deleteSync(recursive: true);
  });

  test('保存与恢复任务、完成状态和创建时间', () async {
    final created = DateTime(2026, 1, 2, 3, 4);
    store.saveTasks([
      PomodoroTask(id: 'a', title: '写作', completed: false, createdAt: created),
      PomodoroTask(
          id: 'b',
          title: '读书',
          completed: true,
          createdAt: created.add(const Duration(hours: 1))),
    ]);
    await store.flush();
    final loaded = store.loadTasks();
    expect(loaded.length, 2);
    final a = loaded.firstWhere((t) => t.id == 'a');
    expect(a.title, '写作');
    expect(a.completed, false);
    expect(a.createdAt, created);
    expect(loaded.firstWhere((t) => t.id == 'b').completed, true);
  });

  test('删除任务后另存快照不会残留旧记录', () async {
    store.saveTasks([
      PomodoroTask(
          id: 'a', title: '写作', completed: false, createdAt: DateTime(2026)),
      PomodoroTask(
          id: 'b', title: '读书', completed: false, createdAt: DateTime(2026)),
    ]);
    await store.flush();
    store.saveTasks([
      PomodoroTask(
          id: 'b', title: '读书', completed: true, createdAt: DateTime(2026)),
    ]);
    await store.flush();
    final loaded = store.loadTasks();
    expect(loaded.length, 1);
    expect(loaded.single.id, 'b');
    expect(loaded.single.completed, true);
  });

  test('旧 JSON 任务迁移到 Hive，并保留选中任务所需 id', () async {
    final legacy = [
      {
        'id': 'legacy-1',
        'title': '旧任务',
        'completed': true,
        'createdAt': '2025-12-31T10:00:00.000'
      }
    ];
    final result = store.migrateFromLegacy(legacy);
    expect(result.migrated, 1);
    expect(result.hasCorrupt, false);
    final loaded = store.loadTasks();
    expect(loaded.single.id, 'legacy-1');
    expect(loaded.single.title, '旧任务');
    expect(loaded.single.completed, true);
  });

  test('损坏的旧任务被跳过，有效任务仍迁移且不覆盖原 JSON', () async {
    final legacy = [
      {
        'id': 'ok',
        'title': '有效',
        'completed': false,
        'createdAt': '2026-01-01T00:00:00.000'
      },
      {
        'id': 'bad',
        'title': '',
        'completed': false,
        'createdAt': '2026-01-01T00:00:00.000'
      },
      {
        'id': 'bad2',
        'title': '坏日期',
        'completed': false,
        'createdAt': 'not-a-date'
      },
      'garbage',
    ];
    final result = store.migrateFromLegacy(legacy);
    expect(result.migrated, 1);
    expect(result.failed, 3);
    expect(result.hasCorrupt, true);
    expect(store.loadTasks().single.id, 'ok');
    // 传入的 legacy 列表未被修改，调用方可原样保留 JSON 文件。
    expect(legacy.length, 4);
  });

  test('已有 Hive 数据时二次迁移被跳过，不覆盖现有任务', () async {
    store.saveTasks([
      PomodoroTask(
          id: 'new', title: '现有任务', completed: false, createdAt: DateTime(2026))
    ]);
    await store.flush();
    final result = store.migrateFromLegacy([
      {
        'id': 'old',
        'title': '旧任务',
        'completed': false,
        'createdAt': '2025-01-01T00:00:00.000'
      }
    ]);
    expect(result.skipped, true);
    expect(result.migrated, 0);
    expect(store.loadTasks().map((t) => t.id), ['new']);
  });

  test('重新打开同一目录后任务仍可恢复', () async {
    store.saveTasks([
      PomodoroTask(
          id: 'persist',
          title: '持久化',
          completed: true,
          createdAt: DateTime(2026))
    ]);
    await store.flush();
    await store.close();
    final reopened = TaskHiveStore(dir.path);
    await reopened.open();
    addTearDown(() => reopened.close());
    expect(reopened.loadTasks().single.title, '持久化');
  });
}
