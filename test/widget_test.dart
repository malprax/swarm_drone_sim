import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:swarm_drone_sim/controllers/simulation_controller.dart';
import 'package:swarm_drone_sim/controllers/ui_controller.dart';
import 'package:swarm_drone_sim/main.dart';

void main() {
  testWidgets('SwarmDroneApp smoke test', (WidgetTester tester) async {
    // Set standard desktop window size for desktop application test
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    Get.reset();
    Get.put(SimulationController());
    Get.put(UIController());

    await tester.pumpWidget(const SwarmDroneApp());
    await tester.pumpAndSettle();

    expect(find.text('Swarm Drone Simulator (Flutter GetX)'), findsOneWidget);
    expect(find.text('SIMULATION CONTROLS'), findsOneWidget);
    expect(find.text('SWARM TELEMETRY'), findsOneWidget);
    expect(find.text('Run 1 (Manual)'), findsOneWidget);
    expect(find.text('Active Swarm Size (AI Mapping Mode):'), findsOneWidget);
    expect(find.text('1 Drone'), findsOneWidget);
    expect(find.text('2 Drones'), findsOneWidget);
    expect(find.text('3 Drones'), findsOneWidget);

    final sim = Get.find<SimulationController>();
    final ui = Get.find<UIController>();

    // Default is 3 drones
    expect(sim.activeDroneCount.value, equals(3));
    expect(find.text('3-DRONE AI LOCAL ROOM MAPPING'), findsOneWidget);

    // Tap 1 Drone choice chip
    await tester.tap(find.text('1 Drone'));
    await tester.pumpAndSettle();

    expect(sim.activeDroneCount.value, equals(1));
    expect(find.text('AI LOCAL ROOM MAPPING (1 DRONE - WIDE SCAN)'), findsOneWidget);

    // Tap 2 Drones choice chip
    await tester.tap(find.text('2 Drones'));
    await tester.pumpAndSettle();

    expect(sim.activeDroneCount.value, equals(2));
    expect(find.text('2-DRONE AI LOCAL ROOM MAPPING'), findsOneWidget);

    // Tap 3 Drones choice chip back
    await tester.tap(find.text('3 Drones'));
    await tester.pumpAndSettle();

    expect(sim.activeDroneCount.value, equals(3));
    expect(find.text('3-DRONE AI LOCAL ROOM MAPPING'), findsOneWidget);

    // Test direct click on drone without pressing random button
    ui.lockAndDismissGizmos();
    expect(ui.gizmoMode.value, equals(GizmoMode.none));

    // Calling activateDroneGizmos(0) simulates direct pointer down on Drone 0
    ui.activateDroneGizmos(0);
    await tester.pumpAndSettle();

    expect(ui.gizmoMode.value, equals(GizmoMode.drones));
    expect(ui.activeGizmoDroneIndex.value, equals(0));

    // Tap empty arena to dismiss
    ui.lockAndDismissGizmos();
    await tester.pumpAndSettle();
    expect(ui.gizmoMode.value, equals(GizmoMode.none));
  });
}
