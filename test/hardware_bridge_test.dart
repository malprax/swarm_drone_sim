import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:swarm_drone_sim/controllers/simulation_controller.dart';
import 'package:swarm_drone_sim/controllers/ui_controller.dart';
import 'package:swarm_drone_sim/models/drone_model.dart';
import 'package:swarm_drone_sim/models/vector2.dart';
import 'package:swarm_drone_sim/services/hardware_bridge_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('HardwareBridgeService & RealDronePacket Tests', () {
    test('RealDronePacket.fromJson parses complete telemetry payload', () {
      final jsonMap = {
        'type': 'telemetry',
        'drone_id': 'swarm_drone_01',
        'timestamp': 1726650000.123,
        'position': {'x': 1.25, 'y': -2.50, 'z': 0.85},
        'heading': {'yaw_deg': 45.0, 'yaw_rad': 0.7854},
        'battery': {'voltage': 15.6, 'percentage': 82.0},
        'status': 'flying',
        'sensors': {
          'lidar_5x': [1.2, 2.5, 0.8, 3.0, 1.5],
        },
      };

      final packet = RealDronePacket.fromJson(jsonMap);

      expect(packet.droneId, equals('swarm_drone_01'));
      expect(packet.x, closeTo(1.25, 0.001));
      expect(packet.y, closeTo(-2.50, 0.001));
      expect(packet.z, closeTo(0.85, 0.001));
      expect(packet.yawDeg, closeTo(45.0, 0.01));
      expect(packet.batteryVoltage, closeTo(15.6, 0.001));
      expect(packet.batteryPercentage, closeTo(82.0, 0.001));
      expect(packet.status, equals('flying'));
      expect(packet.lidarDistances.length, equals(5));
      expect(packet.lidarDistances[0], closeTo(1.2, 0.01));
      expect(packet.lidarDistances[1], closeTo(2.5, 0.01));
      expect(packet.lidarDistances[2], closeTo(0.8, 0.01));
      expect(packet.lidarDistances[3], closeTo(3.0, 0.01));
      expect(packet.lidarDistances[4], closeTo(1.5, 0.01));
    });

    test('RealDronePacket.fromJson handles empty/partial payload gracefully', () {
      final packet = RealDronePacket.fromJson({});

      expect(packet.droneId, equals('rpi4_drone'));
      expect(packet.x, equals(0.0));
      expect(packet.y, equals(0.0));
      expect(packet.z, equals(0.0));
      expect(packet.yawDeg, equals(0.0));
      expect(packet.status, equals('standby'));
      expect(packet.lidarDistances.length, equals(5));
      expect(packet.lidarDistances.every((d) => d == 0.0), isTrue);
    });
  });

  group('SimulationController Real Drone Mode & SLAM Tests', () {
    late SimulationController sim;

    setUp(() {
      Get.reset();
      sim = Get.put(SimulationController());
      Get.put(UIController());
    });

    tearDown(() {
      sim.stopRun();
      Get.reset();
    });

    test('Switching data source between simulation and real drone', () {
      expect(sim.isRealDroneMode, isFalse);
      expect(sim.activeDroneCount.value, equals(3));

      // Switch to real drone mode
      sim.setDataSource(AppDataSource.realDrone);
      expect(sim.isRealDroneMode, isTrue);
      expect(sim.activeDroneCount.value, equals(1));
      expect(sim.activeDrones.first.name, contains('Real Drone'));
      expect(sim.activeDrones.first.role, equals(DroneRole.leader));

      // Switch back to virtual simulation mode
      sim.setDataSource(AppDataSource.simulation);
      expect(sim.isRealDroneMode, isFalse);
      expect(sim.activeDroneCount.value, equals(3));
      expect(sim.drones[0].name, equals('Drone1'));
    });

    test('Live telemetry updates position, heading, and SLAM occupancy map', () {
      sim.setDataSource(AppDataSource.realDrone);

      final packet = RealDronePacket(
        droneId: 'rpi4_drone',
        timestamp: 100.0,
        position: const Vector2(0.0, 0.0),
        altitude: 0.5,
        headingRad: 0.0,
        batteryVoltage: 16.2,
        batteryPercentage: 90.0,
        status: 'active',
        lidarDistances: [1.0, 1.5, 2.0, 2.5, 1.2],
      );

      sim.onRealDroneTelemetry(packet);

      final drone = sim.activeDrones.first;
      expect(drone.position.x, closeTo(0.0, 0.001));
      expect(drone.position.y, closeTo(0.0, 0.001));
      expect(drone.batteryVoltage, closeTo(16.2, 0.001));
      expect(drone.currentSensorRays.length, equals(5));

      // Check SLAM map updates
      final originCell = sim.map.worldToCellSafe(const Vector2(0.0, 0.0));
      expect(originCell, isNotNull);
      expect(sim.map.isFree(originCell!), isTrue);

      // 0 deg LiDAR is pointing forward along +X with distance 1.0m
      final hitPos = const Vector2(1.0, 0.0);
      final hitCell = sim.map.worldToCellSafe(hitPos);
      expect(hitCell, isNotNull);
      expect(sim.map.isOccupied(hitCell!), isTrue);

      // Local drone map should also be occupied at hit cell
      expect(drone.localMap.isOccupied(hitCell), isTrue);
    });

    test('clearRealDroneMap clears both global and local occupancy maps', () {
      sim.setDataSource(AppDataSource.realDrone);

      final packet = RealDronePacket(
        droneId: 'rpi4_drone',
        timestamp: 101.0,
        position: const Vector2(0.0, 0.0),
        altitude: 0.5,
        headingRad: 0.0,
        batteryVoltage: 16.2,
        batteryPercentage: 90.0,
        status: 'active',
        lidarDistances: [1.0, 1.5, 2.0, 2.5, 1.2],
      );
      sim.onRealDroneTelemetry(packet);

      expect(sim.map.scannedCellsCount, greaterThan(0));

      // Clear map
      sim.clearRealDroneMap();
      expect(sim.map.scannedCellsCount, equals(0));
      expect(sim.activeDrones.first.localMap.scannedCellsCount, equals(0));
    });
  });
}
