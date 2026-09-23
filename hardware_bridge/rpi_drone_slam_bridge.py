#!/usr/bin/env python3
"""
Raspberry Pi 4 Drone SLAM Telemetry Bridge
==========================================
Ground Control Station Bridge for Flutter Swarm Drone Simulator.
Connects physical or simulated sensors to Flutter Ground Station via WebSocket.

Modes:
- Default / Standby : Drone parked at (0, 0), zero speed, LED beacon blinking, no fake walls.
- Hardware (--hw)   : Auto-scans I2C (LiDAR TF-Luna/VL53L1X) and Serial (UWB/Pixhawk).
- Demo (--demo/mock): Virtual walking simulation with room obstacles.

Usage:
  # Standby / Idle Mode:
  python3 rpi_drone_slam_bridge.py --port 8765

  # Real Physical Hardware with True 1:1 Meters:
  python3 rpi_drone_slam_bridge.py --port 8765

  # Real Physical Hardware with 3x Desk Movement Amplification:
  python3 rpi_drone_slam_bridge.py --port 8765 --scale 3.0
"""

import argparse
import asyncio
from collections import deque
import glob
import json
import math
import os
import re
import statistics
import sys
import threading
import time
from typing import Dict, List, Optional, Set

try:
    import websockets
except ImportError:
    print("[ERROR] 'websockets' library not found.")
    print("Please install it: sudo apt install -y python3-websockets (on Pi) or pip3 install websockets")
    sys.exit(1)

try:
    import serial
except ImportError:
    serial = None


class HardwareDetector:
    """Detects connected physical sensors on Raspberry Pi (I2C LiDARs, Serial UWB, Pixhawk)"""

    @staticmethod
    def scan_i2c_sensors() -> Dict[str, bool]:
        """Check for I2C LiDARs (0x10 = TF-Luna, 0x29 = VL53L1X)"""
        detected = {"tf_luna": False, "vl53l1x": False}
        if not os.path.exists("/dev/i2c-1"):
            return detected

        try:
            import smbus2
            bus = smbus2.SMBus(1)
            try:
                bus.read_byte(0x10)
                detected["tf_luna"] = True
            except Exception:
                pass
            try:
                bus.read_byte(0x29)
                detected["vl53l1x"] = True
            except Exception:
                pass
            bus.close()
        except ImportError:
            pass
        return detected

    @staticmethod
    def scan_serial_ports() -> List[str]:
        """Detect connected USB serial devices (ESP32 UWB DW3000, Pixhawk TELEM2)"""
        ports = []
        candidates = (
            glob.glob("/dev/ttyUSB*") +
            glob.glob("/dev/ttyACM*") +
            glob.glob("/dev/serial0") +
            glob.glob("/dev/ttyAMA0")
        )
        for p in candidates:
            if os.path.exists(p) and p not in ports:
                ports.append(p)
        return ports


