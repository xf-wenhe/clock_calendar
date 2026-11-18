import 'dart:async';
import 'package:flutter/material.dart';
import 'package:window_manager/window_manager.dart';
import '../timing/countdown_controller.dart';
import '../timing/countdown_core.dart';
import '../pomodoro/pomodoro_controller.dart';
import '../pomodoro/pomodoro_phase.dart';

class TimerCapsule extends StatefulWidget {
  const TimerCapsule(
      {super.key,
      required this.countdown,
      required this.onExpand,
      this.pomodoro,
      this.preferPomodoro = false});
  final CountdownController countdown;
  final PomodoroController? pomodoro;
  final bool preferPomodoro;
  final VoidCallback onExpand;
  @override
  State<TimerCapsule> createState() => _TimerCapsuleState();
}

class _TimerCapsuleState extends State<TimerCapsule> {
  Timer? _timer;
  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(milliseconds: 250), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  String _format(int ms) {
    final n = (ms + 999) ~/ 1000;
    final h = n ~/ 3600, m = (n ~/ 60) % 60, s = n % 60;
    return h > 0
        ? '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}'
        : '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.pomodoro, usePomo = widget.preferPomodoro && p != null;
    final running = usePomo
        ? p.state.isRunning
        : widget.countdown.state.status == CountdownStatus.running;
    final title = usePomo
        ? (p.state.phase == PomodoroPhase.work
            ? '专注'
            : p.state.phase == PomodoroPhase.shortBreak
                ? '短休息'
                : '长休息')
        : '倒计时';
    final value =
        usePomo ? p.state.formattedTime : _format(widget.countdown.remainingMs);
    final progress = usePomo
        ? p.state.progress
        : widget.countdown.state.progress(widget.countdown.state.endsAt == null
            ? 0
            : widget.countdown.state.endsAt! - widget.countdown.remainingMs);
    void toggle() {
      if (usePomo) {
        if (running) {
          p.pause();
        } else {
          p.start();
        }
      } else {
        if (running) {
          widget.countdown.pause();
        } else if (widget.countdown.state.status == CountdownStatus.paused) {
          widget.countdown.resume();
        } else {
          widget.countdown.start();
        }
      }
      setState(() {});
    }

    return Material(
        color: const Color(0xF0202638),
        borderRadius: BorderRadius.circular(18),
        child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            child: Row(children: [
              Expanded(
                  child: DragToMoveArea(
                      child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                    Text(title, maxLines: 1, overflow: TextOverflow.ellipsis),
                    Text(value,
                        style: const TextStyle(
                            fontSize: 22,
                            fontFamily: 'Cascadia Mono',
                            fontWeight: FontWeight.bold)),
                    LinearProgressIndicator(value: progress)
                  ]))),
              IconButton(
                  tooltip: running ? '暂停' : '继续',
                  onPressed: toggle,
                  icon: Icon(running
                      ? Icons.pause_rounded
                      : Icons.play_arrow_rounded)),
              IconButton(
                  tooltip: '展开',
                  onPressed: widget.onExpand,
                  icon: const Icon(Icons.open_in_full_rounded)),
            ])));
  }
}
