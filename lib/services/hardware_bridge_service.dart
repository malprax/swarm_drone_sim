import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'package:get/get.dart';
import '../models/vector2.dart';

/// Connection lifecycle states for real drone hardware bridge
enum HardwareConnectionState {
  disconnected,
  connecting,
  connected,
  error,
}

/// Structured telemetry packet received from the physical Raspberry Pi 4
class RealDronePacket {
  final double timestamp;
  final String droneId;
  final Vector2 position;
  final double altitude;
  final double headingRad;
  final double batteryVoltage;
  final double batteryPercentage;
  final Vector2 opticalFlowVelocity;
  final List<double> lidarDistances; // 5 LiDAR readings in meters
  final String status;

  double get x => position.x;
  double get y => position.y;
  double get z => altitude;
  double get yawDeg => headingRad * 180.0 / math.pi;

  const RealDronePacket({
    required this.timestamp,
    this.droneId = 'rpi4_drone',
    required this.position,
    this.altitude = 0.0,
    required this.headingRad,
    this.batteryVoltage = 16.8,
    this.batteryPercentage = 100.0,
    this.opticalFlowVelocity = Vector2.zero,
    required this.lidarDistances,
    this.status = 'active',
  });

  /// Factory parser for incoming JSON payload from Raspberry Pi
  factory RealDronePacket.fromJson(Map<String, dynamic> json) {
    // 1. Position parsing
    double x = 0.0;
    double y = 0.0;
    double z = 0.0;
    if (json['position'] is Map) {
      final pos = json['position'] as Map<String, dynamic>;
      x = (pos['x'] as num?)?.toDouble() ?? 0.0;
      y = (pos['y'] as num?)?.toDouble() ?? 0.0;
      z = (pos['z'] as num?)?.toDouble() ?? 0.0;
    } else if (json['x'] != null && json['y'] != null) {
      x = (json['x'] as num).toDouble();
      y = (json['y'] as num).toDouble();
      z = (json['z'] as num?)?.toDouble() ?? 0.0;
    }

    // 2. Heading angle in radians
    double heading = 0.0;
    if (json['heading'] is Map) {
      final h = json['heading'] as Map<String, dynamic>;
      if (h['yaw_rad'] != null) {
        heading = (h['yaw_rad'] as num).toDouble();
      } else if (h['yaw_deg'] != null) {
        heading = (h['yaw_deg'] as num).toDouble() * math.pi / 180.0;
      }
    } else if (json['heading_rad'] != null) {
      heading = (json['heading_rad'] as num).toDouble();
    } else if (json['heading_deg'] != null) {
      heading = (json['heading_deg'] as num).toDouble() * math.pi / 180.0;
    } else if (json['yaw_deg'] != null) {
      heading = (json['yaw_deg'] as num).toDouble() * math.pi / 180.0;
    }

    // 3. Optical flow velocity
    double vx = 0.0;
    double vy = 0.0;
    if (json['optical_flow'] is Map) {
      final of = json['optical_flow'] as Map<String, dynamic>;
      vx = (of['vx'] as num?)?.toDouble() ?? 0.0;
      vy = (of['vy'] as num?)?.toDouble() ?? 0.0;
    }

    // 4. Battery parsing
    double batV = 16.8;
    double batPct = 100.0;
    if (json['battery'] is Map) {
      final b = json['battery'] as Map<String, dynamic>;
      batV = (b['voltage'] as num?)?.toDouble() ?? 16.8;
      batPct = (b['percentage'] as num?)?.toDouble() ?? 100.0;
    } else {
      if (json['battery_voltage'] != null) {
        batV = (json['battery_voltage'] as num).toDouble();
      }
      if (json['battery_percentage'] != null) {
        batPct = (json['battery_percentage'] as num).toDouble();
      }
    }

    // 5. LiDAR distances (5 channels: Front 0°, Angle 45°, Left 90°, Right -90°, Rear 180°)
    final lidars = <double>[0.0, 0.0, 0.0, 0.0, 0.0];
    if (json['sensors'] is Map && (json['sensors'] as Map)['lidar_5x'] is List) {
      final list = (json['sensors'] as Map)['lidar_5x'] as List;
      for (int i = 0; i < math.min(list.length, 5); i++) {
        final item = list[i];
        if (item is num) lidars[i] = item.toDouble();
      }
    } else if (json['lidars'] is List) {
      final list = json['lidars'] as List;
      for (int i = 0; i < math.min(list.length, 5); i++) {
        final item = list[i];
        if (item is num) {
          lidars[i] = item.toDouble();
        } else if (item is Map) {
          final dist = item['distance_m'] ?? item['distance'];
          if (dist is num) lidars[i] = dist.toDouble();
        }
      }
    } else if (json['lidar_distances'] is List) {
      final list = json['lidar_distances'] as List;
      for (int i = 0; i < math.min(list.length, 5); i++) {
        final item = list[i];
        if (item is num) lidars[i] = item.toDouble();
      }
    }

    return RealDronePacket(
      timestamp: (json['timestamp'] as num?)?.toDouble() ?? DateTime.now().millisecondsSinceEpoch / 1000.0,
      droneId: (json['drone_id']?.toString()) ?? 'rpi4_drone',
      position: Vector2(x, y),
      altitude: z,
      headingRad: heading,
      batteryVoltage: batV,
      batteryPercentage: batPct,
      opticalFlowVelocity: Vector2(vx, vy),
      lidarDistances: lidars,
      status: (json['status'] as String?) ?? 'standby',
    );
  }
}