class RealDroneBridge:
    def __init__(self, mode: str = "hardware", scale: float = 1.0):
        self.mode = mode  # "standby", "demo", or "hardware"
        self.scale = scale  # Movement sensitivity multiplier (1.0 = true metric, >1.0 = desk amplification)
        self.drone_id = 1

        # Odometry state
        self.x = 0.0
        self.y = 0.0
        self.z = 0.0  # Ground level
        self.heading_rad = 0.0
        self.battery_voltage = 15.6  # 4S LiPo fully charged
        self.vx = 0.0
        self.vy = 0.0
        self.status = "standby"

        # 5 LiDAR sensors: [0°, 45°, 90°, -90°, 180°]
        self.lidar_angles_deg = [0.0, 45.0, 90.0, -90.0, 180.0]
        self.lidar_distances: List[float] = [-1.0, -1.0, -1.0, -1.0, -1.0]
        self.max_range = 10.0

        # Demo room parameters
        self.mock_t = 0.0
        self.mock_room_min_x = -3.5
        self.mock_room_max_x = 3.5
        self.mock_room_min_y = -2.5
        self.mock_room_max_y = 2.5

        # Hardware status
        self.i2c_status = {"tf_luna": False, "vl53l1x": False}
        self.serial_ports: List[str] = []

        # Ultra-Low Latency UWB DW3000 Ranging state
        self.uwb_port: Optional[str] = None
        self.uwb_raw_dist: float = 0.0
        self.uwb_smooth_dist: float = 0.0
        self.uwb_origin_dist: Optional[float] = None
        self.deadband_m: float = 0.035  # 3.5 cm movement trigger threshold
        self.uwb_history = deque(maxlen=3)  # Fast 3-sample median filter (zero phase lag)
        self.uwb_warmup: List[float] = []
        self.is_moving: bool = False
        self.last_move_time: float = 0.0
        self.stationary_samples: int = 0
        self.uwb_connected: bool = False
        self._stop_uwb: bool = False
        self.uwb_thread: Optional[threading.Thread] = None

        if self.mode == "hardware":
            self._probe_hardware()
        elif self.mode == "demo":
            self.status = "flying"
            self.z = 1.0

        # Connected WebSocket clients
        self.clients: Set[websockets.WebSocketServerProtocol] = set()

    def _probe_hardware(self):
        """Probe for real physical sensors"""
        print("[HARDWARE] Scanning physical sensors on Raspberry Pi...")
        self.i2c_status = HardwareDetector.scan_i2c_sensors()
        self.serial_ports = HardwareDetector.scan_serial_ports()

        has_lidar = any(self.i2c_status.values())
        has_serial = len(self.serial_ports) > 0

        print(f"  • I2C Bus (/dev/i2c-1) : {'TF-Luna' if self.i2c_status['tf_luna'] else ('VL53L1X' if self.i2c_status['vl53l1x'] else 'No LiDAR found')}")
        print(f"  • Serial/UWB/Pixhawk    : {', '.join(self.serial_ports) if has_serial else 'No serial device connected'}")

        if not has_lidar and not has_serial:
            print("[HARDWARE] ⚠️ No physical sensors found.")
            print("[HARDWARE] 🛡️  Defaulting to STANDBY IDLE mode (Drone parked at 0,0, LEDs blinking).")
            self.mode = "standby"
        else:
            print("[HARDWARE] ✅ Physical sensors detected. Ready for telemetry stream.")
            self.status = "active"
            if has_serial:
                self._start_uwb_reader(self.serial_ports[0])

    def _start_uwb_reader(self, port: str):
        """Spawn background daemon thread reading UWB serial telemetry with zero-lag filter"""
        if not serial:
            print("[UWB] ⚠️ 'pyserial' not installed. Skipping direct serial reading.")
            return

        def reader():
            print(f"[UWB] Opening serial port {port} at 115200 baud...", flush=True)
            try:
                ser = serial.Serial(port, 115200, timeout=1.0)
                try:
                    ser.setDTR(False)
                    ser.setRTS(False)
                except Exception:
                    pass
                self.uwb_port = port
                self.uwb_connected = True
                print(f"[UWB] ✅ Connected to {port}. Listening for DW3000 ranging packets...", flush=True)

                ok_pattern = re.compile(r"OK,\s*([\d\.]+)", re.IGNORECASE)
                dist_pattern = re.compile(r"DIST:\s*([\d\.]+)\s*m", re.IGNORECASE)
                alt_pattern = re.compile(r"(?:Range|Distance):\s*([\d\.]+)", re.IGNORECASE)
                last_print = 0.0
                last_was_moving = False

                while not self._stop_uwb:
                    line = ser.readline().decode('utf-8', errors='ignore').strip()
                    if not line:
                        continue

                    m = ok_pattern.search(line) or dist_pattern.search(line) or alt_pattern.search(line)
                    if m:
                        try:
                            d = float(m.group(1))
                            if d < 0.10 or d > 25.0:
                                continue

                            self.uwb_raw_dist = d

                            # 1. Low-Latency 3-Sample Median Filter (Eliminates multipath spikes in 1 step)
                            self.uwb_history.append(d)
                            med_d = statistics.median(self.uwb_history)

                            # 2. Fast Baseline Origin Lock (First 5 stable samples)
                            if self.uwb_origin_dist is None:
                                self.uwb_warmup.append(med_d)
                                if len(self.uwb_warmup) < 5:
                                    continue
                                self.uwb_origin_dist = statistics.mean(self.uwb_warmup)
                                self.uwb_smooth_dist = self.uwb_origin_dist
                                print(f"[UWB] 🎯 Baseline Origin locked: {self.uwb_origin_dist:.3f} m", flush=True)

                            # 3. Dynamic Dual-Rate Tracking Filter (Instant step response + solid stationary hold)
                            diff = abs(med_d - self.uwb_smooth_dist)
                            now = time.time()

                            if diff >= self.deadband_m:
                                # Physical motion: Fast tracking (alpha 0.75 - 0.90) -> No lag!
                                alpha = 0.90 if diff >= 0.07 else 0.75
                                self.uwb_smooth_dist = (1.0 - alpha) * self.uwb_smooth_dist + alpha * med_d

                                # Update Drone X immediately with scale multiplier
                                delta = (self.uwb_smooth_dist - self.uwb_origin_dist) * self.scale
                                self.x = round(delta, 3)
                                self.is_moving = True
                                self.last_move_time = now
                                self.stationary_samples = 0
                            else:
                                # Small jitter or hand stationary: Lock position immediately!
                                self.stationary_samples += 1
                                # Slowly absorb drift
                                self.uwb_smooth_dist = 0.96 * self.uwb_smooth_dist + 0.04 * med_d

                                # When still for 2 samples or > 150ms: immediately switch to stationary
                                if self.stationary_samples >= 2 or (now - self.last_move_time > 0.15):
                                    self.is_moving = False

                            self.status = "active"

                            # 4. Low-Latency Responsive Terminal Logging
                            should_print = False
                            if self.is_moving:
                                # Realtime 10Hz print during motion so output follows user's hand instantly
                                if now - last_print > 0.10:
                                    should_print = True
                            else:
                                # Immediate print when transitioning to stationary, then heartbeat every 1.5s
                                if last_was_moving or (now - last_print > 1.5):
                                    should_print = True

                            if should_print:
                                state_tag = "🚀 BERGERAK" if self.is_moving else "🛡️ DIAM (STABIL)"
                                scale_str = f" [Scale {self.scale:.1f}x]" if self.scale != 1.0 else ""
                                raw_delta = self.uwb_smooth_dist - self.uwb_origin_dist
                                print(
                                    f"[UWB] 📡 Dist: {d:.3f} m (Δ {raw_delta:+.3f}m) | Drone X: {self.x:+.3f} m{scale_str} [{state_tag}]",
                                    flush=True
                                )
                                last_print = now
                                last_was_moving = self.is_moving

                        except ValueError:
                            pass
                    elif "FAIL" in line or "RX_TIMEOUT" in line:
                        now = time.time()
                        if now - last_print > 2.0:
                            print("[UWB] ⏳ RX_TIMEOUT: Waiting for Anchor signal...", flush=True)
                            last_print = now
            except Exception as e:
                print(f"[UWB] ⚠️ Serial reader error: {e}", flush=True)
                self.uwb_connected = False

        self.uwb_thread = threading.Thread(target=reader, daemon=True)
        self.uwb_thread.start()

    def zero_calibration(self):
        """Calibrate current physical spot as local origin (0, 0)"""
        print("[BRIDGE] Zero calibration command received. Resetting origin (0, 0)...", flush=True)
        if self.uwb_history:
            self.uwb_origin_dist = statistics.median(self.uwb_history)
        elif self.uwb_smooth_dist > 0:
            self.uwb_origin_dist = self.uwb_smooth_dist
        elif self.uwb_raw_dist > 0:
            self.uwb_origin_dist = self.uwb_raw_dist

        self.x = 0.0
        self.y = 0.0
        self.heading_rad = 0.0
        self.vx = 0.0
        self.vy = 0.0
        self.is_moving = False
        self.stationary_samples = 5
        print(f"[UWB] 🎯 Zero origin calibrated to physical distance: {self.uwb_origin_dist:.3f} m", flush=True)

    def update_hardware(self, dt: float):
        """Update sensor readings based on active mode"""
        if self.mode == "demo":
            self._update_demo_telemetry(dt)
        elif self.mode == "hardware":
            self._update_physical_sensors(dt)
        else:
            self._update_standby(dt)

    def _update_standby(self, dt: float):
        """Drone stays completely still, no fake walls, LED blinking"""
        self.x = 0.0
        self.y = 0.0
        self.z = 0.0
        self.vx = 0.0
        self.vy = 0.0
        self.heading_rad = 0.0
        self.status = "standby"
        self.lidar_distances = [-1.0, -1.0, -1.0, -1.0, -1.0]
        self.battery_voltage = 15.6

    def _update_demo_telemetry(self, dt: float):
        """Virtual patrol simulation inside a demo room"""
        self.mock_t += dt
        self.status = "flying"
        self.z = 1.0

        speed = 0.45
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

        self.lidar_distances = []
        for angle_deg in self.lidar_angles_deg:
            total_ang = self.heading_rad + math.radians(angle_deg)
            cos_a = math.cos(total_ang)
            sin_a = math.sin(total_ang)

            hit_dist = self.max_range
            if cos_a > 1e-4:
                d = (self.mock_room_max_x - self.x) / cos_a
                if 0 < d < hit_dist:
                    hit_dist = d
            elif cos_a < -1e-4:
                d = (self.mock_room_min_x - self.x) / cos_a
                if 0 < d < hit_dist:
                    hit_dist = d
            if sin_a > 1e-4:
                d = (self.mock_room_max_y - self.y) / sin_a
                if 0 < d < hit_dist:
                    hit_dist = d
            elif sin_a < -1e-4:
                d = (self.mock_room_min_y - self.y) / sin_a
                if 0 < d < hit_dist:
                    hit_dist = d

            noise = 0.015 * math.sin(self.mock_t * 10 + angle_deg)
            self.lidar_distances.append(round(max(0.1, hit_dist + noise), 3))

    def _update_physical_sensors(self, dt: float):
        """Read real physical sensors from Raspberry Pi GPIO / I2C / UART"""
        if self.uwb_connected and self.uwb_origin_dist is not None:
            self.status = "active"

    def build_telemetry_packet(self) -> dict:
        return {
            "timestamp": time.time(),
            "drone_id": self.drone_id,
            "status": self.status,
            "mode": self.mode,
            "led_blink": self.status == "standby",
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
            "uwb": {
                "connected": self.uwb_connected,
                "port": self.uwb_port or "None",
                "raw_distance_m": round(self.uwb_raw_dist, 3),
                "origin_distance_m": round(self.uwb_origin_dist or 0.0, 3),
                "scale": self.scale,
                "is_moving": self.is_moving,
            },
            "lidars": [
                {
                    "id": i,
                    "angle_deg": self.lidar_angles_deg[i],
                    "distance_m": self.lidar_distances[i],
                    "connected": self.lidar_distances[i] > 0,
                }
                for i in range(5)
            ],
            "lidar_distances": self.lidar_distances,
        }


