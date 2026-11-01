import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../controllers/simulation_controller.dart';
import '../../controllers/ui_controller.dart';
import '../../models/drone_model.dart';
import '../../models/grid_map_2d.dart';
import '../../models/vector2.dart';
import '../../utils/app_theme.dart';

class MinimapPanel extends StatelessWidget {
  final bool? isVertical;

  const MinimapPanel({super.key, this.isVertical});

  @override
  Widget build(BuildContext context) {
    final sim = Get.find<SimulationController>();
    final ui = Get.find<UIController>();

    return Obx(() {
      if (!ui.showMinimaps.value) return const SizedBox.shrink();

      final isDark = ui.isDarkMode;
      final effectiveVertical = isVertical ?? (ui.activeSplitLayout.value != ArenaSplitLayout.horizontal);

      return Container(
        decoration: BoxDecoration(
          color: AppColors.minimapPanel(isDark),
          border: Border(
            top: effectiveVertical ? BorderSide.none : BorderSide(color: AppColors.border(isDark), width: 1.0),
            left: effectiveVertical ? BorderSide(color: AppColors.border(isDark), width: 1.0) : BorderSide.none,
          ),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Section Header
            if (effectiveVertical)
              Row(
                children: [
                  Icon(
                    Icons.map_outlined,
                    color: isDark ? Colors.cyanAccent : const Color(0xFF0284C7),
                    size: 15,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Obx(() => Text(
                          sim.activeDroneCount.value == 1
                              ? 'AI SLAM MAPPING (1 DRONE)'
                              : '${sim.activeDroneCount.value}x AI SLAM MAPPING',
                          style: TextStyle(
                            color: AppColors.textPrimary(isDark),
                            fontWeight: FontWeight.bold,
                            fontSize: 11,
                            letterSpacing: 0.6,
                          ),
                          overflow: TextOverflow.ellipsis,
                        )),
                  ),
                  IconButton(
                    onPressed: () => ui.showMinimaps.value = false,
                    icon: Icon(Icons.close, size: 15, color: isDark ? Colors.white60 : const Color(0xFF64748B)),
                    tooltip: 'Hide Minimap Panel',
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ],
              )
            else
              Row(
                children: [
                  Icon(
                    Icons.map_outlined,
                    color: isDark ? Colors.cyanAccent : const Color(0xFF0284C7),
                    size: 16,
                  ),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Obx(() => Text(
                          sim.activeDroneCount.value == 1
                              ? 'AI LOCAL ROOM MAPPING (1 DRONE - WIDE SCAN)'
                              : '${sim.activeDroneCount.value}-DRONE AI LOCAL ROOM MAPPING',
                          style: TextStyle(
                            color: AppColors.textPrimary(isDark),
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                            letterSpacing: 0.8,
                          ),
                          overflow: TextOverflow.ellipsis,
                        )),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'RPi 4 • Pixhawk 6 • 5x LiDAR • OF • UWB DW3000',
                      style: TextStyle(
                        color: AppColors.textMuted(isDark),
                        fontSize: 10,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  IconButton(
                    onPressed: () => ui.showMinimaps.value = false,
                    icon: Icon(Icons.close, size: 16, color: isDark ? Colors.white60 : const Color(0xFF64748B)),
                    tooltip: 'Hide Minimaps',
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ],
              ),
            const SizedBox(height: 6),

            // Adaptive Minimap Boxes: Row in Horizontal mode, Column in Vertical mode
            Expanded(
              child: effectiveVertical
                  ? Column(
                      children: sim.activeDrones.map((drone) {
                        return Expanded(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 3),
                            child: _SingleDroneMinimap(drone: drone),
                          ),
                        );
                      }).toList(),
                    )
                  : Row(
                      children: sim.activeDrones.map((drone) {
                        return Expanded(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 4),
                            child: _SingleDroneMinimap(drone: drone),
                          ),
                        );
                      }).toList(),
                    ),
            ),
          ],
        ),
      );
    });
  }
}

class _SingleDroneMinimap extends StatelessWidget {
  final DroneModel drone;

  const _SingleDroneMinimap({required this.drone});

