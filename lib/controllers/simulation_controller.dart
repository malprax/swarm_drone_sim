import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../models/arena_map.dart';
import '../models/batch_run_result.dart';
import '../models/drone_model.dart';
import '../models/grid_map_2d.dart';
import '../models/vector2.dart';
import '../utils/csv_helper.dart';

enum SimState { standby, running, targetFound, complete }

class SimulationController extends GetxController {
  // Swarm & Scene State
  final drones = <DroneModel>[].obs;
  final activeDroneCount = 3.obs; // 1, 2, or 3 drones

  List<DroneModel> get activeDrones => drones.take(activeDroneCount.value).toList();
  final targetPosition = const Vector2(3.0, 0.0).obs;
  final homeBase = ArenaMap.defaultHomeBase.obs;
  final simState = SimState.standby.obs;
  late GridMap2D map;

  // Real-time metrics
  final elapsedTime = 0.0.obs;
  final timeToFind = 0.0.obs;
  final leaderDroneName = ''.obs;
  final leaderDroneRole = ''.obs;
  final arrivedCount = 0.obs;
  final missionComplete = false.obs;

  // Drone Hardware & Frame Selection
  final globalFrameType = DroneFrameType.fpv.obs;

  // Simulation Controls
  final timeScale = 1.0.obs;
  final isBatchRunning = false.obs;
  final batchCurrentRun = 0.obs;
  final batchTotalRuns = 30.obs;
  final batchResults = <BatchRunResult>[].obs;

  // Configuration toggles
  final randomLeaderEachRun = true.obs;
  final randomTargetEachRun = true.obs;
  final batchRunsInput = 30.obs;
  final runTimeoutSecondsReal = 120.0.obs;

  // CSV State
  final lastCsvPath = ''.obs;
  final isCsvReady = false.obs;

  Timer? _simTimer;
  final math.Random _random = math.Random();
  bool _stopRequested = false;

  // Internal run timing
  double _currentRunTimeToFind = -1.0;

  @override
  void onInit() {
    super.onInit();
    map = GridMap2D();
    _initDrones();
    targetPosition.value = ArenaMap.pickValidTarget(_random);
  }

  @override
  void onClose() {
    _simTimer?.cancel();
    super.onClose();
  }

  void _initDrones() {
    drones.clear();
    for (int i = 0; i < 3; i++) {
      final pos = ArenaMap.defaultStartPositions[i];
      drones.add(
        DroneModel(
          name: 'Drone${i + 1}',
          teamIndex: i,
          role: i == 0 ? DroneRole.leader : DroneRole.member,
          position: pos,
          returnHomePos: pos,
          frameType: globalFrameType.value,
        ),
      );
    }
  }

  /// Change frame type for all drones
  void setGlobalFrameType(DroneFrameType type) {
    globalFrameType.value = type;
    for (final d in drones) {
      d.frameType = type;
    }
    drones.refresh();
  }

  bool get isRunning =>
      simState.value == SimState.running ||
      simState.value == SimState.targetFound ||
      isBatchRunning.value;

  /// Configure active drone count (1, 2, or 3)
  void setActiveDroneCount(int count) {
    if (isRunning) return;
    if (simState.value == SimState.complete) simState.value = SimState.standby;

    final valid = count.clamp(1, 3);
    activeDroneCount.value = valid;

    // Adjust roles properly for active drones
    if (valid == 1) {
      drones[0].role = DroneRole.leader; // 1 drone is always Yellow Leader
    } else {
      int leaderCount = 0;
      for (int i = 0; i < valid; i++) {
        if (drones[i].role == DroneRole.leader) leaderCount++;
      }
      if (leaderCount != 1) {
        for (int i = 0; i < valid; i++) {
          drones[i].role = i == 0 ? DroneRole.leader : DroneRole.member;
        }
      }
    }

    drones.refresh();
  }

  /// Randomize drone roles before flight (1 Yellow Leader, remaining Blue Members)
  void randomizePreFlightRoles([int? seed]) {
    if (isRunning) return;
    if (simState.value == SimState.complete) simState.value = SimState.standby;

    final count = activeDroneCount.value;
    if (count <= 1) {
      drones[0].role = DroneRole.leader;
      drones.refresh();
      return;
    }

    final rng = seed != null ? math.Random(seed) : _random;
    final leaderIdx = rng.nextInt(count);
    for (int i = 0; i < count; i++) {
      drones[i].role = i == leaderIdx ? DroneRole.leader : DroneRole.member;
    }
    drones.refresh();
  }

  /// Randomize active drone positions inside rooms before flight
  void randomizeDronePositions() {
    if (isRunning) return;
    if (simState.value == SimState.complete) simState.value = SimState.standby;

    final count = activeDroneCount.value;
    final newPositions = ArenaMap.pickValidDronePositions(_random, count);
    for (int i = 0; i < count; i++) {
      drones[i].reset(newPositions[i]);
    }
    drones.refresh();
  }

  /// Randomize target position inside rooms before flight
  void randomizeTargetPosition() {
    if (isRunning) return;
    if (simState.value == SimState.complete) simState.value = SimState.standby;
    targetPosition.value = ArenaMap.pickValidTarget(_random);
  }

