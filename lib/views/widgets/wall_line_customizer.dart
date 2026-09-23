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

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xEE0B1120),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFF334155), width: 1.0),
        boxShadow: const [
          BoxShadow(color: Colors.black45, blurRadius: 6, offset: Offset(0, 2)),
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
              const Text(
                'Tebal: ',
                style: TextStyle(
                  color: Colors.white60,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
              ),
              _buildThicknessPill(ui, 0, '0 pt', '0 Point: Sembunyikan garis merah dinding'),
              const SizedBox(width: 3),
              _buildThicknessPill(ui, 1, '1 pt', '1 Point: Garis merah tipis'),
              const SizedBox(width: 3),
              _buildThicknessPill(ui, 2, '2 pt', '2 Point: Garis merah sedang'),
              const SizedBox(width: 3),
              _buildThicknessPill(ui, 3, '3 pt', '3 Point: Garis merah tebal'),
            ],
          ),
          const SizedBox(height: 5),

          // Row 2: Line Pattern / Style selector (Sambung, Putus, Tajam, Tumpul)
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Pola: ',
                style: TextStyle(
                  color: Colors.white60,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
              ),
              _buildStylePill(ui, WallLineStyle.solid, '—', 'Sambung', 'Garis Lurus Sambung (Kontinu)'),
              const SizedBox(width: 3),
              _buildStylePill(ui, WallLineStyle.dashed, '- -', 'Putus', 'Garis Putus-putus (Dashed)'),
              const SizedBox(width: 3),
              _buildStylePill(ui, WallLineStyle.zigzag, '⋀⋁', 'Tajam', 'Bergelombang Tajam (Zigzag Wave)'),
              const SizedBox(width: 3),
              _buildStylePill(ui, WallLineStyle.wavy, '〜', 'Tumpul', 'Bergelombang Tumpul (Sinusoidal Wave)'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildThicknessPill(UIController ui, int pt, String label, String tooltip) {
    return Obx(() {
      final isSelected = ui.wallLineThickness.value == pt;
      final activeColor = pt == 0 ? Colors.amberAccent : Colors.cyanAccent;

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
              color: isSelected ? activeColor.withValues(alpha: 0.25) : const Color(0xFF0F172A),
              borderRadius: BorderRadius.circular(4),
              border: Border.all(
                color: isSelected ? activeColor : const Color(0xFF334155),
                width: 1.0,
              ),
            ),
            child: Text(
              label,
              style: TextStyle(
                color: isSelected ? activeColor : Colors.white70,
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
  ) {
    return Obx(() {
      final isSelected = ui.wallLineStyle.value == style;
      const activeColor = Colors.cyanAccent;

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
              color: isSelected ? activeColor.withValues(alpha: 0.25) : const Color(0xFF0F172A),
              borderRadius: BorderRadius.circular(4),
              border: Border.all(
                color: isSelected ? activeColor : const Color(0xFF334155),
                width: 1.0,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  iconSymbol,
                  style: TextStyle(
                    color: isSelected ? activeColor : Colors.white60,
                    fontSize: 9.5,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(width: 3),
                Text(
                  label,
                  style: TextStyle(
                    color: isSelected ? activeColor : Colors.white70,
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
