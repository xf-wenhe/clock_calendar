import 'package:flutter/material.dart';

class AlarmReminder extends StatelessWidget {
  const AlarmReminder({super.key, required this.name, required this.waiting});
  final String name;
  final int waiting;
  @override
  Widget build(BuildContext context) => PopScope(
        canPop: false,
        child: AlertDialog(
          title: const Text('闹钟'),
          content: Text('$name\n还有 $waiting 个待处理提醒'),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('贪睡 9 分钟')),
            FilledButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('停止')),
          ],
        ),
      );
}
