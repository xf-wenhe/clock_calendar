# 开源来源

## 已集成：lunar-flutter

- 仓库：https://github.com/6tail/lunar-flutter
- 许可证：MIT，完整许可证见 `third_party/lunar/LICENSE`。
- 固定版本：v1.7.7，commit `2980b99ab97cba0505d78ec16a352d98b025bc5d`。
- 对应关系：上游 `lib/` → `third_party/lunar/lib/`，源码未修改；上游 `pubspec.yaml` → `third_party/lunar/pubspec.yaml`。
- 集成：`lib/utils/chinese_holidays.dart` 调用公历、农历、节日、节气和生肖接口；将“元旦节”显示为“元旦”。应用保守限制显示年份为 1900–2100。
- 选用原因：现有 Dart 3.3 SDK 无法满足上游 v1.7.9 的 Dart 3.5.4 要求。

## 已集成：holiday-cn

- 仓库：https://github.com/NateScarlet/holiday-cn
- 许可证：MIT，完整许可证见 `third_party/holiday-cn/LICENSE`。
- 固定 commit：`a8a8b4e8e960e1934a8b62aad34663a66a53b578`，提交时间 2026-11-12 23:34 UTC。
- 对应关系：上游 `2007.json`–`2027.json` → `assets/holidays/`，文件未修改；`LICENSE` → `third_party/holiday-cn/LICENSE`。
- 集成：`lib/services/holiday_data.dart` 验证和缓存数据；`lib/widgets/calendar_widget.dart` 显示调休标记和更新入口。下载数据来自上游 master，与内置固定版本分别记录更新时间。

## 已集成：tempo-app 秒表

- 仓库：https://github.com/fernandohalim/tempo-app
- 许可证：MIT，完整许可证见 `third_party/tempo/LICENSE`。
- 固定 commit：`5076cf6eb0bbdbe455eb1b3c346411802fd611a6`。
- 上游 `src/core/stopwatch.ts` → `lib/timing/stopwatch_core.dart`：翻译为 Dart 不可变状态；上游 `src/core/stopwatch.test.ts` → `test/stopwatch_core_test.dart`：移植状态与边界测试。
- `lib/timing/stopwatch_controller.dart` 使用与倒计时一致的 Windows `GetTickCount64` 单调时间源（微软 Windows Time 文档明确：该源包含睡眠/休眠时间），规则为“休眠期间继续累计，应用完全退出后清零，切页/迷你模式不停止”，界面按需刷新。时间源可注入，`test/stopwatch_core_test.dart` 用 8 小时时间跳变覆盖休眠恢复、暂停冻结；真实 Windows 休眠实机验证仍未完成（标注“未验证”）。

## 已集成：tempo-app 倒计时

- 同一仓库及 commit `5076cf6eb0bbdbe455eb1b3c346411802fd611a6`，MIT 许可证见 `third_party/tempo/LICENSE`。
- 上游 `src/core/timer.ts` → `lib/timing/countdown_core.dart`；上游 `src/core/timer.test.ts` → `test/countdown_core_test.dart`，移植状态转换及到期边界测试。
- 集成时将上游秒级暂停改为毫秒精度；Windows 使用 `GetTickCount64` 作为目标时间基准，避免系统时钟修改影响计时。`lib/timing/countdown_controller.dart` 管理运行状态，`lib/services/countdown_store.dart` 保存快照，重启后恢复为暂停，使用最近一次保存的剩余时长。
- 界面：`lib/widgets/countdown_view.dart`；快捷预设编辑和本地持久化为本项目集成代码。

## 已集成：tempo-app 闹钟调度

