import 'dart:async';
import 'dart:io';
import 'package:get/get.dart';
import 'uwb_bindings.dart';

class UwbEngineService extends GetxService {
  UwbEngine? _engine;
  StreamSubscription<DroneStateModel>? _stateSub;
  Timer? _statsTimer;

  final isRunning = false.obs;
  final latestState = Rxn<DroneStateModel>();
  final anchors = <AnchorModel>[].obs;
  final stats = const EngineStats(
    totalEnqueued: 0,
    totalDequeued: 0,
    droppedPackets: 0,
    avgLatencyMs: 0.0,
  ).obs;

  @override
  void onInit() {
    super.onInit();
    _initEngine();
  }

  void _initEngine() {
    try {
      final home = Platform.environment['HOME'] ?? '';
      final configPath = '$home/Developer/swarm_drone_high/config.json';
      final dylibPath = '$home/Developer/swarm_drone_high/build/libuwb_core_native.dylib';

      _engine = UwbEngine(libraryPath: File(dylibPath).existsSync() ? dylibPath : null);
      _engine!.initialize(File(configPath).existsSync() ? configPath : null);

      anchors.value = _engine!.getAnchors();
    } catch (e) {
      // ignore
    }
  }

  void startEngine() {
    if (_engine == null) _initEngine();
    if (_engine == null) return;
    if (isRunning.value) return;

    try {
      _engine!.start();
      isRunning.value = true;

      _stateSub = _engine!.stateStream.listen((state) {
        latestState.value = state;
      });

      _statsTimer = Timer.periodic(const Duration(milliseconds: 250), (_) {
        if (_engine != null && isRunning.value) {
          stats.value = _engine!.getStats();
        }
      });
    } catch (e) {
      // ignore
    }
  }

  void stopEngine() {
    _stateSub?.cancel();
    _stateSub = null;
    _statsTimer?.cancel();
    _statsTimer = null;

    if (_engine != null && isRunning.value) {
      _engine!.stop();
      isRunning.value = false;
    }
  }

  void toggleEngine() {
    if (isRunning.value) {
      stopEngine();
    } else {
      startEngine();
    }
  }

  @override
  void onClose() {
    stopEngine();
    _engine?.dispose();
    _engine = null;
    super.onClose();
  }
}
