import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../controllers/ui_controller.dart';

/// Interactive HUD control widget for customizing detected wall line thickness (0-3 pt)
/// and pattern/style (Solid, Dashed, Sharp Zigzag, Smooth Wavy).
class WallLineCustomizerWidget extends StatelessWidget {
  const WallLineCustomizerWidget({super.key});

  @override
  Widget build(BuildContext context) {
    final ui = Get.find<UIController>();

    return Obx(() {
      final isDark = ui.isDarkMode;

      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xEE0B1120) : Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1), width: 1.0),
          boxShadow: isDark
              ? const [
                  BoxShadow(color: Colors.black45, blurRadius: 6, offset: Offset(0, 2)),
                ]
              : const [
                  BoxShadow(color: Colors.black12, blurRadius: 6, offset: Offset(0, 2)),
                ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Row 1: Line Thickness selector (0 pt, 1 pt, 2 pt, 3 pt)
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Tebal: ',
                  style: TextStyle(
                    color: isDark ? Colors.white60 : const Color(0xFF64748B),
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                _buildThicknessPill(ui, 0, '0 pt', '0 Point: Sembunyikan garis merah dinding', isDark),
                const SizedBox(width: 3),
                _buildThicknessPill(ui, 1, '1 pt', '1 Point: Garis merah tipis', isDark),
                const SizedBox(width: 3),
                _buildThicknessPill(ui, 2, '2 pt', '2 Point: Garis merah sedang', isDark),
                const SizedBox(width: 3),
                _buildThicknessPill(ui, 3, '3 pt', '3 Point: Garis merah tebal', isDark),
              ],
            ),
            const SizedBox(height: 5),

            // Row 2: Line Pattern / Style selector (Sambung, Putus, Tajam, Tumpul)
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Pola: ',
                  style: TextStyle(
                    color: isDark ? Colors.white60 : const Color(0xFF64748B),
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                _buildStylePill(ui, WallLineStyle.solid, '—', 'Sambung', 'Garis Lurus Sambung (Kontinu)', isDark),
                const SizedBox(width: 3),
                _buildStylePill(ui, WallLineStyle.dashed, '- -', 'Putus', 'Garis Putus-putus (Dashed)', isDark),
                const SizedBox(width: 3),
                _buildStylePill(ui, WallLineStyle.zigzag, '⋀⋁', 'Tajam', 'Bergelombang Tajam (Zigzag Wave)', isDark),
                const SizedBox(width: 3),
                _buildStylePill(ui, WallLineStyle.wavy, '〜', 'Tumpul', 'Bergelombang Tumpul (Sinusoidal Wave)', isDark),
              ],
            ),
          ],
        ),
      );
    });
  }

  Widget _buildThicknessPill(
    UIController ui,
    int pt,
    String label,
    String tooltip,
    bool isDark,
  ) {
    return Obx(() {
      final isSelected = ui.wallLineThickness.value == pt;
      final activeColor = pt == 0
          ? (isDark ? Colors.amberAccent : Colors.amber.shade800)
          : (isDark ? Colors.cyanAccent : const Color(0xFF0284C7));

      return Tooltip(
        message: tooltip,
        waitDuration: const Duration(milliseconds: 300),
        child: InkWell(
          onTap: () => ui.setWallLineThickness(pt),
          borderRadius: BorderRadius.circular(4),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2.5),
            decoration: BoxDecoration(
              color: isSelected
                  ? activeColor.withValues(alpha: isDark ? 0.25 : 0.15)
                  : (isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9)),
              borderRadius: BorderRadius.circular(4),
              border: Border.all(
                color: isSelected ? activeColor : (isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1)),
                width: 1.0,
              ),
            ),
            child: Text(
              label,
              style: TextStyle(
                color: isSelected ? activeColor : (isDark ? Colors.white70 : const Color(0xFF475569)),
                fontSize: 9.5,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ),
        ),
      );
    });
  }

  Widget _buildStylePill(
    UIController ui,
    WallLineStyle style,
    String iconSymbol,
    String label,
    String tooltip,
    bool isDark,
  ) {
    return Obx(() {
      final isSelected = ui.wallLineStyle.value == style;
      final activeColor = isDark ? Colors.cyanAccent : const Color(0xFF0284C7);

      return Tooltip(
        message: tooltip,
        waitDuration: const Duration(milliseconds: 300),
        child: InkWell(
          onTap: () => ui.setWallLineStyle(style),
          borderRadius: BorderRadius.circular(4),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2.5),
            decoration: BoxDecoration(
              color: isSelected
                  ? activeColor.withValues(alpha: isDark ? 0.25 : 0.15)
                  : (isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9)),
              borderRadius: BorderRadius.circular(4),
              border: Border.all(
                color: isSelected ? activeColor : (isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1)),
                width: 1.0,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  iconSymbol,
                  style: TextStyle(
                    color: isSelected ? activeColor : (isDark ? Colors.white60 : const Color(0xFF64748B)),
                    fontSize: 9.5,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(width: 3),
                Text(
                  label,
                  style: TextStyle(
                    color: isSelected ? activeColor : (isDark ? Colors.white70 : const Color(0xFF475569)),
                    fontSize: 9.0,
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    });
  }
}
