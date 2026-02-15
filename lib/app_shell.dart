// screens/app_shell.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:reality_gap/screens/home_screen.dart';
import 'package:reality_gap/screens/permissions_screen.dart';
import 'package:reality_gap/screens/time_tracker_screen.dart';
import 'package:reality_gap/screens/weekly_summary_screen.dart';

class AppShell extends StatefulWidget {
  final int initialIndex;
  const AppShell({Key? key, this.initialIndex = 0}) : super(key: key);

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  late int _currentIndex;

  static const List<Widget> _tabs = [
    HomeScreen(),
    TimeTrackerScreen(),
    WeeklySummaryScreen(),
    _SettingsTab(),
  ];

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
  }

  void _onTabTapped(int index) {
    if (index == _currentIndex) return;
    HapticFeedback.selectionClick(); // subtle haptic, feels premium
    setState(() => _currentIndex = index);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: _tabs,
      ),
      bottomNavigationBar: _MinimalNavBar(
        currentIndex: _currentIndex,
        onTap: _onTabTapped,
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Fully custom nav bar — no Flutter BottomNavigationBar widget at all.
// That widget injects the scale/fade animation and can't be disabled cleanly.
// This one is a plain Row of _NavItem widgets with AnimatedOpacity only.
// ─────────────────────────────────────────────────────────────────────────────

class _MinimalNavBar extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;

  const _MinimalNavBar({
    required this.currentIndex,
    required this.onTap,
  });

  static const _items = [
    _NavItemData(
        icon: Icons.today_outlined,
        activeIcon: Icons.today_rounded,
        label: 'Today'),
    _NavItemData(
        icon: Icons.timer_outlined,
        activeIcon: Icons.timer_rounded,
        label: 'Tracker'),
    _NavItemData(
        icon: Icons.calendar_month_outlined,
        activeIcon: Icons.calendar_month_rounded,
        label: 'Weekly'),
    _NavItemData(
        icon: Icons.settings_outlined,
        activeIcon: Icons.settings_rounded,
        label: 'Settings'),
  ];

  @override
  Widget build(BuildContext context) {
    final bottomPadding = MediaQuery.of(context).padding.bottom;

    return Container(
      decoration: const BoxDecoration(
        color: Colors.black,
        border: Border(
          top: BorderSide(color: Color(0xFF1A1A1A), width: 1),
        ),
      ),
      child: Padding(
        padding: EdgeInsets.only(bottom: bottomPadding),
        child: SizedBox(
          height: 56,
          child: Row(
            children: List.generate(_items.length, (i) {
              return Expanded(
                child: _NavItem(
                  data: _items[i],
                  isActive: i == currentIndex,
                  onTap: () => onTap(i),
                ),
              );
            }),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Single nav item — opacity-only transition, no scale, no position shift
// ─────────────────────────────────────────────────────────────────────────────

class _NavItem extends StatelessWidget {
  final _NavItemData data;
  final bool isActive;
  final VoidCallback onTap;

  const _NavItem({
    required this.data,
    required this.isActive,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque, // full tap area, not just icon
      child: SizedBox(
        height: 56,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // ── Icon ───────────────────────────────────────────────────────
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 180),
              switchInCurve: Curves.easeOut,
              switchOutCurve: Curves.easeIn,
              // transitionBuilder suppresses the default scale — opacity only
              transitionBuilder: (child, animation) {
                return FadeTransition(opacity: animation, child: child);
              },
              child: Icon(
                isActive ? data.activeIcon : data.icon,
                key: ValueKey(isActive),
                size: 22,
                color: isActive ? Colors.white : const Color(0xFF4A4A4A),
              ),
            ),

            const SizedBox(height: 4),

            // ── Label ──────────────────────────────────────────────────────
            AnimatedDefaultTextStyle(
              duration: const Duration(milliseconds: 180),
              curve: Curves.easeOut,
              style: TextStyle(
                fontSize: 10,
                letterSpacing: 0.3,
                fontWeight: isActive ? FontWeight.w500 : FontWeight.w400,
                color: isActive ? Colors.white : const Color(0xFF4A4A4A),
              ),
              child: Text(data.label),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Data class — keeps the items list declarative and easy to extend
// ─────────────────────────────────────────────────────────────────────────────

class _NavItemData {
  final IconData icon;
  final IconData activeIcon;
  final String label;

  const _NavItemData({
    required this.icon,
    required this.activeIcon,
    required this.label,
  });
}

// ─────────────────────────────────────────────────────────────────────────────
// Settings tab wrapper
// ─────────────────────────────────────────────────────────────────────────────

class _SettingsTab extends StatelessWidget {
  const _SettingsTab();

  @override
  Widget build(BuildContext context) {
    return PermissionsScreen(
      onPermissionGranted: () {},
      showBackButton: true,
    );
  }
}
