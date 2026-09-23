import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../controllers/ui_controller.dart';

/// Layout preset switcher matching the 4 split icons from reference image:
/// 1. [ | ⚏ ] Right Stacked (Arena Left, Minimaps stacked on Right)
/// 2. [ ▮ ▯ ] Arena Focus (Fullscreen Arena)
/// 3. [ ▔ ▃ ] Horizontal Split (Arena Top, Minimaps Bottom)
/// 4. [ ▯ | ▯ ] Vertical Split (Arena Left, Minimap Right)
class LayoutPresetSelector extends StatelessWidget {
  final bool showHeader;

  const LayoutPresetSelector({super.key, this.showHeader = false});

  @override
  Widget build(BuildContext context) {
    final ui = Get.find<UIController>();

    return Obx(() {
      final current = ui.activeSplitLayout.value;

      final buttonsRow = Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // 1. Right Stacked / Vertical Split (Arena Left, Minimap Right)
          _LayoutIconButton(
            isActive: current == ArenaSplitLayout.rightStacked || current == ArenaSplitLayout.vertical,
            tooltip: 'Split Kanan: Arena di Kiri, Minimap Bertumpuk di Kanan',
            painter: const _RightStackedIconPainter(),
            onTap: () => ui.setSplitLayout(ArenaSplitLayout.rightStacked),
          ),
          const SizedBox(width: 4),

          // 2. Arena Full (Full box with boundary, arena full without minimap)
          _LayoutIconButton(
            isActive: current == ArenaSplitLayout.arenaFocus,
            tooltip: 'Arena Full: Layar Penuh Arena Tanpa Minimap',
            painter: const _ArenaFocusIconPainter(),
            onTap: () => ui.setSplitLayout(ArenaSplitLayout.arenaFocus),
          ),
          const SizedBox(width: 4),

          // 3. Horizontal Split (Arena Top, Minimap Bottom)
          _LayoutIconButton(
            isActive: current == ArenaSplitLayout.horizontal,
            tooltip: 'Split Bawah: Arena di Atas, Minimap di Bawah (Geser Tinggi)',
            painter: const _HorizontalSplitIconPainter(),
            onTap: () => ui.setSplitLayout(ArenaSplitLayout.horizontal),
          ),
        ],
      );

      if (!showHeader) {
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 3),
          decoration: BoxDecoration(
            color: const Color(0xFF0F172A),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: const Color(0xFF334155), width: 1.0),
          ),
          child: buttonsRow,
        );
      }

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
            const Text(
              'Layout:',
              style: TextStyle(
                color: Colors.white60,
                fontSize: 10,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 5),
            buttonsRow,
          ],
        ),
      );
    });
  }
}

class _LayoutIconButton extends StatefulWidget {
  final bool isActive;
  final String tooltip;
  final CustomPainter painter;
  final VoidCallback onTap;

  const _LayoutIconButton({
    required this.isActive,
    required this.tooltip,
    required this.painter,
    required this.onTap,
  });

  @override
  State<_LayoutIconButton> createState() => _LayoutIconButtonState();
}

