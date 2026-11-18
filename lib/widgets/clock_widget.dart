import 'dart:math' as math;
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import '../utils/time_format.dart';

class ClockWidget extends StatefulWidget {
  const ClockWidget({
    super.key,
    this.showTimeChip = true,
    this.showDateChip = true,
    this.use24Hour = true,
    this.showSeconds = true,
  });

  final bool showTimeChip;
  final bool showDateChip;
  final bool use24Hour;
  final bool showSeconds;

  @override
  State<ClockWidget> createState() => _ClockWidgetState();
}

class _ClockWidgetState extends State<ClockWidget>
    with SingleTickerProviderStateMixin {
  DateTime _now = DateTime.now();
  Timer? _tickTimer;
  late final Ticker _pulseTicker;
  double _pulseValue = 0.0;

  @override
  void initState() {
    super.initState();
    _pulseTicker = createTicker(_tickPulse)..start();
    _startTickTimer();
  }

  @override
  void dispose() {
    _tickTimer?.cancel();
    _pulseTicker.dispose();
    super.dispose();
  }

  void _tickPulse(Duration elapsed) {
    final seconds = elapsed.inMilliseconds / 1000.0;
    final pulse = (math.sin(seconds * math.pi) + 1.0) / 2.0;
    if (_pulseValue != pulse) {
      setState(() {
        _pulseValue = pulse;
      });
    }
  }

  void _startTickTimer() {
    _tickTimer?.cancel();
    _tickTimer = Timer(const Duration(seconds: 1), _tick);
  }

  void _tick() {
    if (!mounted) return;
    setState(() {
      _now = DateTime.now();
    });
    _startTickTimer();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return LayoutBuilder(
      builder: (context, constraints) {
        final size = Size(
          math.min(constraints.maxWidth, constraints.maxHeight),
          math.min(constraints.maxHeight, constraints.maxWidth),
        );
        final diameter = math.min(size.width, size.height);
        final scale = math.min(diameter / 520, 1.0);
        final hasChips = widget.showTimeChip || widget.showDateChip;
        final outerPadding = math
            .max(diameter * (hasChips ? 0.032 : 0.018), hasChips ? 10 : 4)
            .toDouble();
        final dialEdgePadding = math
            .max(diameter * (hasChips ? 0.018 : 0.008), hasChips ? 9 : 3)
            .toDouble();
        final dialWidth = math
            .max(
              diameter - outerPadding * 2 - dialEdgePadding * 2,
              0,
            )
            .toDouble();
        final chipHeight = math.max(outerPadding * 0.85, 36).toDouble();

        return Padding(
          padding: EdgeInsets.all(outerPadding),
          child: Stack(
            alignment: AlignmentDirectional.center,
            children: [
              Center(
                child: Container(
                  width: dialWidth,
                  height: dialWidth,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        colorScheme.primary.withAlpha(235),
                        colorScheme.primary.withAlpha(165),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: colorScheme.primary.withAlpha(110),
                      width: 1.4,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: colorScheme.primary.withAlpha(60),
                        blurRadius: 32,
                        offset: const Offset(0, 18),
                      ),
                    ],
                  ),
                  child: CustomPaint(
                    painter: _ClockPainter(
                      colorScheme: colorScheme,
                      now: _now,
                      pulseValue: _pulseValue,
                      radius: (dialWidth / 2).toDouble(),
                      showSeconds: widget.showSeconds,
                    ),
                  ),
                ),
              ),
              if (widget.showTimeChip)
                Positioned(
                  top: 0,
                  left: dialEdgePadding,
                  right: dialEdgePadding,
                  child: _TimeChip(
                    now: _now,
                    colorScheme: colorScheme,
                    height: chipHeight,
                    scale: scale,
                    use24Hour: widget.use24Hour,
                    showSeconds: widget.showSeconds,
                  ),
                ),
              if (widget.showDateChip)
                Positioned(
                  bottom: 0,
                  left: dialEdgePadding,
                  right: dialEdgePadding,
                  child: _DateChip(
                    now: _now,
                    colorScheme: colorScheme,
                    height: chipHeight,
                    scale: scale,
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  static String _formatDate(DateTime now) {
    const weekdays = ['周一', '周二', '周三', '周四', '周五', '周六', '周日'];
    return '${now.month}月${now.day}日  ${weekdays[now.weekday - 1]}';
  }
}

class _TimeChip extends StatelessWidget {
  const _TimeChip({
    required this.now,
    required this.colorScheme,
    required this.height,
    required this.scale,
    required this.use24Hour,
    required this.showSeconds,
  });

  final DateTime now;
  final ColorScheme colorScheme;
  final double height;
  final double scale;
  final bool use24Hour;
  final bool showSeconds;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      height: height,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            colorScheme.primary,
            colorScheme.primary.withAlpha(195),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(height / 2),
        border: Border.all(
          color: colorScheme.primary.withAlpha(110),
          width: 1.1,
        ),
        boxShadow: [
          BoxShadow(
            color: colorScheme.primary.withAlpha(44),
            blurRadius: 22,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Center(
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Padding(
            padding:
                EdgeInsets.symmetric(horizontal: math.max(height * 0.12, 16)),
            child: Text(
              formatClock(now, use24Hour: use24Hour, showSeconds: showSeconds),
              style: TextStyle(
                fontFamily: 'SF Mono',
                fontFamilyFallback: const [
                  'Cascadia Mono',
                  'Consolas',
                  'JetBrains Mono',
                  'Roboto Mono',
                  'monospace',
                ],
                fontSize: height * 0.42,
                fontWeight: FontWeight.w700,
                color: colorScheme.onPrimary,
                letterSpacing: math.max(2.4 * scale, 1.4),
                height: 1.15,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _DateChip extends StatelessWidget {
  const _DateChip({
    required this.now,
    required this.colorScheme,
    required this.height,
    required this.scale,
  });

  final DateTime now;
  final ColorScheme colorScheme;
  final double height;
  final double scale;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      height: height,
      decoration: BoxDecoration(
        color: const Color(0xFF252A3B).withAlpha(120),
        borderRadius: BorderRadius.circular(height / 2),
        border: Border.all(
          color: colorScheme.outlineVariant.withAlpha(110),
          width: 1,
        ),
      ),
      child: Center(
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Padding(
            padding:
                EdgeInsets.symmetric(horizontal: math.max(height * 0.13, 14)),
            child: DefaultTextStyle(
              style: TextStyle(
                fontFamily: 'SF Compact Display',
                fontFamilyFallback: const [
                  'SF Pro Text',
                  'Noto Sans SC',
                  'PingFang SC',
                  'Microsoft YaHei',
                  'Segoe UI',
                  'sans-serif',
                ],
                fontSize: height * 0.37,
                fontWeight: FontWeight.w600,
                color: colorScheme.onSurfaceVariant,
                letterSpacing: math.max(0.6 * scale, 0.2),
                height: 1.25,
              ),
              child: Text(_ClockWidgetState._formatDate(now)),
            ),
          ),
        ),
      ),
    );
  }
}

class _ClockPainter extends CustomPainter {
  _ClockPainter({
    required this.colorScheme,
    required this.now,
    required this.pulseValue,
    required this.radius,
    required this.showSeconds,
  });

  final ColorScheme colorScheme;
  final DateTime now;
  final double pulseValue;
  final double radius;
  final bool showSeconds;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final safeRadius = math.max(radius, 20).toDouble();

    final bgPaint = Paint()
      ..shader = const RadialGradient(
        colors: [
          Color(0xFF242A3F),
          Color(0xFF1A1F2E),
        ],
        center: Alignment.topLeft,
        radius: 1.05,
      ).createShader(Rect.fromCircle(center: center, radius: safeRadius))
      ..style = PaintingStyle.fill;
    canvas.drawCircle(center, safeRadius, bgPaint);

    _drawTicks(canvas, center, safeRadius);

    _drawHours(canvas, center, safeRadius);

    _drawHands(canvas, center, safeRadius);

    final glowPaint = Paint()
      ..color = colorScheme.primary.withAlpha((28 + 48 * pulseValue).toInt())
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 22);
    canvas.drawCircle(center, safeRadius * 0.16, glowPaint);
  }

  void _drawTicks(Canvas canvas, Offset center, double safeRadius) {
    final tickPaint = Paint()
      ..color = colorScheme.outlineVariant.withAlpha(95)
      ..strokeWidth = math.max(safeRadius * 0.012, 1.1).toDouble()
      ..strokeCap = StrokeCap.round;

    for (int i = 0; i < 60; i++) {
      final angle = (i * 6 - 90) * math.pi / 180;
      final isMajor = i % 5 == 0;
      final inner = safeRadius -
          (isMajor ? safeRadius * 0.12 : safeRadius * 0.07).toDouble();
      final outer = safeRadius - 2;
      final start = Offset(
        center.dx + inner * math.cos(angle),
        center.dy + inner * math.sin(angle),
      );
      final end = Offset(
        center.dx + outer * math.cos(angle),
        center.dy + outer * math.sin(angle),
      );
      canvas.drawLine(start, end, tickPaint);
    }
  }

  void _drawHours(Canvas canvas, Offset center, double safeRadius) {
    final textPainter = TextPainter(
        textDirection: TextDirection.ltr,
        textScaler:
            TextScaler.linear(math.min(safeRadius / 260, 1.0).toDouble()));

    for (int i = 1; i <= 12; i++) {
      final angle = (i * 30 - 90) * math.pi / 180;
      final radiusOffset = safeRadius * 0.78;
      final x = center.dx + radiusOffset * math.cos(angle);
      final y = center.dy + radiusOffset * math.sin(angle);
      final label = TextSpan(
        text: '$i',
        style: TextStyle(
          fontFamily: 'SF Compact Display',
          fontFamilyFallback: const [
            'SF Pro Text',
            'Noto Sans SC',
            'PingFang SC',
            'Microsoft YaHei',
            'Segoe UI',
            'sans-serif',
          ],
          fontSize: math.max(safeRadius * 0.22, 13).toDouble(),
          fontWeight: FontWeight.w600,
          color: colorScheme.onSurfaceVariant,
          height: 1.1,
        ),
      );

      textPainter.text = label;
      textPainter.layout();

      textPainter.paint(
        canvas,
        Offset(x - textPainter.width / 2, y - textPainter.height / 2),
      );
    }
  }

  void _drawHands(Canvas canvas, Offset center, double safeRadius) {
    final hour = now.hour % 12;
    final minute = now.minute;
    final second = now.second;
    final millisecond = now.millisecond;

    final hourAngle = ((hour + minute / 60) * 30 - 90) * math.pi / 180;
    final minuteAngle = ((minute + second / 60) * 6 - 90) * math.pi / 180;
    final smoothSecond = second + millisecond / 1000;
    final secondAngle = (smoothSecond * 6 - 90) * math.pi / 180;

    _drawHand(
      canvas,
      center,
      hourAngle,
      safeRadius * 0.34,
      colorScheme.onSurface,
      3.8,
      true,
    );
    _drawHand(
      canvas,
      center,
      minuteAngle,
      safeRadius * 0.52,
      colorScheme.onSurface,
      2.7,
      true,
    );
    if (showSeconds) {
      _drawSecondHand(canvas, center, secondAngle, safeRadius * 0.65);
    } else {
      _drawCenterDot(canvas, center);
    }
  }

  void _drawHand(Canvas canvas, Offset center, double angle, double length,
      Color color, double strokeWidth, bool hasTail) {
    final tip = Offset(
      center.dx + length * math.cos(angle),
      center.dy + length * math.sin(angle),
    );

    if (hasTail) {
      final tail = Offset(
        center.dx - length * 0.18 * math.cos(angle),
        center.dy - length * 0.18 * math.sin(angle),
      );

      final tailPaint = Paint()
        ..color = color.withAlpha(125)
        ..strokeWidth = strokeWidth * 0.6
        ..strokeCap = StrokeCap.round;

      canvas.drawLine(center, tail, tailPaint);
    }

    final paint = Paint()
      ..color = color
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 0.9)
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(center, tip, paint);
  }

  void _drawSecondHand(
      Canvas canvas, Offset center, double angle, double length) {
    const accent = Color(0xFFFF7B9C);
    final tailX = center.dx - length * 0.24 * math.cos(angle);
    final tailY = center.dy - length * 0.24 * math.sin(angle);
    final headX = center.dx + length * math.cos(angle);
    final headY = center.dy + length * math.sin(angle);

    final glowPaint = Paint()
      ..color = accent.withAlpha(55)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 24);
    canvas.drawCircle(
        Offset(headX, headY), math.max(length * 0.14, 3.2), glowPaint);

    final paint = Paint()
      ..color = accent
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 0.8)
      ..strokeWidth = 1.55
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(Offset(tailX, tailY), Offset(headX, headY), paint);

    final counterWeightPaint = Paint()
      ..color = accent.withAlpha(175)
      ..strokeWidth = 1.55
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(
      center,
      Offset(
        center.dx + length * 0.16 * math.cos(angle),
        center.dy + length * 0.16 * math.sin(angle),
      ),
      counterWeightPaint,
    );

    final dotPaint = Paint()
      ..color = accent
      ..style = PaintingStyle.fill;
    canvas.drawCircle(Offset(headX, headY), 2.4, dotPaint);

    final centerDotPaint = Paint()
      ..color = accent.withAlpha(230)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(center, 2.8, centerDotPaint);
    canvas.drawCircle(center, 1.15, _centerInkPaint());
  }

  void _drawCenterDot(Canvas canvas, Offset center) {
    final paint = Paint()
      ..color = colorScheme.primary.withAlpha(230)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(center, 2.8, paint);
    canvas.drawCircle(center, 1.15, _centerInkPaint());
  }

  Paint _centerInkPaint() {
    return Paint()
      ..color = const Color(0xFF0F1117).withAlpha(235)
      ..style = PaintingStyle.fill;
  }

  @override
  bool shouldRepaint(_ClockPainter oldDelegate) =>
      oldDelegate.now != now ||
      oldDelegate.pulseValue != pulseValue ||
      oldDelegate.showSeconds != showSeconds;
}
