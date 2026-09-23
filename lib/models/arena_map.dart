import 'dart:math' as math;
import 'vector2.dart';

/// Represents an oriented wall surface facing the walkable arena rooms
class WallSurface {
  final Vector2 start;
  final Vector2 end;
  final Vector2 normal;
  final String name;

  const WallSurface(this.start, this.end, this.normal, {this.name = ''});

  double get length => start.distance(end);
}

/// Defines the arena layout, walls, rooms, start positions, and raycasting
class ArenaMap {
  /// Exact 12 wall bounding boxes ported directly from Unity scene (Main.unity)
  static final List<Rect2D> walls = [
    // Outer boundaries
    Rect2D(-14.481, -4.607, 14.501, -4.124, name: 'wall_bottom'),
    Rect2D(-14.481, -4.124, -13.998, 9.884, name: 'wall_left'),
    Rect2D(14.018, -4.124, 14.501, 9.884, name: 'wall_right'),
    Rect2D(-14.465, 9.884, -6.994, 10.367, name: 'wall_top1'),
    Rect2D(-1.278, 9.884, 14.501, 10.367, name: 'wall_top2'),

    // Interior room partitions
    Rect2D(-7.477, -1.548, -6.994, 10.045, name: 'wall_room12'),
    Rect2D(-7.236, 3.089, -0.795, 3.572, name: 'wall_room2'),
    Rect2D(-1.278, 3.524, -0.795, 9.965, name: 'wall_room22'),
    Rect2D(6.676, 3.427, 7.159, 9.868, name: 'wall_room23'),
    Rect2D(3.617, -1.403, 4.100, 3.105, name: 'wall_room24'),
    Rect2D(1.974, 3.089, 7.127, 3.572, name: 'wall_room25'),
    Rect2D(2.007, 3.089, 7.159, 3.572, name: 'wall_room26'),
  ];

  /// Room-facing wall boundary surfaces for rendering stylized detected wall contours
  static final List<WallSurface> wallSurfaces = [
    // 1. Outer boundaries (interior room faces)
    const WallSurface(Vector2(-13.998, -4.124), Vector2(14.018, -4.124), Vector2(0.0, 1.0), name: 'outer_bottom'),
    const WallSurface(Vector2(-13.998, -4.124), Vector2(-13.998, 9.884), Vector2(1.0, 0.0), name: 'outer_left'),
    const WallSurface(Vector2(14.018, -4.124), Vector2(14.018, 9.884), Vector2(-1.0, 0.0), name: 'outer_right'),
    const WallSurface(Vector2(-13.998, 9.884), Vector2(-6.994, 9.884), Vector2(0.0, -1.0), name: 'outer_top_west'),
    const WallSurface(Vector2(-1.278, 9.884), Vector2(14.018, 9.884), Vector2(0.0, -1.0), name: 'outer_top_east'),

    // 2. Interior partition: wall_room12
    const WallSurface(Vector2(-7.477, -1.548), Vector2(-7.477, 9.884), Vector2(-1.0, 0.0), name: 'room12_west'),
    const WallSurface(Vector2(-6.994, -1.548), Vector2(-6.994, 3.089), Vector2(1.0, 0.0), name: 'room12_east_lower'),
    const WallSurface(Vector2(-6.994, 3.572), Vector2(-6.994, 9.884), Vector2(1.0, 0.0), name: 'room12_east_upper'),
    const WallSurface(Vector2(-7.477, -1.548), Vector2(-6.994, -1.548), Vector2(0.0, -1.0), name: 'room12_south_cap'),

    // 3. Interior partition: wall_room2
    const WallSurface(Vector2(-6.994, 3.089), Vector2(-0.795, 3.089), Vector2(0.0, -1.0), name: 'room2_south'),
    const WallSurface(Vector2(-6.994, 3.572), Vector2(-1.278, 3.572), Vector2(0.0, 1.0), name: 'room2_north'),
    const WallSurface(Vector2(-0.795, 3.089), Vector2(-0.795, 3.572), Vector2(1.0, 0.0), name: 'room2_east_cap'),

    // 4. Interior partition: wall_room22
    const WallSurface(Vector2(-1.278, 3.572), Vector2(-1.278, 9.884), Vector2(-1.0, 0.0), name: 'room22_west'),
    const WallSurface(Vector2(-0.795, 3.524), Vector2(-0.795, 9.884), Vector2(1.0, 0.0), name: 'room22_east'),

    // 5. Interior partition: wall_room23
    const WallSurface(Vector2(6.676, 3.572), Vector2(6.676, 9.868), Vector2(-1.0, 0.0), name: 'room23_west'),
    const WallSurface(Vector2(7.159, 3.572), Vector2(7.159, 9.868), Vector2(1.0, 0.0), name: 'room23_east'),
    const WallSurface(Vector2(6.676, 3.427), Vector2(7.159, 3.427), Vector2(0.0, -1.0), name: 'room23_south_cap'),

    // 6. Interior partition: wall_room24
    const WallSurface(Vector2(3.617, -1.403), Vector2(3.617, 3.089), Vector2(-1.0, 0.0), name: 'room24_west'),
    const WallSurface(Vector2(4.100, -1.403), Vector2(4.100, 3.089), Vector2(1.0, 0.0), name: 'room24_east'),
    const WallSurface(Vector2(3.617, -1.403), Vector2(4.100, -1.403), Vector2(0.0, -1.0), name: 'room24_south_cap'),

    // 7. Interior partition: wall_room25 & 26
    const WallSurface(Vector2(1.974, 3.572), Vector2(6.676, 3.572), Vector2(0.0, 1.0), name: 'room25_north'),
    const WallSurface(Vector2(1.974, 3.089), Vector2(7.159, 3.089), Vector2(0.0, -1.0), name: 'room25_south'),
    const WallSurface(Vector2(1.974, 3.089), Vector2(1.974, 3.572), Vector2(-1.0, 0.0), name: 'room25_west_cap'),
  ];

