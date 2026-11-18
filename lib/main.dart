import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart'
    show LicenseRegistry, LicenseEntryWithLineBreaks;
import 'package:flutter/services.dart' show rootBundle;
import 'package:window_manager/window_manager.dart';
import 'package:screen_retriever/screen_retriever.dart';

import 'widgets/clock_widget.dart';
import 'widgets/calendar_widget.dart';
import 'widgets/stopwatch_view.dart';
import 'timing/stopwatch_controller.dart';
import 'timing/countdown_controller.dart';
import 'services/countdown_store.dart';
import 'widgets/countdown_view.dart';
import 'timing/alarm_controller.dart';
import 'widgets/alarm_view.dart';
import 'widgets/alarm_reminder.dart';
import 'pomodoro/pomodoro_controller.dart';
import 'pomodoro/task_hive.dart';
import 'widgets/pomodoro_view.dart';
import 'widgets/timer_capsule.dart';
import 'timing/countdown_core.dart';
import 'services/app_tray.dart';
import 'services/window_bounds.dart';
import 'services/window_preferences.dart';
import 'services/display_topology.dart';
import 'services/sound_controller.dart';
import 'utils/time_format.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  LicenseRegistry.addLicense(() async* {
    const sources = {
      'lunar-flutter': 'third_party/lunar/LICENSE',
      'holiday-cn': 'third_party/holiday-cn/LICENSE',
      'tempo-app': 'third_party/tempo/LICENSE',
      'pomodoro-focus': 'third_party/pomodoro-focus/LICENSE',
      'turboc/pomodoro': 'third_party/turboc-pomodoro/LICENSE',
      'Hive': 'third_party/hive/LICENSE',
      'tray_manager': 'third_party/tray-manager/LICENSE',
      'menu_base': 'third_party/menu-base/LICENSE',
      'shortid': 'third_party/shortid/LICENSE',
      'screen_retriever': 'third_party/screen-retriever/LICENSE',
      'audioplayers': 'third_party/audioplayers/LICENSE',
    };
    for (final entry in sources.entries) {
      yield LicenseEntryWithLineBreaks(
          [entry.key], await rootBundle.loadString(entry.value));
    }
  });
  await windowManager.ensureInitialized();
  runApp(const ClockCalendarApp());
}

class ClockCalendarApp extends StatelessWidget {
  const ClockCalendarApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '精致深色表盘',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        colorSchemeSeed: const Color(0xFF7C83FF),
        scaffoldBackgroundColor: const Color(0xFF0F111A),
      ),
      // 桌面端默认会给可滚动视图画滚动条；本应用内容都按可用空间自适应铺满，
      // 不需要滚动条，统一关掉更干净。
      scrollBehavior:
          const MaterialScrollBehavior().copyWith(scrollbars: false),
      home: const _AppShell(),
    );
  }
}

/// 顶层外壳：负责「完整界面」与「迷你挂件」两种形态，并监听窗口尺寸自动切换。
class _AppShell extends StatefulWidget {
  const _AppShell();

