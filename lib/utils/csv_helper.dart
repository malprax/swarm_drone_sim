import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import '../models/batch_run_result.dart';

class CsvHelper {
  /// Save batch run results to CSV in the application documents or desktop directory
  static Future<String> saveBatchResultsToCsv(List<BatchRunResult> results) async {
    final now = DateTime.now();
    final timestamp =
        '${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}_'
        '${now.hour.toString().padLeft(2, '0')}${now.minute.toString().padLeft(2, '0')}${now.second.toString().padLeft(2, '0')}';
    final fileName = 'montecarlo_$timestamp.csv';

    Directory dir;
    try {
      if (!kIsWeb && (Platform.isMacOS || Platform.isWindows || Platform.isLinux)) {
        dir = await getApplicationDocumentsDirectory();
      } else {
        dir = await getApplicationDocumentsDirectory();
      }
    } catch (_) {
      dir = Directory.current;
    }

    final swarmDir = Directory('${dir.path}/SwarmDroneResults');
    if (!await swarmDir.exists()) {
      await swarmDir.create(recursive: true);
    }

    final filePath = '${swarmDir.path}/$fileName';
    final file = File(filePath);

    final sink = file.openWrite();
    sink.writeln(BatchRunResult.csvHeader);
    for (final r in results) {
      sink.writeln(r.toCsvLine());
    }
    await sink.flush();
    await sink.close();

    return filePath;
  }

  /// Open CSV file in default system application (Numbers/Excel on Mac)
  static Future<void> openFile(String path) async {
    if (kIsWeb) return;
    if (!File(path).existsSync()) return;

    if (Platform.isMacOS) {
      await Process.run('open', [path]);
    } else if (Platform.isWindows) {
      await Process.run('explorer.exe', [path]);
    } else if (Platform.isLinux) {
      await Process.run('xdg-open', [path]);
    }
  }

  /// Open directory containing the CSV file in Finder / Explorer
  static Future<void> openFolder(String filePath) async {
    if (kIsWeb) return;
    final dirPath = File(filePath).parent.path;
    if (!Directory(dirPath).existsSync()) return;

    if (Platform.isMacOS) {
      await Process.run('open', [dirPath]);
    } else if (Platform.isWindows) {
      await Process.run('explorer.exe', [dirPath]);
    } else if (Platform.isLinux) {
      await Process.run('xdg-open', [dirPath]);
    }
  }
}
