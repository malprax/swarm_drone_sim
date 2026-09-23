import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../models/drone_model.dart';
import '../models/vector2.dart';

enum GizmoMode { none, drones, target }
enum GizmoAxis { none, x, y, xy }

/// Split-Screen presets for Arena and Minimap (as shown in reference icons)
enum ArenaSplitLayout {
  rightStacked, // [ | ⚏ ] Arena on Left, Minimap cards stacked vertically on Right
  arenaFocus,   // [ ▮ ▯ ] Arena 100% Fullscreen Focus
  horizontal,   // [ ▔ ▃ ] Arena on Top, Minimap Panel on Bottom (resizable height)
  vertical,     // [ ▯ | ▯ ] Arena on Left, Minimap Panel on Right (resizable width)
}

/// Pattern/style for red wall detection lines in Arena & Minimap
enum WallLineStyle {
  solid,  // Sambung (Garis Lurus Kontinu)
  dashed, // Putus-putus (Dashed Line)
  zigzag, // Bergelombang Tajam (Sharp Zigzag)
  wavy,   // Bergelombang Tumpul (Smooth Sinusoidal Wave)
}

class UIController extends GetxController {
  // Canvas visualization toggles
  final showSensors = true.obs;
  final showGrid = true.obs;
  final showPaths = true.obs;
  final showMissionPath = true.obs; // Toggle historical search breadcrumbs
  final showDroneLabels = true.obs;
  final showTargetArea = true.obs;
  final showMinimaps = true.obs; // Toggle 3 AI Minimap boxes

  // Wall detection line customization (0 pt, 1 pt, 2 pt, 3 pt) & style
  final wallLineThickness = 2.obs; // 0 = off, 1 = 1pt, 2 = 2pt, 3 = 3pt
  final wallLineStyle = WallLineStyle.solid.obs; // solid, dashed, zigzag, wavy

  // Multi-Mode Split Layout (Presets)
  final activeSplitLayout = ArenaSplitLayout.horizontal.obs;

  // Resizable Split Dimensions
  static const double defaultMinimapHeight = 220.0;
  static const double minMinimapHeight = 110.0;
  final minimapHeight = defaultMinimapHeight.obs;

  static const double defaultMinimapWidth = 360.0;
  static const double minMinimapWidth = 220.0;
  final minimapWidth = defaultMinimapWidth.obs;

  // Left & Right Panels Width & Collapsed States
  static const double defaultLeftPanelWidth = 270.0;
  static const double minLeftPanelWidth = 200.0;
  static const double maxLeftPanelWidth = 460.0;
  final leftPanelWidth = defaultLeftPanelWidth.obs;
  final isLeftPanelCollapsed = false.obs;

  static const double defaultRightPanelWidth = 260.0;
  static const double minRightPanelWidth = 200.0;
  static const double maxRightPanelWidth = 460.0;
  final rightPanelWidth = defaultRightPanelWidth.obs;
  final isRightPanelCollapsed = false.obs;

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

  // Real Drone Raspberry Pi Connection Controllers
  final rpiIpController = TextEditingController(text: '192.168.1.50');
  final rpiPortController = TextEditingController(text: '8765');

  @override
  void onClose() {
    runsInputController.dispose();
    rpiIpController.dispose();
    rpiPortController.dispose();
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

  // ===========================================================================
  // MULTI-MODE SPLIT LAYOUT & DRAGGABLE DIVIDER RESIZING
  // ===========================================================================
  void setSplitLayout(ArenaSplitLayout layout) {
    activeSplitLayout.value = layout;
    if (layout == ArenaSplitLayout.arenaFocus) {
      showMinimaps.value = false;
    } else {
      showMinimaps.value = true;
    }
  }

  /// Resize Minimap height in Horizontal Split mode
  /// Dragging up (negative delta) expands minimap; dragging down reduces it
  void resizeMinimapHeight(double delta, double availableHeight) {
    final maxH = math.max(minMinimapHeight + 50.0, availableHeight * 0.75);
    final next = minimapHeight.value - delta;
    minimapHeight.value = next.clamp(minMinimapHeight, maxH);
  }

  /// Resize Minimap width in Vertical / Stacked Split mode
  /// Dragging left (negative delta) expands minimap width; dragging right reduces it
  void resizeMinimapWidth(double delta, double availableWidth) {
    final maxW = math.max(minMinimapWidth + 50.0, availableWidth * 0.70);
    final next = minimapWidth.value - delta;
    minimapWidth.value = next.clamp(minMinimapWidth, maxW);
  }

  /// Resize Left Control Panel width
  /// Dragging right (positive delta) expands left panel; dragging left reduces it
  void resizeLeftPanel(double delta) {
    final next = leftPanelWidth.value + delta;
    leftPanelWidth.value = next.clamp(minLeftPanelWidth, maxLeftPanelWidth);
    if (isLeftPanelCollapsed.value && leftPanelWidth.value > minLeftPanelWidth) {
      isLeftPanelCollapsed.value = false;
    }
  }

  /// Resize Right Swarm Telemetry Sidebar width
  /// Dragging left (negative delta) expands right panel; dragging right reduces it
  void resizeRightPanel(double delta) {
    final next = rightPanelWidth.value - delta;
    rightPanelWidth.value = next.clamp(minRightPanelWidth, maxRightPanelWidth);
    if (isRightPanelCollapsed.value && rightPanelWidth.value > minRightPanelWidth) {
      isRightPanelCollapsed.value = false;
    }
  }

  void toggleLeftPanel() {
    isLeftPanelCollapsed.value = !isLeftPanelCollapsed.value;
  }

  void toggleRightPanel() {
    isRightPanelCollapsed.value = !isRightPanelCollapsed.value;
  }

  void resetSplitDimensions() {
    minimapHeight.value = defaultMinimapHeight;
    minimapWidth.value = defaultMinimapWidth;
    leftPanelWidth.value = defaultLeftPanelWidth;
    rightPanelWidth.value = defaultRightPanelWidth;
    isLeftPanelCollapsed.value = false;
    isRightPanelCollapsed.value = false;
  }

  void setWallLineThickness(int pt) {
    wallLineThickness.value = pt.clamp(0, 3);
  }

  void setWallLineStyle(WallLineStyle style) {
    wallLineStyle.value = style;
  }
}
