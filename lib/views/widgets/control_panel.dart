import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../controllers/simulation_controller.dart';
import '../../controllers/ui_controller.dart';
import '../../models/drone_model.dart';
import 'csv_viewer_dialog.dart';

class ControlPanel extends StatelessWidget {
  const ControlPanel({super.key});

  @override
  Widget build(BuildContext context) {
    final sim = Get.find<SimulationController>();
    final ui = Get.find<UIController>();

    return Container(
      color: const Color(0xFF161E2E),
      child: ListView(
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
      ),
    );
  }
}