  @override
  State<_AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<_AppShell>
    with WindowListener, SingleTickerProviderStateMixin
    implements ScreenListener {
  bool _isMini = false;
  bool _isCapsule = false;
  bool _capsulePomodoro = false;
  bool _autoCapsule = false;
  bool _holidayAutoUpdate = true;
  bool _lastCountdownRunning = false;
  bool _lastPomodoroRunning = false;
  bool _showStopwatch = false;
  bool _showCountdown = false;
  bool _showAlarm = false;
  bool _showPomodoro = false;
  bool _pomodoroChanged = false;
  bool _pomodoroDialogOpen = false;
  bool _closeToTray = false;
  bool _alwaysOnTop = false;
  bool _use24Hour = true;
  bool _showSeconds = true;
  bool _trayReady = false;
  bool _windowVisible = true;
  bool _restoringWindow = false;
  bool _switchingWindow = false;
  Rect? _fullBounds;
  Timer? _windowSaveTimer;
  Timer? _displayPollTimer;
  bool _pollingDisplays = false;
  final DisplayTopologyTracker _displayTopology = DisplayTopologyTracker();
  late final AppTray _tray;
  late final CountdownStore _windowStore;
  late final SoundController _sound;
  late final CountdownStore _soundStore;
  bool _soundChanged = false;
  bool _alarmChanged = false;
  bool _alarmDialogOpen = false;
  bool _countdownChanged = false;
  final StopwatchController _stopwatch = StopwatchController();
  late final CountdownController _countdown;
  late final CountdownStore _countdownStore;
  late final AlarmController _alarms;
  late final CountdownStore _alarmStore;
  late final PomodoroController _pomodoro;
  late final CountdownStore _pomodoroStore;
  late final TaskHiveStore _taskHive;
  String? _taskMigrationNotice;
  static const double _miniSize = 260;
  static const double _enterMiniWidth = 380;
  static const double _exitMiniWidth = 470;

  late final AnimationController _enter = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 700),
  )..forward();
  late final Animation<double> _fade =
      CurvedAnimation(parent: _enter, curve: Curves.easeOut);
  late final Animation<double> _scale = Tween<double>(begin: 0.96, end: 1.0)
      .animate(CurvedAnimation(parent: _enter, curve: Curves.easeOutCubic));

  @override
  void initState() {
    super.initState();
    final base =
        Platform.environment['LOCALAPPDATA'] ?? Directory.systemTemp.path;
    _windowStore = CountdownStore(File('$base/clock_calendar_app/window.json'));
    _soundStore = CountdownStore(File('$base/clock_calendar_app/sound.json'));
    _sound = SoundController();
    _sound.addListener(_saveSound);
    _restoreSound();
    _tray = AppTray(onAction: _handleTrayAction);
    _initializeDesktop();
    screenRetriever.addListener(this);
    _displayPollTimer =
        Timer.periodic(const Duration(seconds: 10), (_) => _pollDisplays());
    _countdownStore =
        CountdownStore(File('$base/clock_calendar_app/countdown.json'));
    _alarmStore = CountdownStore(File('$base/clock_calendar_app/alarms.json'));
    _pomodoroStore =
        CountdownStore(File('$base/clock_calendar_app/pomodoro.json'));
    _taskHive = TaskHiveStore('$base/clock_calendar_app');
    _pomodoro = PomodoroController(
        onChanged: (snapshot) {
          _pomodoroChanged = true;
          _pomodoroStore.save(snapshot);
          // Keep tasks in the upstream Hive store as well; the JSON snapshot
          // remains a backward-compatible backup of settings/state/selection.
          final rows = snapshot['tasks'];
          if (rows is List) {
            _taskHive.saveTasks([
              for (final row in rows)
                if (row is Map)
                  PomodoroTask(
                    id: row['id'] as String,
                    title: row['title'] as String,
                    completed: row['completed'] as bool,
                    createdAt: DateTime.parse(row['createdAt'] as String),
                  )
            ]);
          }
        },
        onCompleted: _pomodoroComplete);
    unawaited(_restorePomodoro());
    _alarms = AlarmController(
        onChanged: (snapshot) {
          _alarmChanged = true;
          _alarmStore.save(snapshot);
        },
        onRing: _showAlarmQueue);
    _restoreAlarms();
    _countdown = CountdownController(
        onChanged: (snapshot) {
          _countdownChanged = true;
          _countdownStore.save(snapshot);
        },
        onComplete: _countdownComplete);
    _restoreCountdown();
    _countdown.addListener(_countdownActivityChanged);
    _pomodoro.addListener(_pomodoroActivityChanged);
    windowManager.addListener(this);
  }

  void _countdownActivityChanged() {
    final running = _countdown.state.status == CountdownStatus.running;
    if (running &&
        !_lastCountdownRunning &&
        _autoCapsule &&
        _windowVisible &&
        !_isMini &&
        !_restoringWindow) {
      unawaited(_enterMini(capsule: true));
    }
    _lastCountdownRunning = running;
  }

  void _pomodoroActivityChanged() {
    final running = _pomodoro.state.isRunning;
    if (running &&
        !_lastPomodoroRunning &&
        _autoCapsule &&
        _windowVisible &&
        !_isMini &&
        !_restoringWindow) {
      unawaited(_enterMini(capsule: true, preferPomodoro: true));
    }
    _lastPomodoroRunning = running;
  }

  void _saveSound() {
    _soundChanged = true;
    _soundStore.save(_sound.snapshot());
  }

  Future<void> _restoreSound() async {
    final saved = await _soundStore.load();
    if (mounted && !_soundChanged && saved != null) _sound.restore(saved);
  }

  Future<void> _initializeDesktop() async {
    final saved = await _windowStore.load();
    if (!mounted) return;
    final prefs = WindowPreferences.fromMap(saved ?? {});
    _restoringWindow = true;
    _closeToTray = prefs.closeToTray;
    _alwaysOnTop = prefs.alwaysOnTop;
    _use24Hour = prefs.use24Hour;
    _showSeconds = prefs.showSeconds;
    _autoCapsule = prefs.autoCapsule;
    _holidayAutoUpdate = prefs.holidayAutoUpdate;
    _isCapsule = prefs.mini && prefs.capsule;
    _capsulePomodoro = prefs.capsulePomodoro;
    _fullBounds = prefs.fullBounds;
    try {
      await _tray.initialize(alwaysOnTop: _alwaysOnTop);
      if (!mounted) {
        await _tray.dispose();
        return;
      }
      _trayReady = true;
      await windowManager.setPreventClose(_closeToTray);
      await windowManager.setAlwaysOnTop(_alwaysOnTop || prefs.mini);
      if (prefs.mini) {
        await windowManager.setBackgroundColor(Colors.transparent);
        await windowManager.setAsFrameless();
        await windowManager.setHasShadow(false);
        if (mounted) setState(() => _isMini = true);
      }
      if (prefs.bounds != null) await _setVisibleBounds(prefs.bounds!);
    } catch (_) {
      // Keep normal window closing available if desktop integration is unavailable.
      _trayReady = false;
      try {
        await windowManager.setPreventClose(false);
      } catch (_) {}
    } finally {
      _restoringWindow = false;
      if (mounted) {
        setState(() {});
        unawaited(_pollDisplays());
      }
    }
  }

  Future<void> _setVisibleBounds(Rect bounds) async {
    try {
      final displays = await screenRetriever.getAllDisplays();
      final areas = [
        for (final d in displays)
          if (d.visiblePosition != null && d.visibleSize != null)
            d.visiblePosition! & d.visibleSize!
      ];
      await windowManager.setBounds(keepWindowVisible(bounds, areas));
    } catch (_) {
      await windowManager.setAlignment(Alignment.center);
    }
  }

  Future<void> _pollDisplays() async {
    if (!mounted || _pollingDisplays || _restoringWindow || _switchingWindow) {
      return;
    }
    _pollingDisplays = true;
    try {
      final displays = await screenRetriever.getAllDisplays();
      final changed = _displayTopology.update([
        for (final display in displays)
          '${display.id}:${display.visiblePosition}:${display.visibleSize}:${display.size}:${display.scaleFactor}',
      ]);
      if (changed && mounted) {
        await _setVisibleBounds(await windowManager.getBounds());
      }
    } catch (_) {
      // A failed sample is ignored; the next poll retries.
    } finally {
      _pollingDisplays = false;
    }
  }

  void _scheduleWindowSave() {
    if (_restoringWindow || _switchingWindow) return;
    _windowSaveTimer?.cancel();
    _windowSaveTimer = Timer(const Duration(milliseconds: 500), _saveWindow);
  }

  Future<void> _saveWindow() async {
    try {
      final bounds = await windowManager.getBounds();
      if (!_isMini) _fullBounds = bounds;
      _windowStore.save(WindowPreferences(
              closeToTray: _closeToTray,
              alwaysOnTop: _alwaysOnTop,
              use24Hour: _use24Hour,
              showSeconds: _showSeconds,
              capsule: _isCapsule,
              capsulePomodoro: _capsulePomodoro,
              autoCapsule: _autoCapsule,
              holidayAutoUpdate: _holidayAutoUpdate,
              mini: _isMini,
              bounds: bounds,
              fullBounds: _fullBounds)
          .toMap());
    } catch (_) {}
  }

  @override
  void onWindowMoved() => _scheduleWindowSave();

  @override
  void onWindowResized() => _scheduleWindowSave();

  @override
  void onScreenEvent(String eventName) async {
    if (_restoringWindow || _switchingWindow) return;
    try {
      await _setVisibleBounds(await windowManager.getBounds());
    } catch (_) {}
  }

  @override
  void onWindowClose() async {
    if (_closeToTray && _trayReady) {
      await _saveWindow();
      if (mounted) setState(() => _windowVisible = false);
      await windowManager.hide();
    } else {
      // A real window close must flush pending writes before teardown;
      // otherwise the async stores can lose their last snapshot.
      await _flushAllStores();
      await _tray.dispose();
      await windowManager.setPreventClose(false);
      await windowManager.destroy();
    }
  }

  /// 提醒前确保窗口可见：若隐藏到托盘/最小化则恢复显示，但刻意不调用 focus，
  /// 避免提醒无故抢夺用户当前键盘焦点。
  Future<void> _revealWindowForAlert() async {
    if (_isMini) await _exitMini();
    if (!_windowVisible || !await windowManager.isVisible()) {
      if (mounted) setState(() => _windowVisible = true);
      try {
        if (await windowManager.isMinimized()) await windowManager.restore();
        await windowManager.show();
        // 刻意不调用 focus()：提醒只恢复显示，不抢占用户当前键盘焦点。
      } catch (_) {}
    }
  }

  Future<void> _flushAllStores() async {
    if (_pomodoroChanged) _pomodoroStore.save(_pomodoro.snapshot());
    if (_countdownChanged) _countdownStore.save(_countdown.snapshot());
    if (_alarmChanged) _alarmStore.save(_alarms.snapshot());
    await Future.wait([
      _windowStore.flush(),
      _soundStore.flush(),
      _pomodoroStore.flush(),
      _countdownStore.flush(),
      _alarmStore.flush(),
      _taskHive.flush(),
    ]);
  }

  @override
  void onWindowMinimize() {
    if (mounted) setState(() => _windowVisible = false);
  }

  @override
  void onWindowRestore() {
    if (mounted) setState(() => _windowVisible = true);
  }

  Future<void> _setTop(bool value) async {
    setState(() => _alwaysOnTop = value);
    try {
      await windowManager.setAlwaysOnTop(value || _isMini);
      await _tray.updateMenu(alwaysOnTop: value);
    } catch (_) {}
    await _saveWindow();
  }

  Future<void> _setCloseToTray(bool value) async {
    if (value && !_trayReady) return;
    setState(() => _closeToTray = value);
    try {
      await windowManager.setPreventClose(value);
    } catch (_) {}
    await _saveWindow();
  }

  Future<void> _showWindowSettings() async {
    if (!mounted) return;
    await showDialog<void>(
        context: context,
        builder: (context) => StatefulBuilder(
            builder: (context, refresh) => AlertDialog(
                  title: const Text('设置'),
                  content: SizedBox(
                      width: 400,
                      child: SingleChildScrollView(
                          child:
                              Column(mainAxisSize: MainAxisSize.min, children: [
                        const Text(
                            '启用关闭到托盘后，点击关闭按钮会隐藏窗口，计时和闹钟继续运行。可在托盘菜单选择“彻底退出”。'),
                        SwitchListTile(
                            title: const Text('关闭到托盘'),
                            subtitle: _trayReady ? null : const Text('托盘不可用'),
                            value: _closeToTray,
                            onChanged: _trayReady
                                ? (v) {
                                    _setCloseToTray(v);
                                    refresh(() {});
                                  }
                                : null),
                        SwitchListTile(
                            title: const Text('窗口置顶'),
                            value: _alwaysOnTop,
                            onChanged: (v) {
                              _setTop(v);
                              refresh(() {});
                            }),
                        SwitchListTile(
                            title: const Text('24 小时制'),
                            value: _use24Hour,
                            onChanged: (v) {
                              setState(() => _use24Hour = v);
                              _saveWindow();
                              refresh(() {});
                            }),
                        SwitchListTile(
                            title: const Text('显示秒'),
                            value: _showSeconds,
                            onChanged: (v) {
                              setState(() => _showSeconds = v);
                              _saveWindow();
                              refresh(() {});
                            }),
                        SwitchListTile(
                            title: const Text('开始计时后自动缩为胶囊'),
                            value: _autoCapsule,
                            onChanged: (v) {
                              setState(() => _autoCapsule = v);
                              _saveWindow();
                              refresh(() {});
                            }),
                        SwitchListTile(
                            title: const Text('自动检查调休数据更新'),
                            subtitle: const Text('每 7 天最多检查一次'),
                            value: _holidayAutoUpdate,
                            onChanged: (v) {
                              setState(() => _holidayAutoUpdate = v);
                              _saveWindow();
                              refresh(() {});
                            }),
                        SwitchListTile(
                            title: const Text('静音'),
                            value: _sound.muted,
                            onChanged: (v) {
                              _sound.configure(
                                  sound: _sound.sound,
                                  volume: _sound.volume,
                                  muted: v);
                              refresh(() {});
                            }),
                        Row(children: [
                          const Text('提示音'),
                          const SizedBox(width: 16),
                          Expanded(
                              child: DropdownButton<String>(
                            value: _sound.sound,
                            isExpanded: true,
                            items: [
                              for (final entry
                                  in SoundController.sounds.entries)
                                DropdownMenuItem(
                                    value: entry.key, child: Text(entry.value))
                            ],
                            onChanged: (v) {
                              if (v != null) {
                                _sound.configure(
                                    sound: v,
                                    volume: _sound.volume,
                                    muted: _sound.muted);
                                refresh(() {});
                              }
                            },
                          )),
                          IconButton(
                              tooltip: '试听',
                              onPressed:
                                  _sound.muted ? null : () => _sound.play(),
                              icon: const Icon(Icons.play_arrow)),
                        ]),
                        Row(children: [
                          const Text('音量'),
                          Expanded(
                              child: Slider(
                                  value: _sound.volume,
                                  onChanged: (v) {
                                    _sound.configure(
                                        sound: _sound.sound,
                                        volume: v,
                                        muted: _sound.muted);
                                    refresh(() {});
                                  }))
                        ]),
                        TextButton(
                            onPressed: () => showLicensePage(
                                context: context, applicationName: '时钟与日历'),
                            child: const Text('开源致谢')),
                      ]))),
                  actions: [
                    TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('完成'))
                  ],
                )));
  }

  Future<void> _handleTrayAction(String action) async {
    if (!mounted) return;
    if (action == 'exit') {
      await _saveWindow();
      await _sound.stop(); // 退出时停止循环播放的闹钟铃声。
      await _flushAllStores();
      await _taskHive.close();
      await _tray.dispose();
      await windowManager.setPreventClose(false);
      await windowManager.destroy();
      return;
    }
    if (action == 'toggle') {
      if (await windowManager.isVisible() &&
          !await windowManager.isMinimized()) {
        if (mounted) setState(() => _windowVisible = false);
        await windowManager.hide();
      } else {
        if (mounted) setState(() => _windowVisible = true);
        if (await windowManager.isMinimized()) await windowManager.restore();
        await windowManager.show();
        await windowManager.focus();
      }
      return;
    }
    if (action == 'top') {
      await _setTop(!_alwaysOnTop);
      return;
    }
    if (mounted) setState(() => _windowVisible = true);
    await windowManager.show();
    if (action == 'mini') {
      if (_isMini) {
        await _exitMini();
      } else {
        await _enterMini();
      }
      return;
    }
    if (_isMini) await _exitMini();
    if (!mounted) return;
    if (action == 'settings') {
      await _showWindowSettings();
      return;
    }
    setState(() {
      _showPomodoro = action == 'pomodoro';
      _showCountdown = action == 'countdown';
      _showStopwatch = action == 'stopwatch';
      _showAlarm = action == 'alarm';
    });
  }

  Future<void> _restorePomodoro() async {
    final saved = await _pomodoroStore.load();
    if (!mounted || _pomodoroChanged) return;

    // Restore settings / timer state / selection from the JSON backup first.
    if (saved != null) _pomodoro.restore(saved);

    // Task persistence now comes from the upstream Hive mechanism.
    try {
      await _taskHive.open();
      final legacyRows = saved?['tasks'];
      final result =
          _taskHive.migrateFromLegacy(legacyRows is List ? legacyRows : null);
      final hiveTasks = _taskHive.loadTasks();
      _pomodoro.replaceTasksFromHive(hiveTasks,
          selectedId: saved?['selected'] as String?);
      if (result.hasCorrupt) {
        _taskMigrationNotice =
            '检测到 ${result.failed} 条损坏的旧任务数据，已跳过；原 JSON 数据保留未改动。';
      } else if (result.migrated > 0) {
        _taskMigrationNotice = '已将 ${result.migrated} 条任务迁移到本地持久化。';
      }
    } catch (_) {
      // Hive unavailable: keep the tasks already restored from the JSON backup
      // and tell the user rather than silently losing data.
      _taskMigrationNotice = '任务本地存储不可用，已回退读取 JSON 备份数据。';
    }
    if (mounted) setState(() {});
  }

  Future<void> _pomodoroComplete() async {
    if (!mounted || _pomodoroDialogOpen) return;
    _pomodoroDialogOpen = true;
    unawaited(_sound.play());
    await _revealWindowForAlert();
    if (!mounted) {
      _pomodoroDialogOpen = false;
      return;
    }
    await showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
              title: const Text('番茄钟阶段完成'),
              content: const Text('已进入下一阶段。'),
              actions: [
                TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('知道了'))
              ],
            ));
    _pomodoroDialogOpen = false;
  }

  Future<void> _restoreAlarms() async {
    final saved = await _alarmStore.load();
    if (mounted && !_alarmChanged && saved != null) _alarms.restore(saved);
  }

  Future<void> _showAlarmQueue() async {
    if (_alarmDialogOpen || !mounted) return;
    _alarmDialogOpen = true;
    await _revealWindowForAlert();
    while (mounted && _alarms.queue.isNotEmpty) {
      if (!mounted) break;
      final alarm = _alarms.queue.first;
      unawaited(_sound.play(loop: true));
      final snooze = await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (context) => AlarmReminder(
          name: alarm.name,
          waiting: _alarms.queue.length - 1,
        ),
      );
      await _sound.stop();
      if (!mounted) break;
      if (snooze == true) {
        _alarms.snooze();
      } else {
        _alarms.stop();
      }
    }
    _alarmDialogOpen = false;
  }

  Future<void> _restoreCountdown() async {
    final saved = await _countdownStore.load();
    if (mounted && !_countdownChanged && saved != null) {
      _countdown.restore(saved);
    }
  }

  Future<void> _countdownComplete() async {
    unawaited(_sound.play());
    await _revealWindowForAlert();
    if (!mounted) return;
    showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
              title: const Text('倒计时结束'),
              content: const Text('设定的时间已到。'),
              actions: [
                TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('知道了'))
              ],
            ));
  }

  @override
  void dispose() {
    windowManager.removeListener(this);
    screenRetriever.removeListener(this);
    _windowSaveTimer?.cancel();
    _displayPollTimer?.cancel();
    unawaited(_tray.dispose());
    _sound.removeListener(_saveSound);
    _sound.dispose();
    _countdown.removeListener(_countdownActivityChanged);
    _pomodoro.removeListener(_pomodoroActivityChanged);
    if (_pomodoroChanged) _pomodoroStore.save(_pomodoro.snapshot());
    _pomodoro.dispose();
    unawaited(_taskHive.close());
    if (_alarmChanged) _alarmStore.save(_alarms.snapshot());
    _alarms.dispose();
    if (_countdownChanged) _countdownStore.save(_countdown.snapshot());
    _countdown.dispose();
    _stopwatch.dispose();
    _enter.dispose();
    super.dispose();
  }

  @override
  void onWindowResize() {
    _evaluateSize();
  }

  Future<void> _evaluateSize() async {
    if (_switchingWindow || _restoringWindow) return;
    final size = await windowManager.getSize();
    if (!_isMini && size.width <= _enterMiniWidth) {
      _enterMini();
    } else if (_isMini && size.width >= _exitMiniWidth) {
      _exitMini();
    }
  }

  Future<void> _enterMini(
      {bool capsule = false, bool preferPomodoro = false}) async {
    if (_isMini || _switchingWindow) return;
    _switchingWindow = true;
    try {
      _fullBounds = await windowManager.getBounds();
    } catch (_) {}
    if (!mounted) {
      _switchingWindow = false;
      return;
    }
    try {
      setState(() {
        _isMini = true;
        _isCapsule = capsule;
        _capsulePomodoro = preferPomodoro;
      });
      await windowManager.setBackgroundColor(Colors.transparent);
      await windowManager.setAsFrameless();
      await windowManager.setHasShadow(false);
      await windowManager.setAlwaysOnTop(true);
      await windowManager.setSize(
          capsule ? const Size(360, 100) : const Size(_miniSize, _miniSize));
      await windowManager.setAlignment(Alignment.topRight);
    } finally {
      _switchingWindow = false;
    }
    await _saveWindow();
  }

  Future<void> _exitMini() async {
    if (!_isMini || _switchingWindow) return;
    _switchingWindow = true;
    try {
      setState(() {
        _isMini = false;
        _isCapsule = false;
      });
      await windowManager.setTitleBarStyle(TitleBarStyle.normal);
      await windowManager.setBackgroundColor(Colors.black);
      await windowManager.setAlwaysOnTop(_alwaysOnTop);
      if (_fullBounds != null) {
        await _setVisibleBounds(_fullBounds!);
      } else {
        await windowManager.setSize(const Size(1120, 760));
        await windowManager.setAlignment(Alignment.center);
      }
    } finally {
      _switchingWindow = false;
    }
    await _saveWindow();
  }

  void _toggleMini() {
    if (_isMini) {
      _exitMini();
    } else {
      _enterMini();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_windowVisible) return const SizedBox.shrink();
    final view = _isMini
        ? _isCapsule
            ? TimerCapsule(
                countdown: _countdown,
                pomodoro: _pomodoro,
                preferPomodoro: _capsulePomodoro,
                onExpand: _exitMini)
            : _MiniView(
                onExpand: _toggleMini,
                use24Hour: _use24Hour,
                showSeconds: _showSeconds)
        : _MainView(
            onMini: _toggleMini,
            use24Hour: _use24Hour,
            showSeconds: _showSeconds,
            holidayAutoUpdate: _holidayAutoUpdate,
            showStopwatch: _showStopwatch,
            showCountdown: _showCountdown,
            showAlarm: _showAlarm,
            showPomodoro: _showPomodoro,
            taskMigrationNotice: _taskMigrationNotice,
            stopwatch: _stopwatch,
            countdown: _countdown,
            alarms: _alarms,
            pomodoro: _pomodoro,
            onToggleStopwatch: () => setState(() {
              _showStopwatch = !_showStopwatch;
              _showCountdown = false;
              _showAlarm = false;
              _showPomodoro = false;
            }),
            onToggleCountdown: () => setState(() {
              _showCountdown = !_showCountdown;
              _showStopwatch = false;
              _showAlarm = false;
              _showPomodoro = false;
            }),
            onToggleAlarm: () => setState(() {
              _showAlarm = !_showAlarm;
              _showStopwatch = false;
              _showCountdown = false;
              _showPomodoro = false;
            }),
            onTogglePomodoro: () => setState(() {
              _showPomodoro = !_showPomodoro;
              _showAlarm = false;
              _showStopwatch = false;
              _showCountdown = false;
            }),
            onSettings: _showWindowSettings,
            onCapsule: () {
              final usePomodoro = _showPomodoro ||
                  (!_showCountdown && _pomodoro.state.isRunning);
              setState(() {
                _showPomodoro = usePomodoro;
                _showCountdown = !usePomodoro;
                _showAlarm = false;
                _showStopwatch = false;
              });
              _enterMini(capsule: true, preferPomodoro: usePomodoro);
            },
          );
    return FadeTransition(
      opacity: _fade,
      child: ScaleTransition(scale: _scale, child: view),
    );
  }
}

