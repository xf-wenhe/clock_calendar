import 'dart:convert';
import 'dart:io';
import 'dart:async';
import 'package:flutter/material.dart';
import 'dart:math' as math;
import 'package:flutter/services.dart';

import '../utils/chinese_holidays.dart';
import '../services/holiday_data.dart';

class CalendarWidget extends StatefulWidget {
  const CalendarWidget({super.key, this.autoUpdate = true});

  final bool autoUpdate;

  @override
  State<CalendarWidget> createState() => _CalendarWidgetState();
}

class _CalendarWidgetState extends State<CalendarWidget> {
  DateTime _selectedDate = DateTime.now();
  DateTime _displayDate = DateTime.now();
  final HolidayData _holidayData = HolidayData();
  final Set<int> _loadedYears = {};
  bool _updating = false;
  String? _updateStatus;
  Timer? _automaticUpdateTimer;
  Directory get _cacheDirectory => Directory(
      '${Platform.environment['LOCALAPPDATA'] ?? Directory.systemTemp.path}/clock_calendar_app/holidays');

  @override
  void initState() {
    super.initState();
    _loadYears(_displayDate.year);
    if (widget.autoUpdate) {
      _automaticUpdateTimer =
          Timer(const Duration(seconds: 10), _automaticUpdate);
    }
  }

