import 'package:flutter_test/flutter_test.dart';
import 'package:clock_calendar_app/services/app_tray.dart';

void main() {
  test('托盘菜单包含全部页面和窗口操作', () {
    final menu = AppTray.buildMenu(alwaysOnTop: true);
    final keys =
        menu.items!.map((item) => item.key).whereType<String>().toList();
    expect(keys, [
      'clock',
      'pomodoro',
      'countdown',
      'stopwatch',
      'alarm',
      'mini',
      'top',
      'settings',
      'exit'
    ]);
    expect(menu.getMenuItem('top')!.checked, true);
  });
  test('左右键与菜单选择派发对应操作', () {
    final actions = <String>[];
    final tray =
        AppTray(onAction: actions.add, showMenu: () => actions.add('menu'));
    tray.onTrayIconMouseDown();
    tray.onTrayIconRightMouseDown();
    tray.onTrayMenuItemClick(
        AppTray.buildMenu(alwaysOnTop: false).getMenuItem('alarm')!);
    expect(actions, ['toggle', 'menu', 'alarm']);
  });
}