  @override
  Widget build(BuildContext context) {
    final ui = Get.find<UIController>();
    final isDark = ui.isDarkMode;
    final isLeader = drone.role == DroneRole.leader;
    final roleColor = drone.ledColor;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: roleColor.withValues(alpha: isDark ? 0.6 : 0.4),
          width: 1.5,
        ),
        boxShadow: isDark
            ? null
            : [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 3,
                  offset: const Offset(0, 1),
                ),
              ],
      ),
      child: Column(
        children: [
          // Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 3),
            decoration: BoxDecoration(
              color: roleColor.withValues(alpha: isDark ? 0.12 : 0.08),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(7)),
            ),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final isCompact = constraints.maxWidth < 150;
                final isUltraCompact = constraints.maxWidth < 95;

                return Row(
                  children: [
                    Container(
                      width: 6,
                      height: 6,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: roleColor,
                        boxShadow: [
                          BoxShadow(color: roleColor.withValues(alpha: 0.8), blurRadius: 2),
                        ],
                      ),
                    ),
                    const SizedBox(width: 4),
                    Flexible(
                      child: Text(
                        drone.name,
                        style: TextStyle(
                          color: isDark ? Colors.white : const Color(0xFF0F172A),
                          fontWeight: FontWeight.bold,
                          fontSize: 10,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (!isCompact) ...[
                      const SizedBox(width: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                        decoration: BoxDecoration(
                          color: isLeader
                              ? (isDark ? Colors.amber.shade900 : Colors.amber.shade100)
                              : (isDark ? Colors.cyan.shade900 : Colors.cyan.shade100),
                          borderRadius: BorderRadius.circular(3),
                        ),
                        child: Text(
                          isLeader ? 'LEADER' : 'MEMBER',
                          style: TextStyle(
                            color: isLeader
                                ? (isDark ? Colors.amberAccent : Colors.amber.shade900)
                                : (isDark ? Colors.cyanAccent : const Color(0xFF0369A1)),
                            fontSize: 8,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ] else if (!isUltraCompact) ...[
                      const SizedBox(width: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 1),
                        decoration: BoxDecoration(
                          color: isLeader
                              ? (isDark ? Colors.amber.shade900 : Colors.amber.shade100)
                              : (isDark ? Colors.cyan.shade900 : Colors.cyan.shade100),
                          borderRadius: BorderRadius.circular(2),
                        ),
                        child: Text(
                          isLeader ? 'L' : 'M',
                          style: TextStyle(
                            color: isLeader
                                ? (isDark ? Colors.amberAccent : Colors.amber.shade900)
                                : (isDark ? Colors.cyanAccent : const Color(0xFF0369A1)),
                            fontSize: 7.5,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                    const Spacer(),
                    Text(
                      isCompact
                          ? '${drone.exploredPercentage.toStringAsFixed(0)}%'
                          : '${drone.exploredPercentage.toStringAsFixed(0)}% Map',
                      style: TextStyle(
                        color: isDark ? Colors.white70 : const Color(0xFF475569),
                        fontSize: 9,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                );
              },
            ),
          ),

          // Minimap Custom Canvas
          Expanded(
            child: ClipRRect(
              borderRadius: const BorderRadius.vertical(bottom: Radius.circular(7)),
              child: CustomPaint(
                size: Size.infinite,
                painter: _DroneLocalMapPainter(
                  drone: drone,
                  wallLineThickness: ui.wallLineThickness.value,
                  isDark: isDark,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DroneLocalMapPainter extends CustomPainter {
  final DroneModel drone;
  final int wallLineThickness;
  final bool isDark;

  _DroneLocalMapPainter({
    required this.drone,
    required this.wallLineThickness,
    required this.isDark,
  });

  static const double worldCenterX = 0.0;
  static const double worldCenterY = 3.0;
  static const double worldSpanX = 32.0;
  static const double worldSpanY = 18.0;

  @override
  void paint(Canvas canvas, Size size) {
    final scale = math.min(size.width / worldSpanX, size.height / worldSpanY);
    final origin = Offset(size.width / 2.0, size.height / 2.0);

    Offset w2s(Vector2 w) {
      final dx = (w.x - worldCenterX) * scale;
      final dy = -(w.y - worldCenterY) * scale;
      return Offset(origin.dx + dx, origin.dy + dy);
    }

    // Background
    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.width, size.height),
      Paint()..color = isDark ? const Color(0xFF0B1017) : const Color(0xFFF1F5F9),
    );

    final map = drone.localMap;
    final cellPixelSize = math.max(1.2, map.cellSize * scale);

    final freePaint = Paint()
      ..color = const Color(0x4406B6D4) // Local explored free space in glowing cyan
      ..style = PaintingStyle.fill;

    final occupiedPaint = Paint()
      ..color = const Color(0xDDDC2626) // Local detected walls in bold red
      ..style = PaintingStyle.fill;

    // Draw discovered cells
    for (int y = 0; y < map.height; y += 1) {
      for (int x = 0; x < map.width; x += 1) {
        final val = map.rawGrid[y * map.width + x];
        if (val == GridMap2D.unknown) continue;

        final centerW = map.cellToWorldCenter(Vector2Int(x, y));
        final screenCenter = w2s(centerW);
        final rect = Rect.fromCenter(
          center: screenCenter,
          width: cellPixelSize,
          height: cellPixelSize,
        );

        if (val == GridMap2D.free) {
          canvas.drawRect(rect, freePaint);
        } else if (val == GridMap2D.occupied && wallLineThickness > 0) {
          canvas.drawRect(rect, occupiedPaint);
        }
      }
    }

    // Draw Drone Position & Heading Cone on its Minimap
    final droneScreenPos = w2s(drone.position);
    final droneR = math.max(3.0, drone.droneRadius * scale);

    // 4-pole LED glow marker
    final ledColor = drone.ledColor;
    canvas.drawCircle(
      droneScreenPos,
      droneR * 2.0,
      Paint()..color = ledColor.withValues(alpha: 0.35),
    );
    canvas.drawCircle(
      droneScreenPos,
      droneR,
      Paint()..color = ledColor,
    );

    // Heading direction pointer
    final headingVec = Vector2(math.cos(drone.headingAngle), math.sin(drone.headingAngle));
    final pointerEnd = w2s(drone.position + headingVec * 0.8);
    canvas.drawLine(
      droneScreenPos,
      pointerEnd,
      Paint()
        ..color = Colors.white
        ..strokeWidth = 1.5,
    );
  }

  @override
  bool shouldRepaint(covariant _DroneLocalMapPainter oldDelegate) => true;
}
