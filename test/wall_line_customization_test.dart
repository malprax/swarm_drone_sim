import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:swarm_drone_sim/controllers/simulation_controller.dart';
import 'package:swarm_drone_sim/controllers/ui_controller.dart';
import 'package:swarm_drone_sim/models/arena_map.dart';
import 'package:swarm_drone_sim/views/arena_canvas.dart';
import 'package:swarm_drone_sim/views/widgets/layout_preset_selector.dart';
import 'package:swarm_drone_sim/views/widgets/wall_line_customizer.dart';

void main() {
  setUp(() {
    Get.reset();
    Get.put(SimulationController());
    Get.put(UIController());
  });

  tearDown(() {
    Get.reset();
  });

  group('WallLineCustomizer & UIController Tests', () {
    test('Default wall line settings are 2 pt and solid', () {
      final ui = Get.find<UIController>();
      expect(ui.wallLineThickness.value, 2);
      expect(ui.wallLineStyle.value, WallLineStyle.solid);
    });

    test('Setting thickness updates reactive observable', () {
      final ui = Get.find<UIController>();

      ui.setWallLineThickness(0);
      expect(ui.wallLineThickness.value, 0);

      ui.setWallLineThickness(1);
      expect(ui.wallLineThickness.value, 1);

      ui.setWallLineThickness(3);
      expect(ui.wallLineThickness.value, 3);
    });

    test('Setting line style updates reactive observable', () {
      final ui = Get.find<UIController>();

      ui.setWallLineStyle(WallLineStyle.dashed);
      expect(ui.wallLineStyle.value, WallLineStyle.dashed);

      ui.setWallLineStyle(WallLineStyle.zigzag);
      expect(ui.wallLineStyle.value, WallLineStyle.zigzag);

      ui.setWallLineStyle(WallLineStyle.wavy);
      expect(ui.wallLineStyle.value, WallLineStyle.wavy);

      ui.setWallLineStyle(WallLineStyle.solid);
      expect(ui.wallLineStyle.value, WallLineStyle.solid);
    });

    testWidgets(
      'WallLineCustomizerWidget renders all thickness and style options',
      (tester) async {
        await tester.pumpWidget(
          const MaterialApp(home: Scaffold(body: WallLineCustomizerWidget())),
        );

        // Verify thickness buttons
        expect(find.text('0 pt'), findsOneWidget);
        expect(find.text('1 pt'), findsOneWidget);
        expect(find.text('2 pt'), findsOneWidget);
        expect(find.text('3 pt'), findsOneWidget);

        // Verify style buttons
        expect(find.text('Sambung'), findsOneWidget);
        expect(find.text('Putus'), findsOneWidget);
        expect(find.text('Tajam'), findsOneWidget);
        expect(find.text('Tumpul'), findsOneWidget);

        // Tap '1 pt' thickness
        await tester.tap(find.text('1 pt'));
        await tester.pumpAndSettle();
        expect(Get.find<UIController>().wallLineThickness.value, 1);

        // Tap '0 pt' thickness (hidden)
        await tester.tap(find.text('0 pt'));
        await tester.pumpAndSettle();
        expect(Get.find<UIController>().wallLineThickness.value, 0);

        // Tap 'Tajam' zigzag style
        await tester.tap(find.text('Tajam'));
        await tester.pumpAndSettle();
        expect(
          Get.find<UIController>().wallLineStyle.value,
          WallLineStyle.zigzag,
        );

        // Tap 'Tumpul' wavy style
        await tester.tap(find.text('Tumpul'));
        await tester.pumpAndSettle();
        expect(
          Get.find<UIController>().wallLineStyle.value,
          WallLineStyle.wavy,
        );

        // Tap 'Putus' dashed style
        await tester.tap(find.text('Putus'));
        await tester.pumpAndSettle();
        expect(
          Get.find<UIController>().wallLineStyle.value,
          WallLineStyle.dashed,
        );
      },
    );

    testWidgets(
      'ArenaCanvas renders WallLineCustomizerWidget aligned with LayoutPresetSelector',
      (tester) async {
        tester.view.physicalSize = const Size(1400, 900);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() => tester.view.resetPhysicalSize());

        await tester.pumpWidget(
          const MaterialApp(home: Scaffold(body: ArenaCanvas())),
        );
        await tester.pump();

        // Verify top-right toolbar contains WallLineCustomizerWidget and LayoutPresetSelector
        expect(find.byType(WallLineCustomizerWidget), findsOneWidget);
        expect(find.byType(LayoutPresetSelector), findsOneWidget);
      },
    );

    test('ArenaMap wallSurfaces covers all room boundaries', () {
      expect(ArenaMap.wallSurfaces.length, greaterThanOrEqualTo(18));
      for (final s in ArenaMap.wallSurfaces) {
        expect(s.length, greaterThan(0));
        expect(s.normal.magnitude, closeTo(1.0, 0.01));
      }
    });
  });
}
