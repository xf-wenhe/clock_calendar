import 'package:clock_calendar_app/main.dart';
import 'package:clock_calendar_app/widgets/clock_widget.dart';
import 'package:clock_calendar_app/widgets/calendar_widget.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';

void main() {
  testWidgets('窗口设置包含声音选择、静音和音量', (tester) async {
    tester.view.physicalSize = const Size(1440, 900);
    tester.view.devicePixelRatio = 1;
    await tester.pumpWidget(const ClockCalendarApp());
    await tester.tap(find.byTooltip('窗口设置'));
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text('静音'), findsOneWidget);
    expect(find.text('提示音'), findsOneWidget);
    expect(find.byType(Slider), findsOneWidget);
  });
  testWidgets('可以打开番茄钟并返回日历', (tester) async {
    tester.view.physicalSize = const Size(1440, 900);
    tester.view.devicePixelRatio = 1;
    await tester.pumpWidget(const ClockCalendarApp());
    await tester.tap(find.byTooltip('番茄钟'));
    await tester.pump();
    expect(find.widgetWithText(TextField, '新任务'), findsOneWidget);
    await tester.tap(find.byTooltip('时钟日历'));
    await tester.pump();
    expect(find.byType(CalendarWidget), findsOneWidget);
  });
  testWidgets('可以打开闹钟并返回日历', (tester) async {
    tester.view.physicalSize = const Size(1440, 900);
    tester.view.devicePixelRatio = 1;
    await tester.pumpWidget(const ClockCalendarApp());
    await tester.tap(find.byTooltip('闹钟'));
    await tester.pump();
    expect(find.text('新建闹钟'), findsOneWidget);
    await tester.tap(find.byTooltip('时钟日历'));
    await tester.pump();
    expect(find.byType(CalendarWidget), findsOneWidget);
  });
  testWidgets('可以打开倒计时并返回日历', (tester) async {
    tester.view.physicalSize = const Size(1440, 900);
    tester.view.devicePixelRatio = 1;
    await tester.pumpWidget(const ClockCalendarApp());
    await tester.tap(find.byTooltip('倒计时'));
    await tester.pump();
    expect(find.text('倒计时'), findsOneWidget);
    await tester.tap(find.byTooltip('时钟日历'));
    await tester.pump();
    expect(find.byType(CalendarWidget), findsOneWidget);
  });
  testWidgets('可以在时钟日历和秒表之间切换', (tester) async {
    tester.view.physicalSize = const Size(1440, 900);
    tester.view.devicePixelRatio = 1;
    await tester.pumpWidget(const ClockCalendarApp());
    await tester.tap(find.byTooltip('秒表'));
    await tester.pump();
    expect(find.text('开始'), findsOneWidget);
    await tester.tap(find.byTooltip('时钟日历'));
    await tester.pump();
    expect(find.byType(CalendarWidget), findsOneWidget);
  });
  testWidgets('App loads and shows clock and calendar',
      (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1440, 900);
    tester.view.devicePixelRatio = 1.0;

    await tester.pumpWidget(const ClockCalendarApp());

    expect(find.byType(ClockWidget), findsOneWidget);
    expect(find.byType(CalendarWidget), findsOneWidget);
  });

  testWidgets('Layout scales down on small desktop width',
      (WidgetTester tester) async {
    tester.view.physicalSize = const Size(420, 780);
    tester.view.devicePixelRatio = 1.0;

    await tester.pumpWidget(const ClockCalendarApp());
    await tester.pump(const Duration(seconds: 1));

    expect(find.byType(ClockWidget), findsOneWidget);
    expect(find.byType(CalendarWidget), findsOneWidget);
  });
}
