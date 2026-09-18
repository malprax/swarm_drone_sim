import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../controllers/simulation_controller.dart';

class CsvViewerDialog extends StatelessWidget {
  const CsvViewerDialog({super.key});

  @override
  Widget build(BuildContext context) {
    final sim = Get.find<SimulationController>();
    final results = sim.batchResults;

    final successCount = results.where((r) => r.status == 'OK').length;
    final successRate = results.isNotEmpty ? (successCount / results.length * 100) : 0.0;
    final avgFindTime = results.isNotEmpty
        ? (results.map((r) => r.timeToFind).reduce((a, b) => a + b) / results.length)
        : 0.0;

    return Dialog(
      backgroundColor: const Color(0xFF131B26),
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        width: 1000,
        height: 700,
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                const Icon(Icons.table_chart, color: Colors.cyanAccent),
                const SizedBox(width: 10),
                const Text(
                  'MONTE CARLO EXPERIMENT RESULTS',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                IconButton(
                  onPressed: () => Get.back(),
                  icon: const Icon(Icons.close, color: Colors.white70),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Summary metrics bar
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: const Color(0xFF1E293B),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _metricItem('Total Runs', '${results.length}'),
                  _metricItem('Success Rate', '${successRate.toStringAsFixed(1)}%'),
                  _metricItem('Avg Find Time', '${avgFindTime.toStringAsFixed(2)}s'),
                  _metricItem('CSV File', sim.lastCsvPath.value.split("/").last),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Results Table
            Expanded(
              child: SingleChildScrollView(
                scrollDirection: Axis.vertical,
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: DataTable(
                    headingRowColor: WidgetStateProperty.all(const Color(0xFF1E293B)),
                    columns: const [
                      DataColumn(label: Text('Run', style: TextStyle(color: Colors.cyanAccent))),
                      DataColumn(label: Text('Status', style: TextStyle(color: Colors.cyanAccent))),
                      DataColumn(label: Text('Finder', style: TextStyle(color: Colors.cyanAccent))),
                      DataColumn(label: Text('Role', style: TextStyle(color: Colors.cyanAccent))),
                      DataColumn(label: Text('Find Time (s)', style: TextStyle(color: Colors.cyanAccent))),
                      DataColumn(label: Text('Total Time (s)', style: TextStyle(color: Colors.cyanAccent))),
                      DataColumn(label: Text('Target (X, Y)', style: TextStyle(color: Colors.cyanAccent))),
                      DataColumn(label: Text('Wall Hits', style: TextStyle(color: Colors.cyanAccent))),
                      DataColumn(label: Text('Drone Hits', style: TextStyle(color: Colors.cyanAccent))),
                    ],
                    rows: results.map((r) {
                      final isOk = r.status == 'OK';
                      return DataRow(
                        cells: [
                          DataCell(Text('${r.runIndex}', style: const TextStyle(color: Colors.white))),
                          DataCell(
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: isOk ? Colors.green.shade900 : Colors.red.shade900,
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                r.status,
                                style: TextStyle(
                                  color: isOk ? Colors.greenAccent : Colors.redAccent,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 11,
                                ),
                              ),
                            ),
                          ),
                          DataCell(Text(r.foundDrone, style: const TextStyle(color: Colors.white70))),
                          DataCell(Text(r.foundRole, style: const TextStyle(color: Colors.white70))),
                          DataCell(Text(r.timeToFind.toStringAsFixed(2), style: const TextStyle(color: Colors.white))),
                          DataCell(Text(r.timeTotal.toStringAsFixed(2), style: const TextStyle(color: Colors.white))),
                          DataCell(Text('(${r.targetPos.x.toStringAsFixed(2)}, ${r.targetPos.y.toStringAsFixed(2)})',
                              style: const TextStyle(color: Colors.white70))),
                          DataCell(Text('${r.wallCollisions}', style: const TextStyle(color: Colors.amberAccent))),
                          DataCell(Text('${r.droneCollisions}', style: const TextStyle(color: Colors.orangeAccent))),
                        ],
                      );
                    }).toList(),
                  ),
                ),
              ),
            ),

            const SizedBox(height: 12),
            // Actions
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                ElevatedButton.icon(
                  onPressed: () => sim.openCsvFolder(),
                  icon: const Icon(Icons.folder_open),
                  label: const Text('Open Folder in Finder'),
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.blueGrey),
                ),
                const SizedBox(width: 8),
                ElevatedButton.icon(
                  onPressed: () => sim.openCsvFile(),
                  icon: const Icon(Icons.open_in_new),
                  label: const Text('Open CSV File'),
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.teal),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _metricItem(String title, String val) {
    return Column(
      children: [
        Text(title, style: const TextStyle(color: Colors.white54, fontSize: 11)),
        const SizedBox(height: 4),
        Text(
          val,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 14,
          ),
        ),
      ],
    );
  }
}
