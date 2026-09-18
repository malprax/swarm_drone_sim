import 'dart:math' as math;

/// 2D Vector with floating point coordinates
class Vector2 {
  final double x;
  final double y;

  const Vector2(this.x, this.y);

  static const Vector2 zero = Vector2(0, 0);
  static const Vector2 right = Vector2(1, 0);
  static const Vector2 left = Vector2(-1, 0);
  static const Vector2 up = Vector2(0, 1);
  static const Vector2 down = Vector2(0, -1);

  Vector2 operator +(Vector2 v) => Vector2(x + v.x, y + v.y);
  Vector2 operator -(Vector2 v) => Vector2(x - v.x, y - v.y);
  Vector2 operator -() => Vector2(-x, -y);
  Vector2 operator *(double s) => Vector2(x * s, y * s);
  Vector2 operator /(double s) => s == 0 ? Vector2.zero : Vector2(x / s, y / s);

  double get sqrMagnitude => x * x + y * y;
  double get magnitude => math.sqrt(sqrMagnitude);

  Vector2 get normalized {
    final m = magnitude;
    return m > 1e-6 ? Vector2(x / m, y / m) : Vector2.zero;
  }

  double dot(Vector2 v) => x * v.x + y * v.y;
  double cross(Vector2 v) => x * v.y - y * v.x;

  double distance(Vector2 v) => (this - v).magnitude;
  double sqrDistance(Vector2 v) => (this - v).sqrMagnitude;

  /// Angle in radians relative to positive X-axis (-pi to pi)
  double get angle => math.atan2(y, x);

  /// Signed angle between this and [to] in radians (-pi to pi)
  double signedAngleTo(Vector2 to) {
    final sin = cross(to);
    final cos = dot(to);
    return math.atan2(sin, cos);
  }

  /// Rotate vector by angle [rad]
  Vector2 rotate(double rad) {
    final c = math.cos(rad);
    final s = math.sin(rad);
    return Vector2(x * c - y * s, x * s + y * c);
  }

  static Vector2 lerp(Vector2 a, Vector2 b, double t) {
    final cl = t.clamp(0.0, 1.0);
    return Vector2(a.x + (b.x - a.x) * cl, a.y + (b.y - a.y) * cl);
  }

  static Vector2 clampMagnitude(Vector2 v, double maxLength) {
    final sqrMag = v.sqrMagnitude;
    if (sqrMag > maxLength * maxLength) {
      final mag = math.sqrt(sqrMag);
      if (mag > 1e-6) return v * (maxLength / mag);
    }
    return v;
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Vector2 &&
          (x - other.x).abs() < 1e-6 &&
          (y - other.y).abs() < 1e-6;

  @override
  int get hashCode => Object.hash((x * 1000).round(), (y * 1000).round());

  @override
  String toString() => '(${x.toStringAsFixed(2)}, ${y.toStringAsFixed(2)})';
}

/// 2D Vector with integer coordinates for grid indexing
class Vector2Int {
  final int x;
  final int y;

  const Vector2Int(this.x, this.y);

  static const Vector2Int zero = Vector2Int(0, 0);

  Vector2Int operator +(Vector2Int v) => Vector2Int(x + v.x, y + v.y);
  Vector2Int operator -(Vector2Int v) => Vector2Int(x - v.x, y - v.y);

  double distance(Vector2Int v) {
    final dx = (x - v.x).toDouble();
    final dy = (y - v.y).toDouble();
    return math.sqrt(dx * dx + dy * dy);
  }

  int manhattanDistance(Vector2Int v) => (x - v.x).abs() + (y - v.y).abs();

  int octileDistance(Vector2Int v) {
    final dx = (x - v.x).abs();
    final dy = (y - v.y).abs();
    final dmin = math.min(dx, dy);
    final dmax = math.max(dx, dy);
    return 14 * dmin + 10 * (dmax - dmin);
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Vector2Int && x == other.x && y == other.y;

  @override
  int get hashCode => Object.hash(x, y);

  @override
  String toString() => '($x, $y)';
}

/// Axis-aligned 2D bounding box
class Rect2D {
  final double minX;
  final double minY;
  final double maxX;
  final double maxY;
  final String? name;

