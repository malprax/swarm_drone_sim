import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:swarm_drone_sim/controllers/simulation_controller.dart';
import 'package:swarm_drone_sim/controllers/ui_controller.dart';
import 'package:swarm_drone_sim/models/vector2.dart';
import 'package:swarm_drone_sim/views/arena_canvas.dart';

void main() {
  group('Zoom & Camera Controller Tests', () {
    late UIController ui;

    setUp(() {
      Get.reset();
      ui = Get.put(UIController());
    });

    test('Initial zoom and pan state is default 1.0 and zero', () {
      expect(ui.zoom.value, equals(1.0));
      expect(ui.panOffset.value, equals(Offset.zero));
      expect(ui.followingDroneIndex.value, equals(-1));
    });

    test('Zoom in and zoom out updates zoom factor within bounds', () {
      ui.zoomIn();
      expect(ui.zoom.value, closeTo(1.30, 1e-4));

      ui.zoomOut();
      expect(ui.zoom.value, closeTo(1.0, 1e-3));

      // Test max zoom clamp (15.0)
      for (int i = 0; i < 25; i++) {
        ui.zoomIn();
      }
      expect(ui.zoom.value, equals(UIController.maxZoom));

      // Test min zoom clamp (0.5)
      for (int i = 0; i < 35; i++) {
        ui.zoomOut();
      }
      expect(ui.zoom.value, equals(UIController.minZoom));

      // Reset camera
      ui.resetCamera();
      expect(ui.zoom.value, equals(1.0));
      expect(ui.panOffset.value, equals(Offset.zero));
    });

    test('Focal zoom keeps world coordinate stationary under cursor', () {
      const viewport = Size(1000, 600);
      const focalPoint = Offset(700, 300); // 200px to the right of screen center (500, 300)

      ui.zoomBy(2.0, focalPoint: focalPoint, viewportSize: viewport);

      expect(ui.zoom.value, equals(2.0));
      // With zoom 2x centered at +200px right, pan moves by -200px
      expect(ui.panOffset.value.dx, closeTo(-200.0, 1e-4));
      expect(ui.panOffset.value.dy, closeTo(0.0, 1e-4));
    });

    test('centerOnWorld moves camera pan to center world position', () {
      const viewport = Size(1000, 600);
      const targetPos = Vector2(5.0, 3.0); // 5m to right of arena origin (0, 3)

      ui.centerOnWorld(targetPos, viewport, targetZoom: 2.0);

      expect(ui.zoom.value, equals(2.0));
      // Base scale = min(1000/32, 600/18) * 2.0 = 31.25 * 2.0 = 62.5 px/m
      // dx = (5.0 - 0.0) * 62.5 = 312.5 px
      // panOffset = Offset(-312.5, 0.0)
      expect(ui.panOffset.value.dx, closeTo(-312.5, 1e-3));
      expect(ui.panOffset.value.dy, closeTo(0.0, 1e-3));
    });

    test('toggleFollowDrone sets follow mode and focuses camera', () {
      const viewport = Size(1000, 600);
      const dronePos = Vector2(2.0, 1.0);

      ui.toggleFollowDrone(0, viewport, dronePos);
      expect(ui.followingDroneIndex.value, equals(0));
      expect(ui.zoom.value, greaterThanOrEqualTo(4.5)); // Auto zooms in to see drone clearly

      // Toggle again should release follow
      ui.toggleFollowDrone(0, viewport, dronePos);
      expect(ui.followingDroneIndex.value, equals(-1));
    });

    testWidgets('ArenaCanvas responds to mouse wheel and mouse movement zoom', (tester) async {
      Get.reset();
      final sim = Get.put(SimulationController());
      final uiController = Get.put(UIController());

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 800,
              height: 600,
              child: ArenaCanvas(),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(uiController.zoom.value, equals(1.0));

      // 1. Mouse Scroll Wheel Up -> Zoom In
      final center = tester.getCenter(find.byType(ArenaCanvas));
      final pointer = TestPointer(1, PointerDeviceKind.mouse);
      pointer.hover(center);

      await tester.sendEventToBinding(pointer.scroll(const Offset(0, -20)));
      await tester.pumpAndSettle();

      expect(uiController.zoom.value, greaterThan(1.10)); // Noticeable zoom in

      // 2. Mouse Scroll Wheel Down -> Zoom Out
      await tester.sendEventToBinding(pointer.scroll(const Offset(0, 40)));
      await tester.pumpAndSettle();

      expect(uiController.zoom.value, lessThan(1.10));

      // 3. Right-Click Drag Mouse Movement Up -> Zoom In
      await tester.sendEventToBinding(pointer.down(center, buttons: kSecondaryMouseButton));
      await tester.pump();
      await tester.sendEventToBinding(pointer.move(center - const Offset(0, 40), buttons: kSecondaryMouseButton));
      await tester.pumpAndSettle();
      await tester.sendEventToBinding(pointer.up());
      await tester.pumpAndSettle();

      expect(uiController.zoom.value, greaterThan(1.10)); // Mouse movement zoomed in!

      // 4. Quick Zoom Slider in HUD
      final sliderFinder = find.byType(Slider);
      expect(sliderFinder, findsOneWidget);

      sim.stopRun();
    });
  });
}