- 同一仓库及 commit `5076cf6eb0bbdbe455eb1b3c346411802fd611a6`，MIT 许可证见 `third_party/tempo/LICENSE`。
- 上游 `src/core/alarm.ts` → `lib/timing/alarm_core.dart`；上游 `src/core/alarm.test.ts` → `test/alarm_core_test.dart`，移植下一次触发及五分钟漏响宽限规则。
- `lib/timing/alarm_controller.dart` 新增多个提醒排队、九分钟贪睡和数据序列化；使用 Dart 星期编号 1–7。`lib/widgets/alarm_view.dart` 集成编辑界面。
- 程序完全退出或关机后不会响铃；系统级调度尚未实现。

## 已集成：pomodoro-focus 番茄钟引擎

- 仓库：https://github.com/SergeyShastin/pomodoro-focus
- 许可证：MIT，完整许可证见 `third_party/pomodoro-focus/LICENSE`。
- 固定 commit：`9d321d773699a29ed94c1d0f6f1ea3d05ed4d8c4`。
- `lib/features/timer/domain/pomodoro_engine.dart`、`pomodoro_phase.dart`、`pomodoro_timer_state.dart` → `lib/pomodoro/` 同名文件；调整导入和格式。`lib/core/clock/app_clock.dart` → `lib/pomodoro/app_clock.dart`。`lib/features/settings/domain/settings_state.dart` → `lib/pomodoro/settings_state.dart`，仅保留计时所需设置。
- 上游 `test/unit/timer_engine_test.dart` 的暂停、长休息周期和自动进入场景移植至 `test/pomodoro_engine_test.dart`。
- 上游 `lib/core/updates/timer_update_handoff.dart` → `lib/pomodoro/pomodoro_persistence.dart`，复用状态字段和校验；适配本地文件持久化、旧数据迁移及重启后暂停恢复，不沿用单次更新交接的十分钟有效期。
- 上游应用要求 Dart 3.10 和 Flutter 3.38；本项目仅复用纯 Dart 引擎并适配现有 SDK。用 Windows 单调时间源驱动，运行状态重启后恢复为暂停。

## 已集成：turboc/pomodoro 任务数据结构与 Hive 持久化

- 仓库：https://github.com/turboc/pomodoro，MIT 许可证见 `third_party/turboc-pomodoro/LICENSE`，固定 commit `cceb811f08316a035c4da6507af3dc3c6d72bd6b`。
- 上游 `lib/models/task.dart` → `lib/pomodoro/task_hive.dart` 中 `HivePomodoroTask`（`@HiveType(typeId: 0)`，字段 title/isCompleted/createdAt）与 `lib/pomodoro/pomodoro_controller.dart` 中内存模型 `PomodoroTask`。任务操作界面为本项目集成代码。
- 上游 `lib/adapters/task_adapter.dart` 与生成的 `lib/models/task.g.dart` → `lib/pomodoro/task_hive.dart` 中手写的 `HivePomodoroTaskAdapter`（同样按字段编号读写二进制）。
- 上游 `lib/signals/task_signals.dart` 的 `openBoxes/getAllTasks/add/delete` 调用链 → `TaskHiveStore.open/loadTasks/saveTasks`，使用 Hive box `pomodoro_tasks_v1`。
- **持久化实现复用**：任务已由本地 JSON 改为上游同款 Hive 机制持久化，满足“复用上游状态转换和持久化实现”。状态转换仍来自 pomodoro-focus 引擎。
- 计时器仅手动切换阶段、每秒递减的上游实现未被采用；阶段转换改用上述 pomodoro-focus 引擎。

### Hive 依赖与平台适配

