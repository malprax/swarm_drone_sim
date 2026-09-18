import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'arena_map.dart';
import 'astar_2d.dart';
import 'frontier_planner.dart';
import 'grid_map_2d.dart';
import 'vector2.dart';

enum DroneRole { leader, member }
enum DroneStatus { search, chase, found, returnHome, arrived }
enum DroneFrameType { mini, fpv, standardQuad, cinewhoop }

extension DroneFrameTypeExt on DroneFrameType {
  String get displayName {
    switch (this) {
      case DroneFrameType.mini:
        return 'Mini (Compact)';
      case DroneFrameType.fpv:
        return 'FPV (X-Frame)';
      case DroneFrameType.standardQuad:
        return 'Standard Quad';
      case DroneFrameType.cinewhoop:
        return 'Cinewhoop (Ducted)';
    }
  }
}

/// Hardware specifications for each drone
class DroneHardwareSpec {
  final String companionComputer = 'Raspberry Pi 4 (4GB RAM)';
  final String flightController = 'Pixhawk 6 (STM32H7, Dual IMU)';
  final int lidarCount = 5; // Front, Left, Right, Back, 45° Angle
  final String opticalFlow = 'PMW3901 Optical Flow Sensor';
  final String uwbModule = 'Decawave DW3000 UWB (Ranging & Positioning)';
  final String esc = '4-in-1 45A DShot ESC';
  final String battery = '4S 1500mAh LiPo Pack';

  const DroneHardwareSpec();
}

/// Drone sensor ray for rendering
class SensorRay {
  final Vector2 start;
  final Vector2 end;
  final bool hitWall;
  final String sensorName;

  const SensorRay(this.start, this.end, this.hitWall, {this.sensorName = 'LiDAR'});
}

/// Drone simulation model with hardware components, 4-pole LEDs, and local SLAM map
class DroneModel {
  final String name;
  final int teamIndex;
  DroneRole role;
  DroneStatus status = DroneStatus.search;
  DroneFrameType frameType;
  final DroneHardwareSpec hardware = const DroneHardwareSpec();

  Vector2 position;
  Vector2 startPosition;
  Vector2 returnHomePos;
  Vector2 smoothedDir = const Vector2(1, 0);
  double headingAngle = 0.0; // radians
  double propellerAngle = 0.0;

  // Speeds & limits
  double moveSpeed = 2.0;
  double turnSpeedDeg = 220.0;
  double steeringSmoothing = 10.0;
  double droneRadius = 0.22;

  // Collision stats
  int wallCollisionCount = 0;
  int droneCollisionCount = 0;

  // Sensing parameters (5 LiDARs + Optical Flow + UWB)
  double senseRange = 3.0; // 5 LiDAR range
  double detectRange = 6.0;
  double foundDistance = 0.35;
  double waypointArriveDistance = 0.35;
  double homeArriveDistance = 0.50;

  // 5 LiDAR angles relative to forward heading: Front (0°), Left (90°), Right (-90°), Rear (180°), Angle (45°)
  static const List<double> lidarAngles = [
    0.0,
    math.pi / 2.0,
    -math.pi / 2.0,
    math.pi,
    math.pi / 4.0,
  ];

  // Smart launch dispersal
  bool enableLaunchDispersal = true;
  double launchDisperseSeconds = 2.0;
  double launchMinInterDroneDistance = 1.6;
  double launchAwayFromHomeWeight = 1.2;
  double launchRepulsionWeight = 3.0;
  double launchHeadingBiasWeight = 0.7;
  double launchJitterWeight = 0.20;
  double missionStartTime = -999.0;
  Vector2 preferredBiasDir = Vector2.zero;

  // Separation
  double separationRadius = 0.90;
  double separationSteerWeight = 1.8;

  // Corner avoidance
  double cornerAvoidProbe = 0.35;
  double cornerHoldUntil = 0.0;

  // Navigation state
  List<Vector2Int> pathCells = [];
  int pathIndex = 0;
  double replanTimer = 0.0;
  final Map<Vector2Int, double> frontierCooldown = {};
  List<SensorRay> currentSensorRays = [];

  // Historic breadcrumb mission path
  final List<Vector2> missionPath = [];
  double _lastPathRecordTime = 0.0;

