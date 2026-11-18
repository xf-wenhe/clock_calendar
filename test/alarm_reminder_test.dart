import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:clock_calendar_app/widgets/alarm_reminder.dart';

void main() {
  testWidgets('提醒按钮返回贪睡或停止，返回键不会关闭', (tester) async {
    bool? result;
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: Builder(
                builder: (context) => TextButton(
                    onPressed: () async {
                      result = await showDialog<bool>(
                          context: context,
                          barrierDismissible: false,
                          builder: (_) =>
                              const AlarmReminder(name: '起床', waiting: 1));
                    },
                    child: const Text('显示'))))));
    await tester.tap(find.text('显示'));
    await tester.pumpAndSettle();
    expect(find.textContaining('起床'), findsOneWidget);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.textContaining('起床'), findsOneWidget);
    await tester.tap(find.text('贪睡 9 分钟'));
    await tester.pumpAndSettle();
    expect(result, true);
    await tester.tap(find.text('显示'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('停止'));
    await tester.pumpAndSettle();
    expect(result, false);
  });
}