/// 完整界面：问候顶栏 + 时钟 / 日历（宽屏左右、窄屏上下）。
class _MainView extends StatelessWidget {
  const _MainView(
      {required this.onMini,
      required this.use24Hour,
      required this.showSeconds,
      required this.holidayAutoUpdate,
      required this.showStopwatch,
      required this.showCountdown,
      required this.showAlarm,
      required this.showPomodoro,
      required this.taskMigrationNotice,
      required this.stopwatch,
      required this.countdown,
      required this.alarms,
      required this.pomodoro,
      required this.onToggleStopwatch,
      required this.onToggleCountdown,
      required this.onToggleAlarm,
      required this.onTogglePomodoro,
      required this.onSettings,
      required this.onCapsule});

  final VoidCallback onMini;
  final bool use24Hour;
  final bool showSeconds;
  final bool holidayAutoUpdate;
  final bool showStopwatch;
  final bool showCountdown;
  final bool showAlarm;
  final bool showPomodoro;
  final String? taskMigrationNotice;
  final StopwatchController stopwatch;
  final CountdownController countdown;
  final AlarmController alarms;
  final PomodoroController pomodoro;
  final VoidCallback onToggleStopwatch;
  final VoidCallback onToggleCountdown;
  final VoidCallback onToggleAlarm;
  final VoidCallback onTogglePomodoro;
  final VoidCallback onSettings;
  final VoidCallback onCapsule;

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final isWide = size.width >= 840;
    final colorScheme = Theme.of(context).colorScheme;