  @override
  void didUpdateWidget(covariant CalendarWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.autoUpdate != widget.autoUpdate) {
      _automaticUpdateTimer?.cancel();
      _automaticUpdateTimer = widget.autoUpdate
          ? Timer(const Duration(seconds: 10), _automaticUpdate)
          : null;
    }
  }

  @override
  void dispose() {
    _automaticUpdateTimer?.cancel();
    super.dispose();
  }

  Future<void> _automaticUpdate() async {
    final marker = File('${_cacheDirectory.path}/last-attempt.txt');
    try {
      final previous = DateTime.tryParse(await marker.readAsString());
      if (previous != null &&
          DateTime.now().difference(previous) < const Duration(days: 7)) return;
    } catch (_) {
      // A missing marker means this installation has not checked yet.
    }
    if (!mounted || !widget.autoUpdate) return;
    try {
      await _cacheDirectory.create(recursive: true);
      await marker.writeAsString(DateTime.now().toIso8601String());
    } catch (_) {
      return;
    }
    if (mounted && widget.autoUpdate) await _updateYear();
  }

  Future<void> _loadYears(int year) async {
    for (final y in [year - 1, year, year + 1]) {
      if (!_loadedYears.add(y)) continue;
      try {
        final bundled = await rootBundle.loadString('assets/holidays/$y.json');
        await _holidayData.loadYear(y, bundled, _cacheDirectory);
      } catch (_) {
        await _holidayData.loadCachedYear(y, _cacheDirectory);
      }
    }
    if (mounted) setState(() {});
  }

  Future<void> _updateYear() async {
    if (_updating) return;
    final year = _displayDate.year;
    setState(() {
      _updating = true;
      _updateStatus = null;
    });
    final success =
        await _holidayData.updateYear(year, _cacheDirectory, (y) async {
      final client = HttpClient()
        ..connectionTimeout = const Duration(seconds: 10);
      try {
        final request = await client.getUrl(Uri.https(
            'raw.githubusercontent.com',
            '/NateScarlet/holiday-cn/master/$y.json'));
        final response =
            await request.close().timeout(const Duration(seconds: 15));
        if (response.statusCode != 200) throw const HttpException('下载失败');
        return await utf8.decoder
            .bind(response)
            .join()
            .timeout(const Duration(seconds: 15));
      } finally {
        client.close(force: true);
      }
    });
    if (mounted) {
      setState(() {
        _updating = false;
        _updateStatus = success ? '更新成功' : '更新失败，保留已有数据';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final today = DateTime.now();
    final monthHolidays = ChineseHolidaysUtil.getMonthHolidays(
      _displayDate.year,
      _displayDate.month,
    );
    final holidayDays = <int, List<ChineseHoliday>>{};
    for (final holiday in monthHolidays) {
      (holidayDays[holiday.date.day] ??= []).add(holiday);
    }
    final selectedInfo = ChineseHolidaysUtil.getDayInfo(_selectedDate);

    return Material(
      color: Colors.transparent,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final width = constraints.maxWidth;
          final height = constraints.maxHeight;
          final firstDayOffset = _getFirstDayOfMonth(_displayDate);
          final daysInMonth = _getDaysInMonth(_displayDate);
          final rows = ((firstDayOffset + daysInMonth + 6) ~/ 7);

          final daySpacing = math.max(width * 0.02, 6).toDouble();
          final headerSpacing = math.max(width * 0.025, 10).toDouble();
          final crossAxisSpacing = daySpacing;

          // 关键修复：以可用「宽度」排 7 列，不再取 min(width, height) 把日历压成小方块。
          final cellWidth = (width - crossAxisSpacing * 6) / 7;

          // 估算非网格区域占用的高度，再用剩余高度反算每格尺寸，保证 6 行月历完整显示。
          final headerHeight = math.max(cellWidth * 0.46, 44).toDouble();
          final weekdayHeight = cellWidth;
          final infoHeight = math.max(cellWidth * 0.5, 56).toDouble();
          final nonGrid = headerHeight +
              weekdayHeight +
              infoHeight +
              headerSpacing * 2 +
              daySpacing * 0.7;
          // 留 8px 安全余量，保证内容严格小于可用高度，平时完全不滚动（也避免浮点误差触发滚动条）。
          final availableGrid = math.max(height - nonGrid - 8, 0.0);
          final cellHeight = ((availableGrid - (rows - 1) * daySpacing) / rows)
              .clamp(30.0, 220.0);
          final aspectRatio =
              (cellWidth / cellHeight).clamp(0.5, 1.5).toDouble();

          // 文案随格子整体放大。
          final scale = (cellWidth / 52).clamp(0.95, 1.9).toDouble();

          return SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildHeader(colorScheme, width),
                SizedBox(height: headerSpacing),
                SizedBox(
                  height: cellWidth,
                  child: _WeekdayHeader(
                    colorScheme: colorScheme,
                    scale: scale,
                  ),
                ),
                SizedBox(height: daySpacing * 0.7),
                GridView.builder(
                  physics: const NeverScrollableScrollPhysics(),
                  shrinkWrap: true,
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 7,
                    mainAxisSpacing: daySpacing,
                    crossAxisSpacing: crossAxisSpacing,
                    childAspectRatio: aspectRatio,
                  ),
                  itemCount: firstDayOffset + daysInMonth,
                  itemBuilder: (context, index) {
                    if (index < firstDayOffset) {
                      return const SizedBox();
                    }

                    final day = index - firstDayOffset + 1;
                    final date =
                        DateTime(_displayDate.year, _displayDate.month, day);
                    final isSelected = _isSameDay(date, _selectedDate);
                    final isToday = _isSameDay(date, today);
                    final events = holidayDays[day];
                    final holiday =
                        events == null || events.isEmpty ? null : events.first;
                    final holidayColor = holiday == null
                        ? null
                        : _CalendarWidgetState._holidayColor(
                            holiday.type, colorScheme);

                    return _DayCell(
                      day: day,
                      isSelected: isSelected,
                      isToday: isToday,
                      isWeekend: (date.weekday == 6 || date.weekday == 7) &&
                          _holidayData.lookup(date)?.isOffDay != false,
                      officialDay: _holidayData.lookup(date),
                      holiday: holiday,
                      lunarText: ChineseHolidaysUtil.getDayInfo(date)
                          .lunarDate
                          .split('年')
                          .last,
                      holidayColor: holidayColor,
                      colorScheme: colorScheme,
                      scale: scale,
                      cellWidth: cellWidth,
                      onTap: () => _selectDate(day),
                    );
                  },
                ),
                SizedBox(height: headerSpacing),
                _buildSelectedInfo(colorScheme, selectedInfo, width, cellWidth),
                Wrap(crossAxisAlignment: WrapCrossAlignment.center, children: [
                  Text(
                      _holidayData.hasYear(_displayDate.year)
                          ? '${_displayDate.year}年调休数据 · holiday-cn · ${_holidayData.updatedAt[_displayDate.year] == null ? '内置版本 2026-11-13' : '更新于 ${_holidayData.updatedAt[_displayDate.year]!.toLocal().toString().substring(0, 16)}'}'
                          : '${_displayDate.year}年暂无调休数据',
                      style: const TextStyle(fontSize: 11)),
                  TextButton(
                      onPressed: _updating ? null : _updateYear,
                      child: Text(_updating ? '更新中' : '更新数据')),
                  if (_updateStatus != null)
                    Text(_updateStatus!, style: const TextStyle(fontSize: 11)),
                ]),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildHeader(ColorScheme colorScheme, double width) {
    return Row(
      children: [
        _HeaderButton(
          icon: Icons.chevron_left_rounded,
          tooltip: '上个月',
          colorScheme: colorScheme,
          onPressed: _previousMonth,
          width: width,
        ),
        Expanded(
          child: Center(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Padding(
                padding:
                    EdgeInsets.symmetric(horizontal: math.max(width * 0.04, 8)),
                child: Text(
                  '${_displayDate.year}年${_displayDate.month}月',
                  style: TextStyle(
                    fontFamily: 'SF Pro Text',
                    fontFamilyFallback: const [
                      'Noto Sans SC',
                      'PingFang SC',
                      'Microsoft YaHei',
                      'Segoe UI',
                      'sans-serif',
                    ],
                    fontSize: math.max(math.min(width * 0.055, 34), 18),
                    fontWeight: FontWeight.w800,
                    color: colorScheme.onSurface,
                    letterSpacing: 0.4,
                    height: 1.25,
                  ),
                ),
              ),
            ),
          ),
        ),
        _HeaderButton(
          icon: Icons.chevron_right_rounded,
          tooltip: '下个月',
          colorScheme: colorScheme,
          onPressed: _nextMonth,
          width: width,
        ),
        const SizedBox(width: 4),
        _HeaderButton(
          icon: Icons.today_rounded,
          tooltip: '返回今天',
          colorScheme: colorScheme,
          onPressed: _returnToday,
          width: width,
        ),
      ],
    );
  }

  Widget _buildSelectedInfo(ColorScheme colorScheme, ChineseDayInfo info,
      double width, double cellWidth) {
    final weekday = const [
      '周一',
      '周二',
      '周三',
      '周四',
      '周五',
      '周六',
      '周日'
    ][_selectedDate.weekday - 1];
    final date =
        '${_selectedDate.year}年${_selectedDate.month}月${_selectedDate.day}日 $weekday';
    final details = [
      info.lunarDate,
      if (info.zodiac.isNotEmpty) '${info.zodiac}年',
      ...info.events.map((e) => e.name),
      if (_holidayData.lookup(_selectedDate) case final day?)
        '${day.name}${day.isOffDay ? '休息' : '补班'}',
    ].join(' · ');
    return _InfoCard(
        colorScheme: colorScheme,
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(date,
              style:
                  const TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          Text(
            details,
            style: const TextStyle(fontSize: 11),
          ),
        ]));
  }

  void _selectDate(int day) {
    setState(() {
      _selectedDate = DateTime(_displayDate.year, _displayDate.month, day);
    });
    HapticFeedback.lightImpact();
  }

  void _returnToday() {
    final now = DateTime.now();
    setState(() {
      _selectedDate = now;
      _displayDate = now;
    });
    _loadYears(now.year);
  }

  void _previousMonth() {
    setState(() {
      _displayDate = DateTime(_displayDate.year, _displayDate.month - 1);
    });
    _loadYears(_displayDate.year);
  }

  void _nextMonth() {
    setState(() {
      _displayDate = DateTime(_displayDate.year, _displayDate.month + 1);
    });
    _loadYears(_displayDate.year);
  }

  int _getDaysInMonth(DateTime date) =>
      DateTime(date.year, date.month + 1, 0).day;

  int _getFirstDayOfMonth(DateTime date) =>
      DateTime(date.year, date.month, 1).weekday % 7;

  bool _isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  static Color _holidayColor(HolidayType type, ColorScheme colorScheme) {
    switch (type) {
      case HolidayType.holiday:
        return colorScheme.error;
      case HolidayType.festival:
        return const Color(0xFFF59E0B);
      case HolidayType.solarTerm:
        return const Color(0xFF10B981);
    }
  }
}

class _WeekdayHeader extends StatelessWidget {
  const _WeekdayHeader({
    required this.colorScheme,
    required this.scale,
  });

  final ColorScheme colorScheme;
  final double scale;

  @override
  Widget build(BuildContext context) {
    const labels = ['日', '一', '二', '三', '四', '五', '六'];
    return Row(
      children: [
        for (int i = 0; i < 7; i++)
          Expanded(
            child: _WeekdayCell(
              label: labels[i],
              isWeekend: i == 0 || i == 6,
              scale: scale,
            ),
          ),
      ],
    );
  }
}

class _WeekdayCell extends StatelessWidget {
  const _WeekdayCell({
    required this.label,
    required this.isWeekend,
    required this.scale,
  });

  final String label;
  final bool isWeekend;
  final double scale;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: isWeekend
            ? isDark
                ? colorScheme.error.withAlpha(22)
                : colorScheme.error.withAlpha(12)
            : null,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Text(
        label,
        textAlign: TextAlign.center,
        style: TextStyle(
          fontFamily: 'SF Pro Text',
          fontFamilyFallback: const [
            'Noto Sans SC',
            'PingFang SC',
            'Microsoft YaHei',
            'Segoe UI',
            'sans-serif',
          ],
          fontSize: (12.0 * scale).clamp(11.0, 17.0),
          fontWeight: FontWeight.w700,
          color: isWeekend
              ? isDark
                  ? colorScheme.error.withAlpha(210)
                  : colorScheme.error.withAlpha(175)
              : isDark
                  ? Colors.white.withAlpha(165)
                  : const Color(0xFF8B95AD),
          letterSpacing: 0.3,
        ),
      ),
    );
  }
}

