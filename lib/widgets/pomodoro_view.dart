import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../pomodoro/pomodoro_controller.dart';
import '../pomodoro/pomodoro_phase.dart';
import '../pomodoro/settings_state.dart';

class PomodoroView extends StatefulWidget {
  const PomodoroView(
      {super.key, required this.controller, this.persistenceNotice});
  final PomodoroController controller;
  final String? persistenceNotice;
  @override
  State<PomodoroView> createState() => _PomodoroViewState();
}

class _PomodoroViewState extends State<PomodoroView> {
  final _task = TextEditingController();
  @override
  void dispose() {
    _task.dispose();
    super.dispose();
  }

  Future<void> _rename(PomodoroTask task) async {
    final text = TextEditingController(text: task.title);
    final route = DialogRoute<void>(
        context: context,
        builder: (ctx) => AlertDialog(
                title: const Text('编辑任务'),
                content: TextField(
                    controller: text,
                    autofocus: true,
                    maxLength: 80,
                    decoration: const InputDecoration(labelText: '任务名称')),
                actions: [
                  TextButton(
                      onPressed: () => Navigator.pop(ctx),
                      child: const Text('取消')),
                  FilledButton(
                      onPressed: () {
                        widget.controller.renameTask(task.id, text.text);
                        Navigator.pop(ctx);
                      },
                      child: const Text('保存'))
                ]));
    await Navigator.of(context).push(route);
    await route.completed;
    text.dispose();
  }

