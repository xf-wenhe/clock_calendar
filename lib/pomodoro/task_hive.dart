// Task persistence adapted from turboc/pomodoro (MIT) lib/models/task.dart,
// lib/adapters/task_adapter.dart and lib/signals/task_signals.dart, using the
// upstream Hive 2.2.3 persistence mechanism (Apache-2.0).
// Upstream: https://github.com/turboc/pomodoro @ cceb811f08316a035c4da6507af3dc3c6d72bd6b
// Hive: https://github.com/hivedb/hive @ 470473ffc1ba39f6c90f31ababe0ee63b76b69fe (v2.2.3)
// Licenses: third_party/turboc-pomodoro/LICENSE, third_party/hive/LICENSE.
//
// Local adaptations (documented in OPEN_SOURCE.md):
//  * Upstream Task uses an int id derived from the HiveObject box key. This
//    project's JSON tasks already use stable string ids referenced by the
//    selected-task state, so field 3 keeps that string id.
//  * No hive_generator/build_runner: the TypeAdapter is written by hand with
//    the same field numbering as the upstream @HiveType(typeId: 0) model.
//  * No hive_flutter/path_provider: Hive.init(directory) is given the existing
//    LOCALAPPDATA/clock_calendar_app directory so Windows needs no new plugin.
//  * Tasks are authoritative in Hive; the JSON snapshot is kept as a
//    backward-compatible backup and still carries settings/state/selection.
import 'dart:io';

import 'package:hive/hive.dart';

import 'pomodoro_controller.dart' show PomodoroTask;

const int _taskTypeId = 0;
const String _boxName = 'pomodoro_tasks_v1';

@HiveType(typeId: _taskTypeId)
class HivePomodoroTask extends HiveObject {
  HivePomodoroTask({
    required this.id,
    required this.title,
    required this.completed,
    required this.createdAt,
  });

  // Field numbering 1/2/3 matches upstream task.dart
  // (@HiveField(0) title, (1) isCompleted, (2) createdAt), shifted by one to
  // make room for the locally required stable string id at field 0.
  @HiveField(0)
  String id;
  @HiveField(1)
  String title;
  @HiveField(2)
  bool completed;
  @HiveField(3)
  DateTime createdAt;

  PomodoroTask toTask() => PomodoroTask(
        id: id,
        title: title,
        completed: completed,
        createdAt: createdAt,
      );

  static HivePomodoroTask fromTask(PomodoroTask task) => HivePomodoroTask(
        id: task.id,
        title: task.title,
        completed: task.completed,
        createdAt: task.createdAt,
      );
}

/// Hand-written counterpart of the upstream generated TaskAdapter.
class HivePomodoroTaskAdapter extends TypeAdapter<HivePomodoroTask> {
  @override
  final int typeId = _taskTypeId;

  @override
  HivePomodoroTask read(BinaryReader reader) {
    final count = reader.readByte();
    final fields = <int, dynamic>{
      for (var i = 0; i < count; i++) reader.readByte(): reader.read(),
    };
    final id = fields[0] as String?;
    final title = fields[1] as String?;
    final completed = fields[2] as bool?;
    final createdAt = fields[3] as DateTime?;
    if (id == null || id.isEmpty || title == null || title.trim().isEmpty) {
      throw const FormatException('损坏的 Hive 任务字段');
    }
    return HivePomodoroTask(
      id: id,
      title: title,
      completed: completed ?? false,
      createdAt: createdAt ?? DateTime.fromMillisecondsSinceEpoch(0),
    );
  }

  @override
  void write(BinaryWriter writer, HivePomodoroTask obj) {
    writer
      ..writeByte(4)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.title)
      ..writeByte(2)
      ..write(obj.completed)
      ..writeByte(3)
      ..write(obj.createdAt);
  }
}

class MigrationResult {
  const MigrationResult({
    this.migrated = 0,
    this.failed = 0,
    this.skipped = false,
  });
  final int migrated;
  final int failed;
  final bool skipped;
  bool get hasCorrupt => failed > 0;
}

/// Task-only Hive store. Mirrors the upstream call chain
/// (registerAdapter -> openBox -> get/add/delete) with a serialised write queue
/// so application shutdown can flush before disposal.
class TaskHiveStore {
  TaskHiveStore(this.directory);

  final String directory;
  Box<HivePomodoroTask>? _box;
  Future<void> _pending = Future.value();

  bool get isOpen => _box?.isOpen ?? false;
  int get count => _box?.length ?? 0;

  Future<void> open() async {
    if (isOpen) return;
    final dir = Directory(directory);
    if (!dir.existsSync()) dir.createSync(recursive: true);
    Hive.init(directory);
    if (!Hive.isAdapterRegistered(_taskTypeId)) {
      Hive.registerAdapter(HivePomodoroTaskAdapter());
    }
    _box = await Hive.openBox<HivePomodoroTask>(_boxName);
  }

  List<PomodoroTask> loadTasks() {
    final box = _box;
    if (box == null || !box.isOpen) return const [];
    final result = <PomodoroTask>[];
    for (final task in box.values) {
      try {
        result.add(task.toTask());
      } catch (_) {
        // A single corrupt row must not discard the rest.
      }
    }
    return result;
  }

  /// Migrates rows from the legacy JSON `tasks` array into Hive.
  /// Only runs when the box is empty, never overwrites existing data, and
  /// keeps the original JSON file untouched on any failure.
  MigrationResult migrateFromLegacy(List<dynamic>? rows) {
    final box = _box;
    if (box == null || !box.isOpen || rows == null || rows.isEmpty) {
      return const MigrationResult(skipped: true);
    }
    if (box.isNotEmpty) return const MigrationResult(skipped: true);

    var migrated = 0, failed = 0;
    final seen = <String>{};
    for (final row in rows) {
      try {
        if (row is! Map) {
          failed++;
          continue;
        }
        final id = row['id'];
        final title = row['title'];
        final completed = row['completed'];
        final createdRaw = row['createdAt'];
        if (id is! String ||
            id.isEmpty ||
            !seen.add(id) ||
            title is! String ||
            title.trim().isEmpty ||
            completed is! bool ||
            createdRaw is! String) {
          failed++;
          continue;
        }
        final created = DateTime.tryParse(createdRaw);
        if (created == null) {
          failed++;
          continue;
        }
        box.put(
            id,
            HivePomodoroTask(
                id: id,
                title: title,
                completed: completed,
                createdAt: created));
        migrated++;
      } catch (_) {
        failed++;
      }
    }
    return MigrationResult(migrated: migrated, failed: failed);
  }

  /// Serialised, snapshot-style write of the full task list.
  void saveTasks(List<PomodoroTask> tasks) {
    final snapshot = tasks.map(HivePomodoroTask.fromTask).toList();
    _pending = _pending.then((_) async {
      final box = _box;
      if (box == null || !box.isOpen) return;
      final wanted = snapshot.map((t) => t.id).toSet();
      for (final key in box.keys.toList()) {
        if (!wanted.contains(key)) await box.delete(key);
      }
      for (final task in snapshot) {
        await box.put(task.id, task);
      }
    }).catchError((_) {});
  }

  Future<void> flush() => _pending;

  Future<void> close() async {
    await _pending;
    final box = _box;
    _box = null;
    if (box != null && box.isOpen) await box.close();
  }
}