  const Rect2D(this.minX, this.minY, this.maxX, this.maxY, {this.name});

  Vector2 get min => Vector2(minX, minY);
  Vector2 get max => Vector2(maxX, maxY);

  factory Rect2D.fromCenterAndSize(Vector2 center, Vector2 size, {String? name}) {
    final halfW = size.x / 2.0;
    final halfH = size.y / 2.0;
    return Rect2D(
      center.x - halfW,
      center.y - halfH,
      center.x + halfW,
      center.y + halfH,
      name: name,
    );
  }

  double get width => maxX - minX;
  double get height => maxY - minY;
  Vector2 get center => Vector2((minX + maxX) / 2.0, (minY + maxY) / 2.0);
  Vector2 get size => Vector2(width, height);

  bool contains(Vector2 p) =>
      p.x >= minX && p.x <= maxX && p.y >= minY && p.y <= maxY;

  bool overlapsCircle(Vector2 center, double radius) {
    final closestX = center.x.clamp(minX, maxX);
    final closestY = center.y.clamp(minY, maxY);
    final dx = center.x - closestX;
    final dy = center.y - closestY;
    return (dx * dx + dy * dy) <= (radius * radius);
  }

  Vector2 closestPoint(Vector2 p) {
    return Vector2(p.x.clamp(minX, maxX), p.y.clamp(minY, maxY));
  }

  /// Raycast against axis-aligned box
  RaycastHit2D? raycast(Vector2 origin, Vector2 dir, double maxDist) {
    double tmin = 0.0;
    double tmax = maxDist;
    Vector2 normal = Vector2.zero;

    if (dir.x.abs() < 1e-8) {
      if (origin.x < minX || origin.x > maxX) return null;
    } else {
      final ood = 1.0 / dir.x;
      var t1 = (minX - origin.x) * ood;
      var t2 = (maxX - origin.x) * ood;
      var n1 = const Vector2(-1, 0);
      var n2 = const Vector2(1, 0);
      if (t1 > t2) {
        final tmpT = t1; t1 = t2; t2 = tmpT;
        final tmpN = n1; n1 = n2; n2 = tmpN;
      }
      if (t1 > tmin) {
        tmin = t1;
        normal = n1;
      }
      if (t2 < tmax) tmax = t2;
      if (tmin > tmax) return null;
    }

    if (dir.y.abs() < 1e-8) {
      if (origin.y < minY || origin.y > maxY) return null;
    } else {
      final ood = 1.0 / dir.y;
      var t1 = (minY - origin.y) * ood;
      var t2 = (maxY - origin.y) * ood;
      var n1 = const Vector2(0, -1);
      var n2 = const Vector2(0, 1);
      if (t1 > t2) {
        final tmpT = t1; t1 = t2; t2 = tmpT;
        final tmpN = n1; n1 = n2; n2 = tmpN;
      }
      if (t1 > tmin) {
        tmin = t1;
        normal = n1;
      }
      if (t2 < tmax) tmax = t2;
      if (tmin > tmax) return null;
    }

    if (tmin >= 0.0 && tmin <= maxDist) {
      final hitPoint = origin + dir * tmin;
      return RaycastHit2D(
        point: hitPoint,
        normal: normal,
        distance: tmin,
        hitColliderName: name ?? 'Wall',
      );
    }
    return null;
  }

  /// Circle cast (thick ray) against axis-aligned box
  RaycastHit2D? circleCast(
    Vector2 origin,
    double radius,
    Vector2 dir,
    double maxDist,
  ) {
    final expandedBox = Rect2D(
      minX - radius,
      minY - radius,
      maxX + radius,
      maxY + radius,
      name: name,
    );
    return expandedBox.raycast(origin, dir, maxDist);
  }

  @override
  String toString() =>
      'Rect2D($name: [${minX.toStringAsFixed(2)}, ${minY.toStringAsFixed(2)}] -> [${maxX.toStringAsFixed(2)}, ${maxY.toStringAsFixed(2)}])';
}

/// Raycast hit information
class RaycastHit2D {
  final Vector2 point;
  final Vector2 normal;
  final double distance;
  final String hitColliderName;

  const RaycastHit2D({
    required this.point,
    required this.normal,
    required this.distance,
    required this.hitColliderName,
  });
}
