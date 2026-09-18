import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'controllers/simulation_controller.dart';
import 'controllers/ui_controller.dart';
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
    return GetMaterialApp(
      title: 'Swarm Drone Simulation',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF0F172A),
        colorScheme: const ColorScheme.dark(
          primary: Colors.cyanAccent,
          secondary: Colors.tealAccent,
          surface: Color(0xFF1E293B),
        ),
        useMaterial3: true,
      ),
      home: const MainScreen(),
    );
  }
}
