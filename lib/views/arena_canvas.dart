import 'dart:math' as math;
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../controllers/simulation_controller.dart';
import '../controllers/ui_controller.dart';
import '../models/arena_map.dart';
import '../models/drone_model.dart';
import '../models/grid_map_2d.dart';
import '../models/vector2.dart';

class ArenaCanvas extends StatefulWidget {
  const ArenaCanvas({super.key});

  @override
  State<ArenaCanvas> createState() => _ArenaCanvasState();
}

class _ArenaCanvasState extends State<ArenaCanvas> {
  // Zoom & Pan gesture states
  double _startZoom = 1.0;
  Offset _startPan = Offset.zero;
  double _panZoomStartScale = 1.0;
  Offset _panZoomStartPan = Offset.zero;

  // Interactive Gizmo manipulation state
  bool _isDraggingGizmo = false;
  GizmoAxis _activeDragAxis = GizmoAxis.none;
  int _dragDroneIndex = -1; // -1 for target, 0..2 for drones
  Offset _pointerDownScreen = Offset.zero;
  Offset _lastPointerScreen = Offset.zero;
  bool _didDragGizmo = false;
  bool _didPanCanvas = false;

  static const double worldCenterX = 0.0;
  static const double worldCenterY = 3.0;
  static const double worldSpanX = 32.0;
  static const double worldSpanY = 18.0;

  Offset _worldToScreen(Vector2 w, Size size, Offset pan, double zoom) {
    final baseScale = math.min(size.width / worldSpanX, size.height / worldSpanY) * zoom;
    final originScreen = Offset(size.width / 2.0 + pan.dx, size.height / 2.0 + pan.dy);
    final dx = (w.x - worldCenterX) * baseScale;
    final dy = -(w.y - worldCenterY) * baseScale;
    return Offset(originScreen.dx + dx, originScreen.dy + dy);
  }

