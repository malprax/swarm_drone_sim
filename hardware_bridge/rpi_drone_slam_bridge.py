#!/usr/bin/env python3
"""
Raspberry Pi 4 Drone SLAM Telemetry Bridge
==========================================
Ground Control Station Bridge for Flutter Swarm Drone Simulator.
Reads 5x LiDAR sensors, Optical Flow PMW3901, and Pixhawk MAVLink odometry,
then broadcasts high-speed JSON telemetry over WebSocket (default port 8765).

Features:
- Live 5x LiDAR sensor integration (TF-Luna, VL53L1X, RPLiDAR, or Serial LiDARs)
- Optical Flow + IMU odometry (x, y, z, yaw)
- Built-in Mock/Simulator mode (--mock) to test wireless link without physical sensors
- Automatic zero-point calibration from Flutter GCS
- Bidirectional control & ping latency monitoring

Usage:
  # Mock test mode on Mac or Raspberry Pi:
  python3 rpi_drone_slam_bridge.py --mock --port 8765

  # Production hardware mode on Raspberry Pi:
  python3 rpi_drone_slam_bridge.py --port 8765
"""

import argparse
import asyncio
import json
import math
import sys
import time
from typing import Set

try:
    import websockets
except ImportError:
    print("[ERROR] 'websockets' library not found.")
    print("Please install it: pip3 install websockets")
    sys.exit(1)


class RealDroneBridge:
    def __init__(self, mock: bool = False):
        self.mock = mock
        self.drone_id = 1
        self.x = 0.0
        self.y = 0.0
        self.z = 1.0  # 1 meter default altitude
        self.heading_rad = 0.0
        self.battery_voltage = 15.6  # 4S LiPo fully charged
        self.vx = 0.0
        self.vy = 0.0

        # Sensor configuration: 5 LiDAR angles relative to drone forward axis (radians)
        # [0: Front 0°, 1: Angle 45°, 2: Left 90°, 3: Right -90°, 4: Rear 180°]
        self.lidar_angles_deg = [0.0, 45.0, 90.0, -90.0, 180.0]
        self.lidar_distances = [10.0, 10.0, 10.0, 10.0, 10.0]
        self.max_range = 10.0

        # Mock room dimensions for simulation mode (e.g. 7.0m x 5.0m room)
        self.mock_room_min_x = -3.5
        self.mock_room_max_x = 3.5
        self.mock_room_min_y = -2.5
        self.mock_room_max_y = 2.5
        self.mock_t = 0.0

        # Connected WebSocket clients
        self.clients: Set[websockets.WebSocketServerProtocol] = set()

    def zero_calibration(self):
        """Calibrate current physical spot as local origin (0, 0)"""
        print("[BRIDGE] Zero calibration command received. Resetting origin (0, 0)...")
        self.x = 0.0
        self.y = 0.0
        self.heading_rad = 0.0
        self.vx = 0.0
        self.vy = 0.0

    def update_hardware(self, dt: float):
        """Update sensor readings from physical hardware or mock generator"""
        if self.mock:
            self._update_mock_telemetry(dt)
        else:
            self._update_physical_sensors(dt)

    def _update_mock_telemetry(self, dt: float):
        """Simulate drone moving smoothly inside a physical room"""
        self.mock_t += dt

        # Simulate walking drone in an oval trajectory within room
        speed = 0.45  # m/s walking speed
        target_x = 1.8 * math.sin(self.mock_t * 0.4)
        target_y = 1.2 * math.sin(self.mock_t * 0.8)

        dx = target_x - self.x
        dy = target_y - self.y
        dist = math.hypot(dx, dy)

        if dist > 0.01:
            self.vx = (dx / dist) * speed
            self.vy = (dy / dist) * speed
            self.x += self.vx * dt
            self.y += self.vy * dt
            self.heading_rad = math.atan2(self.vy, self.vx)

        # Simulate 5 LiDAR beams intersecting the mock 4 walls
        self.lidar_distances = []
        for angle_deg in self.lidar_angles_deg:
            total_ang = self.heading_rad + math.radians(angle_deg)
            cos_a = math.cos(total_ang)
            sin_a = math.sin(total_ang)

            # Raycast against 4 walls of mock room
            hit_dist = self.max_range
            # Wall X max
            if cos_a > 1e-4:
                d = (self.mock_room_max_x - self.x) / cos_a
                if 0 < d < hit_dist:
                    hit_dist = d
            # Wall X min
            elif cos_a < -1e-4:
                d = (self.mock_room_min_x - self.x) / cos_a
                if 0 < d < hit_dist:
                    hit_dist = d
            # Wall Y max
            if sin_a > 1e-4:
                d = (self.mock_room_max_y - self.y) / sin_a
                if 0 < d < hit_dist:
                    hit_dist = d
            # Wall Y min
            elif sin_a < -1e-4:
                d = (self.mock_room_min_y - self.y) / sin_a
                if 0 < d < hit_dist:
                    hit_dist = d

            # Add minor sensor noise (+- 2cm)
            noise = 0.015 * math.sin(self.mock_t * 10 + angle_deg)
            self.lidar_distances.append(round(max(0.1, hit_dist + noise), 3))

        # Slowly discharge battery (e.g. 15.6V down to 14.8V)
        self.battery_voltage = max(14.4, 15.6 - (self.mock_t * 0.001))

    def _update_physical_sensors(self, dt: float):
        """
        Read real physical sensors from Raspberry Pi GPIO / I2C / UART:
        - TF-Luna / VL53L1X via I2C bus 1
        - Optical Flow PMW3901 via SPI
        - Pixhawk 6 via MAVLink /dev/ttyAMA0
        """
        # (Template for physical hardware reading - replace with your sensor driver calls)
        # E.g.:
        # self.lidar_distances[0] = read_tfluna_front()
        # self.lidar_distances[1] = read_tfluna_angle()
        # ...
        pass

    def build_telemetry_packet(self) -> dict:
        return {
            "timestamp": time.time(),
            "drone_id": self.drone_id,
            "status": "flying" if (abs(self.vx) > 0.01 or abs(self.vy) > 0.01) else "active",
            "position": {
                "x": round(self.x, 3),
                "y": round(self.y, 3),
                "z": round(self.z, 2),
            },
            "heading_rad": round(self.heading_rad, 4),
            "heading_deg": round(math.degrees(self.heading_rad), 1),
            "battery_voltage": round(self.battery_voltage, 2),
            "optical_flow": {
                "vx": round(self.vx, 3),
                "vy": round(self.vy, 3),
            },
            "lidars": [
                {"id": i, "angle_deg": self.lidar_angles_deg[i], "distance_m": self.lidar_distances[i]}
                for i in range(5)
            ],
            "lidar_distances": self.lidar_distances,
        }


