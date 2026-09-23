import 'package:flutter/material.dart';

/// Draggable interactive splitter divider between screen panels (Arena, Minimap, Sidebars).
/// Supports horizontal (height resize) and vertical (width resize) dragging with visual feedback.
class ResizableDivider extends StatefulWidget {
  final Axis axis;
  final ValueChanged<double> onDragUpdate;
  final VoidCallback? onDoubleTap;
  final VoidCallback? onToggleCollapse;
  final bool isCollapsed;
  final String? tooltip;
  final Color? defaultColor;
  final Color? activeColor;

  const ResizableDivider({
    super.key,
    required this.axis,
    required this.onDragUpdate,
    this.onDoubleTap,
    this.onToggleCollapse,
    this.isCollapsed = false,
    this.tooltip,
    this.defaultColor,
    this.activeColor,
  });

  @override
  State<ResizableDivider> createState() => _ResizableDividerState();
}

class _ResizableDividerState extends State<ResizableDivider> {
  bool _isHovered = false;
  bool _isDragging = false;

  @override
  Widget build(BuildContext context) {
    final isHorizontal = widget.axis == Axis.horizontal;
    final cursor = isHorizontal ? SystemMouseCursors.resizeRow : SystemMouseCursors.resizeColumn;

    final baseColor = widget.defaultColor ?? const Color(0xFF334155);
    final highlightColor = widget.activeColor ?? Colors.cyanAccent;
    final isActive = _isHovered || _isDragging;

    Widget dividerContent = Container(
      color: Colors.transparent,
      child: Center(
        child: isHorizontal ? _buildHorizontalDivider(isActive, baseColor, highlightColor) : _buildVerticalDivider(isActive, baseColor, highlightColor),
      ),
    );

    if (widget.tooltip != null) {
      dividerContent = Tooltip(
        message: widget.tooltip!,
        waitDuration: const Duration(milliseconds: 400),
        child: dividerContent,
      );
    }

    return MouseRegion(
      cursor: cursor,
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        behavior: HitTestBehavior.translucent,
        onDoubleTap: widget.onDoubleTap,
        onVerticalDragStart: isHorizontal ? (_) => setState(() => _isDragging = true) : null,
        onVerticalDragUpdate: isHorizontal
            ? (details) {
                widget.onDragUpdate(details.delta.dy);
              }
            : null,
        onVerticalDragEnd: isHorizontal ? (_) => setState(() => _isDragging = false) : null,
        onHorizontalDragStart: !isHorizontal ? (_) => setState(() => _isDragging = true) : null,
        onHorizontalDragUpdate: !isHorizontal
            ? (details) {
                widget.onDragUpdate(details.delta.dx);
              }
            : null,
        onHorizontalDragEnd: !isHorizontal ? (_) => setState(() => _isDragging = false) : null,
        child: SizedBox(
          width: isHorizontal ? double.infinity : 10.0,
          height: isHorizontal ? 10.0 : double.infinity,
          child: dividerContent,
        ),
      ),
    );
  }

  Widget _buildHorizontalDivider(bool isActive, Color baseColor, Color highlightColor) {
    return Stack(
      alignment: Alignment.center,
      children: [
        // Main Line
        AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          height: isActive ? 2.5 : 1.5,
          color: isActive ? highlightColor : baseColor,
        ),

        // Center Handle Grip
        AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          width: isActive ? 44.0 : 32.0,
          height: 5.0,
          decoration: BoxDecoration(
            color: isActive ? highlightColor : const Color(0xFF475569),
            borderRadius: BorderRadius.circular(3.0),
            boxShadow: isActive
                ? [
                    BoxShadow(
                      color: highlightColor.withValues(alpha: 0.6),
                      blurRadius: 6.0,
                      spreadRadius: 1.0,
                    ),
                  ]
                : null,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(
              3,
              (i) => Container(
                width: 3.0,
                height: 3.0,
                margin: const EdgeInsets.symmetric(horizontal: 2.0),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isActive ? Colors.black87 : Colors.white54,
                ),
              ),
            ),
          ),
        ),

        // Optional Quick Collapse Button
        if (widget.onToggleCollapse != null)
          Positioned(
            right: 16,
            child: InkWell(
              onTap: widget.onToggleCollapse,
              borderRadius: BorderRadius.circular(4),
              child: Container(
                padding: const EdgeInsets.all(2),
                decoration: BoxDecoration(
                  color: const Color(0xFF1E293B),
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: isActive ? highlightColor : baseColor, width: 0.8),
                ),
                child: Icon(
                  widget.isCollapsed ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
                  size: 14,
                  color: isActive ? highlightColor : Colors.white70,
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildVerticalDivider(bool isActive, Color baseColor, Color highlightColor) {
    return Stack(
      alignment: Alignment.center,
      children: [
        // Main Line
        AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          width: isActive ? 2.5 : 1.5,
          color: isActive ? highlightColor : baseColor,
        ),

        // Center Handle Grip
        AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          height: isActive ? 44.0 : 32.0,
          width: 5.0,
          decoration: BoxDecoration(
            color: isActive ? highlightColor : const Color(0xFF475569),
            borderRadius: BorderRadius.circular(3.0),
            boxShadow: isActive
                ? [
                    BoxShadow(
                      color: highlightColor.withValues(alpha: 0.6),
                      blurRadius: 6.0,
                      spreadRadius: 1.0,
                    ),
                  ]
                : null,
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(
              3,
              (i) => Container(
                width: 3.0,
                height: 3.0,
                margin: const EdgeInsets.symmetric(vertical: 2.0),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isActive ? Colors.black87 : Colors.white54,
                ),
              ),
            ),
          ),
        ),

        // Optional Quick Collapse Button
        if (widget.onToggleCollapse != null)
          Positioned(
            top: 14,
            child: InkWell(
              onTap: widget.onToggleCollapse,
              borderRadius: BorderRadius.circular(4),
              child: Container(
                padding: const EdgeInsets.all(2),
                decoration: BoxDecoration(
                  color: const Color(0xFF1E293B),
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: isActive ? highlightColor : baseColor, width: 0.8),
                ),
                child: Icon(
                  widget.isCollapsed ? Icons.chevron_right : Icons.chevron_left,
                  size: 14,
                  color: isActive ? highlightColor : Colors.white70,
                ),
              ),
            ),
          ),
      ],
    );
  }
}
