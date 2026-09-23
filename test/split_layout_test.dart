import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:swarm_drone_sim/controllers/simulation_controller.dart';
import 'package:swarm_drone_sim/controllers/ui_controller.dart';
import 'package:swarm_drone_sim/views/widgets/layout_preset_selector.dart';
import 'package:swarm_drone_sim/views/widgets/resizable_divider.dart';

void main() {
  group('Multi-Mode Split Layout & Resizable Splitters Tests', () {
    late UIController ui;

    setUp(() {
      Get.reset();
      ui = Get.put(UIController());
    });

    test('UIController initial split layout and dimensions', () {
      expect(ui.activeSplitLayout.value, equals(ArenaSplitLayout.horizontal));
      expect(ui.minimapHeight.value, equals(UIController.defaultMinimapHeight));
      expect(ui.minimapWidth.value, equals(UIController.defaultMinimapWidth));
      expect(ui.leftPanelWidth.value, equals(UIController.defaultLeftPanelWidth));
      expect(ui.isLeftPanelCollapsed.value, isFalse);
      expect(ui.rightPanelWidth.value, equals(UIController.defaultRightPanelWidth));
      expect(ui.isRightPanelCollapsed.value, isFalse);
    });

    test('Switching split layout presets updates activeSplitLayout and showMinimaps', () {
      // 1. Right Stacked
      ui.setSplitLayout(ArenaSplitLayout.rightStacked);
      expect(ui.activeSplitLayout.value, equals(ArenaSplitLayout.rightStacked));
      expect(ui.showMinimaps.value, isTrue);

      // 2. Arena Focus (Minimap hidden)
      ui.setSplitLayout(ArenaSplitLayout.arenaFocus);
      expect(ui.activeSplitLayout.value, equals(ArenaSplitLayout.arenaFocus));
      expect(ui.showMinimaps.value, isFalse);

      // 3. Vertical Split
      ui.setSplitLayout(ArenaSplitLayout.vertical);
      expect(ui.activeSplitLayout.value, equals(ArenaSplitLayout.vertical));
      expect(ui.showMinimaps.value, isTrue);

      // 4. Horizontal Split
      ui.setSplitLayout(ArenaSplitLayout.horizontal);
      expect(ui.activeSplitLayout.value, equals(ArenaSplitLayout.horizontal));
      expect(ui.showMinimaps.value, isTrue);
    });

    test('resizeMinimapHeight clamps within min and max bounds', () {
      const availableH = 600.0;

      // Drag up: negative delta -> increases height
      ui.resizeMinimapHeight(-50.0, availableH);
      expect(ui.minimapHeight.value, equals(UIController.defaultMinimapHeight + 50.0));

      // Drag down: positive delta -> decreases height
      ui.resizeMinimapHeight(100.0, availableH);
      expect(ui.minimapHeight.value, equals(UIController.defaultMinimapHeight - 50.0));

      // Test lower clamp: drag down excessively
      ui.resizeMinimapHeight(500.0, availableH);
      expect(ui.minimapHeight.value, equals(UIController.minMinimapHeight));

      // Test upper clamp: drag up excessively (75% of available height = 450.0)
      ui.resizeMinimapHeight(-1000.0, availableH);
      expect(ui.minimapHeight.value, equals(450.0));
    });

    test('resizeMinimapWidth clamps within min and max bounds', () {
      const availableW = 1000.0;

      // Drag left: negative delta -> increases width
      ui.resizeMinimapWidth(-60.0, availableW);
      expect(ui.minimapWidth.value, equals(UIController.defaultMinimapWidth + 60.0));

      // Test lower clamp
      ui.resizeMinimapWidth(800.0, availableW);
      expect(ui.minimapWidth.value, equals(UIController.minMinimapWidth));

      // Test upper clamp (70% of available width = 700.0)
      ui.resizeMinimapWidth(-1200.0, availableW);
      expect(ui.minimapWidth.value, equals(700.0));
    });

    test('Left and Right Panel resizing and collapse toggles', () {
      // Left Panel resize
      ui.resizeLeftPanel(40.0);
      expect(ui.leftPanelWidth.value, equals(UIController.defaultLeftPanelWidth + 40.0));

      ui.resizeLeftPanel(-200.0);
      expect(ui.leftPanelWidth.value, equals(UIController.minLeftPanelWidth));

      // Left Panel collapse toggle
      expect(ui.isLeftPanelCollapsed.value, isFalse);
      ui.toggleLeftPanel();
      expect(ui.isLeftPanelCollapsed.value, isTrue);
      ui.toggleLeftPanel();
      expect(ui.isLeftPanelCollapsed.value, isFalse);

      // Right Panel resize
      ui.resizeRightPanel(-50.0); // dragging left expands right panel
      expect(ui.rightPanelWidth.value, equals(UIController.defaultRightPanelWidth + 50.0));

      // Right Panel collapse toggle
      ui.toggleRightPanel();
      expect(ui.isRightPanelCollapsed.value, isTrue);

      // Reset dimensions
      ui.resetSplitDimensions();
      expect(ui.leftPanelWidth.value, equals(UIController.defaultLeftPanelWidth));
      expect(ui.rightPanelWidth.value, equals(UIController.defaultRightPanelWidth));
      expect(ui.isLeftPanelCollapsed.value, isFalse);
      expect(ui.isRightPanelCollapsed.value, isFalse);
    });

    testWidgets('LayoutPresetSelector renders and switches presets on tap', (tester) async {
      Get.reset();
      final controller = Get.put(UIController());
      Get.put(SimulationController());

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Center(
              child: LayoutPresetSelector(),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Starts at Horizontal Split
      expect(controller.activeSplitLayout.value, equals(ArenaSplitLayout.horizontal));

      // Tap Preset 1 (Right Stacked)
      final presetButtons = find.byType(CustomPaint);
      expect(presetButtons, findsWidgets);

      // Tap the first layout button (Split Kanan / Right Stacked)
      final firstButton = find.byTooltip('Split Kanan: Arena di Kiri, Minimap Bertumpuk di Kanan');
      expect(firstButton, findsOneWidget);
      await tester.tap(firstButton);
      await tester.pumpAndSettle();
      expect(controller.activeSplitLayout.value, equals(ArenaSplitLayout.rightStacked));

      // Tap Preset 2 (Arena Full / Focus)
      final fullButton = find.byTooltip('Arena Full: Layar Penuh Arena Tanpa Minimap');
      expect(fullButton, findsOneWidget);
      await tester.tap(fullButton);
      await tester.pumpAndSettle();
      expect(controller.activeSplitLayout.value, equals(ArenaSplitLayout.arenaFocus));

      // Tap Preset 3 (Split Bawah / Horizontal Split)
      final horizontalButton = find.byTooltip('Split Bawah: Arena di Atas, Minimap di Bawah (Geser Tinggi)');
      expect(horizontalButton, findsOneWidget);
      await tester.tap(horizontalButton);
      await tester.pumpAndSettle();
      expect(controller.activeSplitLayout.value, equals(ArenaSplitLayout.horizontal));
    });

    testWidgets('ResizableDivider triggers onDragUpdate and onDoubleTap', (tester) async {
      double draggedDelta = 0.0;
      bool doubleTapped = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              height: 200,
              width: 400,
              child: ResizableDivider(
                axis: Axis.horizontal,
                onDragUpdate: (delta) => draggedDelta += delta,
                onDoubleTap: () => doubleTapped = true,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Drag vertically
      final dividerFinder = find.byType(ResizableDivider);
      expect(dividerFinder, findsOneWidget);

      await tester.drag(dividerFinder, const Offset(0, 40));
      await tester.pumpAndSettle();
      expect(draggedDelta, greaterThan(15.0));

      // Double tap
      await tester.tap(dividerFinder);
      await tester.pump(const Duration(milliseconds: 50));
      await tester.tap(dividerFinder);
      await tester.pumpAndSettle();
      expect(doubleTapped, isTrue);
    });
  });
}
