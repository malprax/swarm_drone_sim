import 'dart:async';
import 'dart:ffi' as ffi;
import 'dart:io';
import 'package:ffi/ffi.dart';

// --- FFI C STRUCTS ---

final class Vec3Native extends ffi.Struct {
  @ffi.Double()
  external double x;
  @ffi.Double()
  external double y;
  @ffi.Double()
  external double z;
}

final class AnchorConfigNative extends ffi.Struct {
  @ffi.Uint8()
  external int id;
  @ffi.Array(7)
  external ffi.Array<ffi.Uint8> padding;
  @ffi.Double()
  external double x;
  @ffi.Double()
  external double y;
  @ffi.Double()
  external double z;
}

final class DroneStateNative extends ffi.Struct {
  @ffi.Uint64()
  external int timestampNs;
  @ffi.Uint8()
  external int droneId;
  @ffi.Uint8()
  external int isConverged;
  @ffi.Array(6)
  external ffi.Array<ffi.Uint8> padding;
  @ffi.Double()
  external double x;
  @ffi.Double()
  external double y;
  @ffi.Double()
  external double z;
  @ffi.Double()
  external double vx;
  @ffi.Double()
  external double vy;
  @ffi.Double()
  external double vz;
  @ffi.Array(3)
  external ffi.Array<ffi.Double> covariance;
  @ffi.Double()
  external double latencyMs;
}

// --- FFI FUNCTION SIGNATURES ---

typedef _CreateEngineC = ffi.Pointer<ffi.Opaque> Function(ffi.Pointer<Utf8> configPath);
typedef _CreateEngineDart = ffi.Pointer<ffi.Opaque> Function(ffi.Pointer<Utf8> configPath);

typedef _StartEngineC = ffi.Int32 Function(ffi.Pointer<ffi.Opaque> engine);
typedef _StartEngineDart = int Function(ffi.Pointer<ffi.Opaque> engine);

typedef _StopEngineC = ffi.Void Function(ffi.Pointer<ffi.Opaque> engine);
typedef _StopEngineDart = void Function(ffi.Pointer<ffi.Opaque> engine);

typedef _DestroyEngineC = ffi.Void Function(ffi.Pointer<ffi.Opaque> engine);
typedef _DestroyEngineDart = void Function(ffi.Pointer<ffi.Opaque> engine);

typedef _StepEngineC = ffi.Int32 Function(ffi.Pointer<ffi.Opaque> engine, ffi.Pointer<DroneStateNative> outState);
typedef _StepEngineDart = int Function(ffi.Pointer<ffi.Opaque> engine, ffi.Pointer<DroneStateNative> outState);

typedef _GetAnchorsC = ffi.Void Function(
    ffi.Pointer<ffi.Opaque> engine,
    ffi.Pointer<AnchorConfigNative> outAnchors,
    ffi.Pointer<ffi.Int32> outCount);
typedef _GetAnchorsDart = void Function(
    ffi.Pointer<ffi.Opaque> engine,
    ffi.Pointer<AnchorConfigNative> outAnchors,
    ffi.Pointer<ffi.Int32> outCount);

typedef _GetStatsC = ffi.Void Function(
    ffi.Pointer<ffi.Opaque> engine,
    ffi.Pointer<ffi.Uint64> totalEnq,
    ffi.Pointer<ffi.Uint64> totalDeq,
    ffi.Pointer<ffi.Uint64> dropped,
    ffi.Pointer<ffi.Double> avgLat);
typedef _GetStatsDart = void Function(
    ffi.Pointer<ffi.Opaque> engine,
    ffi.Pointer<ffi.Uint64> totalEnq,
    ffi.Pointer<ffi.Uint64> totalDeq,
    ffi.Pointer<ffi.Uint64> dropped,
    ffi.Pointer<ffi.Double> avgLat);

// --- DART DATA MODELS ---

class DroneStateModel {
  final int timestampNs;
  final int droneId;
  final bool isConverged;
  final double x;
  final double y;
  final double z;
  final double vx;
  final double vy;
  final double vz;
  final double latencyMs;

  const DroneStateModel({
    required this.timestampNs,
    required this.droneId,
    required this.isConverged,
    required this.x,
    required this.y,
    required this.z,
    required this.vx,
    required this.vy,
    required this.vz,
    required this.latencyMs,
  });

  factory DroneStateModel.fromNative(DroneStateNative native) {
    return DroneStateModel(
      timestampNs: native.timestampNs,
      droneId: native.droneId,
      isConverged: native.isConverged != 0,
      x: native.x,
      y: native.y,
      z: native.z,
      vx: native.vx,
      vy: native.vy,
      vz: native.vz,
      latencyMs: native.latencyMs,
    );
  }
}

class AnchorModel {
  final int id;
  final double x;
  final double y;
  final double z;

  const AnchorModel({
    required this.id,
    required this.x,
    required this.y,
    required this.z,
  });
}

class EngineStats {
  final int totalEnqueued;
  final int totalDequeued;
  final int droppedPackets;
  final double avgLatencyMs;

  const EngineStats({
    required this.totalEnqueued,
    required this.totalDequeued,
    required this.droppedPackets,
    required this.avgLatencyMs,
  });
}

// --- HIGH-LEVEL UWB ENGINE CONTROLLER ---

class UwbEngine {
  late final ffi.DynamicLibrary _dylib;
  ffi.Pointer<ffi.Opaque>? _engineHandle;

  late final _CreateEngineDart _createEngine;
  late final _StartEngineDart _startEngine;
  late final _StopEngineDart _stopEngine;
  late final _DestroyEngineDart _destroyEngine;
  late final _StepEngineDart _stepEngine;
  late final _GetAnchorsDart _getAnchors;
  late final _GetStatsDart _getStats;