const _calendarCellBorderRadius = 16.0;

class _DayCell extends StatelessWidget {
  const _DayCell({
    required this.day,
    required this.isSelected,
    required this.isToday,
    required this.isWeekend,
    required this.holiday,
    required this.holidayColor,
    required this.lunarText,
    required this.officialDay,
    required this.colorScheme,
    required this.scale,
    required this.cellWidth,
    required this.onTap,
  });

  final int day;
  final bool isSelected;
  final bool isToday;
  final bool isWeekend;
  final ChineseHoliday? holiday;
  final String lunarText;
  final HolidayDay? officialDay;
  final Color? holidayColor;
  final ColorScheme colorScheme;
  final double scale;
  final double cellWidth;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    Color? background;
    Color? textColor;

    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (isSelected) {
      background = colorScheme.primary;
      textColor = colorScheme.onPrimary;
    } else if (holidayColor != null) {
      background = holidayColor!.withAlpha(44);
      textColor = colorScheme.onSurface;
    } else if (isToday) {
      background = colorScheme.primary.withAlpha(44);
      textColor = colorScheme.onSurface;
    } else if (isWeekend) {
      // 周末淡淡一抹暖色，提升层次感。
      background = isDark
          ? colorScheme.error.withAlpha(12)
          : colorScheme.error.withAlpha(8);
      textColor = colorScheme.onSurfaceVariant;
    }

