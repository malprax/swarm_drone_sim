import 'dart:collection';
import 'grid_map_2d.dart';
import 'vector2.dart';

/// Frontier exploration planner ported from Unity FrontierPlanner.cs & DroneNavigator.cs
class FrontierPlanner {
  static const List<Vector2Int> neigh4 = [
    Vector2Int(1, 0),
    Vector2Int(-1, 0),
    Vector2Int(0, 1),
    Vector2Int(0, -1),
  ];

  static const List<Vector2Int> neigh8 = [
    Vector2Int(1, 0), Vector2Int(-1, 0), Vector2Int(0, 1), Vector2Int(0, -1),
    Vector2Int(1, 1), Vector2Int(1, -1), Vector2Int(-1, 1), Vector2Int(-1, -1),
  ];

  /// Find best scored frontier candidate cell using BFS
  static Vector2Int? findBestFrontier(
    GridMap2D map,
    Vector2Int start,
    Map<Vector2Int, double> cooldownMap, {
    int maxSearchNodes = 3000,
    int maxCandidates = 30,
  }) {
    if (!map.inBounds(start)) return null;

    final w = map.width;
    final h = map.height;
    final visited = List<bool>.filled(w * h, false);
    final queue = Queue<Vector2Int>();

    queue.add(start);
    visited[start.y * w + start.x] = true;

    final candidates = <Vector2Int>[];
    int expanded = 0;

    while (queue.isNotEmpty && expanded < maxSearchNodes) {
      final cur = queue.removeFirst();
      expanded++;

      if (_isFrontier(map, cur, start)) {
        if (!cooldownMap.containsKey(cur)) {
          candidates.add(cur);
          if (candidates.length >= maxCandidates) break;
        }
      }

      for (final n in neigh4) {
        final nx = cur.x + n.x;
        final ny = cur.y + n.y;
        if (nx < 0 || nx >= w || ny < 0 || ny >= h) continue;

        final nIdx = ny * w + nx;
        if (visited[nIdx]) continue;

        // BFS traverses Free cells on inflated grid
        if (map.rawInflatedGrid[nIdx] != GridMap2D.free) continue;

        visited[nIdx] = true;
        queue.add(Vector2Int(nx, ny));
      }
    }

    if (candidates.isEmpty) return null;

    // Score candidates: higher unknown neighbors, small distance penalty
    double bestScore = -1e9;
    Vector2Int best = candidates.first;

    for (final c in candidates) {
      final unknownCount = _countUnknownNeighbors8(map, c);
      final dist = (c.x - start.x).abs() + (c.y - start.y).abs();
      final score = unknownCount * 2.0 - dist * 0.15;

      if (score > bestScore) {
        bestScore = score;
        best = c;
      }
    }

    return best;
  }

  static bool _isFrontier(GridMap2D map, Vector2Int c, Vector2Int startCell) {
    if (map.getCellInflated(c) != GridMap2D.free) return false;
    // Anti-self frontier: must be at least 2 cells away from start cell
    if (c.distance(startCell) <= 1.5) return false;

    // Must touch an Unknown cell in raw grid
    for (final n in neigh4) {
      final nx = c.x + n.x;
      final ny = c.y + n.y;
      if (nx < 0 || nx >= map.width || ny < 0 || ny >= map.height) continue;
      if (map.rawGrid[ny * map.width + nx] == GridMap2D.unknown) {
        return true;
      }
    }
    return false;
  }

  static int _countUnknownNeighbors8(GridMap2D map, Vector2Int c) {
    int count = 0;
    for (final n in neigh8) {
      final nx = c.x + n.x;
      final ny = c.y + n.y;
      if (nx < 0 || nx >= map.width || ny < 0 || ny >= map.height) continue;
      if (map.rawGrid[ny * map.width + nx] == GridMap2D.unknown) {
        count++;
      }
    }
    return count;
  }
}
