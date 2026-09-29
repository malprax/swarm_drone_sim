import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../services/uwb_bindings.dart';

/// Interactive 2D Ground Control Station (GCS) Top-Down Canvas Widget.
/// Displays 2D Top-Down Grid View (X, Y plane) with real-time Altitude (Z) Readout Badge.
class Uwb2DCanvasWidget extends StatefulWidget {
  final DroneStateModel? droneState;
  final List<AnchorModel> anchors;
  final double arenaWidthMeters;
  final double arenaHeightMeters;
  final bool showTrail;

  const Uwb2DCanvasWidget({
    super.key,
    required this.droneState,
    this.anchors = const [],
    this.arenaWidthMeters = 6.0,
    this.arenaHeightMeters = 6.0,
    this.showTrail = true,
  });

  @override
  State<Uwb2DCanvasWidget> createState() => _Uwb2DCanvasWidgetState();
}

class _Uwb2DCanvasWidgetState extends State<Uwb2DCanvasWidget> {
  final List<Offset> _trailHistory = [];
  static const int _maxTrailPoints = 80;

  @override
  void didUpdateWidget(covariant Uwb2DCanvasWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.droneState != null && widget.showTrail) {
      final pos = Offset(widget.droneState!.x, widget.droneState!.y);
      if (_trailHistory.isEmpty || (_trailHistory.last - pos).distance > 0.02) {
        _trailHistory.add(pos);
        if (_trailHistory.length > _maxTrailPoints) {
          _trailHistory.removeAt(0);
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = widget.droneState;

    return Stack(
      children: [
        // Custom 2D Grid Canvas
        ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: CustomPaint(
            size: Size.infinite,
            painter: Uwb2DPainter(
              droneState: state,
              anchors: widget.anchors,
              trail: _trailHistory,
              arenaWidthMeters: widget.arenaWidthMeters,
              arenaHeightMeters: widget.arenaHeightMeters,
            ),
          ),
        ),

        // Top-Left: Real-time Telemetry & Latency HUD
        Positioned(
          top: 14,
          left: 14,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: const Color(0xE60F172A), // Dark slate
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFF334155), width: 1.2),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha:0.4),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                )
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: (state != null && state.isConverged)
                            ? const Color(0xFF10B981) // Emerald Green
                            : const Color(0xFFF59E0B), // Amber
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: ((state != null && state.isConverged)
                                    ? const Color(0xFF10B981)
                                    : const Color(0xFFF59E0B))
                                .withValues(alpha:0.7),
                            blurRadius: 6,
                          )
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    const Text(
                      'UWB DW3000 ENGINE (C++20)',
                      style: TextStyle(
                        color: Color(0xFFF8FAFC),
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.8,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  state != null
                      ? 'POS: (${state.x.toStringAsFixed(2)}, ${state.y.toStringAsFixed(2)}) m'
                      : 'WAITING FOR UWB STREAM...',
                  style: const TextStyle(
                    color: Color(0xFF94A3B8),
                    fontFamily: 'monospace',
                    fontSize: 11,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  state != null
                      ? 'VEL: ${(math.sqrt(state.vx * state.vx + state.vy * state.vy)).toStringAsFixed(2)} m/s'
                      : 'VEL: 0.00 m/s',
                  style: const TextStyle(
                    color: Color(0xFF94A3B8),
                    fontFamily: 'monospace',
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
        ),

        // Top-Right: High-Performance Latency Target Badge (< 10ms)
        Positioned(
          top: 14,
          right: 14,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0xE60F172A),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: (state != null && state.latencyMs < 10.0)
                    ? const Color(0xFF10B981)
                    : const Color(0xFFEF4444),
                width: 1.2,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.speed_rounded,
                  size: 16,
                  color: Color(0xFF38BDF8),
                ),
                const SizedBox(width: 6),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    const Text(
                      'EKF LATENCY',
                      style: TextStyle(
                        color: Color(0xFF64748B),
                        fontSize: 9,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      state != null
                          ? '${state.latencyMs.toStringAsFixed(3)} ms'
                          : '< 0.05 ms',
                      style: const TextStyle(
                        color: Color(0xFF38BDF8),
                        fontWeight: FontWeight.w800,
                        fontSize: 13,
                        fontFamily: 'monospace',
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),

        // Bottom-Right: Altitude (Z) Readout Badge
        if (state != null)
          Positioned(
            bottom: 16,
            right: 16,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF1E293B), Color(0xFF0F172A)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFF38BDF8), width: 1.5),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF38BDF8).withValues(alpha:0.3),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  )
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: const Color(0xFF38BDF8).withValues(alpha:0.15),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.flight_takeoff_rounded,
                      color: Color(0xFF38BDF8),
                      size: 18,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text(
                        'ALTITUDE (Z)',
                        style: TextStyle(
                          color: Color(0xFF94A3B8),
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.5,
                        ),
                      ),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.baseline,
                        textBaseline: TextBaseline.alphabetic,
                        children: [
                          Text(
                            state.z.toStringAsFixed(2),
                            style: const TextStyle(
                              color: Color(0xFFF8FAFC),
                              fontSize: 22,
                              fontWeight: FontWeight.w900,
                              fontFamily: 'monospace',
                            ),
                          ),
                          const SizedBox(width: 4),
                          const Text(
                            'm',
                            style: TextStyle(
                              color: Color(0xFF38BDF8),
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

/// 2D CustomPainter rendering grid, anchors, trail, and drone marker.
class Uwb2DPainter extends CustomPainter {
  final DroneStateModel? droneState;
  final List<AnchorModel> anchors;
  final List<Offset> trail;
  final double arenaWidthMeters;
  final double arenaHeightMeters;

  Uwb2DPainter({
    required this.droneState,
    required this.anchors,
    required this.trail,
    required this.arenaWidthMeters,
    required this.arenaHeightMeters,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final padding = 40.0;
    final drawWidth = size.width - (padding * 2);
    final drawHeight = size.height - (padding * 2);

    final scaleX = drawWidth / arenaWidthMeters;
    final scaleY = drawHeight / arenaHeightMeters;
    final scale = math.min(scaleX, scaleY);

    final originX = padding + (drawWidth - (arenaWidthMeters * scale)) / 2;
    final originY = padding + (drawHeight - (arenaHeightMeters * scale)) / 2;

    // Helper: Meter (X, Y) to Canvas Pixel (Px, Py)
    Offset toCanvas(double x, double y) {
      return Offset(
        originX + (x * scale),
        originY + ((arenaHeightMeters - y) * scale), // Invert Y for standard Cartesian
      );
    }

    // 1. Draw Canvas Background
    final bgPaint = Paint()..color = const Color(0xFF090D16);
    canvas.drawRect(Offset.zero & size, bgPaint);

    // 2. Draw Arena Boundary
    final arenaRect = Rect.fromPoints(
      toCanvas(0, arenaHeightMeters),
      toCanvas(arenaWidthMeters, 0),
    );
    final arenaBgPaint = Paint()..color = const Color(0xFF0F172A);
    canvas.drawRect(arenaRect, arenaBgPaint);

    // 3. Draw Grid Lines (1-meter major, 0.5-meter minor)
    final minorGridPaint = Paint()
      ..color = const Color(0xFF1E293B)
      ..strokeWidth = 0.8;
    final majorGridPaint = Paint()
      ..color = const Color(0xFF334155)
      ..strokeWidth = 1.2;

    // Vertical grid lines
    for (double x = 0; x <= arenaWidthMeters; x += 0.5) {
      final isMajor = (x - x.round()).abs() < 1e-4;
      final p1 = toCanvas(x, 0);
      final p2 = toCanvas(x, arenaHeightMeters);
      canvas.drawLine(p1, p2, isMajor ? majorGridPaint : minorGridPaint);

      if (isMajor) {
        _drawText(canvas, '${x.toInt()}m', Offset(p1.dx, p1.dy + 6),
            const TextStyle(color: Color(0xFF64748B), fontSize: 10));
      }
    }

    // Horizontal grid lines
    for (double y = 0; y <= arenaHeightMeters; y += 0.5) {
      final isMajor = (y - y.round()).abs() < 1e-4;
      final p1 = toCanvas(0, y);
      final p2 = toCanvas(arenaWidthMeters, y);
      canvas.drawLine(p1, p2, isMajor ? majorGridPaint : minorGridPaint);

      if (isMajor) {
        _drawText(canvas, '${y.toInt()}m', Offset(p1.dx - 24, p1.dy - 6),
            const TextStyle(color: Color(0xFF64748B), fontSize: 10));
      }
    }

    // Arena border frame
    final borderPaint = Paint()
      ..color = const Color(0xFF475569)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;
    canvas.drawRect(arenaRect, borderPaint);

    // 4. Draw Physical Anchors
    for (final anchor in anchors) {
      final anchorPos = toCanvas(anchor.x, anchor.y);

      // Coverage circle
      final coveragePaint = Paint()
        ..color = const Color(0xFF38BDF8).withValues(alpha:0.08)
        ..style = PaintingStyle.fill;
      canvas.drawCircle(anchorPos, 32, coveragePaint);

      // Anchor diamond marker
      final markerPaint = Paint()
        ..color = const Color(0xFF38BDF8)
        ..style = PaintingStyle.fill;
      final diamondPath = Path()
        ..moveTo(anchorPos.dx, anchorPos.dy - 9)
        ..lineTo(anchorPos.dx + 9, anchorPos.dy)
        ..lineTo(anchorPos.dx, anchorPos.dy + 9)
        ..lineTo(anchorPos.dx - 9, anchorPos.dy)
        ..close();
      canvas.drawPath(diamondPath, markerPaint);

      // Anchor Label
      _drawText(canvas, 'A${anchor.id}', Offset(anchorPos.dx + 12, anchorPos.dy - 6),
          const TextStyle(color: Color(0xFF38BDF8), fontWeight: FontWeight.bold, fontSize: 11));
    }

    // 5. Draw Motion Trail
    if (trail.length > 1) {
      for (int i = 0; i < trail.length - 1; ++i) {
        final p1 = toCanvas(trail[i].dx, trail[i].dy);
        final p2 = toCanvas(trail[i + 1].dx, trail[i + 1].dy);
        final opacity = ((i + 1) / trail.length).clamp(0.1, 0.85);

        final trailPaint = Paint()
          ..color = const Color(0xFF10B981).withValues(alpha:opacity)
          ..strokeWidth = 2.5
          ..strokeCap = StrokeCap.round;
        canvas.drawLine(p1, p2, trailPaint);
      }
    }

    // 6. Draw Drone Marker
    if (droneState != null) {
      final dronePos = toCanvas(droneState!.x, droneState!.y);

      // Outer glow pulse
      final glowPaint = Paint()
        ..color = const Color(0xFF10B981).withValues(alpha:0.25)
        ..style = PaintingStyle.fill;
      canvas.drawCircle(dronePos, 22, glowPaint);

      // Outer ring
      final ringPaint = Paint()
        ..color = const Color(0xFF10B981)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.0;
      canvas.drawCircle(dronePos, 14, ringPaint);

      // Drone center core
      final corePaint = Paint()
        ..color = const Color(0xFFF8FAFC)
        ..style = PaintingStyle.fill;
      canvas.drawCircle(dronePos, 6, corePaint);

      // Heading / Velocity Arrow
      final speed = math.sqrt(droneState!.vx * droneState!.vx + droneState!.vy * droneState!.vy);
      if (speed > 0.05) {
        final angle = math.atan2(-droneState!.vy, droneState!.vx); // inverted Y
        final arrowLen = (speed * 25.0).clamp(18.0, 50.0);
        final arrowEnd = Offset(
          dronePos.dx + arrowLen * math.cos(angle),
          dronePos.dy + arrowLen * math.sin(angle),
        );

        final arrowPaint = Paint()
          ..color = const Color(0xFFF59E0B)
          ..strokeWidth = 2.5
          ..strokeCap = StrokeCap.round;
        canvas.drawLine(dronePos, arrowEnd, arrowPaint);

        // Arrow head
        final headAngle1 = angle + math.pi * 0.85;
        final headAngle2 = angle - math.pi * 0.85;
        final head1 = Offset(arrowEnd.dx + 8 * math.cos(headAngle1), arrowEnd.dy + 8 * math.sin(headAngle1));
        final head2 = Offset(arrowEnd.dx + 8 * math.cos(headAngle2), arrowEnd.dy + 8 * math.sin(headAngle2));
        canvas.drawLine(arrowEnd, head1, arrowPaint);
        canvas.drawLine(arrowEnd, head2, arrowPaint);
      }
    }
  }

  void _drawText(Canvas canvas, String text, Offset offset, TextStyle style) {
    final textPainter = TextPainter(
      text: TextSpan(text: text, style: style),
      textDirection: TextDirection.ltr,
    )..layout();
    textPainter.paint(canvas, offset);
  }

  @override
  bool shouldRepaint(covariant Uwb2DPainter oldDelegate) => true;
}
