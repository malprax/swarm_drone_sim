import 'dart:typed_data';
import 'vector2.dart';

/// Occupancy grid 2D ported from Unity GridMap2D.cs
/// 0 = Unknown, 1 = Free, 2 = Occupied
class GridMap2D {
  static const int unknown = 0;
  static const int free = 1;
  static const int occupied = 2;

  final double cellSize;
  final int width;
  final int height;
  final Vector2 originWorld;
  final int inflateCells;

  late final Uint8List _grid;
  late final Uint8List _inflatedGrid;

  GridMap2D({
    this.cellSize = 0.3,
    this.width = 120,
    this.height = 120,
    this.originWorld = const Vector2(-18.0, -18.0),
    this.inflateCells = 2,
  }) {
    _grid = Uint8List(width * height);
    _inflatedGrid = Uint8List(width * height);
    clear();
  }

  void clear() {
    _grid.fillRange(0, _grid.length, unknown);
    _inflatedGrid.fillRange(0, _inflatedGrid.length, unknown);
    rebuildInflation();
  }

  bool worldToCell(Vector2 world, {required Vector2Int outCell}) {
    final cx = ((world.x - originWorld.x) / cellSize).floor();
    final cy = ((world.y - originWorld.y) / cellSize).floor();
    return inBoundsXY(cx, cy);
  }

  Vector2Int? worldToCellSafe(Vector2 world) {
    final cx = ((world.x - originWorld.x) / cellSize).floor();
    final cy = ((world.y - originWorld.y) / cellSize).floor();
    if (inBoundsXY(cx, cy)) {
      return Vector2Int(cx, cy);
    }
    return null;
  }

  Vector2 cellToWorldCenter(Vector2Int cell) {
    return Vector2(
      originWorld.x + (cell.x + 0.5) * cellSize,
      originWorld.y + (cell.y + 0.5) * cellSize,
    );
  }

  bool inBounds(Vector2Int c) => inBoundsXY(c.x, c.y);

  bool inBoundsXY(int x, int y) => x >= 0 && x < width && y >= 0 && y < height;

  int getCell(Vector2Int c) {
    if (!inBounds(c)) return occupied;
    return _grid[c.y * width + c.x];
  }

  int getCellInflated(Vector2Int c) {
    if (!inBounds(c)) return occupied;
    return _inflatedGrid[c.y * width + c.x];
  }

  void setFree(Vector2Int c) {
    if (!inBounds(c)) return;
    final idx = c.y * width + c.x;
    if (_grid[idx] == unknown) {
      _grid[idx] = free;
    }
  }

  void setOccupied(Vector2Int c) {
    if (!inBounds(c)) return;
    final idx = c.y * width + c.x;
    _grid[idx] = occupied;
  }

  /// Rebuild inflation layer so paths don't hug walls
  void rebuildInflation() {
    // Copy base to inflated
    _inflatedGrid.setAll(0, _grid);
    if (inflateCells <= 0) return;

    for (int y = 0; y < height; y++) {
      for (int x = 0; x < width; x++) {
        if (_grid[y * width + x] != occupied) continue;

        for (int dy = -inflateCells; dy <= inflateCells; dy++) {
          final ny = y + dy;
          if (ny < 0 || ny >= height) continue;
          for (int dx = -inflateCells; dx <= inflateCells; dx++) {
            final nx = x + dx;
            if (nx < 0 || nx >= width) continue;
            _inflatedGrid[ny * width + nx] = occupied;
          }
        }
      }
    }
  }

  double get exploredPercentage {
    int known = 0;
    for (int i = 0; i < _grid.length; i++) {
      if (_grid[i] != unknown) known++;
    }
    return (known / _grid.length) * 100.0;
  }

  Uint8List get rawGrid => _grid;
  Uint8List get rawInflatedGrid => _inflatedGrid;
}