  // Individual AI Local Room Map (SLAM occupancy grid)
  late final GridMap2D localMap;

  bool isStopped = false;
  bool isStandby = true;

  DroneModel({
    required this.name,
    required this.teamIndex,
    required this.role,
    required this.position,
    Vector2? returnHomePos,
    this.frameType = DroneFrameType.fpv,
  })  : startPosition = position,
        returnHomePos = returnHomePos ?? position {
    smoothedDir = _computeInitialBiasDir();
    headingAngle = smoothedDir.angle;
    localMap = GridMap2D();
    missionPath.add(position);
  }

  /// 4-pole LED Color: Yellow (Leader), Blue (Member)
  Color get ledColor => role == DroneRole.leader
      ? const Color(0xFFFFD600) // Vibrant Yellow
      : const Color(0xFF00E5FF); // Vibrant Blue / Cyan

  String get roleLabel => role == DroneRole.leader ? 'LEADER (Yellow)' : 'MEMBER (Blue)';

  /// Returns 4 cardinal pole offsets (East/Front, West/Back, North/Right, South/Left) relative to drone heading
  List<Vector2> getPoleLedOffsets() {
    final d = droneRadius * 0.32;
    return [
      Vector2(d, 0),
      Vector2(-d, 0),
      Vector2(0, -d),
      Vector2(0, d),
    ];
  }

  /// Record current position to mission search trail
  void recordMissionStep() {
    if (missionPath.isEmpty || missionPath.last.distance(position) >= 0.05) {
      missionPath.add(position);
    }
  }

  void markMissionStarted(double currentTime) {
    missionStartTime = currentTime;
    preferredBiasDir = _computeInitialBiasDir();
    isStandby = false;
    isStopped = false;
    status = DroneStatus.search;
    missionPath.clear();
    missionPath.add(position);
  }

  void reset(Vector2 newPos, {DroneRole? newRole, bool clearLocalMap = true}) {
    position = newPos;
    startPosition = newPos;
    returnHomePos = newPos;
    if (newRole != null) role = newRole;

    status = DroneStatus.search;
    isStopped = false;
    isStandby = true;
    wallCollisionCount = 0;
    droneCollisionCount = 0;
    pathCells.clear();
    pathIndex = 0;
    replanTimer = 0.0;
    frontierCooldown.clear();
    currentSensorRays.clear();
    cornerHoldUntil = 0.0;
    missionStartTime = -999.0;
    preferredBiasDir = _computeInitialBiasDir();
    smoothedDir = preferredBiasDir;
    headingAngle = smoothedDir.angle;

    missionPath.clear();
    missionPath.add(position);
    _lastPathRecordTime = 0.0;

    if (clearLocalMap) {
      localMap.clear();
    }
  }

  Vector2 _computeInitialBiasDir() {
    final a = teamIndex * (math.pi * 2.0 / 3.0); // 0, 120, 240 deg
    return Vector2(math.cos(a), math.sin(a)).normalized;
  }

  bool isInLaunchDispersal(double currentTime, List<DroneModel> allDrones) {
    if (!enableLaunchDispersal) return false;
    if (missionStartTime < 0) return false;

    final elapsed = currentTime - missionStartTime;
    if (elapsed > launchDisperseSeconds) return false;

    // Finish earlier if already far enough from peers
    for (final other in allDrones) {
      if (identical(other, this)) continue;
      if (position.distance(other.position) < launchMinInterDroneDistance) {
        return true;
      }
    }
    return false;
  }