async def handler(websocket, bridge: RealDroneBridge):
    """Handle new incoming WebSocket client connection from Flutter GCS"""
    bridge.clients.add(websocket)
    print(f"[BRIDGE] Client connected: {websocket.remote_address}")

    try:
        async for message in websocket:
            try:
                data = json.loads(message)
                cmd = data.get("command")

                if cmd == "handshake":
                    client_name = data.get("client", "Unknown_GCS")
                    print(f"[BRIDGE] Handshake received from: {client_name}")
                    await websocket.send(json.dumps({
                        "type": "handshake_ack",
                        "server": "RPi4_Drone_Bridge",
                        "mode": bridge.mode,
                        "status": bridge.status,
                        "timestamp": time.time(),
                    }))

                elif cmd == "zero_calibration":
                    bridge.zero_calibration()
                    await websocket.send(json.dumps({
                        "type": "zero_calibrated",
                        "status": "success",
                        "timestamp": time.time(),
                    }))

                elif cmd == "ping":
                    client_time = data.get("client_time", time.time())
                    await websocket.send(json.dumps({
                        "type": "pong",
                        "client_time": client_time,
                        "server_time": time.time(),
                    }))

                elif cmd == "set_mode":
                    new_mode = data.get("mode")
                    if new_mode in ["standby", "demo", "hardware"]:
                        bridge.mode = new_mode
                        print(f"[BRIDGE] Mode switched to: {bridge.mode}")

                elif cmd == "set_scale":
                    new_scale = float(data.get("scale", 1.0))
                    bridge.scale = max(0.1, min(10.0, new_scale))
                    print(f"[BRIDGE] Movement scale updated: {bridge.scale:.2f}x")

            except json.JSONDecodeError:
                pass
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
    parser.add_argument("--scale", type=float, default=1.0, help="Movement sensitivity scale multiplier (default: 1.0 = true metric, 2.0 or 3.0 = desk amplification)")
    parser.add_argument("--demo", "--mock", action="store_true", help="Run virtual walking room demo")
    parser.add_argument("--hw", "--hardware", action="store_true", help="Scan and read real physical sensors")
    parser.add_argument("--idle", "--standby", action="store_true", help="Stationary standby mode with blinking LEDs (Default)")
    args = parser.parse_args()

    mode = "hardware"
    if args.demo:
        mode = "demo"
    elif args.idle:
        mode = "standby"

    bridge = RealDroneBridge(mode=mode, scale=args.scale)

    print("==================================================================")
    print("🛸 RASPBERRY PI 4 DRONE SLAM TELEMETRY BRIDGE")
    print("==================================================================")
    print(f" Mode            : {mode.upper()} {'(Stationary at 0,0, LEDs blinking)' if mode == 'standby' else ''}")
    print(f" Server URL      : ws://{args.host}:{args.port}")
    print(f" Telemetry Rate  : {args.hz} Hz")
    print(f" Movement Scale  : {args.scale:.1f}x {'(True 1:1 Metric)' if args.scale == 1.0 else '(Desk Amplification)'}")
    print("==================================================================")
    print("Waiting for Flutter Ground Station connection...")

    try:
        server = await websockets.serve(
            lambda ws: handler(ws, bridge),
            args.host,
            args.port,
        )
    except OSError as e:
        if e.errno == 98 or "address already in use" in str(e).lower():
            print(f"\n[ERROR] ❌ Port {args.port} sedang dipakai proses python lain!")
            print(f"[FIX] Jalankan perintah ini di Raspberry Pi untuk melepas port:")
            print(f"      fuser -k {args.port}/tcp   (atau: killall -9 python3)")
            print(f"      Lalu jalankan kembali script ini.\n")
            sys.exit(1)
        raise

    await broadcast_loop(bridge, frequency_hz=args.hz)


if __name__ == "__main__":
    try:
        asyncio.run(main())
    except KeyboardInterrupt:
        print("\n[BRIDGE] Server stopped by user.")
