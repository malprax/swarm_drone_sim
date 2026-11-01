import 'package:flutter/material.dart';
import '../../models/drone_model.dart';

class DroneTelemetryCard extends StatelessWidget {
  final DroneModel drone;

  const DroneTelemetryCard({super.key, required this.drone});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isLeader = drone.role == DroneRole.leader;
    final roleColor = drone.ledColor;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: roleColor.withValues(alpha: isDark ? 0.5 : 0.4),
          width: 1.5,
        ),
        boxShadow: isDark
            ? null
            : [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header: Name & Role/Status badges using Wrap to never overflow
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 6,
            runSpacing: 4,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 9,
                    height: 9,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: roleColor,
                      boxShadow: [
                        BoxShadow(
                          color: roleColor.withValues(alpha: 0.8),
                          blurRadius: 5,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    drone.name,
                    style: TextStyle(
                      color: isDark ? Colors.white : const Color(0xFF0F172A),
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
              Wrap(
                spacing: 4,
                runSpacing: 2,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                    decoration: BoxDecoration(
                      color: isLeader
                          ? (isDark ? Colors.amber.shade900 : Colors.amber.shade100)
                          : (isDark ? Colors.cyan.shade900 : Colors.cyan.shade100),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      isLeader ? 'LEADER' : 'MEMBER',
                      style: TextStyle(
                        color: isLeader
                            ? (isDark ? Colors.amberAccent : Colors.amber.shade900)
                            : (isDark ? Colors.cyanAccent : const Color(0xFF0369A1)),
                        fontWeight: FontWeight.bold,
                        fontSize: 9,
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                    decoration: BoxDecoration(
                      color: _statusColor(drone.status, isDark).withValues(alpha: isDark ? 0.2 : 0.15),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      drone.status.name.toUpperCase(),
                      style: TextStyle(
                        color: _statusColor(drone.status, isDark),
                        fontWeight: FontWeight.bold,
                        fontSize: 9,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 6),

          // Hardware Specs Summary
          Text(
            'Frame: ${drone.frameType.displayName} | RPi 4 + Pixhawk 6',
            style: TextStyle(
              color: isDark ? Colors.cyanAccent : const Color(0xFF0284C7),
              fontSize: 9.5,
              fontWeight: FontWeight.w500,
            ),
          ),
          Text(
            'Sensors: 5x LiDAR, 1x OptFlow, 1x DW3000 UWB',
            style: TextStyle(
              color: isDark ? Colors.white.withValues(alpha: 0.7) : const Color(0xFF64748B),
              fontSize: 9,
            ),
          ),
          const SizedBox(height: 4),

          // Coordinates & Waypoints
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            spacing: 8,
            runSpacing: 2,
            children: [
              Text(
                'Pos: (${drone.position.x.toStringAsFixed(1)}, ${drone.position.y.toStringAsFixed(1)})',
                style: TextStyle(
                  color: isDark ? Colors.white70 : const Color(0xFF475569),
                  fontSize: 10,
                ),
              ),
              Text(
                'WP: ${drone.pathIndex}/${drone.pathCells.length}',
                style: TextStyle(
                  color: isDark ? Colors.white70 : const Color(0xFF475569),
                  fontSize: 10,
                ),
              ),
            ],
          ),
          const SizedBox(height: 2),

          // Room Exploration & Collisions
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            spacing: 8,
            runSpacing: 2,
            children: [
              Text(
                'SLAM Mapped: ${drone.exploredPercentage.toStringAsFixed(1)}%',
                style: TextStyle(
                  color: isDark ? Colors.lightGreenAccent : Colors.green.shade700,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                'Hits: W${drone.wallCollisionCount} D${drone.droneCollisionCount}',
                style: TextStyle(
                  color: isDark ? Colors.amberAccent : Colors.amber.shade900,
                  fontSize: 10,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Color _statusColor(DroneStatus s, bool isDark) {
    switch (s) {
      case DroneStatus.search:
        return isDark ? Colors.lightBlueAccent : const Color(0xFF0284C7);
      case DroneStatus.chase:
        return isDark ? Colors.amberAccent : Colors.amber.shade800;
      case DroneStatus.found:
        return isDark ? Colors.greenAccent : Colors.green.shade700;
      case DroneStatus.returnHome:
        return isDark ? Colors.purpleAccent : Colors.purple.shade700;
      case DroneStatus.arrived:
        return isDark ? Colors.grey : const Color(0xFF64748B);
    }
  }
}
