class DisplayTopologyTracker {
  String? _previous;
  bool update(Iterable<String> descriptors) {
    final values = descriptors.toList()..sort();
    if (values.isEmpty) return false;
    final current = values.join('|');
    final changed = _previous != null && _previous != current;
    _previous = current;
    return changed;
  }
}