    final header = Padding(
      padding: EdgeInsets.fromLTRB(
        isWide ? 40 : 18,
        isWide ? 22 : 14,
        isWide ? 30 : 16,
        0,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const Expanded(child: _GreetingHeader()),
          IconButton(
              tooltip: '计时胶囊',
              onPressed: onCapsule,
              icon: const Icon(Icons.horizontal_rule_rounded)),
          IconButton(
              tooltip: '窗口设置',
              onPressed: onSettings,
              icon: const Icon(Icons.settings_outlined)),
          IconButton(
            icon: Icon(showPomodoro
                ? Icons.calendar_month_rounded
                : Icons.spa_outlined),
            tooltip: showPomodoro ? '时钟日历' : '番茄钟',
            onPressed: onTogglePomodoro,
          ),
          IconButton(
            icon: Icon(
                showAlarm ? Icons.calendar_month_rounded : Icons.alarm_rounded),
            tooltip: showAlarm ? '时钟日历' : '闹钟',
            onPressed: onToggleAlarm,
          ),
          IconButton(
            icon: Icon(showCountdown
                ? Icons.calendar_month_rounded
                : Icons.hourglass_bottom_rounded),
            tooltip: showCountdown ? '时钟日历' : '倒计时',
            onPressed: onToggleCountdown,
          ),
          IconButton(
            icon: Icon(showStopwatch
                ? Icons.calendar_month_rounded
                : Icons.timer_outlined),
            tooltip: showStopwatch ? '时钟日历' : '秒表',
            onPressed: onToggleStopwatch,
          ),
          Material(
            color: Colors.transparent,
            child: IconButton(
              icon: const Icon(Icons.picture_in_picture_alt_rounded),
              tooltip: '迷你模式（缩到右上角固定）',
              color: colorScheme.onSurfaceVariant,
              onPressed: onMini,
            ),
          ),
        ],
      ),
    );

    final clockPanel = Padding(
      padding: EdgeInsets.symmetric(
        horizontal: isWide ? 40 : 18,
        vertical: isWide ? 24 : 12,
      ),
      child: ClockWidget(use24Hour: use24Hour, showSeconds: showSeconds),
    );

    final calendarPanel = Padding(
      padding: EdgeInsets.symmetric(
        horizontal: isWide ? 30 : 16,
        vertical: isWide ? 20 : 10,
      ),
      child: CalendarWidget(autoUpdate: holidayAutoUpdate),
    );

    final Widget body;
    if (isWide) {
      body = Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(flex: 45, child: clockPanel),
          const VerticalDivider(
              width: 1, thickness: 1, indent: 24, endIndent: 24),
          Expanded(flex: 55, child: calendarPanel),
        ],
      );
    } else {
      body = Column(
        children: [
          Expanded(flex: 45, child: clockPanel),
          const Divider(height: 1, thickness: 1),
          Expanded(flex: 55, child: calendarPanel),
        ],
      );
    }

    return Material(
      color: Colors.transparent,
      child: _AuroraBackground(
        child: SafeArea(
          child: Column(
            children: [
              header,
              Expanded(
                  child: showPomodoro
                      ? Scaffold(
                          backgroundColor: Colors.transparent,
                          body: PomodoroView(
                              controller: pomodoro,
                              persistenceNotice: taskMigrationNotice))
                      : showAlarm
                          ? Scaffold(
                              backgroundColor: Colors.transparent,
                              body: AlarmView(controller: alarms))
                          : showCountdown
                              ? Scaffold(
                                  backgroundColor: Colors.transparent,
                                  body: CountdownView(controller: countdown),
                                )
                              : showStopwatch
                                  ? StopwatchView(controller: stopwatch)
                                  : body),
            ],
          ),
        ),
      ),
    );
  }
}

