// screens/home/tracker_card.dart
//
// Drop into HomeScreen._buildBody() between AppBreakdownCards and the Output StatRow:
//
//   TrackerCard(
//     onTap: () async {
//       await Navigator.push(context,
//         MaterialPageRoute(builder: (_) => const TimeTrackerScreen()));
//       _loadData();
//     },
//   ),
//   const SizedBox(height: 32),

import 'package:flutter/material.dart';
import '../../services/tracker_service.dart';

/// A compact status card for the Time Tracker shown on the Home Screen.
///
/// Reads tracker state on each build via [FutureBuilder] so it always
/// reflects the latest status without the Home Screen needing to know
/// anything about TrackerService.
///
/// Tapping anywhere on the card calls [onTap] (navigate to TimeTrackerScreen).
class TrackerCard extends StatefulWidget {
  final VoidCallback onTap;

  const TrackerCard({Key? key, required this.onTap}) : super(key: key);

  @override
  State<TrackerCard> createState() => _TrackerCardState();
}

class _TrackerCardState extends State<TrackerCard> {
  // Re-read on every resume so card is fresh after returning from tracker screen
  bool _isActive = false;
  int _intervalMinutes = 30;
  int _slotsToday = 0;
  int _loggedToday = 0;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  /// Called by HomeScreen._loadData() indirectly — the card is rebuilt
  /// whenever the home screen calls setState, so initState + didUpdateWidget
  /// are enough to keep it fresh.
  Future<void> _refresh() async {
    final active = await TrackerService.instance.isActive;
    final interval = await TrackerService.instance.intervalMinutes;
    List<_SlotCount> counts = [_SlotCount(0, 0)];

    if (active) {
      final slots = await TrackerService.instance.getSlots();
      counts = [
        _SlotCount(
          slots.length,
          slots.where((s) => s.isLogged).length,
        )
      ];
    }

    if (mounted) {
      setState(() {
        _isActive = active;
        _intervalMinutes = interval;
        _slotsToday = counts.first.total;
        _loggedToday = counts.first.logged;
      });
    }
  }

  String _formatTime(int minutes) {
    if (minutes < 60) return '${minutes}m';
    final h = minutes ~/ 60;
    final m = minutes % 60;
    return m == 0 ? '${h}h' : '${h}h ${m}m';
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () async {
        widget.onTap();
        // Refresh after returning
        await Future.delayed(const Duration(milliseconds: 300));
        _refresh();
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: _isActive
              ? const Color(0xFF0D1A0D) // dark green tint when active
              : const Color(0xFF0D0D0D),
          border: Border.all(
            color:
                _isActive ? const Color(0xFF2E5C2E) : const Color(0xFF222222),
          ),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Row(
          children: [
            // ── Icon ──────────────────────────────────────────────────────
            Icon(
              Icons.timer_outlined,
              size: 18,
              color:
                  _isActive ? const Color(0xFF4CAF50) : const Color(0xFF666666),
            ),
            const SizedBox(width: 12),

            // ── Label + subtitle ───────────────────────────────────────────
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Time Tracker',
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          color: _isActive ? Colors.white : Colors.white70,
                        ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    _isActive
                        ? 'Every ${_formatTime(_intervalMinutes)} · $_loggedToday/$_slotsToday logged'
                        : 'Not running',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Colors.white38,
                          fontSize: 12,
                        ),
                  ),
                ],
              ),
            ),

            // ── Status badge ───────────────────────────────────────────────
            _isActive ? _ActiveBadge() : _InactiveBadge(),
          ],
        ),
      ),
    );
  }
}

class _SlotCount {
  final int total;
  final int logged;
  _SlotCount(this.total, this.logged);
}

// ── Active badge — "Active ●" ──────────────────────────────────────────────
class _ActiveBadge extends StatefulWidget {
  @override
  State<_ActiveBadge> createState() => _ActiveBadgeState();
}

class _ActiveBadgeState extends State<_ActiveBadge>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _pulse;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
    _pulse = Tween<double>(begin: 0.4, end: 1.0).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          'Active',
          style: const TextStyle(
            fontSize: 12,
            color: Color(0xFF4CAF50),
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(width: 6),
        FadeTransition(
          opacity: _pulse,
          child: Container(
            width: 6,
            height: 6,
            decoration: const BoxDecoration(
              color: Color(0xFF4CAF50),
              shape: BoxShape.circle,
            ),
          ),
        ),
      ],
    );
  }
}

// ── Inactive badge — "Start →" ─────────────────────────────────────────────
class _InactiveBadge extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Text(
      'Start →',
      style: const TextStyle(
        fontSize: 12,
        color: Color(0xFF555555),
      ),
    );
  }
}