- 上游依赖 Hive `2.2.3`（https://github.com/hivedb/hive，Apache-2.0，完整许可证见 `third_party/hive/LICENSE`），固定 commit `470473ffc1ba39f6c90f31ababe0ee63b76b69fe`（tag `v2.2.3`）。本项目 `pubspec.yaml` 同样固定 `hive: 2.2.3`。
- 兼容性说明：Hive 2.2.3 的 pubspec 声明 `sdk: >=2.12.0 <3.0.0`，但已在本项目 Flutter 3.16.0-8.0.pre / Dart 3.3.0-2.0.dev 下实测通过 `flutter pub get`、`flutter analyze` 以及真实 Hive 读写测试（见 `test/task_hive_test.dart`），故直接复用，无需引入不兼容的新版本或改写为自研存储。
- 本地适配（均为明确记录的修改，非伪装移植）：
  1. 上游 `Task.id` 为 `int`（来自 HiveObject 的 box key 与 Signals 状态）；本项目旧 JSON 任务使用稳定的字符串 id，且选中状态按该 id 引用，故新增 `@HiveField(0) String id` 保留，其余字段编号整体后移一位。
  2. 未引入 `hive_generator`/`build_runner`，按上游字段编号手写 `TypeAdapter`。
  3. 未引入 `hive_flutter`/`path_provider`，改用 `Hive.init(directory)` 指向既有 `LOCALAPPDATA/clock_calendar_app`，避免新增 Windows 原生插件。
  4. JSON 快照 `pomodoro.json` 保留为配置/计时状态/选中状态的向后兼容备份；启动时仅当 Hive 为空才迁移其中的 `tasks`，损坏条目跳过并提示，原 JSON 不改写；迁移失败时回退读取 JSON 数据。
- 覆盖测试：`test/task_hive_test.dart`（保存恢复、快照删除、旧数据迁移、损坏数据跳过且不覆盖、二次迁移不覆盖、重开目录恢复）与 `test/pomodoro_controller_test.dart`（Hive 任务替换时选中状态校正、重复 id 拒绝）。

## 已集成：托盘和显示器插件

- [tray_manager](https://github.com/leanflutter/tray_manager) 0.2.3，MIT，commit `62959f7100e1abba372f6248d656e45633a1eb37`；上游 `lib/src/tray_manager.dart` 和 `windows/` 由包管理器原样提供，`lib/services/app_tray.dart` 为本项目接入。许可证见 `third_party/tray-manager/LICENSE`。
- [menu_base](https://github.com/leanflutter/menu_base) 0.1.1，MIT，tag `v0.1.1` 对应 `55b1863abc3682a19be5b00a177b9a228023bf5d`；作为托盘插件依赖原样使用。许可证见 `third_party/menu-base/LICENSE`。
- [shortid](https://github.com/0xff00ff/shortid) 0.1.2，BSD-3-Clause，tag `v0.1.2` 对应 `73e010785e7c72ab1b43d33fa155381e7f835cda`；作为托盘插件依赖原样使用。许可证见 `third_party/shortid/LICENSE`。
- [screen_retriever](https://github.com/leanflutter/screen_retriever) 0.1.9，MIT，commit `e90de0e1d743ffcd305789ecb5ac1bfa4cf6f7c9`；上游 `lib/src/screen_retriever.dart` 和 `windows/` 由包管理器原样提供，`lib/services/window_bounds.dart` 为本项目适配。许可证见 `third_party/screen-retriever/LICENSE`。
- 以上版本固定于 `pubspec.yaml` / `pubspec.lock`；托盘和显示器插件的主要 Dart 文件已与对应提交比对。

## 已集成：提示音

- [audioplayers](https://github.com/bluefireteam/audioplayers) 5.2.1，MIT，tag `audioplayers-v5.2.1` 对应 commit `8489ac8a492067418b590a37d47303c5dbb16060`；Windows 实现 3.1.0 的 tag 对应 commit `b0bdb8e6e36756475730a64d8439a35cec1e3cc5`。插件由包管理器原样提供；`lib/services/sound_controller.dart` 为本项目接入。许可证见 `third_party/audioplayers/LICENSE`。
- Tempo commit `5076cf6eb0bbdbe455eb1b3c346411802fd611a6` 的 `assets/sounds/*.wav` → `assets/sounds/*.wav`，未修改；音效名称映射来自 `src/core/sounds.ts`。许可证见 `third_party/tempo/LICENSE`。
