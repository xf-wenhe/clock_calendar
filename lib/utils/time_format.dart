String formatClock(DateTime now,
    {required bool use24Hour, required bool showSeconds}) {
  final hour = use24Hour ? now.hour : (now.hour % 12 == 0 ? 12 : now.hour % 12);
  final prefix = use24Hour
      ? ''
      : now.hour < 12
          ? '上午 '
          : '下午 ';
  final h = hour.toString().padLeft(2, '0'),
      m = now.minute.toString().padLeft(2, '0'),
      s = now.second.toString().padLeft(2, '0');
  return '$prefix$h:$m${showSeconds ? ':$s' : ''}';
}
