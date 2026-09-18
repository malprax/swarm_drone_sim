import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:swarm_drone_sim/controllers/simulation_controller.dart';
import 'package:swarm_drone_sim/controllers/ui_controller.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('SimulationController manual run and tick simulation', () async {
    Get.reset();
    final sim = Get.put(SimulationController());
    Get.put(UIController());

    expect(sim.drones.length, equals(3));
    expect(sim.simState.value, equals(SimState.standby));

    // Start manual run
    sim.startManualRun();
    expect(sim.simState.value, equals(SimState.running));

    // Stop run
    sim.stopRun();
    expect(sim.simState.value, equals(SimState.standby));
  });

  test('SimulationController batch run generates valid CSV', () async {
    Get.reset();
    final sim = Get.put(SimulationController());
    Get.put(UIController());

    // Execute 2 fast batch runs at 20x timeScale
    await sim.startBatchRun(
      runs: 2,
      scale: 20.0,
      randomLeader: true,
      randomTarget: true,
    );

    expect(sim.batchResults.length, equals(2));
    expect(sim.isCsvReady.value, isTrue);
    expect(sim.lastCsvPath.value, isNotEmpty);

    final csvFile = File(sim.lastCsvPath.value);
    expect(await csvFile.exists(), isTrue);

    final lines = await csvFile.readAsLines();
    expect(lines.length, equals(3)); // 1 header + 2 run rows
    expect(lines[0], equals('run,status,foundDrone,foundRole,timeToFind,timeTotal,targetX,targetY,wallCollisions,droneCollisions'));
  });
}