  /// Reset active drones back to standard home pads
  void resetToDefaultPositions() {
    if (isRunning) return;
    if (simState.value == SimState.complete) simState.value = SimState.standby;
    final count = activeDroneCount.value;
    for (int i = 0; i < count; i++) {
      final pos = ArenaMap.defaultStartPositions[i];
      drones[i].reset(pos);
    }
    drones.refresh();
  }

  /// Safely move target using gizmo with wall collision avoidance
  void moveTargetSafely(Vector2 newPos) {
    if (isRunning) return;
    if (simState.value == SimState.complete) simState.value = SimState.standby;
    final clamped = ArenaMap.clampPositionAgainstWalls(
      newPos,
      0.35,
      targetPosition.value,
    );
    targetPosition.value = clamped;
  }

  /// Safely move a specific drone using gizmo with wall collision avoidance
  void moveDroneSafely(int droneIndex, Vector2 newPos) {
    if (isRunning) return;
    if (simState.value == SimState.complete) simState.value = SimState.standby;
    if (droneIndex < 0 || droneIndex >= drones.length) return;

    final drone = drones[droneIndex];
    final clamped = ArenaMap.clampPositionAgainstWalls(
      newPos,
      drone.droneRadius,
      drone.position,
    );
    drone.position = clamped;
    drone.startPosition = clamped;
    drone.returnHomePos = clamped;
    if (drone.missionPath.isNotEmpty) {
      drone.missionPath[0] = clamped;
    }
    drones.refresh();
  }

  // ===========================================================================
  // MANUAL RUN
  // ===========================================================================
  void startManualRun() {
    _stopRequested = false;
    isBatchRunning.value = false;
    _resetSimulation();

    // Randomize roles immediately before takeoff: 1 Leader (Yellow), 2 Members (Blue)
    if (randomLeaderEachRun.value) {
      randomizePreFlightRoles();
    }

    _beginMission();
    _startTicker();
  }

  void _resetSimulation() {
    map.clear();
    arrivedCount.value = 0;
    missionComplete.value = false;
    elapsedTime.value = 0.0;
    timeToFind.value = 0.0;
    _currentRunTimeToFind = -1.0;
    leaderDroneName.value = '';
    leaderDroneRole.value = '';

    for (int i = 0; i < drones.length; i++) {
      drones[i].reset(drones[i].position, clearLocalMap: true);
    }

    simState.value = SimState.standby;
    drones.refresh();
  }

  void _beginMission() {
    simState.value = SimState.running;
    for (final d in activeDrones) {
      d.markMissionStarted(elapsedTime.value);
    }
    drones.refresh();
  }

  void stopRun() {
    _stopRequested = true;
    _simTimer?.cancel();
    _simTimer = null;
    isBatchRunning.value = false;
    simState.value = SimState.standby;

    for (final d in drones) {
      d.isStopped = true;
      d.isStandby = true;
    }
    drones.refresh();
  }

  // ===========================================================================
  // SIMULATION TICKER
  // ===========================================================================
  void _startTicker() {
    _simTimer?.cancel();
    const baseIntervalMs = 16; // ~60 Hz
    _simTimer = Timer.periodic(const Duration(milliseconds: baseIntervalMs), (timer) {
      if (_stopRequested) {
        timer.cancel();
        return;
      }

      // Physics delta time adjusted by time scale
      final dt = (baseIntervalMs / 1000.0) * timeScale.value;
      _tick(dt);
    });
  }

  void _tick(double dt) {
    elapsedTime.value += dt;

    // Tick active drones
    final curDrones = activeDrones;
    for (final d in curDrones) {
      d.updateTick(
        dt: dt,
        currentTime: elapsedTime.value,
        map: map,
        targetPos: targetPosition.value,
        allDrones: curDrones,
        onTargetFound: _onDroneFoundTarget,
        onArrivedHome: _onDroneArrivedHome,
      );
    }

    drones.refresh();
  }

  void _onDroneFoundTarget(DroneModel finder) {
    if (simState.value == SimState.targetFound || simState.value == SimState.complete) {
      return;
    }

    simState.value = SimState.targetFound;
    leaderDroneName.value = finder.name;
    leaderDroneRole.value = finder.role == DroneRole.leader ? 'Leader' : 'Member';

    if (_currentRunTimeToFind < 0) {
      _currentRunTimeToFind = elapsedTime.value;
      timeToFind.value = _currentRunTimeToFind;
    }

    // Force all active drones to return home
    for (final d in activeDrones) {
      d.forceReturnHome(map);
    }
  }

  void _onDroneArrivedHome(DroneModel d) {
    arrivedCount.value++;
    if (arrivedCount.value >= activeDroneCount.value) {
      simState.value = SimState.complete;
      missionComplete.value = true;
      if (!isBatchRunning.value) {
        _simTimer?.cancel();
      }
    }
  }