  /// Fixed default start positions from Unity SimManager
  static const List<Vector2> defaultStartPositions = [
    Vector2(-5.7, 1.4),
    Vector2(-3.7, 1.4),
    Vector2(-1.7, 1.4),
  ];

  /// HomeBase position from Unity SimManager
  static const Vector2 defaultHomeBase = Vector2(-5.7, 1.4);

  /// Target spawn area from Unity ExperimentUIController
  static const Vector2 targetMin = Vector2(-1.0, -3.0);
  static const Vector2 targetMax = Vector2(8.0, 3.0);
  static const Rect2D targetSpawnBounds = Rect2D(-1.0, -3.0, 8.0, 3.0);

  /// Designated walkable room zones inside the arena for AI recognition & random placements
  static final List<Rect2D> roomZones = [
    const Rect2D(-6.8, -1.0, -1.0, 2.9, name: 'Room 1 (Base Hangar)'),
    const Rect2D(-13.5, -3.5, -7.8, 9.2, name: 'Room 2 (West Wing)'),
    const Rect2D(-0.5, 3.8, 6.4, 9.4, name: 'Room 3 (North Center)'),
    const Rect2D(7.4, 3.8, 13.5, 9.4, name: 'Room 4 (North East)'),
    const Rect2D(4.4, -3.5, 13.5, 2.7, name: 'Room 5 (South East)'),
    const Rect2D(-0.5, -3.5, 3.3, 2.7, name: 'Room 6 (Central Hallway)'),
  ];

  /// Raycast against all walls in the arena, returns closest hit
  static RaycastHit2D? raycast(Vector2 origin, Vector2 dir, double maxDist) {
    RaycastHit2D? closestHit;
    double minDistance = maxDist;

    for (final wall in walls) {
      final hit = wall.raycast(origin, dir, minDistance);
      if (hit != null && hit.distance < minDistance) {
        minDistance = hit.distance;
        closestHit = hit;
      }
    }
    return closestHit;
  }

