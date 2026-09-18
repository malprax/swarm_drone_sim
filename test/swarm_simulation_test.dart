import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:swarm_drone_sim/models/arena_map.dart';
import 'package:swarm_drone_sim/models/astar_2d.dart';
import 'package:swarm_drone_sim/models/batch_run_result.dart';
import 'package:swarm_drone_sim/models/drone_model.dart';
import 'package:swarm_drone_sim/models/frontier_planner.dart';
import 'package:swarm_drone_sim/models/grid_map_2d.dart';
import 'package:swarm_drone_sim/models/vector2.dart';

void main() {
  group('Vector2 and Rect2D Math Tests', () {
    test('Vector2 basic operations', () {
      const v1 = Vector2(3, 4);
      const v2 = Vector2(1, 2);

      expect(v1 + v2, const Vector2(4, 6));
      expect(v1 - v2, const Vector2(2, 2));
      expect(v1.magnitude, closeTo(5.0, 1e-5));
      expect(v1.normalized.magnitude, closeTo(1.0, 1e-5));
      expect(v1.distance(const Vector2(3, 8)), closeTo(4.0, 1e-5));
    });

    test('Rect2D raycasting', () {
      const box = Rect2D(0, 0, 2, 2, name: 'TestBox');
      const origin = Vector2(-2, 1);
      const dir = Vector2(1, 0);

      final hit = box.raycast(origin, dir, 5.0);
      expect(hit, isNotNull);
      expect(hit!.distance, closeTo(2.0, 1e-5));
      expect(hit.point.x, closeTo(0.0, 1e-5));
      expect(hit.point.y, closeTo(1.0, 1e-5));
      expect(hit.normal.x, closeTo(-1.0, 1e-5));
    });

    test('Rect2D circle collision', () {
      const box = Rect2D(0, 0, 2, 2);
      expect(box.overlapsCircle(const Vector2(1, 1), 0.5), isTrue);
      expect(box.overlapsCircle(const Vector2(2.2, 1), 0.3), isTrue);
      expect(box.overlapsCircle(const Vector2(5, 5), 0.5), isFalse);
    });
  });

  group('GridMap2D and Inflation Tests', () {
    test('Coordinate conversion', () {
      final map = GridMap2D(
        cellSize: 0.3,
        width: 120,
        height: 120,
        originWorld: const Vector2(-18.0, -18.0),
      );

      final cell = map.worldToCellSafe(const Vector2(0, 0));
      expect(cell, isNotNull);
      expect(cell!.x, equals(60));
      expect(cell.y, equals(60));

      final world = map.cellToWorldCenter(cell);
      expect(world.x, closeTo(0.15, 1e-5));
      expect(world.y, closeTo(0.15, 1e-5));
    });

    test('SetFree, SetOccupied and Inflation', () {
      final map = GridMap2D(
        cellSize: 0.3,
        width: 20,
        height: 20,
        originWorld: const Vector2(0, 0),
        inflateCells: 1,
      );

      final c = const Vector2Int(5, 5);
      map.setOccupied(c);
      map.rebuildInflation();

      expect(map.getCell(c), equals(GridMap2D.occupied));
      expect(map.getCellInflated(c), equals(GridMap2D.occupied));
      // Neighbor should be inflated to occupied
      expect(map.getCellInflated(const Vector2Int(5, 6)), equals(GridMap2D.occupied));
      expect(map.getCellInflated(const Vector2Int(4, 5)), equals(GridMap2D.occupied));
    });
  });

  group('A* 2D Pathfinding Tests', () {
    test('A* finds clear path between free cells', () {
      final map = GridMap2D(
        cellSize: 0.3,
        width: 20,
        height: 20,
        originWorld: const Vector2(0, 0),
        inflateCells: 0,
      );

      // Mark line of cells free
      for (int x = 2; x <= 8; x++) {
        for (int y = 2; y <= 8; y++) {
          map.setFree(Vector2Int(x, y));
        }
      }
      map.rebuildInflation();

      final start = const Vector2Int(2, 2);
      final goal = const Vector2Int(8, 8);
      final path = AStar2D.findPath(map, start, goal);

      expect(path, isNotEmpty);
      expect(path.first, equals(start));
      expect(path.last, equals(goal));
    });

    test('A* returns empty when blocked by occupied wall', () {
      final map = GridMap2D(
        cellSize: 0.3,
        width: 10,
        height: 10,
        originWorld: const Vector2(0, 0),
        inflateCells: 0,
      );

      for (int x = 0; x < 10; x++) {
        for (int y = 0; y < 10; y++) {
          map.setFree(Vector2Int(x, y));
        }
      }

      // Block middle column with wall
      for (int y = 0; y < 10; y++) {
        map.setOccupied(Vector2Int(5, y));
      }
      map.rebuildInflation();

      final start = const Vector2Int(2, 5);
      final goal = const Vector2Int(8, 5);
      final path = AStar2D.findPath(map, start, goal);

      expect(path, isEmpty);
    });
  });

  group('Frontier Exploration Tests', () {
    test('Frontier finds free cell bordering unknown cell', () {
      final map = GridMap2D(
        cellSize: 0.3,
        width: 20,
        height: 20,
        originWorld: const Vector2(0, 0),
        inflateCells: 0,
      );

      // Mark a patch free
      for (int x = 2; x <= 6; x++) {
        for (int y = 2; y <= 6; y++) {
          map.setFree(Vector2Int(x, y));
        }
      }
      map.rebuildInflation();

      final start = const Vector2Int(4, 4);
      final cooldown = <Vector2Int, double>{};
      final frontier = FrontierPlanner.findBestFrontier(map, start, cooldown);

      expect(frontier, isNotNull);
      expect(map.getCellInflated(frontier!), equals(GridMap2D.free));
    });
  });

  group('Arena & Monte Carlo Model Tests', () {
    test('ArenaMap walls exist and home base position is correct', () {
      expect(ArenaMap.walls.length, equals(12));
      expect(ArenaMap.defaultHomeBase, equals(const Vector2(-5.7, 1.4)));
      expect(ArenaMap.defaultStartPositions.length, equals(3));
    });

    test('BatchRunResult CSV serialization matches Unity format', () {
      const res = BatchRunResult(
        runIndex: 1,
        status: 'OK',
        foundDrone: 'Drone2',
        foundRole: 'Leader',
        timeToFind: 12.345,
        timeTotal: 18.765,
        targetPos: Vector2(2.5, 1.2),
        wallCollisions: 3,
        droneCollisions: 1,
      );

      final line = res.toCsvLine();
      expect(line, equals('1,OK,Drone2,Leader,12.345,18.765,2.500,1.200,3,1'));
      expect(BatchRunResult.csvHeader, equals('run,status,foundDrone,foundRole,timeToFind,timeTotal,targetX,targetY,wallCollisions,droneCollisions'));
    });

    test('DroneModel initialization and status transitions', () {
      final drone = DroneModel(
        name: 'Drone1',
        teamIndex: 0,
        role: DroneRole.leader,
        position: const Vector2(-5.7, 1.4),
      );

      expect(drone.name, equals('Drone1'));
      expect(drone.role, equals(DroneRole.leader));
      expect(drone.status, equals(DroneStatus.search));

      final map = GridMap2D();
      drone.forceReturnHome(map);
      expect(drone.status, equals(DroneStatus.returnHome));
    });
  });

  group('Custom Hardware & 4-Pole LED Tests', () {
    test('Drone hardware specifications match user requirements', () {
      final drone = DroneModel(
        name: 'Drone1',
        teamIndex: 0,
        role: DroneRole.leader,
        position: const Vector2(-5.7, 1.4),
      );

      expect(drone.hardware.companionComputer, contains('Raspberry Pi 4'));
      expect(drone.hardware.flightController, contains('Pixhawk 6'));
      expect(drone.hardware.lidarCount, equals(5));
      expect(drone.hardware.opticalFlow, contains('Optical Flow'));
      expect(drone.hardware.uwbModule, contains('DW3000'));
      expect(drone.hardware.battery, contains('4S'));
      expect(drone.hardware.esc, contains('4-in-1'));
    });

    test('4-Pole LEDs: Leader has Yellow and Member has Blue', () {
      final leader = DroneModel(
        name: 'Drone1',
        teamIndex: 0,
        role: DroneRole.leader,
        position: const Vector2(0, 0),
      );
      final member = DroneModel(
        name: 'Drone2',
        teamIndex: 1,
        role: DroneRole.member,
        position: const Vector2(0, 0),
      );

      expect(leader.ledColor, equals(const Color(0xFFFFD600))); // Yellow
      expect(member.ledColor, equals(const Color(0xFF00E5FF))); // Blue

      final poles = leader.getPoleLedOffsets();
      expect(poles.length, equals(4)); // North, South, East, West poles
    });

    test('Frame customization options', () {
      final drone = DroneModel(
        name: 'Drone1',
        teamIndex: 0,
        role: DroneRole.leader,
        position: const Vector2(0, 0),
        frameType: DroneFrameType.fpv,
      );

      expect(drone.frameType, equals(DroneFrameType.fpv));
      expect(drone.frameType.displayName, equals('FPV (X-Frame)'));

      drone.frameType = DroneFrameType.mini;
      expect(drone.frameType.displayName, equals('Mini (Compact)'));

      drone.frameType = DroneFrameType.standardQuad;
      expect(drone.frameType.displayName, equals('Standard Quad'));

      drone.frameType = DroneFrameType.cinewhoop;
      expect(drone.frameType.displayName, equals('Cinewhoop (Ducted)'));
    });
  });

  group('Pre-flight Randomizer & Room Mapping Tests', () {
    test('pickValidDronePositions places drones in rooms without wall overlap', () {
      final rand = math.Random(42);
      final positions = ArenaMap.pickValidDronePositions(rand, 3);
      expect(positions.length, equals(3));

      for (int i = 0; i < positions.length; i++) {
        final pos = positions[i];
        // Check distance to all walls
        for (final wall in ArenaMap.walls) {
          expect(wall.overlapsCircle(pos, 0.4), isFalse,
              reason: 'Drone $i overlaps with wall ${wall.name}');
        }
        // Check separation between drones
        for (int j = i + 1; j < positions.length; j++) {
          expect(pos.distance(positions[j]), greaterThanOrEqualTo(1.0),
              reason: 'Drones $i and $j too close together');
        }
      }
    });

    test('pickValidTarget places target inside arena clear of walls', () {
      final rand = math.Random(42);
      final target = ArenaMap.pickValidTarget(rand);
      expect(target.x, inInclusiveRange(-17.0, 17.0));
      expect(target.y, inInclusiveRange(-7.0, 13.0));

      for (final wall in ArenaMap.walls) {
        expect(wall.overlapsCircle(target, 0.6), isFalse,
            reason: 'Target overlaps with wall ${wall.name}');
      }
    });

    test('Independent local SLAM map and mission path recording', () {
      final drone = DroneModel(
        name: 'Drone1',
        teamIndex: 0,
        role: DroneRole.leader,
        position: const Vector2(0, 0),
      );

      expect(drone.missionPath.length, equals(1));
      expect(drone.missionPath.first, equals(const Vector2(0, 0)));
      expect(drone.exploredPercentage, equals(0.0));

      // Record path step
      drone.position = const Vector2(1, 1);
      drone.recordMissionStep();
      expect(drone.missionPath.length, equals(2));
      expect(drone.missionPath.first, equals(const Vector2(0, 0)));

      // Simulate local perception update
      drone.localMap.setFree(const Vector2Int(60, 60));
      drone.localMap.setOccupied(const Vector2Int(60, 61));
      drone.localMap.rebuildInflation();

      expect(drone.exploredPercentage, greaterThan(0.0));
    });
  });
}
