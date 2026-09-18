import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../controllers/simulation_controller.dart';
import '../../controllers/ui_controller.dart';
import '../../models/drone_model.dart';
import '../../models/grid_map_2d.dart';
import '../../models/vector2.dart';

class MinimapPanel extends StatelessWidget {
  const MinimapPanel({super.key});

  @override
  Widget build(BuildContext context) {
    final sim = Get.find<SimulationController>();
    final ui = Get.find<UIController>();

    return Obx(() {
      if (!ui.showMinimaps.value) return const SizedBox.shrink();

      return Container(
        height: 220,
        decoration: const BoxDecoration(
          color: Color(0xFF111827),
          border: Border(top: BorderSide(color: Color(0xFF374151), width: 1.5)),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Section Header
            Row(
              children: [
                const Icon(Icons.map_outlined, color: Colors.cyanAccent, size: 16),
                const SizedBox(width: 8),
                Obx(() => Text(
                      sim.activeDroneCount.value == 1
                          ? 'AI LOCAL ROOM MAPPING (1 DRONE - WIDE SCAN)'
                          : '${sim.activeDroneCount.value}-DRONE AI LOCAL ROOM MAPPING',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                        letterSpacing: 0.8,
                      ),
                    )),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    'RPi 4 • Pixhawk 6 • 5x LiDAR • OF • UWB DW3000',
                    style: TextStyle(color: Colors.white54, fontSize: 10),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                IconButton(
                  onPressed: () => ui.showMinimaps.value = false,
                  icon: const Icon(Icons.close, size: 16, color: Colors.white60),
                  tooltip: 'Hide Minimaps',
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ],
            ),
            const SizedBox(height: 6),

            // Adaptive Minimap Boxes Side-by-Side (1: 100% full-width, 2: 50%/50%, 3: 33.3% each)
            Expanded(
              child: Row(
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
    final isLeader = drone.role == DroneRole.leader;
    final roleColor = drone.ledColor;

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: roleColor.withValues(alpha: 0.6),
          width: 1.5,
        ),
      ),
      child: Column(
        children: [
          // Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
            decoration: BoxDecoration(
              color: roleColor.withValues(alpha: 0.12),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(7)),
            ),
            child: Row(
              children: [
                Container(
                  width: 7,
                  height: 7,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: roleColor,
                    boxShadow: [
                      BoxShadow(color: roleColor.withValues(alpha: 0.8), blurRadius: 3),
                    ],
                  ),
                ),
                const SizedBox(width: 4),
                Text(
                  drone.name,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 10,
                  ),
                ),
                const SizedBox(width: 4),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                  decoration: BoxDecoration(
                    color: isLeader ? Colors.amber.shade900 : Colors.cyan.shade900,
                    borderRadius: BorderRadius.circular(3),
                  ),
                  child: Text(
                    isLeader ? 'LEADER' : 'MEMBER',
                    style: TextStyle(
                      color: isLeader ? Colors.amberAccent : Colors.cyanAccent,
                      fontSize: 8,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const Spacer(),
                Text(
                  '${drone.exploredPercentage.toStringAsFixed(0)}% Map',
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 9,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),

          // Minimap Custom Canvas
          Expanded(
            child: ClipRRect(
              borderRadius: const BorderRadius.vertical(bottom: Radius.circular(7)),
              child: CustomPaint(
                size: Size.infinite,
                painter: _DroneLocalMapPainter(drone: drone),
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

  _DroneLocalMapPainter({required this.drone});

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
      Paint()..color = const Color(0xFF0B1017),
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
        } else if (val == GridMap2D.occupied) {
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
