abstract class AppClock {
  DateTime now();
}

class SystemClock implements AppClock {
  const SystemClock();

  @override
  DateTime now() => DateTime.now();
}

class TestClock implements AppClock {
  DateTime _current;

  TestClock([DateTime? initialTime])
      : _current = initialTime ?? DateTime(2026, 1, 1, 9, 0, 0);

  @override
  DateTime now() => _current;

  void advance(Duration duration) {
    _current = _current.add(duration);
  }

  void setTime(DateTime time) {
    _current = time;
  }
}