  /// Update individual local map & global shared map using 5 LiDAR sensors + Optical Flow
  void tickMap(GridMap2D globalMap) {
    // Current cell free in local & global maps
    final currCell = localMap.worldToCellSafe(position);
    if (currCell != null) {
      localMap.setFree(currCell);
      globalMap.setFree(currCell);
    }

    final rays = <SensorRay>[];
    const sensorNames = ['Front LiDAR', 'Left LiDAR', 'Right LiDAR', 'Rear LiDAR', 'Angle LiDAR'];

    for (int i = 0; i < lidarAngles.length; i++) {
      final ang = headingAngle + lidarAngles[i];
      final dir = Vector2(math.cos(ang), math.sin(ang));

      final hit = ArenaMap.raycast(position, dir, senseRange);
      final hitDist = hit != null ? hit.distance : senseRange;
      final rayEnd = position + dir * hitDist;

      rays.add(SensorRay(position, rayEnd, hit != null, sensorName: sensorNames[i]));

      // Mark free cells along ray in both local and global map
      final steps = (hitDist / localMap.cellSize).ceil();
      for (int s = 1; s <= steps; s++) {
        final p = position + dir * math.min(hitDist, s * localMap.cellSize);
        final c = localMap.worldToCellSafe(p);
        if (c != null) {
          localMap.setFree(c);
          globalMap.setFree(c);
        }
      }

      // Mark occupied cell at hit point
      if (hit != null) {
        final occPoint = hit.point + (-dir) * 0.02;
        final occCell = localMap.worldToCellSafe(occPoint);
        if (occCell != null) {
          localMap.setOccupied(occCell);
          globalMap.setOccupied(occCell);
        }
      }
    }

    localMap.rebuildInflation();
    globalMap.rebuildInflation();
    currentSensorRays = rays;
  }

  /// Main physics and decision tick
  void updateTick({
    required double dt,
    required double currentTime,
    required GridMap2D map,
    required Vector2 targetPos,
    required List<DroneModel> allDrones,
    required Function(DroneModel) onTargetFound,
    required Function(DroneModel) onArrivedHome,
  }) {
    if (isStopped || isStandby) return;

    // Decay frontier cooldowns
    frontierCooldown.removeWhere((cell, time) => (time - dt) <= 0);
    frontierCooldown.updateAll((cell, time) => time - dt);

    // Record historic mission path (every 0.1s or 0.2m)
    if (currentTime - _lastPathRecordTime >= 0.1) {
      if (missionPath.isEmpty || missionPath.last.distance(position) >= 0.15) {
        missionPath.add(position);
        _lastPathRecordTime = currentTime;
      }
    }

    // Update map with 5 LiDAR sensors
    tickMap(map);

    // Check target Line Of Sight
    final distToTarget = position.distance(targetPos);
    final hasLos = ArenaMap.hasLineOfSight(position, targetPos, detectRange);

    if (status != DroneStatus.returnHome && status != DroneStatus.arrived) {
      if (hasLos) {
        if (distToTarget <= foundDistance) {
          status = DroneStatus.found;
          onTargetFound(this);
          forceReturnHome(map);
          return;
        } else {
          status = DroneStatus.chase;
        }
      } else {
        status = DroneStatus.search;
      }
    }

    // Check return arrival
    if (status == DroneStatus.returnHome) {
      if (position.distance(returnHomePos) <= homeArriveDistance) {
        status = DroneStatus.arrived;
        isStopped = true;
        onArrivedHome(this);
        return;
      }
    }

    // Advance path waypoints
    _advanceWaypoint(map);

    // Decide steering direction
    Vector2 desiredDir = _decideDesiredDirection(
      currentTime: currentTime,
      map: map,
      targetPos: targetPos,
      allDrones: allDrones,
      hasLos: hasLos,
    );

    // Apply corner avoidance
    desiredDir = _applyCornerAvoid(desiredDir);

    // Apply separation steering from other drones
    desiredDir = _applySeparation(desiredDir, allDrones);

    // Smooth direction
    final tSmooth = 1.0 - math.exp(-steeringSmoothing * dt);
    smoothedDir = Vector2.lerp(smoothedDir, desiredDir, tSmooth);
    if (smoothedDir.sqrMagnitude < 1e-5) smoothedDir = desiredDir;
    smoothedDir = smoothedDir.normalized;

    // Rotate towards smoothedDir
    final targetAngle = smoothedDir.angle;
    double angleDiff = targetAngle - headingAngle;
    while (angleDiff > math.pi) {
      angleDiff -= 2 * math.pi;
    }
    while (angleDiff < -math.pi) {
      angleDiff += 2 * math.pi;
    }

    final maxTurn = (turnSpeedDeg * math.pi / 180.0) * dt;
    final turnStep = angleDiff.clamp(-maxTurn, maxTurn);
    headingAngle += turnStep;

    // Apply depenetration against other drones
    _applyDepenetration(allDrones);

    // Move forward with wall collision check
    final forward = Vector2(math.cos(headingAngle), math.sin(headingAngle));
    final stepDist = moveSpeed * dt;

    final wallHit = ArenaMap.circleCast(
      position,
      droneRadius,
      forward,
      stepDist + 0.02,
    );

    if (wallHit == null) {
      position = position + forward * stepDist;
    } else {
      wallCollisionCount++;
      final safeDist = math.max(0.0, wallHit.distance - 0.02);
      position = position + forward * math.min(safeDist, stepDist);

      // Corner escape nudge if stuck
      final side = _chooseSaferSide();
      smoothedDir = (forward * 0.2 + side * 1.2).normalized;
      headingAngle = smoothedDir.angle;
    }

    // Animate propellers
    propellerAngle = (propellerAngle + (360.0 + moveSpeed * 720.0) * dt) % 360.0;
  }

