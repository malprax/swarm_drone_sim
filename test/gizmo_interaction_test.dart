import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:swarm_drone_sim/controllers/simulation_controller.dart';
import 'package:swarm_drone_sim/controllers/ui_controller.dart';
import 'package:swarm_drone_sim/models/arena_map.dart';
import 'package:swarm_drone_sim/models/vector2.dart';

void main() {
  group('Gizmo & Wall Clamping Interaction Tests', () {
    late SimulationController sim;
    late UIController ui;

    setUp(() {
      Get.reset();
      sim = Get.put(SimulationController());
      ui = Get.put(UIController());
    });

    test('ArenaMap.clampPositionAgainstWalls blocks wall penetration', () {
      // wall_bottom is at y in [-4.607, -4.124]
      const currentSafe = Vector2(0.0, -2.0);

      // Attempt to move straight into wall_bottom at y = -4.3
      const blockedY = Vector2(0.0, -4.3);
      final clamped = ArenaMap.clampPositionAgainstWalls(blockedY, 0.35, currentSafe);

      // Clamped position must NOT overlap any wall
      expect(ArenaMap.overlapsWall(clamped, 0.35), isFalse);
    });

    test('ArenaMap.clampPositionAgainstWalls allows sliding along clear axis', () {
      // Current safe at (0.0, -2.0)
      const currentSafe = Vector2(0.0, -2.0);
      // Proposed moves X to 3.0, but tries to push Y into wall_bottom at -4.3
      const proposed = Vector2(3.0, -4.3);

      final clamped = ArenaMap.clampPositionAgainstWalls(proposed, 0.35, currentSafe);

      // Should have slid along X while keeping safe Y
      expect(clamped.x, closeTo(3.0, 1e-4));
      expect(clamped.y, closeTo(currentSafe.y, 1e-4));
      expect(ArenaMap.overlapsWall(clamped, 0.35), isFalse);
    });

    test('UIController gizmo activation and lock/dismissal', () {
      expect(ui.gizmoMode.value, equals(GizmoMode.none));

      // Activate Target Gizmo
      ui.activateTargetGizmo();
      expect(ui.gizmoMode.value, equals(GizmoMode.target));
      expect(ui.activeGizmoAxis.value, equals(GizmoAxis.none));

      // Lock and Dismiss
      ui.lockAndDismissGizmos();
      expect(ui.gizmoMode.value, equals(GizmoMode.none));

      // Activate Drone Gizmos
      ui.activateDroneGizmos(1);
      expect(ui.gizmoMode.value, equals(GizmoMode.drones));
      expect(ui.activeGizmoDroneIndex.value, equals(1));

      ui.lockAndDismissGizmos();
      expect(ui.gizmoMode.value, equals(GizmoMode.none));
    });

    test('SimulationController moveTargetSafely and moveDroneSafely', () {
      // (1.0, 1.0) is in open space clear of walls
      const newTarget = Vector2(1.0, 1.0);
      sim.moveTargetSafely(newTarget);

      expect(sim.targetPosition.value.x, closeTo(1.0, 1e-4));
      expect(sim.targetPosition.value.y, closeTo(1.0, 1e-4));
      expect(ArenaMap.overlapsWall(sim.targetPosition.value, 0.35), isFalse);

      // Move Drone 0 safely to (-2.0, 1.0)
      const newDronePos = Vector2(-2.0, 1.0);
      sim.moveDroneSafely(0, newDronePos);

      expect(sim.drones[0].position.x, closeTo(-2.0, 1e-4));
      expect(sim.drones[0].position.y, closeTo(1.0, 1e-4));
      expect(sim.drones[0].startPosition, equals(sim.drones[0].position));
      expect(sim.drones[0].returnHomePos, equals(sim.drones[0].position));
    });

    test('Randomize target and drones works even when simState was complete', () {
      sim.simState.value = SimState.complete;

      sim.randomizeTargetPosition();
      expect(sim.simState.value, equals(SimState.standby));
      expect(ArenaMap.overlapsWall(sim.targetPosition.value, 0.30), isFalse);

      sim.simState.value = SimState.complete;
      sim.randomizeDronePositions();
      expect(sim.simState.value, equals(SimState.standby));
      for (final d in sim.activeDrones) {
        expect(ArenaMap.overlapsWall(d.position, d.droneRadius), isFalse);
      }
    });

    test('Swarm size selection (1, 2, 3) and role assignment', () {
      // Test 1 Drone: Must be Leader with Yellow LEDs
      sim.setActiveDroneCount(1);
      expect(sim.activeDroneCount.value, equals(1));
      expect(sim.activeDrones.length, equals(1));
      expect(sim.activeDrones[0].role.name, equals('leader'));
      expect(sim.activeDrones[0].ledColor, equals(const Color(0xFFFFD600)));

      // Test 2 Drones: 1 Leader (Yellow), 1 Member (Blue)
      sim.setActiveDroneCount(2);
      expect(sim.activeDroneCount.value, equals(2));
      expect(sim.activeDrones.length, equals(2));
      expect(sim.activeDrones[0].role.name, equals('leader'));
      expect(sim.activeDrones[0].ledColor, equals(const Color(0xFFFFD600)));
      expect(sim.activeDrones[1].role.name, equals('member'));
      expect(sim.activeDrones[1].ledColor, equals(const Color(0xFF00E5FF)));

      // Test 3 Drones: 1 Leader (Yellow), 2 Members (Blue)
      sim.setActiveDroneCount(3);
      expect(sim.activeDroneCount.value, equals(3));
      expect(sim.activeDrones.length, equals(3));
      expect(sim.activeDrones.where((d) => d.role.name == 'leader').length, equals(1));
      expect(sim.activeDrones.where((d) => d.role.name == 'member').length, equals(2));
    });
  });
}