  // ===========================================================================
  // BATCH / MONTE CARLO RUN
  // ===========================================================================
  Future<void> startBatchRun({
    required int runs,
    required double scale,
    required bool randomLeader,
    required bool randomTarget,
  }) async {
    _stopRequested = false;
    _simTimer?.cancel();
    isBatchRunning.value = true;
    batchTotalRuns.value = runs;
    batchCurrentRun.value = 0;
    batchResults.clear();
    isCsvReady.value = false;
    lastCsvPath.value = '';
    timeScale.value = scale;

    if (Get.context != null) {
      Get.dialog(
        const _BatchProgressDialog(),
        barrierDismissible: false,
      );
    }

    await _runBatchAsync(runs, randomLeader, randomTarget);
  }

  Future<void> _runBatchAsync(int runs, bool randomLeader, bool randomTarget) async {
    for (int r = 1; r <= runs; r++) {
      if (_stopRequested) break;

      batchCurrentRun.value = r;
      _resetSimulation();

      if (randomLeader) {
        randomizePreFlightRoles(_random.nextInt(100000) + r * 17);
      }

      if (randomTarget) {
        targetPosition.value = ArenaMap.pickValidTarget(_random);
      }

      _beginMission();

      const stepMs = 16;
      final dt = (stepMs / 1000.0) * timeScale.value;
      bool timeout = false;
      final realStart = DateTime.now();

      while (!missionComplete.value && !_stopRequested) {
        _tick(dt);

        final realElapsed = DateTime.now().difference(realStart).inSeconds;
        if (realElapsed >= runTimeoutSecondsReal.value) {
          timeout = true;
          break;
        }

        await Future.delayed(const Duration(milliseconds: 1));
      }

      int wallCol = 0;
      int droneCol = 0;
      for (final d in drones) {
        wallCol += d.wallCollisionCount;
        droneCol += d.droneCollisionCount;
      }

      final result = BatchRunResult(
        runIndex: r,
        status: (!timeout && missionComplete.value) ? 'OK' : 'FAIL_TIMEOUT',
        foundDrone: leaderDroneName.value.isNotEmpty ? leaderDroneName.value : 'NONE',
        foundRole: leaderDroneRole.value.isNotEmpty ? leaderDroneRole.value : 'NONE',
        timeToFind: _currentRunTimeToFind >= 0 ? _currentRunTimeToFind : elapsedTime.value,
        timeTotal: elapsedTime.value,
        targetPos: targetPosition.value,
        wallCollisions: wallCol,
        droneCollisions: droneCol,
      );

      batchResults.add(result);
    }

    if (batchResults.isNotEmpty) {
      try {
        final path = await CsvHelper.saveBatchResultsToCsv(batchResults);
        lastCsvPath.value = path;
        isCsvReady.value = true;
      } catch (e) {
        debugPrint('[SimController] Error saving CSV: $e');
      }
    }

    isBatchRunning.value = false;
    timeScale.value = 1.0;
    if (Get.isDialogOpen ?? false) {
      Get.back();
    }

    if (Get.context != null) {
      Get.snackbar(
        'Monte Carlo Selesai',
        '${batchResults.length} runs selesai dieksekusi. CSV siap dibuka.',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.teal.shade900,
        colorText: Colors.white,
        duration: const Duration(seconds: 4),
      );
    }
  }

  void openCsvFile() {
    if (lastCsvPath.value.isNotEmpty) {
      CsvHelper.openFile(lastCsvPath.value);
    }
  }

  void openCsvFolder() {
    if (lastCsvPath.value.isNotEmpty) {
      CsvHelper.openFolder(lastCsvPath.value);
    }
  }
}

class _BatchProgressDialog extends StatelessWidget {
  const _BatchProgressDialog();

  @override
  Widget build(BuildContext context) {
    final sim = Get.find<SimulationController>();
    return PopScope(
      canPop: false,
      child: Dialog(
        backgroundColor: const Color(0xFF1E2430),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Obx(() {
            final cur = sim.batchCurrentRun.value;
            final total = sim.batchTotalRuns.value;
            final progress = total > 0 ? (cur / total).clamp(0.0, 1.0) : 0.0;

            return Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Row(
                  children: [
                    Icon(Icons.auto_graph, color: Colors.cyanAccent),
                    SizedBox(width: 12),
                    Text(
                      'Monte Carlo Batch Running...',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                LinearProgressIndicator(
                  value: progress,
                  minHeight: 10,
                  backgroundColor: Colors.white12,
                  valueColor: const AlwaysStoppedAnimation(Colors.cyanAccent),
                  borderRadius: BorderRadius.circular(5),
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Run $cur / $total',
                      style: const TextStyle(color: Colors.white70, fontSize: 14),
                    ),
                    Text(
                      '${(progress * 100).toStringAsFixed(1)}%',
                      style: const TextStyle(
                        color: Colors.cyanAccent,
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                ElevatedButton.icon(
                  onPressed: () {
                    sim.stopRun();
                    if (Get.isDialogOpen ?? false) Get.back();
                  },
                  icon: const Icon(Icons.stop, color: Colors.white),
                  label: const Text('Stop Batch'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.redAccent,
                    foregroundColor: Colors.white,
                  ),
                ),
              ],
            );
          }),
        ),
      ),
    );
  }
}
