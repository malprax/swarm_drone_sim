import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'controllers/simulation_controller.dart';
import 'controllers/ui_controller.dart';
import 'utils/app_theme.dart';
import 'views/main_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  // Register GetX Controllers
  Get.put(SimulationController());
  Get.put(UIController());

  runApp(const SwarmDroneApp());
}

class SwarmDroneApp extends StatelessWidget {
  const SwarmDroneApp({super.key});

  @override
  Widget build(BuildContext context) {
    final ui = Get.find<UIController>();

    return Obx(() => GetMaterialApp(
      title: 'Swarm Drone Simulation',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: ui.themeMode.value,
      home: const MainScreen(),
    ));
  }
}
