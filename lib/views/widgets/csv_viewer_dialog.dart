import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../controllers/simulation_controller.dart';

class CsvViewerDialog extends StatelessWidget {
  const CsvViewerDialog({super.key});

  @override
  Widget build(BuildContext context) {
    final sim = Get.find<SimulationController>();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final results = sim.batchResults;

    final successCount = results.where((r) => r.status == 'OK').length;
    final successRate = results.isNotEmpty ? (successCount / results.length * 100) : 0.0;
    final avgFindTime = results.isNotEmpty
        ? (results.map((r) => r.timeToFind).reduce((a, b) => a + b) / results.length)
        : 0.0;

    return Dialog(
      backgroundColor: isDark ? const Color(0xFF131B26) : Colors.white,
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
                Icon(Icons.table_chart, color: isDark ? Colors.cyanAccent : const Color(0xFF0284C7)),
                const SizedBox(width: 10),
                Text(
                  'MONTE CARLO EXPERIMENT RESULTS',
                  style: TextStyle(
                    color: isDark ? Colors.white : const Color(0xFF0F172A),
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                IconButton(
                  onPressed: () => Get.back(),
                  icon: Icon(Icons.close, color: isDark ? Colors.white70 : const Color(0xFF64748B)),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Summary metrics bar
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(8),
                border: isDark ? null : Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _metricItem('Total Runs', '${results.length}', isDark),
                  _metricItem('Success Rate', '${successRate.toStringAsFixed(1)}%', isDark),
                  _metricItem('Avg Find Time', '${avgFindTime.toStringAsFixed(2)}s', isDark),
                  _metricItem('CSV File', sim.lastCsvPath.value.split("/").last, isDark),
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
                    headingRowColor: WidgetStateProperty.all(isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0)),
                    columns: [
                      DataColumn(label: Text('Run', style: TextStyle(color: isDark ? Colors.cyanAccent : const Color(0xFF0284C7)))),
                      DataColumn(label: Text('Status', style: TextStyle(color: isDark ? Colors.cyanAccent : const Color(0xFF0284C7)))),
                      DataColumn(label: Text('Finder', style: TextStyle(color: isDark ? Colors.cyanAccent : const Color(0xFF0284C7)))),
                      DataColumn(label: Text('Role', style: TextStyle(color: isDark ? Colors.cyanAccent : const Color(0xFF0284C7)))),
                      DataColumn(label: Text('Find Time (s)', style: TextStyle(color: isDark ? Colors.cyanAccent : const Color(0xFF0284C7)))),
                      DataColumn(label: Text('Total Time (s)', style: TextStyle(color: isDark ? Colors.cyanAccent : const Color(0xFF0284C7)))),
                      DataColumn(label: Text('Target (X, Y)', style: TextStyle(color: isDark ? Colors.cyanAccent : const Color(0xFF0284C7)))),
                      DataColumn(label: Text('Wall Hits', style: TextStyle(color: isDark ? Colors.cyanAccent : const Color(0xFF0284C7)))),
                      DataColumn(label: Text('Drone Hits', style: TextStyle(color: isDark ? Colors.cyanAccent : const Color(0xFF0284C7)))),
                    ],
                    rows: results.map((r) {
                      final isOk = r.status == 'OK';
                      final textPrimary = isDark ? Colors.white : const Color(0xFF0F172A);
                      final textSecondary = isDark ? Colors.white70 : const Color(0xFF475569);

                      return DataRow(
                        cells: [
                          DataCell(Text('${r.runIndex}', style: TextStyle(color: textPrimary))),
                          DataCell(
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: isOk
                                    ? (isDark ? Colors.green.shade900 : Colors.green.shade100)
                                    : (isDark ? Colors.red.shade900 : Colors.red.shade100),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                r.status,
                                style: TextStyle(
                                  color: isOk ? (isDark ? Colors.greenAccent : Colors.green.shade800) : (isDark ? Colors.redAccent : Colors.red.shade800),
                                  fontWeight: FontWeight.bold,
                                  fontSize: 11,
                                ),
                              ),
                            ),
                          ),
                          DataCell(Text(r.foundDrone, style: TextStyle(color: textSecondary))),
                          DataCell(Text(r.foundRole, style: TextStyle(color: textSecondary))),
                          DataCell(Text(r.timeToFind.toStringAsFixed(2), style: TextStyle(color: textPrimary))),
                          DataCell(Text(r.timeTotal.toStringAsFixed(2), style: TextStyle(color: textPrimary))),
                          DataCell(Text('(${r.targetPos.x.toStringAsFixed(2)}, ${r.targetPos.y.toStringAsFixed(2)})',
                              style: TextStyle(color: textSecondary))),
                          DataCell(Text('${r.wallCollisions}', style: TextStyle(color: isDark ? Colors.amberAccent : Colors.amber.shade900))),
                          DataCell(Text('${r.droneCollisions}', style: TextStyle(color: isDark ? Colors.orangeAccent : Colors.orange.shade900))),
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
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.blueGrey, foregroundColor: Colors.white),
                ),
                const SizedBox(width: 8),
                ElevatedButton.icon(
                  onPressed: () => sim.openCsvFile(),
                  icon: const Icon(Icons.open_in_new),
                  label: const Text('Open CSV File'),
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.teal, foregroundColor: Colors.white),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _metricItem(String title, String val, bool isDark) {
    return Column(
      children: [
        Text(title, style: TextStyle(color: isDark ? Colors.white54 : const Color(0xFF64748B), fontSize: 11)),
        const SizedBox(height: 4),
        Text(
          val,
          style: TextStyle(
            color: isDark ? Colors.white : const Color(0xFF0F172A),
            fontWeight: FontWeight.bold,
            fontSize: 14,
          ),
        ),
      ],
    );
  }
}