class _LayoutIconButtonState extends State<_LayoutIconButton> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final activeColor = Colors.cyanAccent;
    final hoverColor = Colors.white70;
    final defaultColor = const Color(0xFF94A3B8);

    final iconColor = widget.isActive
        ? activeColor
        : (_isHovered ? hoverColor : defaultColor);

    return Tooltip(
      message: widget.tooltip,
      waitDuration: const Duration(milliseconds: 300),
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) => setState(() => _isHovered = true),
        onExit: (_) => setState(() => _isHovered = false),
        child: GestureDetector(
          onTap: widget.onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            width: 32,
            height: 28,
            decoration: BoxDecoration(
              color: widget.isActive
                  ? Colors.cyanAccent.withValues(alpha: 0.15)
                  : (_isHovered ? const Color(0xFF1E293B) : Colors.transparent),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(
                color: widget.isActive
                    ? Colors.cyanAccent.withValues(alpha: 0.8)
                    : (_isHovered ? const Color(0xFF475569) : Colors.transparent),
                width: 1.0,
              ),
            ),
            child: Center(
              child: CustomPaint(
                size: const Size(22, 22),
                painter: _ThemedPainterWrapper(
                  originalPainter: widget.painter,
                  color: iconColor,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ThemedPainterWrapper extends CustomPainter {
  final CustomPainter originalPainter;
  final Color color;

  _ThemedPainterWrapper({required this.originalPainter, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    if (originalPainter is _RightStackedIconPainter) {
      _RightStackedIconPainter.paintWithColor(canvas, size, color);
    } else if (originalPainter is _ArenaFocusIconPainter) {
      _ArenaFocusIconPainter.paintWithColor(canvas, size, color);
    } else if (originalPainter is _HorizontalSplitIconPainter) {
      _HorizontalSplitIconPainter.paintWithColor(canvas, size, color);
    }
  }

  @override
  bool shouldRepaint(covariant _ThemedPainterWrapper oldDelegate) {
    return oldDelegate.color != color;
  }
}

/// Icon 1: [ | ⚏ ] Right Stacked (Tall left column + 2 stacked right boxes)
class _RightStackedIconPainter extends CustomPainter {
  const _RightStackedIconPainter();

  static void paintWithColor(Canvas canvas, Size size, Color color) {
    final strokePaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6;

    // Left tall column
    final leftRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(1.5, 1.5, 8.0, size.height - 3.0),
      const Radius.circular(2.5),
    );
    canvas.drawRRect(leftRect, strokePaint);

    // Right top box
    final rightTopRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(12.5, 1.5, size.width - 14.0, (size.height - 5.0) / 2.0),
      const Radius.circular(2.0),
    );
    canvas.drawRRect(rightTopRect, strokePaint);

    // Right bottom box
    final rightBottomRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(12.5, (size.height - 5.0) / 2.0 + 3.5, size.width - 14.0, (size.height - 5.0) / 2.0),
      const Radius.circular(2.0),
    );
    canvas.drawRRect(rightBottomRect, strokePaint);
  }

  @override
  void paint(Canvas canvas, Size size) => paintWithColor(canvas, size, Colors.white);
  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Icon 2: [ ▢ ] Arena Full (One full square box with boundary, representing arena full without minimap)
class _ArenaFocusIconPainter extends CustomPainter {
  const _ArenaFocusIconPainter();

  static void paintWithColor(Canvas canvas, Size size, Color color) {
    final strokePaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6;

    final fillPaint = Paint()
      ..color = color.withValues(alpha: 0.18)
      ..style = PaintingStyle.fill;

    final outerRRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(1.5, 1.5, size.width - 3.0, size.height - 3.0),
      const Radius.circular(3.5),
    );
    canvas.drawRRect(outerRRect, fillPaint);
    canvas.drawRRect(outerRRect, strokePaint);
  }

  @override
  void paint(Canvas canvas, Size size) => paintWithColor(canvas, size, Colors.white);
  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Icon 3: [ ▔ ▃ ] Horizontal Split (Square with bottom half shaded)
class _HorizontalSplitIconPainter extends CustomPainter {
  const _HorizontalSplitIconPainter();

  static void paintWithColor(Canvas canvas, Size size, Color color) {
    final strokePaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6;

    final fillPaint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    final outerRRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(1.5, 1.5, size.width - 3.0, size.height - 3.0),
      const Radius.circular(3.5),
    );
    canvas.drawRRect(outerRRect, strokePaint);

    // Bottom half filled
    final halfH = (size.height - 3.0) / 2.0;
    final bottomFill = RRect.fromRectAndCorners(
      Rect.fromLTWH(1.5, 1.5 + halfH, size.width - 3.0, halfH),
      bottomLeft: const Radius.circular(3.5),
      bottomRight: const Radius.circular(3.5),
    );
    canvas.drawRRect(bottomFill, fillPaint);
  }

  @override
  void paint(Canvas canvas, Size size) => paintWithColor(canvas, size, Colors.white);
  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
