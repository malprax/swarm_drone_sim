import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../models/drone_model.dart';
import '../models/vector2.dart';

enum GizmoMode { none, drones, target }
enum GizmoAxis { none, x, y, xy }

class UIController extends GetxController {
  // Canvas visualization toggles
  final showSensors = true.obs;
  final showGrid = true.obs;
  final showPaths = true.obs;
  final showMissionPath = true.obs; // Toggle historical search breadcrumbs
  final showDroneLabels = true.obs;
  final showTargetArea = true.obs;
  final showMinimaps = true.obs; // Toggle 3 AI Minimap boxes

  // Drone Frame Type Selector
  final selectedFrameType = DroneFrameType.fpv.obs;

  // Interactive Viewport Pan & Zoom
  static const double minZoom = 0.5;
  static const double maxZoom = 15.0;

  final zoom = 1.0.obs;
  final panOffset = Offset.zero.obs;

  // Following Drone Index (-1 = free-roam, 0 = D1, 1 = D2, 2 = D3)
  final followingDroneIndex = (-1).obs;

  // Selected drone for detail inspector
  final selectedDroneIndex = 0.obs;

  // Interactive Transform Gizmo (CorelDraw / CAD-style Sumbu X & Y)
  final gizmoMode = GizmoMode.none.obs;
  final activeGizmoAxis = GizmoAxis.none.obs;
  final activeGizmoDroneIndex = (-1).obs;
  final isDraggingGizmo = false.obs;

  // Batch Runs input controller
  final runsInputController = TextEditingController(text: '30');

  @override
  void onClose() {
    runsInputController.dispose();
    super.onClose();
  }

  /// Reset camera back to default 100% fit-all view
  void resetCamera() {
    zoom.value = 1.0;
    panOffset.value = Offset.zero;
    followingDroneIndex.value = -1;
  }

  /// Zoom by a relative factor, keeping the world coordinate under focalPoint stationary
  void zoomBy(double factor, {Offset? focalPoint, Size? viewportSize}) {
    final oldZoom = zoom.value;
    final newZoom = (oldZoom * factor).clamp(minZoom, maxZoom);
    if ((newZoom - oldZoom).abs() < 1e-5) return;

    if (focalPoint != null && viewportSize != null && viewportSize.width > 0 && viewportSize.height > 0) {
      final center = Offset(viewportSize.width / 2.0, viewportSize.height / 2.0);
      final pMinusCenter = focalPoint - center;
      final oldPan = panOffset.value;
      // Invariant:
      // (focalPoint - center - newPan) / newZoom == (focalPoint - center - oldPan) / oldZoom
      final ratio = newZoom / oldZoom;
      final newPan = pMinusCenter - (pMinusCenter - oldPan) * ratio;
      panOffset.value = newPan;
    }

    zoom.value = newZoom;
  }

  void zoomIn({Size? viewportSize}) => zoomBy(1.30, viewportSize: viewportSize);
  void zoomOut({Size? viewportSize}) => zoomBy(1.0 / 1.30, viewportSize: viewportSize);

  /// Center viewport onto a specific world position (e.g. drone or target)
  void centerOnWorld(Vector2 worldPos, Size viewportSize, {double? targetZoom}) {
    if (targetZoom != null) {
      zoom.value = targetZoom.clamp(minZoom, maxZoom);
    }

    const double worldCenterX = 0.0;
    const double worldCenterY = 3.0;
    const double worldSpanX = 32.0;
    const double worldSpanY = 18.0;

    final baseScale = math.min(viewportSize.width / worldSpanX, viewportSize.height / worldSpanY) * zoom.value;
    final dx = (worldPos.x - worldCenterX) * baseScale;
    final dy = -(worldPos.y - worldCenterY) * baseScale;

    panOffset.value = Offset(-dx, -dy);
  }

  /// Toggle follow camera on a specific drone
  void toggleFollowDrone(int droneIndex, Size viewportSize, Vector2 dronePos) {
    if (followingDroneIndex.value == droneIndex) {
      followingDroneIndex.value = -1;
    } else {
      followingDroneIndex.value = droneIndex;
      if (zoom.value < 3.5) {
        centerOnWorld(dronePos, viewportSize, targetZoom: 4.5);
      } else {
        centerOnWorld(dronePos, viewportSize);
      }
    }
  }

  // ===========================================================================
  // GIZMO MANAGEMENT
  // ===========================================================================
  void activateDroneGizmos([int? droneIndex]) {
    gizmoMode.value = GizmoMode.drones;
    activeGizmoAxis.value = GizmoAxis.none;
    activeGizmoDroneIndex.value = droneIndex ?? -1;
    isDraggingGizmo.value = false;
  }

  void activateTargetGizmo() {
    gizmoMode.value = GizmoMode.target;
    activeGizmoAxis.value = GizmoAxis.none;
    activeGizmoDroneIndex.value = -1;
    isDraggingGizmo.value = false;
  }

  void lockAndDismissGizmos() {
    gizmoMode.value = GizmoMode.none;
    activeGizmoAxis.value = GizmoAxis.none;
    activeGizmoDroneIndex.value = -1;
    isDraggingGizmo.value = false;
  }
}
