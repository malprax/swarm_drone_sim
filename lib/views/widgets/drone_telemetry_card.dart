import 'package:flutter/material.dart';
import '../../models/drone_model.dart';

class DroneTelemetryCard extends StatelessWidget {
  final DroneModel drone;

  const DroneTelemetryCard({super.key, required this.drone});

  @override
  Widget build(BuildContext context) {
    final isLeader = drone.role == DroneRole.leader;
    final roleColor = drone.ledColor;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: roleColor.withValues(alpha: 0.5),
          width: 1.5,
        ),
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
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                    decoration: BoxDecoration(
                      color: isLeader ? Colors.amber.shade900 : Colors.cyan.shade900,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      isLeader ? 'LEADER (YELLOW)' : 'MEMBER (BLUE)',
                      style: TextStyle(
                        color: isLeader ? Colors.amberAccent : Colors.cyanAccent,
                        fontWeight: FontWeight.bold,
                        fontSize: 9,
                      ),
                    ),
                  ),
                  const SizedBox(width: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                    decoration: BoxDecoration(
                      color: _statusColor(drone.status).withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      drone.status.name.toUpperCase(),
                      style: TextStyle(
                        color: _statusColor(drone.status),
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
            style: const TextStyle(color: Colors.cyanAccent, fontSize: 9.5, fontWeight: FontWeight.w500),
          ),
          Text(
            'Sensors: 5x LiDAR, 1x OptFlow, 1x DW3000 UWB',
            style: TextStyle(color: Colors.white.withValues(alpha: 0.7), fontSize: 9),
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
                style: const TextStyle(color: Colors.white70, fontSize: 10),
              ),
              Text(
                'WP: ${drone.pathIndex}/${drone.pathCells.length}',
                style: const TextStyle(color: Colors.white70, fontSize: 10),
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
                style: const TextStyle(color: Colors.lightGreenAccent, fontSize: 10, fontWeight: FontWeight.bold),
              ),
              Text(
                'Hits: W${drone.wallCollisionCount} D${drone.droneCollisionCount}',
                style: const TextStyle(color: Colors.amberAccent, fontSize: 10),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Color _statusColor(DroneStatus s) {
    switch (s) {
      case DroneStatus.search:
        return Colors.lightBlueAccent;
      case DroneStatus.chase:
        return Colors.amberAccent;
      case DroneStatus.found:
        return Colors.greenAccent;
      case DroneStatus.returnHome:
        return Colors.purpleAccent;
      case DroneStatus.arrived:
        return Colors.grey;
    }
  }
}