    final borderColor = isSelected
        ? colorScheme.primary
        : holidayColor != null
            ? holidayColor!.withAlpha(125)
            : isToday
                ? colorScheme.primary.withAlpha(125)
                : isDark
                    ? Colors.white.withAlpha(20)
                    : colorScheme.outlineVariant.withAlpha(160);

    final chipBackground = isSelected
        ? colorScheme.primary
        : holidayColor != null
            ? holidayColor!.withAlpha(18)
            : isToday
                ? colorScheme.primary.withAlpha(18)
                : null;
    final daySize = (cellWidth * 0.30).clamp(14.0, 24.0);
    final holidaySize = (cellWidth * 0.16).clamp(9.0, 13.0);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(_calendarCellBorderRadius),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeInOut,
        decoration: BoxDecoration(
          color: background,
          borderRadius: BorderRadius.circular(_calendarCellBorderRadius),
          border: Border.all(color: borderColor, width: 1),
          boxShadow: background == null
              ? null
              : [
                  BoxShadow(
                    color: background.withAlpha(45),
                    blurRadius: 14,
                    offset: const Offset(0, 6),
                  ),
                ],
        ),
        child: Stack(
          children: [
            if (officialDay != null)
              Positioned(
                  right: 4,
                  top: 2,
                  child: Text(officialDay!.isOffDay ? '休' : '班',
                      style: TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                          color: officialDay!.isOffDay
                              ? Colors.redAccent
                              : Colors.lightBlueAccent))),
            if (chipBackground != null)
              Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: chipBackground,
                    borderRadius:
                        BorderRadius.circular(_calendarCellBorderRadius),
                  ),
                ),
              ),
            Center(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '$day',
                      style: TextStyle(
                        fontFamily: 'SF Pro Text',
                        fontFamilyFallback: const [
                          'Noto Sans SC',
                          'PingFang SC',
                          'Microsoft YaHei',
                          'Segoe UI',
                          'sans-serif',
                        ],
                        fontSize: daySize,
                        fontWeight: isSelected || isToday
                            ? FontWeight.w800
                            : FontWeight.w600,
                        color: textColor ?? colorScheme.onSurface,
                        height: 1.1,
                      ),
                    ),
                    if (holiday != null || lunarText.isNotEmpty)
                      Padding(
                        padding: EdgeInsets.only(top: math.max(2 * scale, 1.5)),
                        child: Text(
                          holiday?.name ?? lunarText,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontFamily: 'SF Pro Text',
                            fontFamilyFallback: const [
                              'Noto Sans SC',
                              'PingFang SC',
                              'Microsoft YaHei',
                              'Segoe UI',
                              'sans-serif',
                            ],
                            fontSize: holidaySize,
                            fontWeight: FontWeight.w600,
                            color: holidayColor ??
                                textColor ??
                                colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HeaderButton extends StatelessWidget {
  const _HeaderButton({
    required this.icon,
    required this.tooltip,
    required this.colorScheme,
    required this.onPressed,
    required this.width,
  });

  final IconData icon;
  final String tooltip;
  final ColorScheme colorScheme;
  final VoidCallback onPressed;
  final double width;

  @override
  Widget build(BuildContext context) {
    final buttonSize = (width * 0.05).clamp(34.0, 52.0);
    final iconSize = buttonSize * 0.5;
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(buttonSize / 2),
        child: Container(
          width: buttonSize.toDouble(),
          height: buttonSize.toDouble(),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: colorScheme.primary.withAlpha(22),
            borderRadius: BorderRadius.circular(buttonSize / 2),
            border: Border.all(
              color: colorScheme.primary.withAlpha(45),
              width: 1,
            ),
          ),
          child: Icon(
            icon,
            size: iconSize.toDouble(),
            color: colorScheme.primary,
          ),
        ),
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  const _InfoCard({required this.colorScheme, required this.child});

  final ColorScheme colorScheme;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      decoration: BoxDecoration(
        color: const Color(0xFF252A3B),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: Colors.white.withAlpha(24),
          width: 1,
        ),
      ),
      child: child,
    );
  }
}