  Vector2 _decideDesiredDirection({
    required double currentTime,
    required GridMap2D map,
    required Vector2 targetPos,
    required List<DroneModel> allDrones,
    required bool hasLos,
  }) {
    // 1. RETURN HOME
    if (status == DroneStatus.returnHome) {
      _planPathTo(map, returnHomePos);
      if (pathCells.isNotEmpty && pathIndex < pathCells.length) {
        final wp = map.cellToWorldCenter(pathCells[pathIndex]);
        final toWp = wp - position;
        if (toWp.sqrMagnitude > 1e-4) return toWp.normalized;
      }
      final toHome = returnHomePos - position;
      return toHome.sqrMagnitude > 1e-4 ? toHome.normalized : smoothedDir;
    }

    // 2. CHASE TARGET
    if (status == DroneStatus.chase && hasLos) {
      final toTarget = targetPos - position;
      return toTarget.sqrMagnitude > 1e-4 ? toTarget.normalized : smoothedDir;
    }

    // 3. SMART LAUNCH DISPERSAL
    if (isInLaunchDispersal(currentTime, allDrones)) {
      return _decideLaunchDispersalDirection(allDrones);
    }

    // 4. FRONTIER EXPLORATION
    replanTimer -= 0.02;
    final needReplan = pathCells.isEmpty || pathIndex >= pathCells.length || replanTimer <= 0;

    if (needReplan) {
      replanTimer = 0.4;
      // Search on local map first for autonomous AI exploration
      final startCell = localMap.worldToCellSafe(position) ?? map.worldToCellSafe(position);
      if (startCell != null) {
        final frontier = FrontierPlanner.findBestFrontier(
          localMap,
          startCell,
          frontierCooldown,
        ) ?? FrontierPlanner.findBestFrontier(
          map,
          startCell,
          frontierCooldown,
        );

        if (frontier != null) {
          frontierCooldown[frontier] = 2.5;
          final path = AStar2D.findPath(map, startCell, frontier);
          if (path.isNotEmpty) {
            pathCells = path;
            pathIndex = 0;
          }
        }
      }
    }

    if (pathCells.isNotEmpty && pathIndex < pathCells.length) {
      final wp = map.cellToWorldCenter(pathCells[pathIndex]);
      final toWp = wp - position;
      if (toWp.sqrMagnitude > 1e-4) {
        final normWp = toWp.normalized;
        return (normWp * 0.85 + preferredBiasDir * 0.15).normalized;
      }
    }

    // Fallback forward + bias
    return (smoothedDir * 0.85 + preferredBiasDir * 0.15).normalized;
  }

  Vector2 _decideLaunchDispersalDirection(List<DroneModel> allDrones) {
    Vector2 awayHome = position - startPosition;
    if (awayHome.sqrMagnitude < 1e-4) awayHome = preferredBiasDir;
    awayHome = awayHome.normalized;

    Vector2 repulse = Vector2.zero;
    int count = 0;

    for (final other in allDrones) {
      if (identical(other, this)) continue;
      final d = position.distance(other.position);
      if (d < launchMinInterDroneDistance && d > 1e-4) {
        final delta = (position - other.position) / d;
        final w = (launchMinInterDroneDistance - d) / launchMinInterDroneDistance;
        repulse = repulse + delta * w;
        count++;
      }
    }

    if (count > 0 && repulse.sqrMagnitude > 1e-4) {
      repulse = repulse.normalized;
    }

    final jitter = Vector2(math.sin(position.x * 5), math.cos(position.y * 5)) * launchJitterWeight;

    final desired = awayHome * launchAwayFromHomeWeight +
        repulse * launchRepulsionWeight +
        preferredBiasDir * launchHeadingBiasWeight +
        jitter;

    return desired.sqrMagnitude > 1e-4 ? desired.normalized : awayHome;
  }

