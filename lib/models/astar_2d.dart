import 'dart:math' as math;
import 'grid_map_2d.dart';
import 'vector2.dart';

/// A* 2D Pathfinding on Occupancy Grid with Inflated safety buffer
class AStar2D {
  static const List<Vector2Int> neigh8 = [
    Vector2Int(1, 0),
    Vector2Int(-1, 0),
    Vector2Int(0, 1),
    Vector2Int(0, -1),
    Vector2Int(1, 1),
    Vector2Int(1, -1),
    Vector2Int(-1, 1),
    Vector2Int(-1, -1),
  ];

  static int _heuristic(Vector2Int a, Vector2Int b) {
    final dx = (a.x - b.x).abs();
    final dy = (a.y - b.y).abs();
    final dmin = math.min(dx, dy);
    final dmax = math.max(dx, dy);
    return 14 * dmin + 10 * (dmax - dmin);
  }

  /// Find path using A* from start to goal on GridMap2D
  static List<Vector2Int> findPath(
    GridMap2D map,
    Vector2Int start,
    Vector2Int goal, {
    int maxNodes = 10000,
  }) {
    if (!map.inBounds(start) || !map.inBounds(goal)) return [];
    if (map.getCellInflated(start) == GridMap2D.occupied) return [];
    if (map.getCellInflated(goal) == GridMap2D.occupied) return [];
    if (start == goal) return [start];

    final w = map.width;
    final h = map.height;
    final totalCells = w * h;

    final bestG = List<int>.filled(totalCells, 1000000000);
    final parent = List<int>.filled(totalCells, -1);
    final closed = List<bool>.filled(totalCells, false);

    final sIdx = start.y * w + start.x;
    final gIdx = goal.y * w + goal.x;

    bestG[sIdx] = 0;

    // Simple priority queue min-heap
    final openIndices = <int>[sIdx];
    final openF = <int>[_heuristic(start, goal)];

    int expanded = 0;

    while (openIndices.isNotEmpty && expanded < maxNodes) {
      expanded++;

      // Pick lowest f
      int bestPos = 0;
      int lowestF = openF[0];
      for (int i = 1; i < openF.length; i++) {
        if (openF[i] < lowestF) {
          lowestF = openF[i];
          bestPos = i;
        }
      }

      final curIdx = openIndices[bestPos];
      // remove at bestPos
      final lastPos = openIndices.length - 1;
      openIndices[bestPos] = openIndices[lastPos];
      openF[bestPos] = openF[lastPos];
      openIndices.removeLast();
      openF.removeLast();

      if (curIdx == gIdx) break;
      if (closed[curIdx]) continue;
      closed[curIdx] = true;

      final cx = curIdx % w;
      final cy = curIdx ~/ w;

      for (int k = 0; k < neigh8.length; k++) {
        final nx = cx + neigh8[k].x;
        final ny = cy + neigh8[k].y;
        if (nx < 0 || nx >= w || ny < 0 || ny >= h) continue;

        final nIdx = ny * w + nx;
        if (closed[nIdx]) continue;

        // Traverse only Free cells on inflated grid
        final cellState = map.rawInflatedGrid[nIdx];
        if (cellState != GridMap2D.free) continue;

        final stepCost = (k < 4) ? 10 : 14;
        final ng = bestG[curIdx] + stepCost;

        if (ng < bestG[nIdx]) {
          bestG[nIdx] = ng;
          parent[nIdx] = curIdx;
          final f = ng + _heuristic(Vector2Int(nx, ny), goal);
          openIndices.add(nIdx);
          openF.add(f);
        }
      }
    }

    if (parent[gIdx] == -1 && gIdx != sIdx) {
      return [];
    }

    // Reconstruct path
    final path = <Vector2Int>[];
    int walk = gIdx;
    path.add(Vector2Int(walk % w, walk ~/ w));

    int guard = 0;
    while (walk != sIdx && walk != -1 && guard++ < 20000) {
      walk = parent[walk];
      if (walk == -1) break;
      path.add(Vector2Int(walk % w, walk ~/ w));
    }

    return path.reversed.toList();
  }
}