/// Service that manages wireless WebSocket connection with physical Raspberry Pi 4 on drone
class HardwareBridgeService extends GetxService {
  final connectionState = HardwareConnectionState.disconnected.obs;
  final hostAddress = '192.168.1.50'.obs;
  final hostPort = 8765.obs;

  // Real-time telemetry metrics
  final lastPacket = Rxn<RealDronePacket>();
  final packetRateHz = 0.0.obs;
  final pingMs = 0.0.obs;
  final totalPacketsReceived = 0.obs;
  final errorMessage = ''.obs;

  WebSocket? _socket;
  Timer? _hzTimer;
  int _packetsThisSecond = 0;
  bool _intentionalDisconnect = false;

  bool get isConnected => connectionState.value == HardwareConnectionState.connected;


  @override
  void onClose() {
    disconnect();
    _hzTimer?.cancel();
    _hzTimer = null;
    super.onClose();
  }

  void _startRateMeter() {
    _hzTimer?.cancel();
    _hzTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      packetRateHz.value = _packetsThisSecond.toDouble();
      _packetsThisSecond = 0;
    });
  }

  /// Connect to Raspberry Pi WebSocket server (e.g. ws://192.168.1.50:8765)
  Future<bool> connect({String? host, int? port}) async {
    if (connectionState.value == HardwareConnectionState.connecting ||
        connectionState.value == HardwareConnectionState.connected) {
      await disconnect();
    }

    if (host != null) hostAddress.value = host.trim();
    if (port != null) hostPort.value = port;

    final targetUri = 'ws://${hostAddress.value}:${hostPort.value}';
    connectionState.value = HardwareConnectionState.connecting;
    errorMessage.value = '';
    _intentionalDisconnect = false;

    try {
      final startConnectTime = DateTime.now().millisecondsSinceEpoch;
      _socket = await WebSocket.connect(targetUri).timeout(const Duration(seconds: 5));
      final connectElapsed = (DateTime.now().millisecondsSinceEpoch - startConnectTime).toDouble();
      pingMs.value = connectElapsed;

      connectionState.value = HardwareConnectionState.connected;
      _startRateMeter();

      // Listen for incoming telemetry packets
      _socket!.listen(
        _onDataReceived,
        onError: _onError,
        onDone: _onDone,
        cancelOnError: true,
      );

      // Send initial handshake
      sendJson({'command': 'handshake', 'client': 'Flutter_Swarm_GCS'});
      return true;
    } catch (e) {
      connectionState.value = HardwareConnectionState.error;
      errorMessage.value = 'Failed to connect to $targetUri: $e';
      return false;
    }
  }

  /// Disconnect current WebSocket session cleanly
  Future<void> disconnect() async {
    _intentionalDisconnect = true;
    _hzTimer?.cancel();
    _hzTimer = null;
    try {
      await _socket?.close(WebSocketStatus.normalClosure, 'Client disconnected');
    } catch (_) {}
    _socket = null;
    connectionState.value = HardwareConnectionState.disconnected;
    packetRateHz.value = 0.0;
  }

  /// Handle incoming raw string data from Raspberry Pi
  void _onDataReceived(dynamic data) {
    try {
      final String text = data is String ? data : utf8.decode(data as List<int>);
      final dynamic decoded = jsonDecode(text);

      if (decoded is Map<String, dynamic>) {
        // Pong response for latency measurement
        if (decoded['type'] == 'pong' && decoded['client_time'] != null) {
          final sentTime = (decoded['client_time'] as num).toDouble();
          final now = DateTime.now().millisecondsSinceEpoch.toDouble();
          pingMs.value = math.max(1.0, now - sentTime);
          return;
        }

        final packet = RealDronePacket.fromJson(decoded);
        lastPacket.value = packet;
        totalPacketsReceived.value++;
        _packetsThisSecond++;
      }
    } catch (e) {
      // Ignore corrupted packet frame
    }
  }

  void _onError(Object error) {
    if (_intentionalDisconnect) return;
    connectionState.value = HardwareConnectionState.error;
    errorMessage.value = 'Connection error: $error';
  }

  void _onDone() {
    if (!_intentionalDisconnect) {
      connectionState.value = HardwareConnectionState.disconnected;
      errorMessage.value = 'Raspberry Pi closed the connection';
    }
  }

  /// Send JSON control command to Raspberry Pi
  bool sendJson(Map<String, dynamic> data) {
    if (_socket != null && isConnected) {
      try {
        _socket!.add(jsonEncode(data));
        return true;
      } catch (_) {}
    }
    return false;
  }

  /// Send Zero / Start Point calibration command
  void sendZeroCalibration() {
    sendJson({
      'command': 'zero_calibration',
      'timestamp': DateTime.now().millisecondsSinceEpoch / 1000.0,
    });
  }

  /// Send Ping to measure round-trip latency
  void ping() {
    sendJson({
      'command': 'ping',
      'client_time': DateTime.now().millisecondsSinceEpoch.toDouble(),
    });
  }
}
