import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../controllers/simulation_controller.dart';
import '../controllers/ui_controller.dart';
import '../services/hardware_bridge_service.dart';
import 'arena_canvas.dart';
import 'widgets/control_panel.dart';
import 'widgets/drone_telemetry_card.dart';
import 'widgets/layout_preset_selector.dart';
import 'widgets/minimap_panel.dart';
import 'widgets/resizable_divider.dart';

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
          // 4-Preset Split Layout Selector [ | ⚏ ] [ ▮ ▯ ] [ ▔ ▃ ] [ ▯ | ▯ ]
          const Center(
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: 6),
              child: LayoutPresetSelector(),
            ),
          ),
          const SizedBox(width: 4),

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
      body: LayoutBuilder(
        builder: (context, constraints) {
          final totalHeight = constraints.maxHeight;

          return Obx(() {
            final splitLayout = ui.activeSplitLayout.value;
            final isLeftCollapsed = ui.isLeftPanelCollapsed.value;
            final isRightCollapsed = ui.isRightPanelCollapsed.value;
            final leftW = isLeftCollapsed ? 0.0 : ui.leftPanelWidth.value;
            final rightW = isRightCollapsed ? 0.0 : ui.rightPanelWidth.value;

            return Row(
              children: [
                // 1. Left Control Panel (Resizable & Collapsible)
                if (!isLeftCollapsed) ...[
                  SizedBox(
                    width: leftW,
                    child: const ControlPanel(),
                  ),
                  ResizableDivider(
                    axis: Axis.vertical,
                    isCollapsed: isLeftCollapsed,
                    onToggleCollapse: ui.toggleLeftPanel,
                    onDragUpdate: (dx) => ui.resizeLeftPanel(dx),
                    onDoubleTap: () => ui.leftPanelWidth.value = UIController.defaultLeftPanelWidth,
                    tooltip: 'Tarik untuk ubah lebar Panel Kontrol • Dobel-klik untuk reset',
                  ),
                ] else ...[
                  _CollapsedRibbon(
                    icon: Icons.chevron_right,
                    tooltip: 'Buka Panel Kontrol (Kiri)',
                    onTap: ui.toggleLeftPanel,
                  ),
                ],

                // 2. Center Multi-Mode Workspace (Arena & Minimaps)
                Expanded(
                  child: _buildCenterWorkspace(context, splitLayout, ui, sim, totalHeight),
                ),

                // 3. Right Telemetry Sidebar (Resizable & Collapsible)
                if (!isRightCollapsed) ...[
                  ResizableDivider(
                    axis: Axis.vertical,
                    isCollapsed: isRightCollapsed,
                    onToggleCollapse: ui.toggleRightPanel,
                    onDragUpdate: (dx) => ui.resizeRightPanel(dx),
                    onDoubleTap: () => ui.rightPanelWidth.value = UIController.defaultRightPanelWidth,
                    tooltip: 'Tarik untuk ubah lebar Panel Telemetri • Dobel-klik untuk reset',
                  ),
                  SizedBox(
                    width: rightW,
                    child: _buildTelemetrySidebar(sim),
                  ),
                ] else ...[
                  _CollapsedRibbon(
                    icon: Icons.chevron_left,
                    tooltip: 'Buka Panel Telemetri (Kanan)',
                    onTap: ui.toggleRightPanel,
                  ),
                ],
              ],
            );
          });
        },
      ),
    );
  }

  /// Center multi-mode split screen workspace
  Widget _buildCenterWorkspace(
    BuildContext context,
    ArenaSplitLayout splitLayout,
    UIController ui,
    SimulationController sim,
    double totalHeight,
  ) {
    switch (splitLayout) {
      case ArenaSplitLayout.arenaFocus:
        return Stack(
          children: [
            const Positioned.fill(
              child: ClipRect(
                child: ArenaCanvas(),
              ),
            ),
            // Floating pill to restore minimaps if user wants
            Positioned(
              bottom: 12,
              right: 12,
              child: InkWell(
                onTap: () => ui.setSplitLayout(ArenaSplitLayout.horizontal),
                borderRadius: BorderRadius.circular(20),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: const Color(0xDD0F172A),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.cyanAccent.withValues(alpha: 0.6), width: 1.0),
                    boxShadow: const [
                      BoxShadow(color: Colors.black54, blurRadius: 8, offset: Offset(0, 3)),
                    ],
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.map_outlined, size: 14, color: Colors.cyanAccent),
                      SizedBox(width: 6),
                      Text(
                        'Tampilkan Minimap',
                        style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        );

      case ArenaSplitLayout.vertical:
      case ArenaSplitLayout.rightStacked:
        return LayoutBuilder(
          builder: (context, centerConstraints) {
            final centerW = centerConstraints.maxWidth;

            return Obx(() {
              final showMaps = ui.showMinimaps.value;
              final curW = ui.minimapWidth.value.clamp(UIController.minMinimapWidth, centerW * 0.70);

              return Row(
                children: [
                  const Expanded(
                    child: ClipRect(
                      child: ArenaCanvas(),
                    ),
                  ),
                  if (showMaps) ...[
                    ResizableDivider(
                      axis: Axis.vertical,
                      onDragUpdate: (dx) => ui.resizeMinimapWidth(dx, centerW),
                      onDoubleTap: () => ui.minimapWidth.value = UIController.defaultMinimapWidth,
                      tooltip: 'Tarik untuk ubah lebar Minimap • Dobel-klik untuk reset',
                    ),
                    SizedBox(
                      width: curW,
                      child: const MinimapPanel(isVertical: true),
                    ),
                  ],
                ],
              );
            });
          },
        );

      case ArenaSplitLayout.horizontal:
        return LayoutBuilder(
          builder: (context, centerConstraints) {
            final centerH = centerConstraints.maxHeight;

            return Obx(() {
              final showMaps = ui.showMinimaps.value;
              final curH = ui.minimapHeight.value.clamp(UIController.minMinimapHeight, centerH * 0.75);

              return Column(
                children: [
                  const Expanded(
                    child: ClipRect(
                      child: ArenaCanvas(),
                    ),
                  ),
                  if (showMaps) ...[
                    ResizableDivider(
                      axis: Axis.horizontal,
                      onDragUpdate: (dy) => ui.resizeMinimapHeight(dy, centerH),
                      onDoubleTap: () => ui.minimapHeight.value = UIController.defaultMinimapHeight,
                      tooltip: 'Tarik untuk ubah tinggi Minimap • Dobel-klik untuk reset',
                    ),
                    SizedBox(
                      height: curH,
                      child: const MinimapPanel(isVertical: false),
                    ),
                  ],
                ],
              );
            });
          },
        );
    }
  }

  /// Right Swarm Telemetry Sidebar
  Widget _buildTelemetrySidebar(SimulationController sim) {
    return Container(
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
    );
  }
}

/// Sleek vertical collapsed ribbon bar with expand chevron button
class _CollapsedRibbon extends StatefulWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;

  const _CollapsedRibbon({
    required this.icon,
    required this.tooltip,
    required this.onTap,
  });

  @override
  State<_CollapsedRibbon> createState() => _CollapsedRibbonState();
}

class _CollapsedRibbonState extends State<_CollapsedRibbon> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: widget.tooltip,
      waitDuration: const Duration(milliseconds: 300),
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) => setState(() => _isHovered = true),
        onExit: (_) => setState(() => _isHovered = false),
        child: GestureDetector(
          onTap: widget.onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            width: 22,
            height: double.infinity,
            decoration: BoxDecoration(
              color: _isHovered ? const Color(0xFF1E293B) : const Color(0xFF0F172A),
              border: Border(
                right: widget.icon == Icons.chevron_right ? const BorderSide(color: Color(0xFF334155), width: 1.0) : BorderSide.none,
                left: widget.icon == Icons.chevron_left ? const BorderSide(color: Color(0xFF334155), width: 1.0) : BorderSide.none,
              ),
            ),
            child: Center(
              child: Icon(
                widget.icon,
                size: 16,
                color: _isHovered ? Colors.cyanAccent : Colors.white54,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
