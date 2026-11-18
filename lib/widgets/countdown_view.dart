import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../timing/countdown_controller.dart';
import '../timing/countdown_core.dart';

class CountdownView extends StatefulWidget {
  const CountdownView({super.key, required this.controller});
  final CountdownController controller;
  @override
  State<CountdownView> createState() => _CountdownViewState();
}

class _CountdownViewState extends State<CountdownView> {
  Timer? _ticker;
  final _hours = TextEditingController(text: '0');
  final _minutes = TextEditingController(text: '25');
  final _seconds = TextEditingController(text: '0');
  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_changed);
    _syncTicker();
  }

  void _changed() {
    _syncTicker();
    if (mounted) setState(() {});
  }

  void _syncTicker() {
    if (widget.controller.state.status == CountdownStatus.running) {
      _ticker ??= Timer.periodic(const Duration(milliseconds: 200), (_) {
        if (mounted) setState(() {});
      });
    } else {
      _ticker?.cancel();
      _ticker = null;
    }
  }

  @override
  void dispose() {
    _ticker?.cancel();
    widget.controller.removeListener(_changed);
    _hours.dispose();
    _minutes.dispose();
    _seconds.dispose();
    super.dispose();
  }

  String _format(int ms) {
    final n = (ms + 999) ~/ 1000;
    return '${(n ~/ 3600).toString().padLeft(2, '0')}:${((n ~/ 60) % 60).toString().padLeft(2, '0')}:${(n % 60).toString().padLeft(2, '0')}';
  }

  void _apply() {
    final h = int.tryParse(_hours.text) ?? 0,
        m = int.tryParse(_minutes.text) ?? 0,
        s = int.tryParse(_seconds.text) ?? 0;
    if (h < 0 ||
        h > 23 ||
        m < 0 ||
        m > 59 ||
        s < 0 ||
        s > 59 ||
        h + m + s == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('请输入 00:00:01 至 23:59:59 的时长')));
      return;
    }
    widget.controller.setDuration((h * 3600 + m * 60 + s) * 1000);
  }

  Future<void> _editPresets() async {
    final fields = [
      for (final n in widget.controller.presets)
        TextEditingController(text: '$n')
    ];
    String? error;
    final route = DialogRoute<void>(
        context: context,
        builder: (dialogContext) => StatefulBuilder(
            builder: (context, refresh) => AlertDialog(
                  title: const Text('编辑快捷预设'),
                  content: SizedBox(
                      width: 320,
                      child: Column(mainAxisSize: MainAxisSize.min, children: [
                        for (var i = 0; i < fields.length; i++)
                          TextField(
                            controller: fields[i],
                            keyboardType: TextInputType.number,
                            inputFormatters: [
                              FilteringTextInputFormatter.digitsOnly,
                              LengthLimitingTextInputFormatter(4)
                            ],
                            decoration:
                                InputDecoration(labelText: '预设 ${i + 1}（分钟）'),
                          ),
                        if (error != null)
                          Text(error!,
                              style:
                                  const TextStyle(color: Colors.orangeAccent)),
                      ])),
                  actions: [
                    TextButton(
                        onPressed: () => Navigator.pop(dialogContext),
                        child: const Text('取消')),
                    FilledButton(
                        onPressed: () {
                          final values = fields
                              .map((f) => int.tryParse(f.text) ?? 0)
                              .toList();
                          if (values.any((v) => v < 1 || v > 1439)) {
                            refresh(() => error = '预设范围为 1–1439 分钟');
                            return;
                          }
                          widget.controller.setPresets(values);
                          Navigator.pop(dialogContext);
                        },
                        child: const Text('保存')),
                  ],
                )));
    await Navigator.of(context).push(route);
    await route.completed;
    for (final field in fields) {
      field.dispose();
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.controller;
    final running = c.state.status == CountdownStatus.running,
        paused = c.state.status == CountdownStatus.paused;
    final editable = !running && !paused;
    Widget field(String label, TextEditingController value) => SizedBox(
        width: 85,
        child: TextField(
            controller: value,
            enabled: editable,
            keyboardType: TextInputType.number,
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
              LengthLimitingTextInputFormatter(2)
            ],
            decoration: InputDecoration(labelText: label)));
    return Center(
        child: SingleChildScrollView(
            child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 600),
                child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(children: [
                      const Text('倒计时',
                          style: TextStyle(
                              fontSize: 28, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 20),
                      FittedBox(
                          child: Text(_format(c.remainingMs),
                              style: const TextStyle(
                                  fontFamily: 'Cascadia Mono', fontSize: 56))),
                      const SizedBox(height: 12),
                      LinearProgressIndicator(
                          value: c.state.progress(c.state.endsAt == null
                              ? 0
                              : c.state.endsAt! - c.remainingMs)),
                      if (c.state.status == CountdownStatus.completed)
                        const Padding(
                            padding: EdgeInsets.all(12),
                            child: Text('时间到',
                                style: TextStyle(
                                    fontSize: 24, color: Colors.amber))),
                      const SizedBox(height: 20),
                      Wrap(
                          alignment: WrapAlignment.center,
                          spacing: 8,
                          children: [
                            for (final n in c.presets)
                              OutlinedButton(
                                  onPressed: editable
                                      ? () => c.setDuration(n * 60000)
                                      : null,
                                  child: Text('$n 分钟')),
                            IconButton(
                                tooltip: '编辑预设',
                                onPressed: _editPresets,
                                icon: const Icon(Icons.edit_outlined)),
                          ]),
                      const SizedBox(height: 12),
                      Wrap(
                          alignment: WrapAlignment.center,
                          spacing: 8,
                          children: [
                            field('时', _hours),
                            field('分', _minutes),
                            field('秒', _seconds),
                            TextButton(
                                onPressed: editable ? _apply : null,
                                child: const Text('设置时长'))
                          ]),
                      const SizedBox(height: 20),
                      Wrap(
                          alignment: WrapAlignment.center,
                          spacing: 12,
                          children: [
                            FilledButton(
                                onPressed: running
                                    ? c.pause
                                    : paused
                                        ? c.resume
                                        : c.start,
                                child: Text(running
                                    ? '暂停'
                                    : paused
                                        ? '继续'
                                        : '开始')),
                            OutlinedButton(
                                onPressed: c.reset, child: const Text('重置')),
                          ]),
                      const SizedBox(height: 18),
                      const Text('关闭应用后恢复为暂停状态，剩余时间取最近一次保存值。',
                          textAlign: TextAlign.center),
                    ])))));
  }
}