  void _planPathTo(GridMap2D map, Vector2 worldGoal) {
    replanTimer -= 0.02;
    if (pathCells.isNotEmpty && replanTimer > 0) return;

    replanTimer = 0.5;
    final startCell = map.worldToCellSafe(position);
    final goalCell = map.worldToCellSafe(worldGoal);

    if (startCell != null && goalCell != null) {
      final path = AStar2D.findPath(map, startCell, goalCell);
      if (path.isNotEmpty) {
        pathCells = path;
        pathIndex = 0;
      }
    }
  }

  void _advanceWaypoint(GridMap2D map) {
    if (pathCells.isEmpty || pathIndex >= pathCells.length) return;
    final wp = map.cellToWorldCenter(pathCells[pathIndex]);
    if (position.distance(wp) <= waypointArriveDistance) {
      pathIndex++;
    }
  }

  Vector2 _applyCornerAvoid(Vector2 desired) {
    final forward = Vector2(math.cos(headingAngle), math.sin(headingAngle));
    final hit = ArenaMap.circleCast(
      position,
      droneRadius,
      forward,
      cornerAvoidProbe,
    );
    if (hit == null) return desired;

    final left = Vector2(-forward.y, forward.x);
    final right = Vector2(forward.y, -forward.x);

    final hitL = ArenaMap.raycast(position, left, cornerAvoidProbe);
    final hitR = ArenaMap.raycast(position, right, cornerAvoidProbe);

    final dL = hitL != null ? hitL.distance : cornerAvoidProbe;
    final dR = hitR != null ? hitR.distance : cornerAvoidProbe;

    final side = (dL >= dR) ? left : right;
    return (desired * 0.55 + side * 0.85).normalized;
  }

  Vector2 _chooseSaferSide() {
    final forward = Vector2(math.cos(headingAngle), math.sin(headingAngle));
    final left = Vector2(-forward.y, forward.x);
    final right = Vector2(forward.y, -forward.x);

    final hitL = ArenaMap.raycast(position, left, 1.0);
    final hitR = ArenaMap.raycast(position, right, 1.0);

    final dL = hitL != null ? hitL.distance : 1.0;
    final dR = hitR != null ? hitR.distance : 1.0;

    return dL >= dR ? left : right;
  }

  Vector2 _applySeparation(Vector2 desired, List<DroneModel> allDrones) {
    Vector2 repulse = Vector2.zero;
    int count = 0;

    for (final other in allDrones) {
      if (identical(other, this)) continue;
      final d = position.distance(other.position);
      if (d < separationRadius && d > 1e-4) {
        final delta = (position - other.position) / d;
        final w = (separationRadius - d) / separationRadius;
        repulse = repulse + delta * w;
        count++;
      }
    }

    if (count == 0) return desired;
    repulse = repulse / count.toDouble();
    final combined = desired + repulse * separationSteerWeight;
    return combined.sqrMagnitude > 1e-4 ? combined.normalized : desired;
  }

  void _applyDepenetration(List<DroneModel> allDrones) {
    for (final other in allDrones) {
      if (identical(other, this)) continue;
      final d = position.distance(other.position);
      final minDist = droneRadius * 2.0;
      if (d < minDist && d > 1e-4) {
        droneCollisionCount++;
        final penetration = minDist - d;
        final normal = (position - other.position) / d;
        position = position + normal * (penetration * 0.5);
      }
    }
  }

  void forceReturnHome(GridMap2D map) {
    if (status == DroneStatus.arrived) return;
    status = DroneStatus.returnHome;
    pathCells.clear();
    pathIndex = 0;
    _planPathTo(map, returnHomePos);
  }

  /// Calculates percentage of arena cells explored by this drone
  double get exploredPercentage {
    int discovered = 0;
    final total = localMap.width * localMap.height;
    for (int i = 0; i < total; i++) {
      if (localMap.rawGrid[i] != GridMap2D.unknown) {
        discovered++;
      }
    }
    return (discovered / total * 100.0).clamp(0.0, 100.0);
  }
}