  Future<void> _settings() async {
    final c = widget.controller, cfg = c.settings;
    final work = TextEditingController(text: '${cfg.workDurationMinutes}'),
        short = TextEditingController(text: '${cfg.shortBreakDurationMinutes}'),
        long = TextEditingController(text: '${cfg.longBreakDurationMinutes}'),
        interval =
            TextEditingController(text: '${cfg.sessionsBeforeLongBreak}');
    var auto = cfg.autoStartBreaks && cfg.autoStartPomodoros;
    String? error;
    Widget field(String label, TextEditingController t) => TextField(
        controller: t,
        keyboardType: TextInputType.number,
        inputFormatters: [
          FilteringTextInputFormatter.digitsOnly,
          LengthLimitingTextInputFormatter(4)
        ],
        decoration: InputDecoration(labelText: label));
    final route = DialogRoute<void>(
        context: context,
        builder: (ctx) => StatefulBuilder(
            builder: (context, update) => AlertDialog(
                    title: const Text('番茄钟设置'),
                    content: SizedBox(
                        width: 360,
                        child: SingleChildScrollView(
                            child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                              field('专注时长（分钟）', work),
                              field('短休息（分钟）', short),
                              field('长休息（分钟）', long),
                              field('长休息间隔（次）', interval),
                              SwitchListTile(
                                  title: const Text('自动进入下一阶段'),
                                  value: auto,
                                  onChanged: (v) => update(() => auto = v)),
                              if (error != null)
                                Text(error!,
                                    style: const TextStyle(
                                        color: Colors.orangeAccent))
                            ]))),
                    actions: [
                      TextButton(
                          onPressed: () => Navigator.pop(ctx),
                          child: const Text('取消')),
                      FilledButton(
                          onPressed: () {
                            final w = int.tryParse(work.text),
                                s = int.tryParse(short.text),
                                l = int.tryParse(long.text),
                                i = int.tryParse(interval.text);
                            if (w == null ||
                                s == null ||
                                l == null ||
                                i == null ||
                                w < 1 ||
                                w > 1440 ||
                                s < 1 ||
                                s > 1440 ||
                                l < 1 ||
                                l > 1440 ||
                                i < 1 ||
                                i > 20) {
                              update(
                                  () => error = '时长范围 1–1440 分钟，间隔范围 1–20 次');
                              return;
                            }
                            c.configure(SettingsState(
                                workDurationMinutes: w,
                                shortBreakDurationMinutes: s,
                                longBreakDurationMinutes: l,
                                sessionsBeforeLongBreak: i,
                                autoStartBreaks: auto,
                                autoStartPomodoros: auto));
                            Navigator.pop(ctx);
                          },
                          child: const Text('保存'))
                    ])));
    await Navigator.of(context).push(route);
    await route.completed;
    work.dispose();
    short.dispose();
    long.dispose();
    interval.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
      animation: widget.controller,
      builder: (context, _) {
        final c = widget.controller, state = c.state;
        final phase = state.phase == PomodoroPhase.work
            ? '专注'
            : state.phase == PomodoroPhase.shortBreak
                ? '短休息'
                : '长休息';
        return Center(
            child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 720),
                child: SingleChildScrollView(
                    padding: const EdgeInsets.all(20),
                    child: Column(children: [
                      Row(children: [
                        const Expanded(
                            child: Text('番茄钟',
                                style: TextStyle(
                                    fontSize: 28,
                                    fontWeight: FontWeight.bold))),
                        IconButton(
                            tooltip: '番茄钟设置',
                            onPressed: _settings,
                            icon: const Icon(Icons.settings_outlined))
                      ]),
                      Text(phase, style: const TextStyle(fontSize: 20)),
                      const SizedBox(height: 8),
                      FittedBox(
                          child: Text(state.formattedTime,
                              style: const TextStyle(
                                  fontSize: 56, fontFamily: 'Cascadia Mono'))),
                      LinearProgressIndicator(value: state.progress),
                      const SizedBox(height: 12),
                      Text(
                          '本轮已完成 ${state.completedPomodorosInCycle} / ${c.settings.sessionsBeforeLongBreak} 次'),
                      Wrap(
                          alignment: WrapAlignment.center,
                          spacing: 10,
                          children: [
                            FilledButton(
                                onPressed: state.isRunning ? c.pause : c.start,
                                child: Text(state.isRunning
                                    ? '暂停'
                                    : state.isPaused
                                        ? '继续'
                                        : '开始')),
                            OutlinedButton(
                                onPressed: c.reset, child: const Text('重置'))
                          ]),
                      const SizedBox(height: 8),
                      const Text('应用退出后恢复为暂停状态，使用最近一次保存值。'),
                      if (widget.persistenceNotice != null)
                        Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: Text(widget.persistenceNotice!,
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                    color: Colors.amberAccent, fontSize: 12))),
                      const Divider(height: 30),
                      Row(children: [
                        Expanded(
                            child: TextField(
                                controller: _task,
                                maxLength: 80,
                                decoration: const InputDecoration(
                                    labelText: '新任务', counterText: ''),
                                onSubmitted: (_) {
                                  c.addTask(_task.text);
                                  _task.clear();
                                })),
                        IconButton(
                            tooltip: '新增任务',
                            onPressed: () {
                              c.addTask(_task.text);
                              _task.clear();
                            },
                            icon: const Icon(Icons.add_circle_outline))
                      ]),
                      if (c.selectedTaskId != null)
                        TextButton(
                            onPressed: () => c.selectTask(null),
                            child: const Text('取消当前任务')),
                      if (c.tasks.isEmpty)
                        const Padding(
                            padding: EdgeInsets.all(16), child: Text('暂无任务')),
                      for (final task in c.tasks)
                        ListTile(
                            contentPadding: EdgeInsets.zero,
                            leading: Checkbox(
                                value: task.completed,
                                onChanged: (v) =>
                                    c.setTaskCompleted(task.id, v ?? false)),
                            title: Text(task.title,
                                style: TextStyle(
                                    decoration: task.completed
                                        ? TextDecoration.lineThrough
                                        : null,
                                    color: c.selectedTaskId == task.id
                                        ? Theme.of(context).colorScheme.primary
                                        : null)),
                            onTap: () => c.selectTask(task.id),
                            trailing: Wrap(children: [
                              IconButton(
                                  tooltip: '编辑任务',
                                  onPressed: () => _rename(task),
                                  icon: const Icon(Icons.edit_outlined)),
                              IconButton(
                                  tooltip: '删除任务',
                                  onPressed: () => c.deleteTask(task.id),
                                  icon: const Icon(Icons.delete_outline))
                            ])),
                    ]))));
      });
}
