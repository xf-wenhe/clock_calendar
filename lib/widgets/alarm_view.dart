import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../timing/alarm_controller.dart';
import '../timing/alarm_core.dart';

class AlarmView extends StatelessWidget {
  const AlarmView({super.key, required this.controller});
  final AlarmController controller;

  String _repeat(AlarmRule rule) {
    if (rule.repeat == AlarmRepeat.once) return '单次';
    if (rule.repeat == AlarmRepeat.daily) return '每天';
    const names = ['一', '二', '三', '四', '五', '六', '日'];
    return [
      for (var d = 1; d <= 7; d++)
        if (rule.weekdays.contains(d)) '周${names[d - 1]}'
    ].join('、');
  }

  Future<void> _edit(BuildContext context, [AlarmEntry? alarm]) async {
    final name = TextEditingController(text: alarm?.name ?? '');
    final hours = TextEditingController(
        text: '${alarm?.rule.hour ?? TimeOfDay.now().hour}');
    final minutes = TextEditingController(
        text: '${alarm?.rule.minute ?? TimeOfDay.now().minute}');
    String? error;
    var repeat = alarm?.rule.repeat ?? AlarmRepeat.once;
    final days = <int>{...?alarm?.rule.weekdays};
    final route = DialogRoute<void>(
        context: context,
        builder: (dialogContext) => StatefulBuilder(
            builder: (context, setDialogState) => AlertDialog(
                  title: Text(alarm == null ? '新建闹钟' : '编辑闹钟'),
                  content: SizedBox(
                      width: 420,
                      child: SingleChildScrollView(
                          child: Column(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                            TextField(
                                controller: name,
                                maxLength: 40,
                                decoration:
                                    const InputDecoration(labelText: '名称')),
                            Row(children: [
                              Expanded(
                                  child: TextField(
                                      controller: hours,
                                      keyboardType: TextInputType.number,
                                      inputFormatters: [
                                        FilteringTextInputFormatter.digitsOnly,
                                        LengthLimitingTextInputFormatter(2)
                                      ],
                                      decoration: const InputDecoration(
                                          labelText: '时'))),
                              const SizedBox(width: 16),
                              Expanded(
                                  child: TextField(
                                      controller: minutes,
                                      keyboardType: TextInputType.number,
                                      inputFormatters: [
                                        FilteringTextInputFormatter.digitsOnly,
                                        LengthLimitingTextInputFormatter(2)
                                      ],
                                      decoration: const InputDecoration(
                                          labelText: '分'))),
                            ]),
                            if (error != null)
                              Text(error!,
                                  style: const TextStyle(
                                      color: Colors.orangeAccent)),
                            DropdownButton<AlarmRepeat>(
                                value: repeat,
                                isExpanded: true,
                                items: const [
                                  DropdownMenuItem(
                                      value: AlarmRepeat.once,
                                      child: Text('单次')),
                                  DropdownMenuItem(
                                      value: AlarmRepeat.daily,
                                      child: Text('每天')),
                                  DropdownMenuItem(
                                      value: AlarmRepeat.weekdays,
                                      child: Text('指定星期'))
                                ],
                                onChanged: (v) {
                                  if (v != null) {
                                    setDialogState(() => repeat = v);
                                  }
                                }),
                            if (repeat == AlarmRepeat.weekdays)
                              Wrap(spacing: 4, children: [
                                for (var d = 1; d <= 7; d++)
                                  FilterChip(
                                      label: Text('周${[
                                        '一',
                                        '二',
                                        '三',
                                        '四',
                                        '五',
                                        '六',
                                        '日'
                                      ][d - 1]}'),
                                      selected: days.contains(d),
                                      onSelected: (selected) =>
                                          setDialogState(() {
                                            if (selected) {
                                              days.add(d);
                                            } else {
                                              days.remove(d);
                                            }
                                          }))
                              ]),
                            if (repeat == AlarmRepeat.weekdays && days.isEmpty)
                              const Text('请至少选择一天',
                                  style: TextStyle(color: Colors.orangeAccent)),
                          ]))),
                  actions: [
                    TextButton(
                        onPressed: () => Navigator.pop(dialogContext),
                        child: const Text('取消')),
                    FilledButton(
                        onPressed: repeat == AlarmRepeat.weekdays &&
                                days.isEmpty
                            ? null
                            : () {
                                final hour = int.tryParse(hours.text);
                                final minute = int.tryParse(minutes.text);
                                if (hour == null ||
                                    minute == null ||
                                    hour > 23 ||
                                    minute > 59) {
                                  setDialogState(
                                      () => error = '时间须在 00:00 至 23:59 之间');
                                  return;
                                }
                                final rule = AlarmRule(
                                    hour: hour,
                                    minute: minute,
                                    repeat: repeat,
                                    weekdays: days);
                                if (alarm == null) {
                                  controller.add(name.text, rule);
                                } else {
                                  controller.update(alarm.id, name.text, rule);
                                }
                                Navigator.pop(dialogContext);
                              },
                        child: const Text('保存'))
                  ],
                )));
    await Navigator.of(context).push(route);
    await route.completed;
    name.dispose();
    hours.dispose();
    minutes.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
      animation: controller,
      builder: (context, _) => Center(
          child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 720),
              child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(children: [
                    Row(children: [
                      const Expanded(
                          child: Text('闹钟',
                              style: TextStyle(
                                  fontSize: 28, fontWeight: FontWeight.bold))),
                      FilledButton.icon(
                          onPressed: () => _edit(context),
                          icon: const Icon(Icons.add),
                          label: const Text('新建闹钟'))
                    ]),
                    const SizedBox(height: 8),
                    const Text('应用完全退出或电脑关机时不会响铃。恢复后仅提醒 5 分钟内漏响的闹钟。'),
                    const SizedBox(height: 8),
                    Expanded(
                        child: controller.alarms.isEmpty
                            ? const Center(child: Text('暂无闹钟'))
                            : ListView.builder(
                                itemCount: controller.alarms.length,
                                itemBuilder: (context, index) {
                                  final a = controller.alarms[index];
                                  final time =
                                      '${a.rule.hour.toString().padLeft(2, '0')}:${a.rule.minute.toString().padLeft(2, '0')}';
                                  return Card(
                                      child: ListTile(
                                          title: Text('${a.name}  $time'),
                                          subtitle: Text(_repeat(a.rule)),
                                          leading: Switch(
                                              value: a.enabled,
                                              onChanged: (v) => controller
                                                  .setEnabled(a.id, v)),
                                          trailing: Wrap(children: [
                                            IconButton(
                                                tooltip: '编辑',
                                                onPressed: () =>
                                                    _edit(context, a),
                                                icon: const Icon(
                                                    Icons.edit_outlined)),
                                            IconButton(
                                                tooltip: '删除',
                                                onPressed: () =>
                                                    controller.delete(a.id),
                                                icon: const Icon(
                                                    Icons.delete_outline))
                                          ])));
                                })),
                  ])))));
}
