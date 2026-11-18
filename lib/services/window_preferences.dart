import 'dart:ui';

class WindowPreferences {
  final bool closeToTray,
      alwaysOnTop,
      mini,
      use24Hour,
      showSeconds,
      capsule,
      capsulePomodoro,
      autoCapsule,
      holidayAutoUpdate;
  final Rect? bounds, fullBounds;
  const WindowPreferences(
      {this.closeToTray = false,
      this.alwaysOnTop = false,
      this.mini = false,
      this.use24Hour = true,
      this.showSeconds = true,
      this.capsule = false,
      this.capsulePomodoro = false,
      this.autoCapsule = false,
      this.holidayAutoUpdate = true,
      this.bounds,
      this.fullBounds});
  static Rect? _parseRect(Object? raw) {
    if (raw is! Map) return null;
    final x = raw['x'], y = raw['y'], w = raw['w'], h = raw['h'];
    if (x is! num ||
        y is! num ||
        w is! num ||
        h is! num ||
        ![x, y, w, h].every((v) => v.isFinite) ||
        w <= 0 ||
        h <= 0 ||
        w > 10000 ||
        h > 10000) return null;
    return Rect.fromLTWH(
        x.toDouble(), y.toDouble(), w.toDouble(), h.toDouble());
  }

  factory WindowPreferences.fromMap(Map<String, dynamic> json) =>
      WindowPreferences(
          closeToTray: json['closeToTray'] == true,
          alwaysOnTop: json['alwaysOnTop'] == true,
          mini: json['mini'] == true,
          use24Hour:
              json['use24Hour'] is bool ? json['use24Hour'] as bool : true,
          showSeconds:
              json['showSeconds'] is bool ? json['showSeconds'] as bool : true,
          capsule: json['capsule'] == true,
          capsulePomodoro: json['capsulePomodoro'] == true,
          autoCapsule: json['autoCapsule'] == true,
          holidayAutoUpdate: json['holidayAutoUpdate'] is bool
              ? json['holidayAutoUpdate'] as bool
              : true,
          bounds: _parseRect(json['bounds']),
          fullBounds: _parseRect(json['fullBounds']));
  Map<String, Object?> toMap() {
    Map<String, double>? rect(Rect? r) => r == null
        ? null
        : {'x': r.left, 'y': r.top, 'w': r.width, 'h': r.height};
    return {
      'closeToTray': closeToTray,
      'alwaysOnTop': alwaysOnTop,
      'mini': mini,
      'use24Hour': use24Hour,
      'showSeconds': showSeconds,
      'capsule': capsule,
      'capsulePomodoro': capsulePomodoro,
      'autoCapsule': autoCapsule,
      'holidayAutoUpdate': holidayAutoUpdate,
      'bounds': rect(bounds),
      'fullBounds': rect(fullBounds)
    };
  }
}
