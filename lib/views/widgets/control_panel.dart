import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../controllers/simulation_controller.dart';
import '../../controllers/ui_controller.dart';
import '../../models/drone_model.dart';
import '../../models/vector2.dart';
import '../../services/hardware_bridge_service.dart';
import 'csv_viewer_dialog.dart';

class ControlPanel extends StatelessWidget {
  const ControlPanel({super.key});

  @override
  Widget build(BuildContext context) {
    final sim = Get.find<SimulationController>();
    final ui = Get.find<UIController>();
    final hw = Get.find<HardwareBridgeService>();

    return Container(
      color: const Color(0xFF161E2E),
      child: Obx(() {
        if (sim.isRealDroneMode) {
          return _buildRealDronePanel(context, sim, ui, hw);
        }
        return _buildSimulationPanel(context, sim, ui);
      }),
    );
  }

  Widget _buildSimulationPanel(BuildContext context, SimulationController sim, UIController ui) {
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      children: [
          // Header
          const Row(
            children: [
              Icon(Icons.tune, color: Colors.cyanAccent, size: 18),
              SizedBox(width: 8),
              Flexible(
                child: Text(
                  'SIMULATION CONTROLS',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.0,
                    fontSize: 13,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Primary Actions (Run / Stop / Batch)
          Obx(() {
            final isRunning = sim.simState.value == SimState.running ||
                sim.simState.value == SimState.targetFound ||
                sim.isBatchRunning.value;

            return Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: isRunning ? null : () => sim.startManualRun(),
                        icon: const Icon(Icons.play_arrow, color: Colors.white, size: 18),
                        label: const Text('Run 1 (Manual)', style: TextStyle(fontSize: 12)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.teal.shade700,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    IconButton.filled(
                      onPressed: isRunning ? () => sim.stopRun() : null,
                      icon: const Icon(Icons.stop, color: Colors.white, size: 18),
                      style: IconButton.styleFrom(
                        backgroundColor: Colors.redAccent,
                        padding: const EdgeInsets.all(8),
                      ),
                      tooltip: 'Stop Simulation',
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: isRunning
                        ? null
                        : () {
                            final runs = int.tryParse(ui.runsInputController.text) ?? 30;
                            sim.startBatchRun(
                              runs: runs,
                              scale: sim.timeScale.value > 1.0 ? sim.timeScale.value : 5.0,
                              randomLeader: sim.randomLeaderEachRun.value,
                              randomTarget: sim.randomTargetEachRun.value,
                            );
                          },
                    icon: const Icon(Icons.auto_graph, color: Colors.white, size: 18),
                    label: const Text('Run Batch (Monte Carlo)', style: TextStyle(fontSize: 12)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.indigoAccent.shade700,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                ),
              ],
            );
          }),

          const SizedBox(height: 12),
          const Divider(color: Colors.white24),
          const SizedBox(height: 6),

          // PRE-FLIGHT SETUP SECTION
          const Text(
            'PRE-FLIGHT SETUP & HARDWARE',
            style: TextStyle(
              color: Colors.cyanAccent,
              fontSize: 11,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.8,
            ),
          ),
          const SizedBox(height: 8),

          // Swarm Size Selector (1 Drone, 2 Drones, 3 Drones)
          const Text(
            'Active Swarm Size (AI Mapping Mode):',
            style: TextStyle(color: Colors.white70, fontSize: 11),
          ),
          const SizedBox(height: 6),
          Obx(() {
            final isRunning = sim.simState.value == SimState.running ||
                sim.simState.value == SimState.targetFound ||
                sim.isBatchRunning.value;
            final count = sim.activeDroneCount.value;

            return Row(
              children: [1, 2, 3].map((n) {
                final isSelected = count == n;
                return Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 2),
                    child: ChoiceChip(
                      label: Center(
                        child: Text(
                          '$n ${n == 1 ? "Drone" : "Drones"}',
                          style: TextStyle(
                            color: isSelected ? Colors.black : Colors.white70,
                            fontWeight: FontWeight.bold,
                            fontSize: 10,
                          ),
                        ),
                      ),
                      selected: isSelected,
                      selectedColor: Colors.amberAccent,
                      backgroundColor: const Color(0xFF0F172A),
                      onSelected: isRunning
                          ? null
                          : (selected) {
                              if (selected) {
                                sim.setActiveDroneCount(n);
                              }
                            },
                    ),
                  ),
                );
              }).toList(),
            );
          }),
          const SizedBox(height: 10),

          // Drone Frame Selector
          const Text(
            'Drone Frame Geometry:',
            style: TextStyle(color: Colors.white70, fontSize: 11),
          ),
          const SizedBox(height: 6),
          Obx(() {
            final isRunning = sim.simState.value == SimState.running ||
                sim.simState.value == SimState.targetFound ||
                sim.isBatchRunning.value;

            return Wrap(
              spacing: 4,
              runSpacing: 4,
              children: DroneFrameType.values.map((frame) {
                final isSelected = ui.selectedFrameType.value == frame;
                return ChoiceChip(
                  label: Text(frame.displayName),
                  selected: isSelected,
                  selectedColor: Colors.cyanAccent,
                  labelStyle: TextStyle(
                    color: isSelected ? Colors.black : Colors.white70,
                    fontWeight: FontWeight.bold,
                    fontSize: 10,
                  ),
                  backgroundColor: const Color(0xFF0F172A),
                  onSelected: isRunning
                      ? null
                      : (selected) {
                          if (selected) {
                            ui.selectedFrameType.value = frame;
                            sim.setGlobalFrameType(frame);
                          }
                        },
                );
              }).toList(),
            );
          }),
          const SizedBox(height: 8),

          // Pre-Flight Randomization Buttons
          Obx(() {
            final isRunning = sim.simState.value == SimState.running ||
                sim.simState.value == SimState.targetFound ||
                sim.isBatchRunning.value;

            return Column(
              children: [
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: isRunning
                        ? null
                        : () {
                            sim.randomizeDronePositions();
                            ui.activateDroneGizmos();
                          },
                    icon: const Icon(Icons.shuffle, size: 14),
                    label: const Text('Randomize Drones in Rooms', style: TextStyle(fontSize: 11)),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.amberAccent,
                      side: const BorderSide(color: Colors.amberAccent, width: 1),
                      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
                      alignment: Alignment.centerLeft,
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: isRunning
                        ? null
                        : () {
                            sim.randomizeTargetPosition();
                            ui.activateTargetGizmo();
                          },
                    icon: const Icon(Icons.gps_fixed, size: 14),
                    label: const Text('Randomize Target in Room', style: TextStyle(fontSize: 11)),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.lightGreenAccent,
                      side: const BorderSide(color: Colors.lightGreenAccent, width: 1),
                      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
                      alignment: Alignment.centerLeft,
                    ),
                  ),
                ),
                if (ui.gizmoMode.value != GizmoMode.none) ...[
                  const SizedBox(height: 6),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () => ui.lockAndDismissGizmos(),
                      icon: const Icon(Icons.lock_outline, size: 14, color: Colors.black),
                      label: const Text('Lock / Selesai Atur Posisi', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.greenAccent,
                        foregroundColor: Colors.black,
                        padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 6),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: isRunning ? null : () => sim.randomizePreFlightRoles(),
                    icon: const Icon(Icons.lightbulb_outline, size: 14),
                    label: const Text('Re-roll 4-Pole LEDs (1 Yellow, 2 Blue)', style: TextStyle(fontSize: 11)),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.cyanAccent,
                      side: const BorderSide(color: Colors.cyanAccent, width: 1),
                      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
                      alignment: Alignment.centerLeft,
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: isRunning ? null : () => sim.resetToDefaultPositions(),
                    icon: const Icon(Icons.restart_alt, size: 14),
                    label: const Text('Reset to Launch Pads', style: TextStyle(fontSize: 11)),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.white70,
                      side: const BorderSide(color: Colors.white24, width: 1),
                      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
                      alignment: Alignment.centerLeft,
                    ),
                  ),
                ),
              ],
            );
          }),

          const SizedBox(height: 12),
          const Divider(color: Colors.white24),
          const SizedBox(height: 8),

          // CSV Result Button (Enabled once batch finishes)
          Obx(() {
            final ready = sim.isCsvReady.value;
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: ready ? () => sim.openCsvFile() : null,
                        icon: const Icon(Icons.table_chart_outlined, size: 16),
                        label: const Text('Open CSV File', style: TextStyle(fontSize: 11)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: ready ? Colors.green.shade700 : Colors.grey.shade800,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
                        ),
                      ),
                    ),
                    const SizedBox(width: 4),
                    IconButton(
                      onPressed: ready
                          ? () {
                              Get.dialog(const CsvViewerDialog());
                            }
                          : null,
                      icon: const Icon(Icons.preview, size: 18),
                      tooltip: 'Preview CSV Table',
                      style: IconButton.styleFrom(
                        foregroundColor: ready ? Colors.cyanAccent : Colors.grey,
                        padding: const EdgeInsets.all(4),
                      ),
                    ),
                  ],
                ),
                if (sim.lastCsvPath.value.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    'Saved: ${sim.lastCsvPath.value.split("/").last}',
                    style: const TextStyle(color: Colors.white54, fontSize: 10),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ],
            );
          }),

          const SizedBox(height: 12),
          const Divider(color: Colors.white24),
          const SizedBox(height: 8),

          // Monte Carlo Settings
          const Text(
            'BATCH SETTINGS',
            style: TextStyle(
              color: Colors.white70,
              fontSize: 11,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.8,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 8,
            runSpacing: 4,
            children: [
              const Text('Number of Runs:', style: TextStyle(color: Colors.white, fontSize: 12)),
              SizedBox(
                width: 65,
                height: 32,
                child: TextField(
                  controller: ui.runsInputController,
                  keyboardType: TextInputType.number,
                  style: const TextStyle(color: Colors.white, fontSize: 12),
                  textAlign: TextAlign.center,
                  decoration: InputDecoration(
                    contentPadding: const EdgeInsets.symmetric(vertical: 2),
                    filled: true,
                    fillColor: const Color(0xFF0F172A),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(6),
                      borderSide: const BorderSide(color: Colors.white30),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),

          // Toggles
          Obx(() => SwitchListTile(
                contentPadding: EdgeInsets.zero,
                dense: true,
                title: const Text('Random Leader each run', style: TextStyle(color: Colors.white, fontSize: 12)),
                value: sim.randomLeaderEachRun.value,
                onChanged: (v) => sim.randomLeaderEachRun.value = v,
                activeThumbColor: Colors.cyanAccent,
              )),
          Obx(() => SwitchListTile(
                contentPadding: EdgeInsets.zero,
                dense: true,
                title: const Text('Random Target each run', style: TextStyle(color: Colors.white, fontSize: 12)),
                value: sim.randomTargetEachRun.value,
                onChanged: (v) => sim.randomTargetEachRun.value = v,
                activeThumbColor: Colors.cyanAccent,
              )),

          const SizedBox(height: 12),
          const Divider(color: Colors.white24),
          const SizedBox(height: 8),

          // Speed Multipliers
          const Text(
            'SIMULATION SPEED',
            style: TextStyle(
              color: Colors.white70,
              fontSize: 11,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.8,
            ),
          ),
          const SizedBox(height: 8),
          Obx(() {
            final cur = sim.timeScale.value;
            final speeds = [1.0, 2.0, 5.0, 10.0, 20.0];

            return Wrap(
              spacing: 4,
              runSpacing: 4,
              children: speeds.map((s) {
                final isSelected = (cur - s).abs() < 0.1;
                return ChoiceChip(
                  label: Text('${s.toInt()}x'),
                  selected: isSelected,
                  selectedColor: Colors.cyanAccent,
                  labelStyle: TextStyle(
                    color: isSelected ? Colors.black : Colors.white70,
                    fontWeight: FontWeight.bold,
                    fontSize: 11,
                  ),
                  backgroundColor: const Color(0xFF0F172A),
                  onSelected: (_) => sim.timeScale.value = s,
                );
              }).toList(),
            );
          }),

          const SizedBox(height: 12),
          const Divider(color: Colors.white24),
          const SizedBox(height: 8),

          // Display Overlays & Features
          const Text(
            'VIEW TOGGLES & SENSORS',
            style: TextStyle(
              color: Colors.white70,
              fontSize: 11,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.8,
            ),
          ),
          Obx(() => CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                dense: true,
                title: const Text('LiDAR Rays (5x) & UWB', style: TextStyle(color: Colors.white, fontSize: 12)),
                value: ui.showSensors.value,
                onChanged: (v) => ui.showSensors.value = v ?? true,
                activeColor: Colors.cyanAccent,
              )),
          Obx(() => CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                dense: true,
                title: const Text('Global Occupancy Grid', style: TextStyle(color: Colors.white, fontSize: 12)),
                value: ui.showGrid.value,
                onChanged: (v) => ui.showGrid.value = v ?? true,
                activeColor: Colors.cyanAccent,
              )),
          Obx(() => CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                dense: true,
                title: const Text('A* Path Trajectories', style: TextStyle(color: Colors.white, fontSize: 12)),
                value: ui.showPaths.value,
                onChanged: (v) => ui.showPaths.value = v ?? true,
                activeColor: Colors.cyanAccent,
              )),
          Obx(() => CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                dense: true,
                title: const Text('Mission History Path', style: TextStyle(color: Colors.amberAccent, fontSize: 12)),
                subtitle: const Text('Search track lines from start', style: TextStyle(color: Colors.white54, fontSize: 10)),
                value: ui.showMissionPath.value,
                onChanged: (v) => ui.showMissionPath.value = v ?? true,
                activeColor: Colors.amberAccent,
              )),
          Obx(() => CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                dense: true,
                title: const Text('3 AI Drone Minimaps', style: TextStyle(color: Colors.lightGreenAccent, fontSize: 12)),
                subtitle: const Text('Individual SLAM room mapping', style: TextStyle(color: Colors.white54, fontSize: 10)),
                value: ui.showMinimaps.value,
                onChanged: (v) => ui.showMinimaps.value = v ?? true,
                activeColor: Colors.lightGreenAccent,
              )),
          Obx(() => CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                dense: true,
                title: const Text('Hardware Specs & Labels', style: TextStyle(color: Colors.white, fontSize: 12)),
                value: ui.showDroneLabels.value,
                onChanged: (v) => ui.showDroneLabels.value = v ?? true,
                activeColor: Colors.cyanAccent,
              )),

          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: () => ui.resetCamera(),
            icon: const Icon(Icons.center_focus_strong, size: 14),
            label: const Text('Reset Camera View', style: TextStyle(fontSize: 11)),
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.white70,
              side: const BorderSide(color: Colors.white24),
              padding: const EdgeInsets.symmetric(vertical: 6),
            ),
          ),
          const SizedBox(height: 16),
        ],
      );
  }

  Widget _buildRealDronePanel(
    BuildContext context,
    SimulationController sim,
    UIController ui,
    HardwareBridgeService hw,
  ) {
    final state = hw.connectionState.value;
    final isConnected = state == HardwareConnectionState.connected;
    final isConnecting = state == HardwareConnectionState.connecting;
    final packet = hw.lastPacket.value;
    final dists = packet?.lidarDistances ?? [10.0, 10.0, 10.0, 10.0, 10.0];

    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      children: [
        // Header
        Row(
          children: [
            const Icon(Icons.wifi_tethering, color: Colors.greenAccent, size: 18),
            const SizedBox(width: 8),
            const Flexible(
              child: Text(
                'REAL DRONE (RPi 4)',
                style: TextStyle(
                  color: Colors.greenAccent,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.0,
                  fontSize: 13,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
              decoration: BoxDecoration(
                color: isConnected ? Colors.green.withValues(alpha: 0.2) : Colors.red.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(4),
                border: Border.all(color: isConnected ? Colors.greenAccent : Colors.redAccent, width: 0.8),
              ),
              child: Text(
                isConnected ? 'ONLINE' : 'OFFLINE',
                style: TextStyle(
                  color: isConnected ? Colors.greenAccent : Colors.redAccent,
                  fontSize: 9,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),

        // 1. Connection Card
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: const Color(0xFF0F172A),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: isConnected ? Colors.greenAccent.withValues(alpha: 0.5) : Colors.white24,
              width: 1.2,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    isConnected ? Icons.check_circle : Icons.radio_button_checked,
                    size: 14,
                    color: isConnected ? Colors.greenAccent : (isConnecting ? Colors.amberAccent : Colors.redAccent),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      isConnected ? 'CONNECTED (RPI 4)' : (isConnecting ? 'CONNECTING...' : 'DISCONNECTED'),
                      style: TextStyle(
                        color: isConnected ? Colors.greenAccent : (isConnecting ? Colors.amberAccent : Colors.redAccent),
                        fontWeight: FontWeight.bold,
                        fontSize: 10,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (isConnected)
                    IconButton(
                      onPressed: () => hw.ping(),
                      icon: const Icon(Icons.refresh, size: 14, color: Colors.white70),
                      tooltip: 'Ping Drone',
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                ],
              ),
              const SizedBox(height: 8),

              // IP and Port Input Row
              Row(
                children: [
                  Expanded(
                    flex: 3,
                    child: TextField(
                      controller: ui.rpiIpController,
                      style: const TextStyle(color: Colors.white, fontSize: 11),
                      decoration: InputDecoration(
                        isDense: true,
                        labelText: 'RPi Host / IP',
                        labelStyle: const TextStyle(color: Colors.white60, fontSize: 10),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(6)),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(6),
                          borderSide: const BorderSide(color: Colors.white24),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    flex: 2,
                    child: TextField(
                      controller: ui.rpiPortController,
                      keyboardType: TextInputType.number,
                      style: const TextStyle(color: Colors.white, fontSize: 11),
                      decoration: InputDecoration(
                        isDense: true,
                        labelText: 'Port',
                        labelStyle: const TextStyle(color: Colors.white60, fontSize: 10),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(6)),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(6),
                          borderSide: const BorderSide(color: Colors.white24),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),

              // Connect / Disconnect Button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: isConnecting
                      ? null
                      : () {
                          if (isConnected) {
                            hw.disconnect();
                          } else {
                            final port = int.tryParse(ui.rpiPortController.text.trim()) ?? 8765;
                            hw.connect(
                              host: ui.rpiIpController.text.trim(),
                              port: port,
                            );
                          }
                        },
                  icon: isConnecting
                      ? const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : Icon(isConnected ? Icons.link_off : Icons.link, size: 16),
                  label: Text(
                    isConnected ? 'Disconnect Drone' : 'Connect to Raspberry Pi',
                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isConnected ? Colors.red.shade800 : Colors.green.shade700,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 8),
                  ),
                ),
              ),

              if (hw.errorMessage.isNotEmpty) ...[
                const SizedBox(height: 6),
                Text(
                  hw.errorMessage.value,
                  style: const TextStyle(color: Colors.redAccent, fontSize: 9),
                ),
              ],
            ],
          ),
        ),

        const SizedBox(height: 10),

        // 2. Telemetry Live Metrics Card
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: const Color(0xFF1E293B),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _metricTile('Rate', '${hw.packetRateHz.value.toStringAsFixed(0)} Hz', Colors.cyanAccent),
                  _metricTile('Latency', '${hw.pingMs.value.toStringAsFixed(0)} ms', Colors.lightGreenAccent),
                  _metricTile('Battery', '${(packet?.batteryVoltage ?? 14.8).toStringAsFixed(1)}V', Colors.amberAccent),
                ],
              ),
              const Divider(color: Colors.white12, height: 12),
              // Motion & UWB Status
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: (packet?.isMoving ?? false)
                          ? Colors.amberAccent.withValues(alpha: 0.2)
                          : Colors.cyanAccent.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      (packet?.isMoving ?? false) ? '🚀 BERGERAK' : '🛡️ DIAM (STABIL)',
                      style: TextStyle(
                        color: (packet?.isMoving ?? false) ? Colors.amberAccent : Colors.cyanAccent,
                        fontSize: 9.5,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  Text(
                    'UWB: ${(packet?.uwbRawDist ?? 0.0).toStringAsFixed(2)}m (Δ: ${((packet != null && packet.uwbOriginDist > 0) ? (packet.uwbRawDist - packet.uwbOriginDist) : 0.0).toStringAsFixed(2)}m)',
                    style: const TextStyle(color: Colors.white70, fontSize: 9.5, fontFamily: 'monospace'),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Wrap(
                alignment: WrapAlignment.spaceBetween,
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 6,
                runSpacing: 4,
                children: [
                  Text(
                    'Pos: (${(sim.drones.isNotEmpty ? sim.drones[0].position.x : 0.0).toStringAsFixed(2)}, ${(sim.drones.isNotEmpty ? sim.drones[0].position.y : 0.0).toStringAsFixed(2)}) m',
                    style: const TextStyle(color: Colors.white70, fontSize: 10, fontFamily: 'monospace'),
                  ),
                  Text(
                    'Heading: ${(sim.drones.isNotEmpty ? (sim.drones[0].headingAngle * 180 / math.pi) : 0.0).toStringAsFixed(0)}°',
                    style: const TextStyle(color: Colors.white70, fontSize: 10, fontFamily: 'monospace'),
                  ),
                ],
              ),
            ],
          ),
        ),

        const SizedBox(height: 10),

        // 3. 5x Real LiDAR Live Distances
        const Text(
          '5x REAL PHYSICAL LIDAR SENSORS:',
          style: TextStyle(color: Colors.cyanAccent, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 0.5),
        ),
        const SizedBox(height: 6),
        ...[
          _lidarBar('L1 Front (0°)', dists[0]),
          _lidarBar('L2 Angle (45°)', dists[1]),
          _lidarBar('L3 Left (90°)', dists[2]),
          _lidarBar('L4 Right (-90°)', dists[3]),
          _lidarBar('L5 Rear (180°)', dists[4]),
        ],

        const SizedBox(height: 10),

        // 4. Hardware SLAM Actions
        const Text(
          'SLAM MAPPING CONTROLS:',
          style: TextStyle(color: Colors.cyanAccent, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 0.5),
        ),
        const SizedBox(height: 6),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: () => sim.calibrateRealDroneZero(),
            icon: const Icon(Icons.my_location, size: 14),
            label: const Text('Set Start Point (0,0) Here', style: TextStyle(fontSize: 11)),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.teal.shade800,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 8),
            ),
          ),
        ),
        const SizedBox(height: 6),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: () => sim.clearRealDroneMap(),
            icon: const Icon(Icons.layers_clear, size: 14),
            label: const Text('Clear SLAM Room Map', style: TextStyle(fontSize: 11)),
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.amberAccent,
              side: const BorderSide(color: Colors.amberAccent, width: 1),
              padding: const EdgeInsets.symmetric(vertical: 8),
            ),
          ),
        ),
        const SizedBox(height: 10),

        // 5. Movement Sensitivity / Scale Multiplier
        const Text(
          'SENSITIVITAS GERAK (SCALE):',
          style: TextStyle(color: Colors.cyanAccent, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 0.5),
        ),
        const SizedBox(height: 6),
        Obx(() {
          final curScale = hw.movementScale.value;
          return Row(
            children: [
              _buildScaleButton(hw, 1.0, '1.0x Real', curScale == 1.0),
              const SizedBox(width: 4),
              _buildScaleButton(hw, 2.0, '2.0x', curScale == 2.0),
              const SizedBox(width: 4),
              _buildScaleButton(hw, 3.0, '3.0x Meja', curScale == 3.0),
            ],
          );
        }),
        const SizedBox(height: 10),

        // 6. View Controls
        const Text(
          'VIEW & CAMERA:',
          style: TextStyle(color: Colors.cyanAccent, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 0.5),
        ),
        const SizedBox(height: 6),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: () {
              final dronePos = sim.drones.isNotEmpty ? sim.drones[0].position : Vector2.zero;
              ui.centerOnWorld(dronePos, const Size(1200, 800), targetZoom: 6.0);
              ui.followingDroneIndex.value = 0;
            },
            icon: const Icon(Icons.zoom_in_map, size: 14, color: Colors.black),
            label: const Text('Fokus 1:1 Desk View (Zoom Dekat)', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.black)),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.cyanAccent,
              foregroundColor: Colors.black,
              padding: const EdgeInsets.symmetric(vertical: 7),
            ),
          ),
        ),
        const SizedBox(height: 4),
        Obx(() => CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              dense: true,
              title: const Text('Tampilkan AI Minimap', style: TextStyle(color: Colors.white, fontSize: 11)),
              value: ui.showMinimaps.value,
              onChanged: (v) => ui.showMinimaps.value = v ?? true,
              activeColor: Colors.cyanAccent,
            )),
        Obx(() => CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              dense: true,
              title: const Text('Tampilkan Jejak Drone', style: TextStyle(color: Colors.white, fontSize: 11)),
              value: ui.showMissionPath.value,
              onChanged: (v) => ui.showMissionPath.value = v ?? true,
              activeColor: Colors.cyanAccent,
            )),
        const SizedBox(height: 4),
        OutlinedButton.icon(
          onPressed: () => ui.resetCamera(),
          icon: const Icon(Icons.center_focus_strong, size: 14),
          label: const Text('Reset Camera View (Fit All)', style: TextStyle(fontSize: 11)),
          style: OutlinedButton.styleFrom(
            foregroundColor: Colors.white70,
            side: const BorderSide(color: Colors.white24),
            padding: const EdgeInsets.symmetric(vertical: 6),
          ),
        ),

        const SizedBox(height: 10),

        // Helper Note
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.blueGrey.shade900.withValues(alpha: 0.5),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: Colors.white12),
          ),
          child: const Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.info_outline, size: 14, color: Colors.cyanAccent),
              SizedBox(width: 6),
              Expanded(
                child: Text(
                  'Gerakkan drone fisik dari titik start. Sensor LiDAR akan mendeteksi dinding ruangan dan memetakan denah ruangan secara live di layar utama dan minimap.',
                  style: TextStyle(color: Colors.white70, fontSize: 9.5, height: 1.3),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
      ],
    );
  }

  Widget _metricTile(String title, String val, Color color) {
    return Column(
      children: [
        Text(title, style: const TextStyle(color: Colors.white54, fontSize: 9)),
        const SizedBox(height: 2),
        Text(val, style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.bold)),
      ],
    );
  }

  Widget _lidarBar(String name, double distM) {
    final clamped = distM.clamp(0.0, 10.0);
    final pct = (clamped / 10.0).clamp(0.0, 1.0);
    final Color barColor = distM < 0.5
        ? Colors.redAccent
        : (distM < 1.2 ? Colors.amberAccent : Colors.greenAccent);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2.5),
      child: Row(
        children: [
          SizedBox(
            width: 78,
            child: Text(
              name,
              style: const TextStyle(color: Colors.white70, fontSize: 9.5),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(3),
              child: LinearProgressIndicator(
                value: pct,
                backgroundColor: const Color(0xFF0F172A),
                valueColor: AlwaysStoppedAnimation<Color>(barColor),
                minHeight: 5,
              ),
            ),
          ),
          const SizedBox(width: 6),
          SizedBox(
            width: 38,
            child: Text(
              '${distM.toStringAsFixed(2)}m',
              style: TextStyle(color: barColor, fontSize: 9.5, fontWeight: FontWeight.bold),
              textAlign: TextAlign.right,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildScaleButton(HardwareBridgeService hw, double scale, String label, bool isSelected) {
    return Expanded(
      child: InkWell(
        onTap: () => hw.setMovementScale(scale),
        borderRadius: BorderRadius.circular(6),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 6),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: isSelected ? Colors.cyanAccent.withValues(alpha: 0.25) : const Color(0xFF0F172A),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(
              color: isSelected ? Colors.cyanAccent : Colors.white24,
              width: 1,
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              color: isSelected ? Colors.cyanAccent : Colors.white70,
              fontSize: 10,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        ),
      ),
    );
  }
}

