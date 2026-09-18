import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../controllers/simulation_controller.dart';
import '../controllers/ui_controller.dart';
import '../services/hardware_bridge_service.dart';
import 'arena_canvas.dart';
import 'widgets/control_panel.dart';
import 'widgets/drone_telemetry_card.dart';
import 'widgets/minimap_panel.dart';

class MainScreen extends StatelessWidget {
  const MainScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final sim = Get.find<SimulationController>();
    final ui = Get.find<UIController>();

    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1E293B),
        titleSpacing: 12,
        title: Row(
          children: [
            const Icon(Icons.flight_takeoff, color: Colors.cyanAccent, size: 20),
            const SizedBox(width: 8),
            const Flexible(
              child: Text(
                'Swarm Drone Simulator (Flutter GetX)',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 10),

            // MODE TOGGLE BUTTON: [ 🎮 Simulasi | 🛸 Real Drone (RPi 4) ]
            Obx(() {
              final isReal = sim.isRealDroneMode;
              return Container(
                decoration: BoxDecoration(
                  color: const Color(0xFF0F172A),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: isReal ? Colors.greenAccent : Colors.cyanAccent.withValues(alpha: 0.5),
                    width: 1.2,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Option 1: Simulasi Virtual
                    InkWell(
                      borderRadius: const BorderRadius.horizontal(left: Radius.circular(19)),
                      onTap: () => sim.setDataSource(AppDataSource.simulation),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                        decoration: BoxDecoration(
                          color: !isReal ? Colors.cyan.shade800 : Colors.transparent,
                          borderRadius: const BorderRadius.horizontal(left: Radius.circular(19)),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.sports_esports_outlined, size: 14, color: !isReal ? Colors.white : Colors.white60),
                            const SizedBox(width: 4),
                            Text(
                              'Simulasi',
                              style: TextStyle(
                                color: !isReal ? Colors.white : Colors.white60,
                                fontSize: 11,
                                fontWeight: !isReal ? FontWeight.bold : FontWeight.normal,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    // Option 2: Real Drone (RPi 4)
                    InkWell(
                      borderRadius: const BorderRadius.horizontal(right: Radius.circular(19)),
                      onTap: () => sim.setDataSource(AppDataSource.realDrone),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                        decoration: BoxDecoration(
                          color: isReal ? Colors.green.shade800 : Colors.transparent,
                          borderRadius: const BorderRadius.horizontal(right: Radius.circular(19)),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.wifi_tethering, size: 14, color: isReal ? Colors.greenAccent : Colors.white60),
                            const SizedBox(width: 4),
                            Text(
                              'Real Drone (RPi 4)',
                              style: TextStyle(
                                color: isReal ? Colors.white : Colors.white60,
                                fontSize: 11,
                                fontWeight: isReal ? FontWeight.bold : FontWeight.normal,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }),

            const SizedBox(width: 8),
            // Mission State Chip
            Obx(() {
              final state = sim.simState.value;
              final Color color;
              final String label;

              switch (state) {
                case SimState.standby:
                  color = Colors.grey;
                  label = 'STANDBY';
                  break;
                case SimState.running:
                  color = sim.isRealDroneMode ? Colors.greenAccent : Colors.lightBlueAccent;
                  label = sim.isRealDroneMode ? 'LIVE SLAM MAPPING' : 'EXPLORING';
                  break;
                case SimState.targetFound:
                  color = Colors.amberAccent;
                  label = 'TARGET FOUND!';
                  break;
                case SimState.complete:
                  color = Colors.greenAccent;
                  label = 'COMPLETE';
                  break;
              }

              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: color, width: 1.0),
                ),
                child: Text(
                  label,
                  style: TextStyle(
                    color: color,
                    fontWeight: FontWeight.bold,
                    fontSize: 10,
                  ),
                ),
              );
            }),
          ],
        ),
        actions: [
          Obx(() {
            if (!sim.isRealDroneMode) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  child: Text(
                    '${sim.elapsedTime.value.toStringAsFixed(1)}s (Find: ${sim.timeToFind.value.toStringAsFixed(1)}s)',
                    style: const TextStyle(
                      color: Colors.cyanAccent,
                      fontWeight: FontWeight.bold,
                      fontSize: 11,
                    ),
                  ),
                ),
              );
            }

            // Real Drone Hardware Link Badge
            final hw = Get.find<HardwareBridgeService>();
            final state = hw.connectionState.value;
            final isConnected = state == HardwareConnectionState.connected;
            final color = isConnected
                ? Colors.greenAccent
                : (state == HardwareConnectionState.connecting ? Colors.amberAccent : Colors.redAccent);
            final label = isConnected
                ? 'RPi LIVE (${hw.packetRateHz.value.toStringAsFixed(0)} Hz • ${hw.pingMs.value.toStringAsFixed(0)}ms)'
                : (state == HardwareConnectionState.connecting ? 'CONNECTING RPi...' : 'RPi DISCONNECTED');

            return Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: color, width: 1.0),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 7,
                        height: 7,
                        decoration: BoxDecoration(shape: BoxShape.circle, color: color),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        label,
                        style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }),
        ],
      ),
      body: Row(
        children: [
          // Left Control Panel
          const SizedBox(
            width: 270,
            child: ControlPanel(),
          ),

          // Center Simulation Arena & 3 Minimaps
          Expanded(
            child: Column(
              children: [
                const Expanded(
                  child: ClipRect(
                    child: ArenaCanvas(),
                  ),
                ),
                Obx(() {
                  if (!ui.showMinimaps.value) return const SizedBox.shrink();
                  return const MinimapPanel();
                }),
              ],
            ),
          ),

          // Right Telemetry Sidebar
          Container(
            width: 260,
            color: const Color(0xFF161E2E),
            padding: const EdgeInsets.all(10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(Icons.sensors, color: Colors.cyanAccent, size: 16),
                    SizedBox(width: 6),
                    Flexible(
                      child: Text(
                        'SWARM TELEMETRY',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Expanded(
                  child: Obx(() {
                    return ListView(
                      children: sim.activeDrones.map((d) => DroneTelemetryCard(drone: d)).toList(),
                    );
                  }),
                ),
                const Divider(color: Colors.white24),
                Obx(() => Text(
                      'Arrived at Home: ${sim.arrivedCount.value} / ${sim.activeDroneCount.value}',
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    )),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
