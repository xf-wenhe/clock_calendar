import 'dart:math' as math;
import 'dart:ui';

/// Constrains a saved window rectangle to the best matching visible work area.
Rect keepWindowVisible(Rect bounds, List<Rect> workAreas) {
  final valid = workAreas
      .where((r) => r.width > 0 && r.height > 0 && r.isFinite)
      .toList();
  if (valid.isEmpty ||
      !bounds.isFinite ||
      bounds.width <= 0 ||
      bounds.height <= 0) return bounds;
  var chosen = valid.first;
  var maxOverlap = 0.0;
  for (final area in valid) {
    final overlap = area.intersect(bounds);
    final size = math.max(0.0, overlap.width) * math.max(0.0, overlap.height);
    if (size > maxOverlap) {
      chosen = area;
      maxOverlap = size;
    }
  }
  final width = math.min(bounds.width, chosen.width),
      height = math.min(bounds.height, chosen.height);
  final left = bounds.left.clamp(chosen.left, chosen.right - width).toDouble();
  final top = bounds.top.clamp(chosen.top, chosen.bottom - height).toDouble();
  return Rect.fromLTWH(left, top, width, height);
}
