import 'dart:async';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import '../lib/services/uwb_bindings.dart';

void main() {
  test('UWB DW3000 Engine Dart FFI End-to-End Pipeline Test', () async {
    final home = Platform.environment['HOME'] ?? '';
    final dylibPath = '$home/Developer/swarm_drone_high/build/libuwb_core_native.dylib';
    final configPath = '$home/Developer/swarm_drone_high/config.json';

    expect(File(dylibPath).existsSync(), isTrue, reason: 'libuwb_core_native.dylib must exist');
    expect(File(configPath).existsSync(), isTrue, reason: 'config.json must exist');

    final engine = UwbEngine(libraryPath: dylibPath);
    engine.initialize(configPath);

    final anchors = engine.getAnchors();
    expect(anchors.length, equals(4));

    engine.start();

    int stateCount = 0;
    final completer = Completer<void>();

    final sub = engine.stateStream.listen((state) {
      stateCount++;
      if (stateCount >= 30 && !completer.isCompleted) {
        completer.complete();
      }
    });

    await completer.future.timeout(const Duration(seconds: 4));
    await sub.cancel();

    final stats = engine.getStats();
    engine.dispose();

    expect(stateCount, greaterThanOrEqualTo(30));
    expect(stats.droppedPackets, equals(0), reason: 'Zero packet loss target');
    expect(stats.avgLatencyMs, lessThan(10.0), reason: '< 10ms latency target');
  });
}