  @override
  Widget build(BuildContext context) {
    final sim = Get.find<SimulationController>();
    final ui = Get.find<UIController>();

    return LayoutBuilder(
      builder: (context, constraints) {
        final viewportSize = Size(constraints.maxWidth, constraints.maxHeight);

        return Stack(
          children: [
            // 1. Gesture Area & Custom Canvas
            Listener(
              behavior: HitTestBehavior.opaque,
              // Mouse Scroll Wheel or Trackpad 2-finger scroll
              onPointerSignal: (pointerSignal) {
                if (pointerSignal is PointerScrollEvent) {
                  final dy = pointerSignal.scrollDelta.dy;
                  if (dy.abs() > 0.01) {
                    // Smooth, natural exponential zoom responding directly to trackpad / wheel scroll delta
                    final factor = math.exp(-dy * 0.0018).clamp(0.85, 1.18);
                    ui.zoomBy(
                      factor,
                      focalPoint: pointerSignal.localPosition,
                      viewportSize: viewportSize,
                    );
                  }
                }
              },
              // macOS Trackpad Native Pan & Zoom Events
              onPointerPanZoomStart: (event) {
                _panZoomStartScale = ui.zoom.value;
                _panZoomStartPan = ui.panOffset.value;
              },
              onPointerPanZoomUpdate: (event) {
                if (_isDraggingGizmo) return; // Prioritize gizmo dragging

                if (event.scale != 1.0 && event.scale > 0) {
                  final newZoom = (_panZoomStartScale * event.scale)
                      .clamp(UIController.minZoom, UIController.maxZoom);
                  final center = Offset(viewportSize.width / 2.0, viewportSize.height / 2.0);
                  final pMinusCenter = event.localPosition - center;
                  final newPan = pMinusCenter -
                      (pMinusCenter - _panZoomStartPan) * (newZoom / _panZoomStartScale) +
                      event.pan;
                  ui.zoom.value = newZoom;
                  ui.panOffset.value = newPan;
                  ui.followingDroneIndex.value = -1;
                } else if (event.panDelta != Offset.zero) {
                  ui.panOffset.value += event.panDelta;
                  ui.followingDroneIndex.value = -1;
                }
              },
              onPointerDown: (event) {
                _pointerDownScreen = event.localPosition;
                _lastPointerScreen = event.localPosition;
                _didDragGizmo = false;
                _didPanCanvas = false;
                _dragDroneIndex = -2; // -2 = empty background

                if (sim.isRunning || sim.isRealDroneMode) return;

                final currentZoom = ui.zoom.value;
                final currentPan = ui.panOffset.value;
                const gizmoLen = 55.0;

                // Priority 1: Check Target Gizmo handles if target gizmo is active
                if (ui.gizmoMode.value == GizmoMode.target) {
                  final targetScreen = _worldToScreen(sim.targetPosition.value, viewportSize, currentPan, currentZoom);
                  final hitAxis = _testGizmoHit(event.localPosition, targetScreen, gizmoLen);

                  if (hitAxis != GizmoAxis.none) {
                    _isDraggingGizmo = true;
                    _activeDragAxis = hitAxis;
                    _dragDroneIndex = -1;
                    _didDragGizmo = true;
                    ui.activeGizmoAxis.value = hitAxis;
                    ui.isDraggingGizmo.value = true;
                    return;
                  }
                }

                // Priority 2: Check Drone Gizmo handles if drone gizmos are active
                if (ui.gizmoMode.value == GizmoMode.drones) {
                  final activeIdx = ui.activeGizmoDroneIndex.value;
                  for (int i = 0; i < sim.activeDrones.length; i++) {
                    if (activeIdx == -1 || activeIdx == i) {
                      final droneScreen = _worldToScreen(sim.activeDrones[i].position, viewportSize, currentPan, currentZoom);
                      final hitAxis = _testGizmoHit(event.localPosition, droneScreen, gizmoLen);

                      if (hitAxis != GizmoAxis.none) {
                        _isDraggingGizmo = true;
                        _activeDragAxis = hitAxis;
                        _dragDroneIndex = i;
                        _didDragGizmo = true;
                        ui.activeGizmoAxis.value = hitAxis;
                        ui.activeGizmoDroneIndex.value = i;
                        ui.isDraggingGizmo.value = true;
                        return;
                      }
                    }
                  }
                }

                // Priority 3: Direct-click on ANY Drone (immediately activates gizmo & starts dragging in XY!)
                for (int i = 0; i < sim.activeDrones.length; i++) {
                  final dScreen = _worldToScreen(sim.activeDrones[i].position, viewportSize, currentPan, currentZoom);
                  if ((event.localPosition - dScreen).distance <= 28.0) {
                    ui.activateDroneGizmos(i);
                    _isDraggingGizmo = true;
                    _activeDragAxis = GizmoAxis.xy;
                    _dragDroneIndex = i;
                    _didDragGizmo = true;
                    ui.activeGizmoAxis.value = GizmoAxis.xy;
                    ui.activeGizmoDroneIndex.value = i;
                    ui.isDraggingGizmo.value = true;
                    return;
                  }
                }

                // Priority 4: Direct-click on Target (immediately activates gizmo & starts dragging in XY!)
                final targetScreen = _worldToScreen(sim.targetPosition.value, viewportSize, currentPan, currentZoom);
                if ((event.localPosition - targetScreen).distance <= 28.0) {
                  ui.activateTargetGizmo();
                  _isDraggingGizmo = true;
                  _activeDragAxis = GizmoAxis.xy;
                  _dragDroneIndex = -1;
                  _didDragGizmo = true;
                  ui.activeGizmoAxis.value = GizmoAxis.xy;
                  ui.isDraggingGizmo.value = true;
                  return;
                }
              },
              onPointerMove: (event) {
                if (_isDraggingGizmo) {
                  _didDragGizmo = true;
                  final deltaScreen = event.localPosition - _lastPointerScreen;
                  final baseScale = math.min(viewportSize.width / worldSpanX, viewportSize.height / worldSpanY) * ui.zoom.value;

                  final dxWorld = deltaScreen.dx / baseScale;
                  final dyWorld = -deltaScreen.dy / baseScale; // Inverted Y in world coordinates

                  final Vector2 delta;
                  switch (_activeDragAxis) {
                    case GizmoAxis.x:
                      delta = Vector2(dxWorld, 0.0);
                      break;
                    case GizmoAxis.y:
                      delta = Vector2(0.0, dyWorld);
                      break;
                    case GizmoAxis.xy:
                      delta = Vector2(dxWorld, dyWorld);
                      break;
                    case GizmoAxis.none:
                      delta = Vector2.zero;
                      break;
                  }

                  if (delta != Vector2.zero) {
                    if (_dragDroneIndex == -1) {
                      sim.moveTargetSafely(sim.targetPosition.value + delta);
                    } else if (_dragDroneIndex >= 0 && _dragDroneIndex < sim.activeDrones.length) {
                      sim.moveDroneSafely(_dragDroneIndex, sim.activeDrones[_dragDroneIndex].position + delta);
                    }
                  }

                  _lastPointerScreen = event.localPosition;
                } else {
                  if ((event.localPosition - _pointerDownScreen).distanceSquared > 16.0) {
                    _didPanCanvas = true;
                  }
                }
              },
              onPointerUp: (event) {
                if (_isDraggingGizmo) {
                  _isDraggingGizmo = false;
                  _activeDragAxis = GizmoAxis.none;
                  ui.isDraggingGizmo.value = false;
                  ui.activeGizmoAxis.value = GizmoAxis.none;
                  // Gizmo remains visible on selected drone/target for further X/Y axis adjustment
                } else if (!_didPanCanvas && !_didDragGizmo && _dragDroneIndex == -2) {
                  // User clicked on empty middle area of screen: DISMISS & LOCK POSITIONS!
                  if (ui.gizmoMode.value != GizmoMode.none) {
                    ui.lockAndDismissGizmos();
                  }
                }
              },
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onScaleStart: (details) {
                  if (_isDraggingGizmo) return;
                  _startZoom = ui.zoom.value;
                  _startPan = ui.panOffset.value;
                },
                onScaleUpdate: (details) {
                  if (_isDraggingGizmo) return; // Prevent canvas pan while dragging gizmo handle

                  if (details.scale != 1.0) {
                    // Pinch to zoom on trackpad or touchscreen
                    final newZoom = (_startZoom * details.scale)
                        .clamp(UIController.minZoom, UIController.maxZoom);
                    final center = Offset(viewportSize.width / 2.0, viewportSize.height / 2.0);
                    final pMinusCenter = details.localFocalPoint - center;
                    final newPan = pMinusCenter -
                        (pMinusCenter - _startPan) * (newZoom / _startZoom);
                    ui.zoom.value = newZoom;
                    ui.panOffset.value = newPan;
                    ui.followingDroneIndex.value = -1;
                  } else {
                    // Click & drag pan with mouse
                    ui.panOffset.value += details.focalPointDelta;
                    if (details.focalPointDelta.distanceSquared > 1.0) {
                      ui.followingDroneIndex.value = -1;
                    }
                  }
                },
                onDoubleTapDown: (details) {
                  if (_isDraggingGizmo) return;
                  ui.zoomBy(
                    1.75,
                    focalPoint: details.localPosition,
                    viewportSize: viewportSize,
                  );
                },
                child: Obx(() {
                  // Read all observables to guarantee instant repainting on any change!
                  final targetPos = sim.targetPosition.value;
                  sim.simState.value;
                  final currentGizmoMode = ui.gizmoMode.value;
                  final currentActiveAxis = ui.activeGizmoAxis.value;
                  final currentActiveDrone = ui.activeGizmoDroneIndex.value;
                  final followIdx = ui.followingDroneIndex.value;

                  // Force read drone positions so dragging triggers continuous redraw
                  for (final d in sim.activeDrones) {
                    d.position;
                  }

                  // Auto follow drone camera tracking
                  if (followIdx >= 0 && followIdx < sim.activeDrones.length) {
                    final targetDrone = sim.activeDrones[followIdx];
                    ui.centerOnWorld(targetDrone.position, viewportSize);
                  }

                  return CustomPaint(
                    size: viewportSize,
                    painter: ArenaPainter(
                      sim: sim,
                      ui: ui,
                      elapsedTime: sim.elapsedTime.value,
                      pan: ui.panOffset.value,
                      zoomLevel: ui.zoom.value,
                      sensorsVisible: ui.showSensors.value,
                      gridVisible: ui.showGrid.value,
                      pathsVisible: ui.showPaths.value,
                      missionPathVisible: ui.showMissionPath.value,
                      labelsVisible: ui.showDroneLabels.value,
                      targetPos: targetPos,
                      gizmoMode: currentGizmoMode,
                      activeGizmoAxis: currentActiveAxis,
                      activeGizmoDroneIndex: currentActiveDrone,
                    ),
                  );
                }),
              ),
            ),

            // 2. Floating Zoom & Camera HUD (Top-Right)
            Positioned(
              top: 10,
              right: 10,
              child: _FloatingZoomHUD(viewportSize: viewportSize),
            ),

            // 3. Floating Bottom Instruction Helper & Position Lock Indicator
            Positioned(
              bottom: 10,
              left: 12,
              right: 12,
              child: Obx(() {
                final mode = ui.gizmoMode.value;
                final isGizmoActive = mode != GizmoMode.none;

                if (isGizmoActive) {
                  return Center(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: const Color(0xEE0F172A),
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(color: Colors.amberAccent, width: 1.5),
                        boxShadow: const [
                          BoxShadow(color: Colors.black87, blurRadius: 12, offset: Offset(0, 3)),
                        ],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.open_with, color: Colors.amberAccent, size: 16),
                          const SizedBox(width: 8),
                          Flexible(
                            child: Text(
                              mode == GizmoMode.target
                                  ? '🎯 Geser Sumbu X (Merah), Y (Hijau), atau Tengah (Bebas) • Klik area kosong layar untuk Kunci Posisi'
                                  : '🚁 Geser Sumbu X (Merah), Y (Hijau), atau Tengah (Bebas) • Klik area kosong layar untuk Kunci Posisi',
                              style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 8),
                          ElevatedButton.icon(
                            onPressed: () => ui.lockAndDismissGizmos(),
                            icon: const Icon(Icons.lock, size: 13, color: Colors.black),
                            label: const Text('Kunci Posisi', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.amberAccent,
                              foregroundColor: Colors.black,
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              minimumSize: const Size(60, 26),
                              visualDensity: VisualDensity.compact,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }

                // Default info pill when gizmo is idle
                final curZoom = (ui.zoom.value * 100).toInt();
                final isReal = sim.isRealDroneMode;
                return Align(
                  alignment: Alignment.bottomLeft,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xCC0F172A),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: isReal ? const Color(0xFF06B6D4) : Colors.white24,
                        width: 1,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          isReal ? Icons.radar : Icons.mouse_outlined,
                          size: 13,
                          color: Colors.cyanAccent,
                        ),
                        const SizedBox(width: 5),
                        Flexible(
                          child: Text(
                            isReal
                                ? '🛸 Real Drone Mode • Memetakan ruangan fisik dengan 5 LiDAR • Zoom: $curZoom%'
                                : 'Zoom: $curZoom% • Putar wheel mouse / pinch trackpad untuk zoom • Geser untuk pan',
                            style: const TextStyle(color: Colors.white70, fontSize: 10),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }),
            ),
          ],
        );
      },
    );
  }

  GizmoAxis _testGizmoHit(Offset pointer, Offset center, double len) {
    // 1. Center Handle (Dual-axis free drag)
    if ((pointer - center).distanceSquared <= 18.0 * 18.0) {
      return GizmoAxis.xy;
    }

    // 2. X Axis (Horizontal red arrow to the right)
    final dx = pointer.dx - center.dx;
    final dy = pointer.dy - center.dy;
    if (dx >= -4.0 && dx <= len + 16.0 && dy.abs() <= 15.0) {
      return GizmoAxis.x;
    }

    // 3. Y Axis (Vertical green arrow upwards)
    // On screen, upwards is negative dy
    if (dy <= 4.0 && dy >= -len - 16.0 && dx.abs() <= 15.0) {
      return GizmoAxis.y;
    }

    return GizmoAxis.none;
  }
}

/// Floating Zoom Controls and Drone Follow Switcher
class _FloatingZoomHUD extends StatelessWidget {
  final Size viewportSize;

  const _FloatingZoomHUD({required this.viewportSize});

  @override
  Widget build(BuildContext context) {
    final sim = Get.find<SimulationController>();
    final ui = Get.find<UIController>();

    return Container(
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: const Color(0xDD1E293B),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFF38BDF8).withValues(alpha: 0.4), width: 1.2),
        boxShadow: const [
          BoxShadow(color: Colors.black45, blurRadius: 8, offset: Offset(0, 3)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          // Row 1: Zoom In, Zoom Out, Reset, and Zoom Badge
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Zoom Out Button
              IconButton(
                onPressed: () => ui.zoomOut(viewportSize: viewportSize),
                icon: const Icon(Icons.remove, size: 16, color: Colors.white),
                tooltip: 'Zoom Out (Scroll Down / Pinch In)',
                style: IconButton.styleFrom(
                  backgroundColor: const Color(0xFF0F172A),
                  padding: const EdgeInsets.all(6),
                  visualDensity: VisualDensity.compact,
                ),
              ),
              const SizedBox(width: 4),

              // Zoom Percent Pill (Click to Reset)
              Obx(() {
                final percent = (ui.zoom.value * 100).toInt();
                return InkWell(
                  onTap: () => ui.resetCamera(),
                  borderRadius: BorderRadius.circular(6),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0F172A),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: Colors.cyanAccent.withValues(alpha: 0.5)),
                    ),
                    child: Text(
                      '$percent%',
                      style: const TextStyle(
                        color: Colors.cyanAccent,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                );
              }),
              const SizedBox(width: 4),

              // Zoom In Button
              IconButton(
                onPressed: () => ui.zoomIn(viewportSize: viewportSize),
                icon: const Icon(Icons.add, size: 16, color: Colors.white),
                tooltip: 'Zoom In (Scroll Up / Pinch Out)',
                style: IconButton.styleFrom(
                  backgroundColor: const Color(0xFF0F172A),
                  padding: const EdgeInsets.all(6),
                  visualDensity: VisualDensity.compact,
                ),
              ),
              const SizedBox(width: 4),

              // Reset Camera View Button
              IconButton(
                onPressed: () => ui.resetCamera(),
                icon: const Icon(Icons.center_focus_strong, size: 16, color: Colors.amberAccent),
                tooltip: 'Fit All / Reset Camera',
                style: IconButton.styleFrom(
                  backgroundColor: const Color(0xFF0F172A),
                  padding: const EdgeInsets.all(6),
                  visualDensity: VisualDensity.compact,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),

          // Row 2: Camera Focus on Drone Buttons
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Focus: ', style: TextStyle(color: Colors.white54, fontSize: 10)),
              _buildFollowButton(ui, -1, 'All', null),
              const SizedBox(width: 3),
              ...sim.activeDrones.asMap().entries.map((entry) {
                final idx = entry.key;
                final drone = entry.value;
                return Padding(
                  padding: const EdgeInsets.only(left: 3),
                  child: _buildFollowButton(ui, idx, 'D${idx + 1}', drone),
                );
              }),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFollowButton(UIController ui, int index, String label, DroneModel? drone) {
    return Obx(() {
      final isSelected = ui.followingDroneIndex.value == index;
      final Color activeColor = drone != null ? drone.ledColor : Colors.cyanAccent;

      return InkWell(
        onTap: () {
          if (index == -1) {
            ui.resetCamera();
          } else if (drone != null) {
            ui.toggleFollowDrone(index, viewportSize, drone.position);
          }
        },
        borderRadius: BorderRadius.circular(4),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
          decoration: BoxDecoration(
            color: isSelected ? activeColor.withValues(alpha: 0.3) : const Color(0xFF0F172A),
            borderRadius: BorderRadius.circular(4),
            border: Border.all(
              color: isSelected ? activeColor : Colors.white24,
              width: 1,
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              color: isSelected ? activeColor : Colors.white70,
              fontSize: 9.5,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      );
    });
  }
}

class ArenaPainter extends CustomPainter {
  final SimulationController sim;
  final UIController ui;
  final double elapsedTime;
  final Offset pan;
  final double zoomLevel;
  final bool sensorsVisible;
  final bool gridVisible;
  final bool pathsVisible;
  final bool missionPathVisible;
  final bool labelsVisible;
  final Vector2 targetPos;
  final GizmoMode gizmoMode;
  final GizmoAxis activeGizmoAxis;
  final int activeGizmoDroneIndex;

  ArenaPainter({
    required this.sim,
    required this.ui,
    required this.elapsedTime,
    required this.pan,
    required this.zoomLevel,
    required this.sensorsVisible,
    required this.gridVisible,
    required this.pathsVisible,
    required this.missionPathVisible,
    required this.labelsVisible,
    required this.targetPos,
    required this.gizmoMode,
    required this.activeGizmoAxis,
    required this.activeGizmoDroneIndex,
  });

  static const double worldCenterX = 0.0;
  static const double worldCenterY = 3.0;
  static const double worldSpanX = 32.0;
  static const double worldSpanY = 18.0;

  @override
  void paint(Canvas canvas, Size size) {
    final baseScale = math.min(size.width / worldSpanX, size.height / worldSpanY) * zoomLevel;

    final originScreen = Offset(
      size.width / 2.0 + pan.dx,
      size.height / 2.0 + pan.dy,
    );

    Offset worldToScreen(Vector2 w) {
      final dx = (w.x - worldCenterX) * baseScale;
      final dy = -(w.y - worldCenterY) * baseScale;
      return Offset(originScreen.dx + dx, originScreen.dy + dy);
    }

    double toScreenDist(double d) => d * baseScale;

    // 1. Draw Floor & Coordinate Grid
    _drawFloor(canvas, size, worldToScreen, baseScale);

    // 2. Draw Occupancy Grid Map
    if (gridVisible) {
      _drawOccupancyGrid(canvas, worldToScreen, baseScale);
    }

    // 3. Draw Target Spawn Area bounds (Simulation mode only)
    if (!sim.isRealDroneMode && ui.showTargetArea.value) {
      _drawTargetArea(canvas, worldToScreen);
    }

    // 4. Draw Walls (Simulation mode only - Real mode discovers walls dynamically via LiDAR)
    if (!sim.isRealDroneMode) {
      _drawWalls(canvas, worldToScreen, toScreenDist);
    }

    // 5. Draw HomeBase or Real Drone Start Point (0,0)
    if (sim.isRealDroneMode) {
      _drawRealDroneOrigin(canvas, worldToScreen, toSDist: toScreenDist);
    } else {
      _drawHomeBase(canvas, worldToScreen, toScreenDist);
    }

    // 6. Draw Target (Simulation mode only)
    if (!sim.isRealDroneMode) {
      _drawTarget(canvas, targetPos, worldToScreen, toScreenDist);
    }

    // 7. Draw Mission Paths (Breadcrumbs / Exploration History)
    if (missionPathVisible) {
      _drawMissionPaths(canvas, worldToScreen);
    }

    // 8. Draw Drones (Detailed Hardware Components, 4-Pole LEDs, Frames, Sensors)
    for (int i = 0; i < sim.activeDrones.length; i++) {
      final drone = sim.activeDrones[i];
      _drawDrone(canvas, drone, worldToScreen, toScreenDist);

      // Draw Drone Gizmo if active (Simulation mode only)
      if (!sim.isRealDroneMode && gizmoMode == GizmoMode.drones) {
        final dScreen = worldToScreen(drone.position);
        final isSelected = activeGizmoDroneIndex == i;
        final currentAxis = isSelected ? activeGizmoAxis : GizmoAxis.none;
        if (activeGizmoDroneIndex == -1 || activeGizmoDroneIndex == i) {
          _drawTransformGizmo(
            canvas,
            drone.position,
            dScreen,
            currentAxis,
            drone.name,
            drone.ledColor,
          );
        }
      }
    }

    // 9. Draw Target Gizmo if active (Simulation mode only)
    if (!sim.isRealDroneMode && gizmoMode == GizmoMode.target) {
      final tScreen = worldToScreen(targetPos);
      _drawTransformGizmo(
        canvas,
        targetPos,
        tScreen,
        activeGizmoAxis,
        'TARGET',
        Colors.amberAccent,
      );
    }

    // 10. Real Drone SLAM Mapping Watermark Overlay
    if (sim.isRealDroneMode) {
      _drawRealDroneWatermark(canvas, size);
    }
  }

  /// CorelDraw / CAD-style Transform Gizmo (Sumbu X & Y)
  void _drawTransformGizmo(
    Canvas canvas,
    Vector2 worldPos,
    Offset center,
    GizmoAxis activeAxis,
    String label,
    Color themeColor,
  ) {
    const len = 55.0;
    const arrowW = 10.0;
    const arrowH = 12.0;

    final isXActive = activeAxis == GizmoAxis.x || activeAxis == GizmoAxis.xy;
    final isYActive = activeAxis == GizmoAxis.y || activeAxis == GizmoAxis.xy;
    final isCenterActive = activeAxis == GizmoAxis.xy;

    // --- Sumbu X (Red Arrow pointing Right) ---
    final xColor = isXActive ? Colors.yellowAccent : const Color(0xFFEF4444);
    final xPaint = Paint()
      ..color = xColor
      ..strokeWidth = isXActive ? 4.5 : 3.2
      ..strokeCap = StrokeCap.round;

    final xEnd = center + const Offset(len, 0);
    canvas.drawLine(center, xEnd, xPaint);

    // X Arrowhead
    final xArrowPath = Path()
      ..moveTo(xEnd.dx + arrowH, xEnd.dy)
      ..lineTo(xEnd.dx, xEnd.dy - arrowW / 2)
      ..lineTo(xEnd.dx, xEnd.dy + arrowW / 2)
      ..close();
    canvas.drawPath(xArrowPath, Paint()..color = xColor);

    // X Label Tag
    final xLabelPainter = TextPainter(
      text: const TextSpan(
        text: 'X',
        style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
      ),
      textDirection: TextDirection.ltr,
    )..layout();

    final xTagRect = Rect.fromCenter(center: xEnd + const Offset(18, 0), width: 14, height: 14);
    canvas.drawRRect(RRect.fromRectAndRadius(xTagRect, const Radius.circular(3)), Paint()..color = xColor);
    xLabelPainter.paint(canvas, xEnd + Offset(18 - xLabelPainter.width / 2, -xLabelPainter.height / 2));

    // --- Sumbu Y (Green Arrow pointing Up) ---
    final yColor = isYActive ? Colors.yellowAccent : const Color(0xFF22C55E);
    final yPaint = Paint()
      ..color = yColor
      ..strokeWidth = isYActive ? 4.5 : 3.2
      ..strokeCap = StrokeCap.round;

    final yEnd = center + const Offset(0, -len);
    canvas.drawLine(center, yEnd, yPaint);

    // Y Arrowhead
    final yArrowPath = Path()
      ..moveTo(yEnd.dx, yEnd.dy - arrowH)
      ..lineTo(yEnd.dx - arrowW / 2, yEnd.dy)
      ..lineTo(yEnd.dx + arrowW / 2, yEnd.dy)
      ..close();
    canvas.drawPath(yArrowPath, Paint()..color = yColor);

    // Y Label Tag
    final yLabelPainter = TextPainter(
      text: const TextSpan(
        text: 'Y',
        style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
      ),
      textDirection: TextDirection.ltr,
    )..layout();

    final yTagRect = Rect.fromCenter(center: yEnd + const Offset(0, -18), width: 14, height: 14);
    canvas.drawRRect(RRect.fromRectAndRadius(yTagRect, const Radius.circular(3)), Paint()..color = yColor);
    yLabelPainter.paint(canvas, yEnd + Offset(-yLabelPainter.width / 2, -18 - yLabelPainter.height / 2));

    // --- Center Handle (Dual-axis free drag) ---
    final centerColor = isCenterActive ? Colors.yellowAccent : themeColor;
    canvas.drawCircle(
      center,
      12.0,
      Paint()
        ..color = centerColor.withValues(alpha: 0.35)
        ..style = PaintingStyle.fill,
    );
    canvas.drawCircle(
      center,
      8.0,
      Paint()
        ..color = centerColor
        ..style = PaintingStyle.fill,
    );
    canvas.drawCircle(
      center,
      8.0,
      Paint()
        ..color = Colors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5,
    );

    // 4-Way Crosshair in Center
    final crossPaint = Paint()
      ..color = Colors.black
      ..strokeWidth = 1.5;
    canvas.drawLine(center + const Offset(-4, 0), center + const Offset(4, 0), crossPaint);
    canvas.drawLine(center + const Offset(0, -4), center + const Offset(0, 4), crossPaint);

    // Live Coordinates HUD Tag
    final coordText = '$label (X: ${worldPos.x.toStringAsFixed(2)}m, Y: ${worldPos.y.toStringAsFixed(2)}m)';
    final coordPainter = TextPainter(
      text: TextSpan(
        text: coordText,
        style: const TextStyle(color: Colors.white, fontSize: 9.5, fontWeight: FontWeight.bold),
      ),
      textDirection: TextDirection.ltr,
    )..layout();

    final coordRect = Rect.fromLTWH(
      center.dx + 12,
      center.dy + 12,
      coordPainter.width + 10,
      coordPainter.height + 6,
    );

    canvas.drawRRect(
      RRect.fromRectAndRadius(coordRect, const Radius.circular(4)),
      Paint()..color = const Color(0xDD0F172A),
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(coordRect, const Radius.circular(4)),
      Paint()
        ..color = themeColor.withValues(alpha: 0.8)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.0,
    );
    coordPainter.paint(canvas, Offset(coordRect.left + 5, coordRect.top + 3));
  }

  void _drawFloor(Canvas canvas, Size size, Offset Function(Vector2) w2s, double scale) {
    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.width, size.height),
      Paint()..color = const Color(0xFF0F172A),
    );

    final fineGridPaint = Paint()
      ..color = const Color(0xFF1E293B).withValues(alpha: 0.6)
      ..strokeWidth = 0.8;

    for (double x = -18.0; x <= 18.0; x += 0.5) {
      final p1 = w2s(Vector2(x, -8.0));
      final p2 = w2s(Vector2(x, 14.0));
      canvas.drawLine(p1, p2, fineGridPaint);
    }

    for (double y = -8.0; y <= 14.0; y += 0.5) {
      final p1 = w2s(Vector2(-18.0, y));
      final p2 = w2s(Vector2(18.0, y));
      canvas.drawLine(p1, p2, fineGridPaint);
    }

    final majorGridPaint = Paint()
      ..color = const Color(0xFF334155).withValues(alpha: 0.8)
      ..strokeWidth = 1.2;

    for (double x = -18.0; x <= 18.0; x += 2.0) {
      final p1 = w2s(Vector2(x, -8.0));
      final p2 = w2s(Vector2(x, 14.0));
      canvas.drawLine(p1, p2, majorGridPaint);
    }

    for (double y = -8.0; y <= 14.0; y += 2.0) {
      final p1 = w2s(Vector2(-18.0, y));
      final p2 = w2s(Vector2(18.0, y));
      canvas.drawLine(p1, p2, majorGridPaint);
    }
  }

  void _drawOccupancyGrid(Canvas canvas, Offset Function(Vector2) w2s, double scale) {
    final map = sim.map;
    final cellPixelSize = math.max(1.0, map.cellSize * scale);

    final freePaint = Paint()
      ..color = sim.isRealDroneMode
          ? const Color(0x1806B6D4)
          : const Color(0x2238BDF8)
      ..style = PaintingStyle.fill;

    final occupiedPaint = Paint()
      ..color = sim.isRealDroneMode
          ? const Color(0xFFEF4444)
          : const Color(0x66DC2626)
      ..style = PaintingStyle.fill;

    for (int y = 0; y < map.height; y += 1) {
      for (int x = 0; x < map.width; x += 1) {
        final val = map.rawGrid[y * map.width + x];
        if (val == GridMap2D.unknown) continue;

        final centerW = map.cellToWorldCenter(Vector2Int(x, y));
        final screenCenter = w2s(centerW);
        final rect = Rect.fromCenter(
          center: screenCenter,
          width: cellPixelSize,
          height: cellPixelSize,
        );

        if (val == GridMap2D.free) {
          canvas.drawRect(rect, freePaint);
        } else if (val == GridMap2D.occupied) {
          canvas.drawRect(rect, occupiedPaint);
        }
      }
    }
  }

  void _drawTargetArea(Canvas canvas, Offset Function(Vector2) w2s) {
    final bounds = ArenaMap.targetSpawnBounds;
    final pMin = w2s(bounds.min);
    final pMax = w2s(bounds.max);

    final rect = Rect.fromPoints(pMin, pMax);
    final borderPaint = Paint()
      ..color = Colors.amberAccent.withValues(alpha: 0.25)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;

    canvas.drawRect(rect, borderPaint);
  }

  void _drawWalls(
    Canvas canvas,
    Offset Function(Vector2) w2s,
    double Function(double) toSDist,
  ) {
    final wallFill = Paint()
      ..color = const Color(0xFF1E293B)
      ..style = PaintingStyle.fill;

    final wallBorder = Paint()
      ..color = const Color(0xFF64748B)
      ..style = PaintingStyle.stroke
      ..strokeWidth = math.max(1.0, toSDist(0.04));

    for (final wall in ArenaMap.walls) {
      final pMin = w2s(wall.min);
      final pMax = w2s(wall.max);
      final rect = Rect.fromPoints(pMin, pMax);

      canvas.drawRect(rect, wallFill);
      canvas.drawRect(rect, wallBorder);
    }
  }

  void _drawHomeBase(
    Canvas canvas,
    Offset Function(Vector2) w2s,
    double Function(double) toSDist,
  ) {
    final homePos = w2s(ArenaMap.defaultHomeBase);
    final radius = toSDist(1.5);

    canvas.drawCircle(
      homePos,
      radius,
      Paint()
        ..color = Colors.tealAccent.withValues(alpha: 0.15)
        ..style = PaintingStyle.fill,
    );

    canvas.drawCircle(
      homePos,
      radius,
      Paint()
        ..color = Colors.tealAccent.withValues(alpha: 0.8)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5,
    );

    final hPaint = Paint()
      ..color = Colors.tealAccent
      ..strokeWidth = 2.0;

    final hSize = radius * 0.45;
    canvas.drawLine(homePos + Offset(-hSize, -hSize), homePos + Offset(-hSize, hSize), hPaint);
    canvas.drawLine(homePos + Offset(hSize, -hSize), homePos + Offset(hSize, hSize), hPaint);
    canvas.drawLine(homePos + Offset(-hSize, 0), homePos + Offset(hSize, 0), hPaint);
  }

  void _drawRealDroneOrigin(
    Canvas canvas,
    Offset Function(Vector2) w2s, {
    required double Function(double) toSDist,
  }) {
    final originPos = w2s(Vector2(0, 0));
    final radius = math.max(14.0, toSDist(0.6));

    // Outer glow
    canvas.drawCircle(
      originPos,
      radius,
      Paint()
        ..color = Colors.cyanAccent.withValues(alpha: 0.12)
        ..style = PaintingStyle.fill,
    );

    // Border ring
    canvas.drawCircle(
      originPos,
      radius,
      Paint()
        ..color = Colors.cyanAccent.withValues(alpha: 0.7)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5,
    );

    // Crosshair
    final crossPaint = Paint()
      ..color = Colors.cyanAccent
      ..strokeWidth = 1.8;
    final chLen = radius * 0.6;
    canvas.drawLine(originPos + Offset(-chLen, 0), originPos + Offset(chLen, 0), crossPaint);
    canvas.drawLine(originPos + Offset(0, -chLen), originPos + Offset(0, chLen), crossPaint);

    // Label
    final tp = TextPainter(
      text: const TextSpan(
        text: 'START POINT (0, 0)',
        style: TextStyle(
          color: Colors.cyanAccent,
          fontSize: 9.5,
          fontWeight: FontWeight.bold,
          backgroundColor: Color(0xCC000000),
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();

    tp.paint(canvas, originPos + Offset(-tp.width / 2, radius + 4));
  }

  void _drawRealDroneWatermark(Canvas canvas, Size size) {
    const text = '🛸 REAL DRONE 5x LIDAR SLAM • HARDWARE BRIDGE';
    final tp = TextPainter(
      text: const TextSpan(
        text: text,
        style: TextStyle(
          color: Color(0x7738BDF8),
          fontSize: 11,
          fontWeight: FontWeight.bold,
          letterSpacing: 1.2,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();

    tp.paint(canvas, const Offset(16, 16));
  }

  void _drawTarget(
    Canvas canvas,
    Vector2 targetPosition,
    Offset Function(Vector2) w2s,
    double Function(double) toSDist,
  ) {
    final tPos = w2s(targetPosition);
    final r = math.max(8.0, toSDist(0.35));

    final waveRadius = (r * 1.5) + (elapsedTime % 1.5) * (r * 2.5);
    final waveAlpha = (1.0 - (elapsedTime % 1.5) / 1.5).clamp(0.0, 1.0) * 0.4;
    canvas.drawCircle(
      tPos,
      waveRadius,
      Paint()
        ..color = Colors.amberAccent.withValues(alpha: waveAlpha)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5,
    );

    final targetPath = Path()
      ..moveTo(tPos.dx, tPos.dy - r)
      ..lineTo(tPos.dx + r, tPos.dy)
      ..lineTo(tPos.dx, tPos.dy + r)
      ..lineTo(tPos.dx - r, tPos.dy)
      ..close();

    canvas.drawPath(
      targetPath,
      Paint()
        ..color = Colors.amberAccent
        ..style = PaintingStyle.fill,
    );

    canvas.drawCircle(tPos, r * 0.4, Paint()..color = Colors.black);
    canvas.drawCircle(tPos, r * 0.2, Paint()..color = Colors.white);
  }

  void _drawMissionPaths(Canvas canvas, Offset Function(Vector2) w2s) {
    for (final drone in sim.activeDrones) {
      if (drone.missionPath.length < 2) continue;

      final path = Path();
      final p0 = w2s(drone.missionPath.first);
      path.moveTo(p0.dx, p0.dy);

      for (int i = 1; i < drone.missionPath.length; i++) {
        final pt = w2s(drone.missionPath[i]);
        path.lineTo(pt.dx, pt.dy);
      }

      final trailPaint = Paint()
        ..color = drone.ledColor.withValues(alpha: 0.45)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.8
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round;

      canvas.drawPath(path, trailPaint);
    }
  }

  void _drawDrone(
    Canvas canvas,
    DroneModel drone,
    Offset Function(Vector2) w2s,
    double Function(double) toSDist,
  ) {
    final center = w2s(drone.position);
    final visualSpan = toSDist(0.38);
    final r = math.max(14.0, visualSpan);

    if (pathsVisible && drone.pathCells.isNotEmpty) {
      final pathPaint = Paint()
        ..color = drone.ledColor.withValues(alpha: 0.6)
        ..strokeWidth = 1.8
        ..style = PaintingStyle.stroke;

      final path = Path();
      path.moveTo(center.dx, center.dy);
      for (int i = drone.pathIndex; i < drone.pathCells.length; i++) {
        final wpW = sim.map.cellToWorldCenter(drone.pathCells[i]);
        final wpS = w2s(wpW);
        path.lineTo(wpS.dx, wpS.dy);
      }
      canvas.drawPath(path, pathPaint);
    }

    if (sensorsVisible) {
      for (final ray in drone.currentSensorRays) {
        final pStart = w2s(ray.start);
        final pEnd = w2s(ray.end);

        final rayPaint = Paint()
          ..color = ray.hitWall ? Colors.redAccent.withValues(alpha: 0.8) : Colors.cyanAccent.withValues(alpha: 0.4)
          ..strokeWidth = 1.2;

        canvas.drawLine(pStart, pEnd, rayPaint);
      }
    }

    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.rotate(-drone.headingAngle);

    _drawDroneHardwareAndFrame(canvas, drone, r);

    canvas.restore();

    if (labelsVisible) {
      final roleStr = drone.role == DroneRole.leader ? 'LEADER' : 'MEMBER';
      final statusStr = drone.status.name.toUpperCase();
      final label = '${drone.name} [$roleStr] ($statusStr)';

      final tp = TextPainter(
        text: TextSpan(
          text: label,
          style: TextStyle(
            color: drone.ledColor,
            fontSize: math.min(12.0, math.max(9.0, r * 0.28)),
            fontWeight: FontWeight.bold,
            backgroundColor: const Color(0xCC000000),
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();

      tp.paint(canvas, center + Offset(-tp.width / 2, r + 6));
    }
  }

  void _drawDroneHardwareAndFrame(Canvas canvas, DroneModel drone, double r) {
    final dArm = r * 0.85;
    final propPositions = [
      Offset(-dArm, -dArm),
      Offset(dArm, -dArm),
      Offset(-dArm, dArm),
      Offset(dArm, dArm),
    ];

    switch (drone.frameType) {
      case DroneFrameType.mini:
        final guardPaint = Paint()
          ..color = const Color(0xFF475569)
          ..style = PaintingStyle.stroke
          ..strokeWidth = math.max(1.5, r * 0.06);
        for (final pos in propPositions) {
          canvas.drawCircle(pos, r * 0.42, guardPaint);
        }
        final armPaint = Paint()
          ..color = const Color(0xFF64748B)
          ..strokeWidth = math.max(2.0, r * 0.08);
        canvas.drawLine(Offset(-dArm, -dArm), Offset(dArm, dArm), armPaint);
        canvas.drawLine(Offset(-dArm, dArm), Offset(dArm, -dArm), armPaint);
        break;

      case DroneFrameType.fpv:
        final carbonPaint = Paint()
          ..color = const Color(0xFF1E293B)
          ..strokeWidth = math.max(2.5, r * 0.12)
          ..strokeCap = StrokeCap.round;
        final edgePaint = Paint()
          ..color = const Color(0xFF475569)
          ..strokeWidth = math.max(1.0, r * 0.04);
        canvas.drawLine(Offset(-dArm * 0.8, -dArm * 1.1), Offset(dArm * 0.8, dArm * 1.1), carbonPaint);
        canvas.drawLine(Offset(-dArm * 0.8, dArm * 1.1), Offset(dArm * 0.8, -dArm * 1.1), carbonPaint);
        canvas.drawLine(Offset(-dArm * 0.8, -dArm * 1.1), Offset(dArm * 0.8, dArm * 1.1), edgePaint);
        canvas.drawLine(Offset(-dArm * 0.8, dArm * 1.1), Offset(dArm * 0.8, -dArm * 1.1), edgePaint);

        final camPaint = Paint()..color = Colors.black;
        canvas.drawRRect(
          RRect.fromRectAndRadius(Rect.fromLTWH(r * 0.45, -r * 0.2, r * 0.35, r * 0.4), const Radius.circular(2)),
          camPaint,
        );
        final lensPaint = Paint()..color = Colors.blueGrey;
        canvas.drawCircle(Offset(r * 0.8, 0), r * 0.12, lensPaint);
        break;

      case DroneFrameType.cinewhoop:
        final ductPaint = Paint()
          ..color = const Color(0xFF3B82F6).withValues(alpha: 0.3)
          ..style = PaintingStyle.fill;
        final ductBorder = Paint()
          ..color = const Color(0xFF60A5FA)
          ..style = PaintingStyle.stroke
          ..strokeWidth = math.max(2.0, r * 0.07);

        for (final pos in propPositions) {
          canvas.drawCircle(pos, r * 0.5, ductPaint);
          canvas.drawCircle(pos, r * 0.5, ductBorder);
        }
        final cArmPaint = Paint()
          ..color = const Color(0xFF1E293B)
          ..strokeWidth = math.max(2.5, r * 0.1);
        canvas.drawLine(Offset(-dArm, -dArm), Offset(dArm, dArm), cArmPaint);
        canvas.drawLine(Offset(-dArm, dArm), Offset(dArm, -dArm), cArmPaint);
        break;

      case DroneFrameType.standardQuad:
        final quadArmPaint = Paint()
          ..color = const Color(0xFF334155)
          ..strokeWidth = math.max(2.5, r * 0.12);
        canvas.drawLine(Offset(-dArm, -dArm), Offset(dArm, dArm), quadArmPaint);
        canvas.drawLine(Offset(-dArm, dArm), Offset(dArm, -dArm), quadArmPaint);

        final skidPaint = Paint()
          ..color = const Color(0xFF0F172A)
          ..strokeWidth = math.max(1.8, r * 0.08);
        canvas.drawLine(Offset(-dArm * 0.6, -r * 0.7), Offset(dArm * 0.6, -r * 0.7), skidPaint);
        canvas.drawLine(Offset(-dArm * 0.6, r * 0.7), Offset(dArm * 0.6, r * 0.7), skidPaint);
        break;
    }

    final escPaint = Paint()..color = const Color(0xFF1E3A8A);
    canvas.drawRRect(
      RRect.fromRectAndRadius(Rect.fromCenter(center: Offset.zero, width: r * 0.85, height: r * 0.85), const Radius.circular(3)),
      escPaint,
    );

    final rpiPaint = Paint()..color = const Color(0xFF15803D);
    canvas.drawRRect(
      RRect.fromRectAndRadius(Rect.fromCenter(center: Offset(-r * 0.05, 0), width: r * 0.68, height: r * 0.68), const Radius.circular(2)),
      rpiPaint,
    );
    final cpuPaint = Paint()..color = const Color(0xFFD1D5DB);
    canvas.drawRect(Rect.fromCenter(center: Offset(-r * 0.1, -r * 0.08), width: r * 0.22, height: r * 0.22), cpuPaint);
    final usbPaint = Paint()..color = const Color(0xFF9CA3AF);
    canvas.drawRect(Rect.fromLTWH(-r * 0.38, -r * 0.28, r * 0.1, r * 0.2), usbPaint);
    canvas.drawRect(Rect.fromLTWH(-r * 0.38, 0.05, r * 0.1, r * 0.2), usbPaint);

    final pixhawkPaint = Paint()..color = const Color(0xFF111827);
    canvas.drawRRect(
      RRect.fromRectAndRadius(Rect.fromCenter(center: Offset(r * 0.04, 0), width: r * 0.48, height: r * 0.48), const Radius.circular(2)),
      pixhawkPaint,
    );
    final arrowPaint = Paint()..color = Colors.white70;
    final arrowPath = Path()
      ..moveTo(r * 0.2, 0)
      ..lineTo(r * 0.08, -r * 0.08)
      ..lineTo(r * 0.08, r * 0.08)
      ..close();
    canvas.drawPath(arrowPath, arrowPaint);

    final batteryPaint = Paint()..color = const Color(0xFFEAB308);
    canvas.drawRRect(
      RRect.fromRectAndRadius(Rect.fromCenter(center: Offset(-r * 0.35, 0), width: r * 0.28, height: r * 0.5), const Radius.circular(2)),
      batteryPaint,
    );
    final xt60Paint = Paint()..color = Colors.orange;
    canvas.drawRect(Rect.fromCenter(center: Offset(-r * 0.5, 0), width: r * 0.08, height: r * 0.12), xt60Paint);

    final flowLensPaint = Paint()..color = Colors.cyanAccent.shade700;
    canvas.drawCircle(Offset.zero, r * 0.08, flowLensPaint);

    final uwbPaint = Paint()..color = const Color(0xFF7C3AED);
    canvas.drawRect(Rect.fromCenter(center: Offset(0, r * 0.3), width: r * 0.16, height: r * 0.12), uwbPaint);
    final rfPaint = Paint()
      ..color = Colors.purpleAccent.withValues(alpha: 0.6)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;
    canvas.drawArc(Rect.fromCircle(center: Offset(0, r * 0.36), radius: r * 0.15), 0, math.pi, false, rfPaint);

    final lidarPaint = Paint()..color = Colors.black87;
    final lidarLensPaint = Paint()..color = Colors.redAccent;
    final lidarPositions = [
      Offset(r * 0.45, 0),
      Offset(0, r * 0.45),
      Offset(0, -r * 0.45),
      Offset(-r * 0.45, 0),
      Offset(r * 0.32, r * 0.32),
    ];

    for (final lp in lidarPositions) {
      canvas.drawCircle(lp, r * 0.08, lidarPaint);
      canvas.drawCircle(lp, r * 0.04, lidarLensPaint);
    }

    final ledColor = drone.ledColor;
    final ledRadius = r * 0.10;
    final dLed = r * 0.32;

    final polePositions = [
      Offset(dLed, 0),
      Offset(-dLed, 0),
      Offset(0, -dLed),
      Offset(0, dLed),
    ];

    final ledGlowPaint = Paint()
      ..color = ledColor.withValues(alpha: 0.45)
      ..style = PaintingStyle.fill;
    final ledCorePaint = Paint()
      ..color = ledColor
      ..style = PaintingStyle.fill;
    final ledWhiteCenter = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;

    for (final pole in polePositions) {
      canvas.drawCircle(pole, ledRadius * 2.2, ledGlowPaint);
      canvas.drawCircle(pole, ledRadius, ledCorePaint);
      canvas.drawCircle(pole, ledRadius * 0.45, ledWhiteCenter);
    }

    final propPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.85)
      ..strokeWidth = math.max(1.5, r * 0.05);
    final propR = r * 0.42;
    final pAngle = drone.propellerAngle * math.pi / 180.0;

    for (final pPos in propPositions) {
      canvas.drawCircle(pPos, r * 0.14, Paint()..color = const Color(0xFF1E293B));
      canvas.drawCircle(pPos, r * 0.08, Paint()..color = const Color(0xFF64748B));

      canvas.save();
      canvas.translate(pPos.dx, pPos.dy);
      canvas.rotate(pAngle);
      canvas.drawLine(Offset(-propR, 0), Offset(propR, 0), propPaint);
      canvas.drawLine(Offset(0, -propR * 0.4), Offset(0, propR * 0.4), propPaint..strokeWidth = math.max(1.0, r * 0.03));
      canvas.restore();
    }

    if (r >= 38.0) {
      _drawMicroAnnotation(canvas, Offset(-r * 0.1, -r * 0.18), 'RPi 4', const Color(0xFF15803D));
      _drawMicroAnnotation(canvas, Offset(r * 0.08, 0.0), 'Pixhawk 6', const Color(0xFF111827));
      _drawMicroAnnotation(canvas, Offset(r * 0.46, 0.0), 'LiDAR 0°', Colors.redAccent.shade700);
      _drawMicroAnnotation(canvas, Offset(-r * 0.35, r * 0.28), '4S LiPo', const Color(0xFFCA8A04));
      _drawMicroAnnotation(canvas, Offset(0, r * 0.42), 'UWB DW3000', const Color(0xFF7C3AED));
    }
  }

  void _drawMicroAnnotation(Canvas canvas, Offset pos, String text, Color bg) {
    final tp = TextPainter(
      text: TextSpan(
        text: text,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 7.5,
          fontWeight: FontWeight.bold,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();

    final pad = const EdgeInsets.symmetric(horizontal: 2.5, vertical: 1);
    final rect = Rect.fromLTWH(
      pos.dx - tp.width / 2 - pad.horizontal / 2,
      pos.dy - tp.height / 2 - pad.vertical / 2,
      tp.width + pad.horizontal,
      tp.height + pad.vertical,
    );

    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, const Radius.circular(2)),
      Paint()..color = bg.withValues(alpha: 0.85),
    );
    tp.paint(canvas, Offset(pos.dx - tp.width / 2, pos.dy - tp.height / 2));
  }

  @override
  bool shouldRepaint(covariant ArenaPainter oldDelegate) => true;
}
