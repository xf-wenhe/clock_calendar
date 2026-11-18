import 'dart:convert';
import 'dart:io';

class CountdownStore {
  CountdownStore(this.file);
  final File file;
  Future<void> _pending = Future.value();
  Future<Map<String, dynamic>?> load() async {
    try {
      final data = jsonDecode(await file.readAsString());
      return data is Map<String, dynamic> ? data : null;
    } catch (_) {
      return null;
    }
  }

  void save(Map<String, Object?> data) {
    final encoded = jsonEncode(data);
    _pending = _pending.then((_) async {
      await file.parent.create(recursive: true);
      final temp = File('${file.path}.tmp');
      await temp.writeAsString(encoded, flush: true);
      await temp.rename(file.path);
    }).catchError((_) {});
  }

  Future<void> flush() => _pending;
}