  /// Circle cast (thick ray) against all walls in the arena
  static RaycastHit2D? circleCast(
    Vector2 origin,
    double radius,
    Vector2 dir,
    double maxDist,
  ) {
    RaycastHit2D? closestHit;
    double minDistance = maxDist;

    for (final wall in walls) {
      final hit = wall.circleCast(origin, radius, dir, minDistance);
      if (hit != null && hit.distance < minDistance) {
        minDistance = hit.distance;
        closestHit = hit;
      }
    }
    return closestHit;
  }

  /// Check if a circle overlaps any wall
  static bool overlapsWall(Vector2 center, double radius) {
    for (final wall in walls) {
      if (wall.overlapsCircle(center, radius)) return true;
    }
    return false;
  }

  /// Clamps proposed position inside arena bounds and prevents wall collisions with sliding support
  static Vector2 clampPositionAgainstWalls(
    Vector2 proposed,
    double radius,
    Vector2 current, {
    double minX = -17.2,
    double maxX = 17.2,
    double minY = -7.2,
    double maxY = 13.2,
  }) {
    // 1. Clamp within outer arena boundary walls
    final clampedX = proposed.x.clamp(minX, maxX);
    final clampedY = proposed.y.clamp(minY, maxY);
    final cand = Vector2(clampedX, clampedY);

    // 2. If direct candidate has zero collision, accept
    if (!overlapsWall(cand, radius)) {
      return cand;
    }

    // 3. Sliding test along X-axis (keep current Y)
    final candX = Vector2(clampedX, current.y);
    if (!overlapsWall(candX, radius)) {
      return candX;
    }

    // 4. Sliding test along Y-axis (keep current X)
    final candY = Vector2(current.x, clampedY);
    if (!overlapsWall(candY, radius)) {
      return candY;
    }

    // 5. If completely blocked by a corner or wall, safely retain current position
    return current;
  }

  /// Check Line Of Sight (LOS) between two points against walls
  static bool hasLineOfSight(Vector2 from, Vector2 to, double maxRange) {
    final dist = from.distance(to);
    if (dist > maxRange) return false;
    final dir = (to - from).normalized;
    final hit = raycast(from, dir, dist);
    return hit == null || hit.distance >= dist - 0.05;
  }

  /// Pick a valid target position randomly placed inside any room without hitting walls
  static Vector2 pickValidTarget(math.Random rand, {double probeRadius = 0.30}) {
    for (int i = 0; i < 80; i++) {
      // Pick random room zone
      final room = roomZones[rand.nextInt(roomZones.length)];
      final x = room.minX + 0.4 + rand.nextDouble() * (room.width - 0.8);
      final y = room.minY + 0.4 + rand.nextDouble() * (room.height - 0.8);
      final p = Vector2(x, y);
      if (!overlapsWall(p, probeRadius)) {
        return p;
      }
    }
    return const Vector2(3.0, 0.0);
  }

  /// Pick valid pre-flight starting positions for N drones distributed in rooms without overlap
  static List<Vector2> pickValidDronePositions(
    math.Random rand,
    int count, {
    double minSeparation = 1.6,
    double wallPadding = 0.5,
  }) {
    final positions = <Vector2>[];

    for (int droneIdx = 0; droneIdx < count; droneIdx++) {
      Vector2? candidate;
      for (int attempt = 0; attempt < 100; attempt++) {
        final room = roomZones[rand.nextInt(roomZones.length)];
        final x = room.minX + wallPadding + rand.nextDouble() * (room.width - 2 * wallPadding);
        final y = room.minY + wallPadding + rand.nextDouble() * (room.height - 2 * wallPadding);
        final p = Vector2(x, y);

        if (overlapsWall(p, wallPadding)) continue;

        // Check separation from already selected drone positions
        bool tooClose = false;
        for (final other in positions) {
          if (p.distance(other) < minSeparation) {
            tooClose = true;
            break;
          }
        }
        if (tooClose) continue;

        candidate = p;
        break;
      }

      positions.add(candidate ?? defaultStartPositions[droneIdx % defaultStartPositions.length]);
    }

    return positions;
  }
}
