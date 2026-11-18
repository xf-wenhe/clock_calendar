import 'dart:async';
import 'package:tray_manager/tray_manager.dart' as tray;

class AppTray with tray.TrayListener {
  AppTray({required this.onAction, void Function()? showMenu})
      : _showMenu = showMenu ??
            (() {
              unawaited(tray.trayManager.popUpContextMenu());
            });
  final void Function(String) onAction;
  final void Function() _showMenu;
  bool _ready = false;
  static tray.Menu buildMenu({required bool alwaysOnTop}) => tray.Menu(items: [
        tray.MenuItem(key: 'clock', label: '时钟日历'),
        tray.MenuItem(key: 'pomodoro', label: '番茄钟'),
        tray.MenuItem(key: 'countdown', label: '倒计时'),
        tray.MenuItem(key: 'stopwatch', label: '秒表'),
        tray.MenuItem(key: 'alarm', label: '闹钟'),
        tray.MenuItem.separator(),
        tray.MenuItem(key: 'mini', label: '迷你模式'),
        tray.MenuItem.checkbox(key: 'top', label: '窗口置顶', checked: alwaysOnTop),
        tray.MenuItem(key: 'settings', label: '设置'),
        tray.MenuItem.separator(),
        tray.MenuItem(key: 'exit', label: '彻底退出'),
      ]);
  Future<void> initialize({required bool alwaysOnTop}) async {
    tray.trayManager.addListener(this);
    try {
      await tray.trayManager.setIcon('assets/tray/app_icon.ico');
      await tray.trayManager.setToolTip('时钟与日历');
      await tray.trayManager
          .setContextMenu(buildMenu(alwaysOnTop: alwaysOnTop));
      _ready = true;
    } catch (_) {
      tray.trayManager.removeListener(this);
      rethrow;
    }
  }

  Future<void> updateMenu({required bool alwaysOnTop}) async {
    if (_ready) {
      await tray.trayManager
          .setContextMenu(buildMenu(alwaysOnTop: alwaysOnTop));
    }
  }

  Future<void> dispose() async {
    if (!_ready) return;
    _ready = false;
    tray.trayManager.removeListener(this);
    await tray.trayManager.destroy();
  }

  @override
  void onTrayIconMouseDown() => onAction('toggle');
  @override
  void onTrayIconRightMouseDown() => _showMenu();
  @override
  void onTrayMenuItemClick(tray.MenuItem menuItem) {
    final key = menuItem.key;
    if (key != null) onAction(key);
  }
}
