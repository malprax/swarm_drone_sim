import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../controllers/ui_controller.dart';
import '../../utils/app_theme.dart';

/// Interactive 3-way toggle button for switching between:
/// - Dark Mode (Gelap)
/// - Light Mode (Terang)
/// - System Mode (Mengikuti Sistem)
class ThemeModeToggle extends StatelessWidget {
  final bool isCompact;

  const ThemeModeToggle({
    super.key,
    this.isCompact = true,
  });

  @override
  Widget build(BuildContext context) {
    final ui = Get.find<UIController>();

    return Obx(() {
      final currentMode = ui.themeMode.value;
      final isDark = ui.isDarkMode;

      if (isCompact) {
        return _buildCompactPill(context, ui, currentMode, isDark);
      } else {
        return _buildExpandedPanel(context, ui, currentMode, isDark);
      }
    });
  }

  /// Compact segmented pill designed for the top AppBar
  Widget _buildCompactPill(
    BuildContext context,
    UIController ui,
    ThemeMode currentMode,
    bool isDark,
  ) {
    final bgColor = isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9);
    final borderColor = isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1);

    return Container(
      height: 28,
      padding: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor, width: 1.0),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildCompactSegment(
            icon: Icons.dark_mode_outlined,
            activeIcon: Icons.dark_mode,
            tooltip: 'Mode Gelap (Dark)',
            isSelected: currentMode == ThemeMode.dark,
            isDark: isDark,
            onTap: () => ui.setThemeMode(ThemeMode.dark),
          ),
          _buildCompactSegment(
            icon: Icons.light_mode_outlined,
            activeIcon: Icons.light_mode,
            tooltip: 'Mode Terang (Light)',
            isSelected: currentMode == ThemeMode.light,
            isDark: isDark,
            onTap: () => ui.setThemeMode(ThemeMode.light),
          ),
          _buildCompactSegment(
            icon: Icons.brightness_auto_outlined,
            activeIcon: Icons.brightness_auto,
            tooltip: 'Mengikuti Sistem (${isDark ? "Aktif: Gelap" : "Aktif: Terang"})',
            isSelected: currentMode == ThemeMode.system,
            isDark: isDark,
            onTap: () => ui.setThemeMode(ThemeMode.system),
          ),
        ],
      ),
    );
  }

  Widget _buildCompactSegment({
    required IconData icon,
    required IconData activeIcon,
    required String tooltip,
    required bool isSelected,
    required bool isDark,
    required VoidCallback onTap,
  }) {
    final activeBg = isDark
        ? Colors.cyanAccent.withValues(alpha: 0.25)
        : const Color(0xFF0284C7).withValues(alpha: 0.20);
    final activeIconColor = isDark ? Colors.cyanAccent : const Color(0xFF0284C7);
    final inactiveIconColor = isDark ? Colors.white38 : const Color(0xFF64748B);

    return Tooltip(
      message: tooltip,
      waitDuration: const Duration(milliseconds: 300),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeInOut,
          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
          decoration: BoxDecoration(
            color: isSelected ? activeBg : Colors.transparent,
            borderRadius: BorderRadius.circular(14),
            border: isSelected
                ? Border.all(color: activeIconColor.withValues(alpha: 0.6), width: 1.0)
                : null,
          ),
          child: Icon(
            isSelected ? activeIcon : icon,
            size: 14,
            color: isSelected ? activeIconColor : inactiveIconColor,
          ),
        ),
      ),
    );
  }

  /// Expanded full-featured setting widget for Control Panel
  Widget _buildExpandedPanel(
    BuildContext context,
    UIController ui,
    ThemeMode currentMode,
    bool isDark,
  ) {
    final cardBg = AppColors.subtleCard(isDark);
    final borderColor = AppColors.border(isDark);
    final titleColor = AppColors.textPrimary(isDark);
    final subColor = AppColors.textMuted(isDark);

    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: borderColor, width: 1.0),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.palette_outlined,
                size: 15,
                color: isDark ? Colors.cyanAccent : const Color(0xFF0284C7),
              ),
              const SizedBox(width: 6),
              Text(
                'TEMA TAMPILAN',
                style: TextStyle(
                  color: titleColor,
                  fontWeight: FontWeight.bold,
                  fontSize: 11,
                  letterSpacing: 0.5,
                ),
              ),
              const Spacer(),
              Text(
                currentMode == ThemeMode.system
                    ? 'Sistem (${isDark ? "Gelap" : "Terang"})'
                    : (currentMode == ThemeMode.dark ? 'Gelap' : 'Terang'),
                style: TextStyle(
                  color: isDark ? Colors.cyanAccent : const Color(0xFF0284C7),
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'Pilih mode gelap, terang, atau ikuti tema sistem operasi',
            style: TextStyle(color: subColor, fontSize: 10),
          ),
          const SizedBox(height: 8),

          // 3-Segment Selector
          Row(
            children: [
              Expanded(
                child: _buildPanelButton(
                  title: 'Gelap',
                  subtitle: 'Dark',
                  icon: Icons.dark_mode_outlined,
                  isSelected: currentMode == ThemeMode.dark,
                  isDark: isDark,
                  onTap: () => ui.setThemeMode(ThemeMode.dark),
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: _buildPanelButton(
                  title: 'Terang',
                  subtitle: 'Light',
                  icon: Icons.light_mode_outlined,
                  isSelected: currentMode == ThemeMode.light,
                  isDark: isDark,
                  onTap: () => ui.setThemeMode(ThemeMode.light),
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: _buildPanelButton(
                  title: 'Sistem',
                  subtitle: 'Auto',
                  icon: Icons.brightness_auto_outlined,
                  isSelected: currentMode == ThemeMode.system,
                  isDark: isDark,
                  onTap: () => ui.setThemeMode(ThemeMode.system),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPanelButton({
    required String title,
    required String subtitle,
    required IconData icon,
    required bool isSelected,
    required bool isDark,
    required VoidCallback onTap,
  }) {
    final activeBg = isDark
        ? Colors.cyanAccent.withValues(alpha: 0.22)
        : const Color(0xFF0284C7).withValues(alpha: 0.16);
    final activeBorder = isDark ? Colors.cyanAccent : const Color(0xFF0284C7);
    final inactiveBorder = isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1);
    final inactiveBg = isDark ? const Color(0xFF1E293B) : Colors.white;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(6),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
        decoration: BoxDecoration(
          color: isSelected ? activeBg : inactiveBg,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: isSelected ? activeBorder : inactiveBorder,
            width: isSelected ? 1.4 : 1.0,
          ),
        ),
        child: Column(
          children: [
            Icon(
              icon,
              size: 16,
              color: isSelected
                  ? activeBorder
                  : (isDark ? Colors.white70 : const Color(0xFF475569)),
            ),
            const SizedBox(height: 3),
            Text(
              title,
              style: TextStyle(
                color: isSelected
                    ? activeBorder
                    : (isDark ? Colors.white : const Color(0xFF0F172A)),
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                fontSize: 10,
              ),
            ),
            Text(
              subtitle,
              style: TextStyle(
                color: isSelected
                    ? activeBorder.withValues(alpha: 0.8)
                    : (isDark ? Colors.white38 : const Color(0xFF94A3B8)),
                fontSize: 8.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
