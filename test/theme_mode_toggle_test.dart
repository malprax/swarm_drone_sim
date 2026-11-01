import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:swarm_drone_sim/controllers/simulation_controller.dart';
import 'package:swarm_drone_sim/controllers/ui_controller.dart';
import 'package:swarm_drone_sim/utils/app_theme.dart';
import 'package:swarm_drone_sim/views/widgets/theme_mode_toggle.dart';

void main() {
  setUp(() {
    Get.reset();
    Get.put(SimulationController());
    Get.put(UIController());
  });

  test('UIController theme mode state switching works correctly', () {
    final ui = Get.find<UIController>();

    expect(ui.themeMode.value, ThemeMode.system);

    ui.setThemeMode(ThemeMode.dark);
    expect(ui.themeMode.value, ThemeMode.dark);
    expect(ui.isDarkMode, isTrue);

    ui.setThemeMode(ThemeMode.light);
    expect(ui.themeMode.value, ThemeMode.light);
    expect(ui.isDarkMode, isFalse);

    ui.setThemeMode(ThemeMode.system);
    expect(ui.themeMode.value, ThemeMode.system);
  });

  testWidgets('ThemeModeToggle compact pill renders and toggles theme', (tester) async {
    final ui = Get.find<UIController>();

    await tester.pumpWidget(
      GetMaterialApp(
        theme: AppTheme.lightTheme,
        darkTheme: AppTheme.darkTheme,
        themeMode: ui.themeMode.value,
        home: const Scaffold(
          body: Center(
            child: ThemeModeToggle(isCompact: true),
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    // Verify icons are present
    expect(find.byIcon(Icons.dark_mode_outlined), findsOneWidget);
    expect(find.byIcon(Icons.light_mode_outlined), findsOneWidget);
    expect(find.byIcon(Icons.brightness_auto), findsOneWidget); // system is selected by default

    // Tap Light mode
    await tester.tap(find.byIcon(Icons.light_mode_outlined));
    await tester.pumpAndSettle();

    expect(ui.themeMode.value, ThemeMode.light);

    // Tap Dark mode
    await tester.tap(find.byIcon(Icons.dark_mode_outlined));
    await tester.pumpAndSettle();

    expect(ui.themeMode.value, ThemeMode.dark);
  });

  testWidgets('ThemeModeToggle expanded panel renders and switches theme', (tester) async {
    final ui = Get.find<UIController>();

    await tester.pumpWidget(
      GetMaterialApp(
        theme: AppTheme.lightTheme,
        darkTheme: AppTheme.darkTheme,
        themeMode: ui.themeMode.value,
        home: const Scaffold(
          body: Center(
            child: SizedBox(
              width: 300,
              child: ThemeModeToggle(isCompact: false),
            ),
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('TEMA TAMPILAN'), findsOneWidget);
    expect(find.text('Gelap'), findsOneWidget);
    expect(find.text('Terang'), findsOneWidget);
    expect(find.text('Sistem'), findsOneWidget);

    // Tap Terang
    await tester.tap(find.text('Terang'));
    await tester.pumpAndSettle();

    expect(ui.themeMode.value, ThemeMode.light);

    // Tap Gelap
    await tester.tap(find.text('Gelap'));
    await tester.pumpAndSettle();

    expect(ui.themeMode.value, ThemeMode.dark);
  });
}