  Timer? _pollingTimer;
  final _stateController = StreamController<DroneStateModel>.broadcast();
  DroneStateModel? _lastState;

  Stream<DroneStateModel> get stateStream => _stateController.stream;
  DroneStateModel? get latestState => _lastState;

  UwbEngine({String? libraryPath}) {
    _loadLibrary(libraryPath);
    _bindFunctions();
  }

  void _loadLibrary(String? customPath) {
    if (customPath != null && File(customPath).existsSync()) {
      _dylib = ffi.DynamicLibrary.open(customPath);
      return;
    }

    String libName;
    if (Platform.isMacOS) {
      libName = 'libuwb_core_native.dylib';
    } else if (Platform.isLinux) {
      libName = 'libuwb_core_native.so';
    } else if (Platform.isWindows) {
      libName = 'uwb_core_native.dll';
    } else {
      throw UnsupportedError('Unsupported platform: ${Platform.operatingSystem}');
    }

    final home = Platform.environment['HOME'] ?? '';
    final searchPaths = [
      libName,
      '$home/Developer/swarm_drone_high/build/$libName',
      './build/$libName',
      '../build/$libName',
      'build/$libName',
    ];

    for (final path in searchPaths) {
      if (File(path).existsSync()) {
        _dylib = ffi.DynamicLibrary.open(path);
        return;
      }
    }

    // Fallback to process resolution
    _dylib = ffi.DynamicLibrary.process();
  }

  void _bindFunctions() {
    _createEngine = _dylib
        .lookup<ffi.NativeFunction<_CreateEngineC>>('uwb_engine_create')
        .asFunction<_CreateEngineDart>();

    _startEngine = _dylib
        .lookup<ffi.NativeFunction<_StartEngineC>>('uwb_engine_start')
        .asFunction<_StartEngineDart>();

    _stopEngine = _dylib
        .lookup<ffi.NativeFunction<_StopEngineC>>('uwb_engine_stop')
        .asFunction<_StopEngineDart>();

    _destroyEngine = _dylib
        .lookup<ffi.NativeFunction<_DestroyEngineC>>('uwb_engine_destroy')
        .asFunction<_DestroyEngineDart>();

    _stepEngine = _dylib
        .lookup<ffi.NativeFunction<_StepEngineC>>('uwb_engine_step')
        .asFunction<_StepEngineDart>();

    _getAnchors = _dylib
        .lookup<ffi.NativeFunction<_GetAnchorsC>>('uwb_engine_get_anchors')
        .asFunction<_GetAnchorsDart>();

    _getStats = _dylib
        .lookup<ffi.NativeFunction<_GetStatsC>>('uwb_engine_get_stats')
        .asFunction<_GetStatsDart>();
  }

  void initialize([String? configJsonPath]) {
    final pathPtr = (configJsonPath != null)
        ? configJsonPath.toNativeUtf8()
        : ffi.nullptr;

    _engineHandle = _createEngine(pathPtr);
    if (pathPtr != ffi.nullptr) {
      calloc.free(pathPtr);
    }
  }

  void start() {
    if (_engineHandle == null) throw StateError('Engine not initialized');
    _startEngine(_engineHandle!);

    _pollingTimer = Timer.periodic(const Duration(milliseconds: 10), (_) {
      _pollOnce();
    });
  }

  void _pollOnce() {
    if (_engineHandle == null) return;
    final statePtr = calloc<DroneStateNative>();
    try {
      final status = _stepEngine(_engineHandle!, statePtr);
      if (status == 1) {
        final state = DroneStateModel.fromNative(statePtr.ref);
        _lastState = state;
        if (!_stateController.isClosed) {
          _stateController.add(state);
        }
      }
    } finally {
      calloc.free(statePtr);
    }
  }

  void stop() {
    _pollingTimer?.cancel();
    _pollingTimer = null;
    if (_engineHandle != null) {
      _stopEngine(_engineHandle!);
    }
  }

  List<AnchorModel> getAnchors() {
    if (_engineHandle == null) return [];
    final anchorsPtr = calloc<AnchorConfigNative>(4);
    final countPtr = calloc<ffi.Int32>();
    try {
      _getAnchors(_engineHandle!, anchorsPtr, countPtr);
      final count = countPtr.value;
      final result = <AnchorModel>[];
      for (int i = 0; i < count; ++i) {
        final a = anchorsPtr[i];
        result.add(AnchorModel(id: a.id, x: a.x, y: a.y, z: a.z));
      }
      return result;
    } finally {
      calloc.free(anchorsPtr);
      calloc.free(countPtr);
    }
  }

  EngineStats getStats() {
    if (_engineHandle == null) {
      return const EngineStats(totalEnqueued: 0, totalDequeued: 0, droppedPackets: 0, avgLatencyMs: 0.0);
    }
    final enqPtr = calloc<ffi.Uint64>();
    final deqPtr = calloc<ffi.Uint64>();
    final dropPtr = calloc<ffi.Uint64>();
    final latPtr = calloc<ffi.Double>();
    try {
      _getStats(_engineHandle!, enqPtr, deqPtr, dropPtr, latPtr);
      return EngineStats(
        totalEnqueued: enqPtr.value,
        totalDequeued: deqPtr.value,
        droppedPackets: dropPtr.value,
        avgLatencyMs: latPtr.value,
      );
    } finally {
      calloc.free(enqPtr);
      calloc.free(deqPtr);
      calloc.free(dropPtr);
      calloc.free(latPtr);
    }
  }

  void dispose() {
    stop();
    _stateController.close();
    if (_engineHandle != null) {
      _destroyEngine(_engineHandle!);
      _engineHandle = null;
    }
  }
}
