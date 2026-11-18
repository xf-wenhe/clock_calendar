import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:clock_calendar_app/widgets/calendar_widget.dart';

void main() {
  testWidgets('切换月份后可返回今天', (tester) async {
    tester.view.physicalSize = const Size(1200, 900);
    tester.view.devicePixelRatio = 1;
    await tester.pumpWidget(const MaterialApp(
        home: Scaffold(body: CalendarWidget(autoUpdate: false))));
    final now = DateTime.now();
    await tester.tap(find.byTooltip('上个月'));
    await tester.pump();
    final previous = DateTime(now.year, now.month - 1);
    expect(find.text('${previous.year}年${previous.month}月'), findsOneWidget);
    await tester.tap(find.byTooltip('返回今天'));
    await tester.pump();
    expect(find.text('${now.year}年${now.month}月'), findsOneWidget);
  });
}