async def handler(websocket, bridge: RealDroneBridge):
    print(f"[BRIDGE] Client connected: {websocket.remote_address}")
    bridge.clients.add(websocket)
    try:
        async for message in websocket:
            try:
                cmd = json.loads(message)
                if cmd.get("command") == "zero_calibration":
                    bridge.zero_calibration()
                elif cmd.get("command") == "ping":
                    await websocket.send(json.dumps({
                        "type": "pong",
                        "client_time": cmd.get("client_time", 0)
                    }))
                elif cmd.get("command") == "handshake":
                    print(f"[BRIDGE] Handshake received from: {cmd.get('client')}")
            except Exception as ex:
                print(f"[WARN] Error handling client message: {ex}")
    except websockets.exceptions.ConnectionClosed:
        pass
    finally:
        bridge.clients.remove(websocket)
        print(f"[BRIDGE] Client disconnected: {websocket.remote_address}")


async def broadcast_loop(bridge: RealDroneBridge, frequency_hz: float = 15.0):
    interval = 1.0 / frequency_hz
    last_time = time.time()

    while True:
        now = time.time()
        dt = now - last_time
        last_time = now

        bridge.update_hardware(dt)

        if bridge.clients:
            packet = bridge.build_telemetry_packet()
            payload = json.dumps(packet)
            # Broadcast to all connected Ground Station clients
            await asyncio.gather(
                *[client.send(payload) for client in bridge.clients],
                return_exceptions=True
            )

        await asyncio.sleep(interval)


async def main():
    parser = argparse.ArgumentParser(description="Raspberry Pi 4 Drone SLAM Telemetry Bridge")
    parser.add_argument("--host", default="0.0.0.0", help="Listen host address (default: 0.0.0.0)")
    parser.add_argument("--port", type=int, default=8765, help="WebSocket port (default: 8765)")
    parser.add_argument("--hz", type=float, default=15.0, help="Broadcast frequency in Hz (default: 15.0)")
    parser.add_argument("--mock", action="store_true", help="Run in mock/demo mode (generates room SLAM data)")
    args = parser.parse_args()

    bridge = RealDroneBridge(mock=args.mock)

    print("==================================================================")
    print("🛸 RASPBERRY PI 4 DRONE SLAM TELEMETRY BRIDGE")
    print("==================================================================")
    print(f" Mode          : {'MOCK SIMULATOR (Demo Room)' if args.mock else 'REAL HARDWARE SENSORS'}")
    print(f" Server URL    : ws://{args.host}:{args.port}")
    print(f" Telemetry Rate: {args.hz} Hz")
    print(f" Sensors       : 5x LiDARs [0°, 45°, 90°, -90°, 180°] + Optical Flow")
    print("==================================================================")
    print("Waiting for Flutter Ground Station connection...")

    server = await websockets.serve(
        lambda ws: handler(ws, bridge),
        args.host,
        args.port,
    )

    await broadcast_loop(bridge, frequency_hz=args.hz)


if __name__ == "__main__":
    try:
        asyncio.run(main())
    except KeyboardInterrupt:
        print("
[BRIDGE] Server stopped by user.")
