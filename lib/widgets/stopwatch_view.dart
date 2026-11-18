import 'dart:async';
import 'dart:ui' show FontFeature;
import 'package:flutter/material.dart';
import '../timing/stopwatch_controller.dart';
import '../timing/stopwatch_core.dart';

class StopwatchView extends StatefulWidget {
  const StopwatchView({super.key, required this.controller});
  final StopwatchController controller;
  @override
  State<StopwatchView> createState() => _StopwatchViewState();
}

class _StopwatchViewState extends State<StopwatchView> {
  Timer? _ticker;
  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onChanged);
    _syncTicker();
  }

  void _onChanged() {
    _syncTicker();
    if (mounted) setState(() {});
  }

  void _syncTicker() {
    if (widget.controller.state.status == StopwatchStatus.running) {
      _ticker ??= Timer.periodic(const Duration(milliseconds: 50), (_) {
        if (mounted) setState(() {});
      });
    } else {
      _ticker?.cancel();
      _ticker = null;
    }
  }

  @override
  void didUpdateWidget(covariant StopwatchView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_onChanged);
      widget.controller.addListener(_onChanged);
      _syncTicker();
    }
  }

  @override
  void dispose() {
    _ticker?.cancel();
    widget.controller.removeListener(_onChanged);
    super.dispose();
  }

  String _format(int ms) {
    final hours = ms ~/ 3600000;
    final minutes = (ms ~/ 60000) % 60;
    final seconds = (ms ~/ 1000) % 60;
    final hundredths = (ms ~/ 10) % 100;
    return '${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}.${hundredths.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.controller;
    final running = c.state.status == StopwatchStatus.running;
    final idle = c.state.status == StopwatchStatus.idle;
    final durations = c.state.lapDurations;
    return Center(
        child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 620),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(children: [
                const Text('秒表',
                    style:
                        TextStyle(fontSize: 28, fontWeight: FontWeight.bold)),
                const SizedBox(height: 24),
                FittedBox(
                    child: Text(_format(c.elapsedMs),
                        style: const TextStyle(
                            fontFamily: 'Cascadia Mono',
                            fontSize: 56,
                            fontFeatures: [FontFeature.tabularFigures()]))),
                const SizedBox(height: 24),
                Wrap(
                    alignment: WrapAlignment.center,
                    spacing: 12,
                    runSpacing: 8,
                    children: [
                      FilledButton(
                          onPressed: running ? c.pause : c.start,
                          child: Text(running
                              ? '暂停'
                              : idle
                                  ? '开始'
                                  : '继续')),
                      OutlinedButton(
                          onPressed: idle ? null : c.lap,
                          child: const Text('计圈')),
                      OutlinedButton(
                          onPressed: idle ? null : c.reset,
                          child: const Text('重置')),
                    ]),
                const SizedBox(height: 16),
                const Text(
                    '规则：使用 Windows 单调时钟计时，电脑休眠期间继续累计；'
                    '应用完全退出后清零，切换页面或迷你模式不停止。',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 12)),
                const SizedBox(height: 12),
                Expanded(
                    child: ListView.builder(
                        itemCount: c.state.laps.length,
                        itemBuilder: (context, index) {
                          final i = c.state.laps.length - index - 1;
                          return ListTile(
                              dense: true,
                              title: Text('第 ${i + 1} 圈'),
                              subtitle: Text('单圈 ${_format(durations[i])}'),
                              trailing: Text('累计 ${_format(c.state.laps[i])}'));
                        })),
              ]),
            )));
  }
}