/// 迷你挂件：顶部状态栏、中间表盘、底部日期。窗口会吸附到右上角并置顶。
class _MiniView extends StatefulWidget {
  const _MiniView(
      {required this.onExpand,
      required this.use24Hour,
      required this.showSeconds});

  final VoidCallback onExpand;
  final bool use24Hour;
  final bool showSeconds;

  @override
  State<_MiniView> createState() => _MiniViewState();
}

class _MiniViewState extends State<_MiniView> {
  DateTime _now = DateTime.now();
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() => _now = DateTime.now());
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  String get _formattedTime => formatClock(_now,
      use24Hour: widget.use24Hour, showSeconds: widget.showSeconds);

  @override
  Widget build(BuildContext context) {
    const radius = 24.0;
    final colorScheme = Theme.of(context).colorScheme;

    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      clipBehavior: Clip.antiAliasWithSaveLayer,
      child: Material(
        color: Colors.transparent,
        child: Stack(
          fit: StackFit.expand,
          children: [
            _AuroraBackground(
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.black.withAlpha(64),
                    borderRadius: BorderRadius.circular(radius),
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
              child: Column(
                children: [
                  SizedBox(
                    height: 32,
                    child: Row(
                      children: [
                        Expanded(
                          child: Center(
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: colorScheme.primary.withAlpha(210),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(
                                _formattedTime,
                                style: TextStyle(
                                  fontFamily: 'SF Mono',
                                  fontFamilyFallback: const [
                                    'Cascadia Mono',
                                    'Consolas',
                                    'Roboto Mono',
                                    'monospace',
                                  ],
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                  color: colorScheme.onPrimary,
                                  letterSpacing: 1.2,
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        _MiniActionButton(
                          icon: Icons.close_rounded,
                          tooltip: '关闭迷你时钟',
                          onPressed: () => windowManager.close(),
                        ),
                        const SizedBox(width: 6),
                        _MiniActionButton(
                          icon: Icons.open_in_full_rounded,
                          tooltip: '展开时钟',
                          onPressed: widget.onExpand,
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: DragToMoveArea(
                        child: ClockWidget(
                      showTimeChip: false,
                      showDateChip: false,
                      use24Hour: widget.use24Hour,
                      showSeconds: widget.showSeconds,
                    )),
                  ),
                  const SizedBox(height: 4),
                  _MiniDateChip(now: _now),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MiniActionButton extends StatelessWidget {
  const _MiniActionButton({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white.withAlpha(24),
      shape: const CircleBorder(),
      clipBehavior: Clip.antiAlias,
      child: SizedBox.square(
        dimension: 30,
        child: IconButton(
          icon: Icon(icon),
          tooltip: tooltip,
          iconSize: 16,
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints.tightFor(width: 30, height: 30),
          color: Colors.white.withAlpha(225),
          onPressed: onPressed,
        ),
      ),
    );
  }
}

class _MiniDateChip extends StatelessWidget {
  const _MiniDateChip({required this.now});

  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final weekdays = ['周一', '周二', '周三', '周四', '周五', '周六', '周日'];
    final text = '${now.month}/${now.day} ${weekdays[now.weekday - 1]}';
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
      decoration: BoxDecoration(
        color: colorScheme.surface.withAlpha(150),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: colorScheme.outlineVariant.withAlpha(60),
          width: 1,
        ),
      ),
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: colorScheme.onSurface,
        ),
      ),
    );
  }
}

class _GreetingHeader extends StatefulWidget {
  const _GreetingHeader();

  @override
  State<_GreetingHeader> createState() => _GreetingHeaderState();
}

class _GreetingHeaderState extends State<_GreetingHeader> {
  late DateTime _now = DateTime.now();
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(minutes: 1), (_) {
      if (mounted) setState(() => _now = DateTime.now());
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final hour = _now.hour;
    final greet = hour < 6
        ? '凌晨好'
        : hour < 12
            ? '早上好'
            : hour < 14
                ? '中午好'
                : hour < 18
                    ? '下午好'
                    : '晚上好';
    final weekdays = ['周一', '周二', '周三', '周四', '周五', '周六', '周日'];
    final date =
        '${_now.year}年${_now.month}月${_now.day}日  ${weekdays[_now.weekday - 1]}';
    final colorScheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          greet,
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w800,
            color: colorScheme.onSurface,
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          date,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

/// 流动极光背景：深色底 + 三团缓慢漂移的柔光，给界面「活」起来的质感。
class _AuroraBackground extends StatefulWidget {
  const _AuroraBackground({required this.child});

  final Widget child;

  @override
  State<_AuroraBackground> createState() => _AuroraBackgroundState();
}

class _AuroraBackgroundState extends State<_AuroraBackground>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 18),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        return Stack(
          children: [
            Container(
              decoration: const BoxDecoration(
                gradient: RadialGradient(
                  center: Alignment.topCenter,
                  radius: 1.35,
                  colors: [Color(0xFF161B2B), Color(0xFF0F111A)],
                ),
              ),
            ),
            Positioned.fill(
              child: CustomPaint(painter: _AuroraPainter(_controller.value)),
            ),
            widget.child,
          ],
        );
      },
    );
  }
}

class _AuroraPainter extends CustomPainter {
  _AuroraPainter(this.t);

  final double t;

  static const _blobs = [
    _Blob(
        color: Color(0xFF7C83FF),
        baseX: 0.22,
        baseY: 0.24,
        r: 0.52,
        dx: 0.12,
        dy: 0.06,
        alpha: 38),
    _Blob(
        color: Color(0xFF3BE8C7),
        baseX: 0.82,
        baseY: 0.72,
        r: 0.46,
        dx: -0.1,
        dy: -0.08,
        alpha: 30),
    _Blob(
        color: Color(0xFFFF7B9C),
        baseX: 0.72,
        baseY: 0.18,
        r: 0.34,
        dx: -0.08,
        dy: 0.1,
        alpha: 22),
  ];

  @override
  void paint(Canvas canvas, Size size) {
    final phase = t * math.pi * 2;
    for (final b in _blobs) {
      final cx =
          (b.baseX + b.dx * math.sin(phase)).clamp(0.0, 1.0) * size.width;
      final cy =
          (b.baseY + b.dy * math.cos(phase)).clamp(0.0, 1.0) * size.height;
      final radius = b.r * math.max(size.width, size.height);
      final paint = Paint()
        ..color = b.color.withAlpha(b.alpha)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 90);
      canvas.drawCircle(Offset(cx, cy), radius, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _AuroraPainter old) => old.t != t;
}

class _Blob {
  const _Blob({
    required this.color,
    required this.baseX,
    required this.baseY,
    required this.r,
    required this.dx,
    required this.dy,
    required this.alpha,
  });

  final Color color;
  final double baseX;
  final double baseY;
  final double r;
  final double dx;
  final double dy;
  final int alpha;
}
