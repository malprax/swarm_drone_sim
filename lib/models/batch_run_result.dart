import 'vector2.dart';

/// Records one Monte Carlo run result for simulation and CSV export
class BatchRunResult {
  final int runIndex;
  final String status; // "OK" or "FAIL_TIMEOUT"
  final String foundDrone;
  final String foundRole;
  final double timeToFind;
  final double timeTotal;
  final Vector2 targetPos;
  final int wallCollisions;
  final int droneCollisions;

  const BatchRunResult({
    required this.runIndex,
    required this.status,
    required this.foundDrone,
    required this.foundRole,
    required this.timeToFind,
    required this.timeTotal,
    required this.targetPos,
    required this.wallCollisions,
    required this.droneCollisions,
  });

  String toCsvLine() {
    return '$runIndex,$status,$foundDrone,$foundRole,'
        '${timeToFind.toStringAsFixed(3)},'
        '${timeTotal.toStringAsFixed(3)},'
        '${targetPos.x.toStringAsFixed(3)},'
        '${targetPos.y.toStringAsFixed(3)},'
        '$wallCollisions,$droneCollisions';
  }

  static String get csvHeader =>
      'run,status,foundDrone,foundRole,timeToFind,timeTotal,targetX,targetY,wallCollisions,droneCollisions';
}
