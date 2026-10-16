import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:swarm_drone_sim/controllers/simulation_controller.dart';
import 'package:swarm_drone_sim/controllers/ui_controller.dart';
import 'package:swarm_drone_sim/services/hardware_bridge_service.dart';
import 'package:swarm_drone_sim/views/arena_canvas.dart';
import 'package:swarm_drone_sim/views/widgets/control_panel.dart';
import 'package:swarm_drone_sim/models/vector2.dart';

void main() {
  group('Home Base ("H" Pad) Visibility Tests', () {
    late SimulationController sim;
    late UIController ui;

    setUp(() {
      Get.reset();
      sim = Get.put(SimulationController());
      ui = Get.put(UIController());
      Get.put(HardwareBridgeService());
    });

    test('UIController showHomeBase defaults to true and can be toggled', () {
      expect(ui.showHomeBase.value, isTrue);

      ui.showHomeBase.value = false;
      expect(ui.showHomeBase.value, isFalse);

      ui.showHomeBase.value = true;
      expect(ui.showHomeBase.value, isTrue);
    });

    testWidgets('ControlPanel renders Home Base checkbox and toggles showHomeBase',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1920, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 420,
              height: 1200,
              child: ControlPanel(),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final homeBaseCheckboxFinder = find.widgetWithText(
        CheckboxListTile,
        'Home Base (Pad "H")',
      );
      await tester.scrollUntilVisible(
        homeBaseCheckboxFinder,
        150.0,
        scrollable: find.byType(Scrollable).first,
      );
      expect(homeBaseCheckboxFinder, findsOneWidget);

      // Verify initial state is checked
      CheckboxListTile checkboxWidget = tester.widget(homeBaseCheckboxFinder);
      expect(checkboxWidget.value, isTrue);
      expect(ui.showHomeBase.value, isTrue);

      // Tap the checkbox to uncheck
      await tester.tap(homeBaseCheckboxFinder);
      await tester.pumpAndSettle();

      expect(ui.showHomeBase.value, isFalse);
      checkboxWidget = tester.widget(homeBaseCheckboxFinder);
      expect(checkboxWidget.value, isFalse);

      // Tap again to re-check
      await tester.tap(homeBaseCheckboxFinder);
      await tester.pumpAndSettle();

      expect(ui.showHomeBase.value, isTrue);
      checkboxWidget = tester.widget(homeBaseCheckboxFinder);
      expect(checkboxWidget.value, isTrue);
    });

    testWidgets('Real Drone tab renders Home Base checkbox and toggles showHomeBase',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1920, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      // Switch to real drone mode
      sim.setDataSource(AppDataSource.realDrone);

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 420,
              height: 1200,
              child: ControlPanel(),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final realDroneHomeBaseFinder = find.widgetWithText(
        CheckboxListTile,
        'Tampilkan Home Base / Pad "H"',
      );
      await tester.scrollUntilVisible(
        realDroneHomeBaseFinder,
        150.0,
        scrollable: find.byType(Scrollable).first,
      );
      expect(realDroneHomeBaseFinder, findsOneWidget);

      // Initial state is true
      expect(ui.showHomeBase.value, isTrue);

      // Tap to uncheck
      await tester.tap(realDroneHomeBaseFinder);
      await tester.pumpAndSettle();

      expect(ui.showHomeBase.value, isFalse);
    });

    test('ArenaPainter correctly paints with homeBaseVisible true and false without errors', () {
      final recorder = PictureRecorder();
      final canvas = Canvas(recorder);
      const size = Size(800, 600);

      // 1. Paint with homeBaseVisible = true and arenaGridVisible = true and targetCircleVisible = true
      final painterVisible = ArenaPainter(
        sim: sim,
        ui: ui,
        elapsedTime: 1.0,
        pan: Offset.zero,
        zoomLevel: 1.0,
        sensorsVisible: true,
        gridVisible: true,
        arenaGridVisible: true,
        pathsVisible: true,
        missionPathVisible: true,
        labelsVisible: true,
        homeBaseVisible: true,
        targetCircleVisible: true,
        targetPos: Vector2(5.0, 5.0),
        gizmoMode: GizmoMode.none,
        activeGizmoAxis: GizmoAxis.none,
        activeGizmoDroneIndex: -1,
        wallLineThickness: 2,
        wallLineStyle: WallLineStyle.solid,
      );

      expect(() => painterVisible.paint(canvas, size), returnsNormally);

      // 2. Paint with homeBaseVisible = false and arenaGridVisible = false and targetCircleVisible = false
      final painterHidden = ArenaPainter(
        sim: sim,
        ui: ui,
        elapsedTime: 1.0,
        pan: Offset.zero,
        zoomLevel: 1.0,
        sensorsVisible: true,
        gridVisible: true,
        arenaGridVisible: false,
        pathsVisible: true,
        missionPathVisible: true,
        labelsVisible: true,
        homeBaseVisible: false,
        targetCircleVisible: false,
        targetPos: Vector2(5.0, 5.0),
        gizmoMode: GizmoMode.none,
        activeGizmoAxis: GizmoAxis.none,
        activeGizmoDroneIndex: -1,
        wallLineThickness: 2,
        wallLineStyle: WallLineStyle.solid,
      );

      expect(() => painterHidden.paint(canvas, size), returnsNormally);
    });

    test('UIController showArenaGrid defaults to true and can be toggled', () {
      expect(ui.showArenaGrid.value, isTrue);

      ui.showArenaGrid.value = false;
      expect(ui.showArenaGrid.value, isFalse);

      ui.showArenaGrid.value = true;
      expect(ui.showArenaGrid.value, isTrue);
    });

    test('UIController showTargetCircle defaults to true and can be toggled', () {
      expect(ui.showTargetCircle.value, isTrue);

      ui.showTargetCircle.value = false;
      expect(ui.showTargetCircle.value, isFalse);

      ui.showTargetCircle.value = true;
      expect(ui.showTargetCircle.value, isTrue);
    });

    testWidgets('ControlPanel renders Lingkaran Kuning Target checkbox and toggles showTargetCircle',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1920, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 420,
              height: 1200,
              child: ControlPanel(),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final targetCircleCheckboxFinder = find.widgetWithText(
        CheckboxListTile,
        'Lingkaran Kuning Target',
      );
      await tester.scrollUntilVisible(
        targetCircleCheckboxFinder,
        150.0,
        scrollable: find.byType(Scrollable).first,
      );
      expect(targetCircleCheckboxFinder, findsOneWidget);

      // Initial state is checked
      CheckboxListTile checkboxWidget = tester.widget(targetCircleCheckboxFinder);
      expect(checkboxWidget.value, isTrue);
      expect(ui.showTargetCircle.value, isTrue);

      // Tap to uncheck
      await tester.tap(targetCircleCheckboxFinder);
      await tester.pumpAndSettle();

      expect(ui.showTargetCircle.value, isFalse);
      checkboxWidget = tester.widget(targetCircleCheckboxFinder);
      expect(checkboxWidget.value, isFalse);

      // Tap again to recheck
      await tester.tap(targetCircleCheckboxFinder);
      await tester.pumpAndSettle();

      expect(ui.showTargetCircle.value, isTrue);
      checkboxWidget = tester.widget(targetCircleCheckboxFinder);
      expect(checkboxWidget.value, isTrue);
    });

    testWidgets('ControlPanel renders Garis Grid Arena checkbox and toggles showArenaGrid',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1920, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 420,
              height: 1200,
              child: ControlPanel(),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final arenaGridCheckboxFinder = find.widgetWithText(
        CheckboxListTile,
        'Garis Grid Arena',
      );
      await tester.scrollUntilVisible(
        arenaGridCheckboxFinder,
        150.0,
        scrollable: find.byType(Scrollable).first,
      );
      expect(arenaGridCheckboxFinder, findsOneWidget);

      // Initial state is checked
      CheckboxListTile checkboxWidget = tester.widget(arenaGridCheckboxFinder);
      expect(checkboxWidget.value, isTrue);
      expect(ui.showArenaGrid.value, isTrue);

      // Tap to uncheck
      await tester.tap(arenaGridCheckboxFinder);
      await tester.pumpAndSettle();

      expect(ui.showArenaGrid.value, isFalse);
      checkboxWidget = tester.widget(arenaGridCheckboxFinder);
      expect(checkboxWidget.value, isFalse);

      // Tap again to recheck
      await tester.tap(arenaGridCheckboxFinder);
      await tester.pumpAndSettle();

      expect(ui.showArenaGrid.value, isTrue);
      checkboxWidget = tester.widget(arenaGridCheckboxFinder);
      expect(checkboxWidget.value, isTrue);
    });
  });
}
