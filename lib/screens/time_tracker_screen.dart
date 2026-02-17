// screens/time_tracker_screen.dart

import 'package:flutter/material.dart';
import '../models/tracker_slot_model.dart';
import '../services/tracker_service.dart';
import '../components/duration_picker.dart';
import 'slot_output_screen.dart';

/// The main Time Tracker page. Has two visual states:
///
///  • Setup  — user picks an interval and taps [Start Tracking]
///  • Active — shows running status, today's slots, and [Stop Tracking]
class TimeTrackerScreen extends StatefulWidget {
  const TimeTrackerScreen({Key? key}) : super(key: key);

  @override
  State<TimeTrackerScreen> createState() => _TimeTrackerScreenState();
}

class _TimeTrackerScreenState extends State<TimeTrackerScreen> {
  // ── State ──────────────────────────────────────────────────────────────
  bool _isLoading = true;
  bool _isActive = false;
  bool _isStarting = false;
  bool _isStopping = false;

  int _intervalMinutes = 30;
  DateTime? _startedAt;
  List<TrackerSlotModel> _slots = [];

  DurationResult _pickedDuration = const DurationResult(hours: 0, minutes: 30);

  @override
  void initState() {
    super.initState();
    _loadState();
  }

  // ── Data ───────────────────────────────────────────────────────────────

  Future<void> _loadState() async {
    setState(() => _isLoading = true);
    final active = await TrackerService.instance.isActive;
    final interval = await TrackerService.instance.intervalMinutes;
    final startedAt = await TrackerService.instance.startedAt;
    final slots = active
        ? await TrackerService.instance.getSlots()
        : <TrackerSlotModel>[];

    setState(() {
      _isActive = active;
      _intervalMinutes = interval;
      _startedAt = startedAt;
      _slots = slots;
      _pickedDuration = DurationResult(
        hours: interval ~/ 60,
        minutes: interval % 60,
      );
      _isLoading = false;
    });
  }

  // ── Actions ────────────────────────────────────────────────────────────

  Future<void> _startTracking() async {
    final totalMinutes = _pickedDuration.totalMinutes;

    if (totalMinutes < 15) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Minimum interval is 15 minutes'),
          backgroundColor: Color(0xFFFF4444),
        ),
      );
      return;
    }

    setState(() => _isStarting = true);

    // ── FIX: wrap everything in try/finally so _isStarting is always reset.
    // Previously, any exception or hung future would leave the button
    // spinning forever.
    try {
      // Request notification permission.
      //
      // On Android 14 (API 34+), flutter_local_notifications ≥ 16 handles
      // POST_NOTIFICATIONS via the plugin initialisation flag
      // (requestNotificationsPermission: true in AndroidInitializationSettings).
      // Calling requestNotificationPermission() here is still correct — it is a
      // no-op on older APIs and surfaces the dialog on 13+.
      final granted =
          await TrackerService.instance.requestNotificationPermission();

      if (!granted && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Notifications blocked — enable in Settings to get reminders. '
              'Tracking will still run.',
            ),
            backgroundColor: Color(0xFF444444),
            duration: Duration(seconds: 4),
          ),
        );
        // Continue — user can still manually log
      }

      await TrackerService.instance.start(totalMinutes);
      await _loadState();
    } catch (e) {
      // Surface any error from TrackerService so the user isn't left with a
      // frozen spinner and no feedback.
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Could not start tracking: $e'),
            backgroundColor: const Color(0xFFFF4444),
          ),
        );
      }
    } finally {
      // ── Always reset the loading flag, even on error or exception.
      if (mounted) setState(() => _isStarting = false);
    }
  }

  Future<void> _stopTracking() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A1A),
        title: const Text('Stop Tracking?'),
        content: const Text(
          'All pending reminders will be cancelled. Today\'s logged slots are kept.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text(
              'Stop',
              style: TextStyle(color: Color(0xFFFF4444)),
            ),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() => _isStopping = true);
    try {
      await TrackerService.instance.stop();
      await _loadState();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Could not stop tracking: $e'),
            backgroundColor: const Color(0xFFFF4444),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isStopping = false);
    }
  }

  Future<void> _goToSlotOutput(TrackerSlotModel slot) async {
    final logged = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => SlotOutputScreen(slot: slot)),
    );
    if (logged == true) await _loadState();
  }

  Future<void> _pickInterval() async {
    final result = await DurationPickerWidget.showPicker(
      context: context,
      initialHours: _pickedDuration.hours,
      initialMinutes: _pickedDuration.minutes,
    );
    if (result != null) {
      setState(() => _pickedDuration = result);
    }
  }

  // ── Helpers ────────────────────────────────────────────────────────────

  String _formatTime(int minutes) {
    if (minutes < 60) return '${minutes}m';
    final h = minutes ~/ 60;
    final m = minutes % 60;
    return m == 0 ? '${h}h' : '${h}h ${m}m';
  }

  String _formatStartedAt(DateTime dt) {
    final h = dt.hour % 12 == 0 ? 12 : dt.hour % 12;
    final m = dt.minute.toString().padLeft(2, '0');
    final period = dt.hour >= 12 ? 'PM' : 'AM';
    return '$h:$m $period';
  }

  // ── Build ──────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Time Tracker')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Colors.white))
          : SafeArea(
              child: _isActive ? _buildActiveState() : _buildSetupState(),
            ),
    );
  }

  // ── Setup state ────────────────────────────────────────────────────────
  Widget _buildSetupState() {
    final totalMinutes = _pickedDuration.totalMinutes;
    final isValid = totalMinutes >= 15;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 16),
          Text(
            'Focus Interval',
            style: Theme.of(context).textTheme.headlineMedium,
          ),
          const SizedBox(height: 16),
          Text(
            'Set how often you want to be reminded to log your output. '
            'After each interval, we\'ll send a notification asking what you produced.',
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: Colors.white70,
                ),
          ),
          const SizedBox(height: 12),
          Text(
            'Minimum interval: 15 minutes.',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Colors.white38,
                ),
          ),
          const SizedBox(height: 48),
          Text(
            'INTERVAL',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Colors.white60,
                  fontSize: 11,
                  letterSpacing: 1.2,
                ),
          ),
          const SizedBox(height: 8),
          GestureDetector(
            onTap: _pickInterval,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                color: const Color(0xFF111111),
                border: Border.all(
                  color: isValid
                      ? const Color(0xFF444444)
                      : const Color(0xFFFF4444).withOpacity(0.5),
                ),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    totalMinutes > 0
                        ? _pickedDuration.formatted
                        : 'Tap to set interval',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color:
                              isValid ? Colors.white : const Color(0xFF888888),
                          fontSize: 15,
                        ),
                  ),
                  const Icon(
                    Icons.schedule,
                    size: 18,
                    color: Color(0xFF888888),
                  ),
                ],
              ),
            ),
          ),
          if (!isValid && totalMinutes > 0) ...[
            const SizedBox(height: 6),
            Text(
              'Must be at least 15 minutes',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: const Color(0xFFFF4444),
                    fontSize: 11,
                  ),
            ),
          ],
          const SizedBox(height: 48),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF111111),
              border: Border.all(color: const Color(0xFF2A2A2A)),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(
                  Icons.notifications_none,
                  size: 18,
                  color: Color(0xFF888888),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'We\'ll ask for notification permission. If denied, you can '
                    'still open the app to log your output manually.',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Colors.white54,
                          height: 1.5,
                        ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 48),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: (!isValid || _isStarting) ? null : _startTracking,
              child: _isStarting
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.black,
                      ),
                    )
                  : const Text('Start Tracking'),
            ),
          ),
        ],
      ),
    );
  }

  // ── Active state ───────────────────────────────────────────────────────
  Widget _buildActiveState() {
    final logged = _slots.where((s) => s.isLogged).length;
    final total = _slots.length;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 16),
          Row(
            children: [
              Text(
                'Tracking',
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      color: const Color(0xFF4CAF50),
                    ),
              ),
              const SizedBox(width: 10),
              _PulseDot(),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Every ${_formatTime(_intervalMinutes)}',
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: Colors.white70,
                ),
          ),
          if (_startedAt != null) ...[
            const SizedBox(height: 4),
            Text(
              'Started at ${_formatStartedAt(_startedAt!)}',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Colors.white38,
                  ),
            ),
          ],
          const SizedBox(height: 32),
          const Divider(),
          const SizedBox(height: 32),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                "Today's slots",
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              Text(
                '$logged / $total logged',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Colors.white38,
                    ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (_slots.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 24),
              child: Text(
                'Your first slot is in progress. Come back when the timer fires.',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Colors.white38,
                    ),
              ),
            )
          else
            ..._slots.map((slot) => _buildSlotCard(slot)).toList(),
          const SizedBox(height: 48),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: _isStopping ? null : _stopTracking,
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFFFF4444),
                side: const BorderSide(color: Color(0xFFFF4444)),
                padding:
                    const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
              ),
              child: _isStopping
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Color(0xFFFF4444),
                      ),
                    )
                  : const Text('Stop Tracking'),
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildSlotCard(TrackerSlotModel slot) {
    final isLogged = slot.isLogged;

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF0D0D0D),
        border: Border.all(
          color: isLogged ? const Color(0xFF2E5C2E) : const Color(0xFF2A2A2A),
        ),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Icon(
              isLogged
                  ? Icons.check_circle_outline
                  : Icons.radio_button_unchecked,
              size: 18,
              color:
                  isLogged ? const Color(0xFF4CAF50) : const Color(0xFF444444),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  slot.timeRange,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Colors.white60,
                        fontSize: 12,
                      ),
                ),
                const SizedBox(height: 4),
                if (isLogged) ...[
                  Text(
                    slot.outputText!,
                    style: Theme.of(context).textTheme.bodyLarge,
                  ),
                  if (slot.outputDurationMinutes != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      _formatTime(slot.outputDurationMinutes!),
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: Colors.white38,
                          ),
                    ),
                  ],
                ] else
                  Text(
                    'Not logged yet',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: const Color(0xFF555555),
                        ),
                  ),
              ],
            ),
          ),
          if (!isLogged)
            GestureDetector(
              onTap: () => _goToSlotOutput(slot),
              child: Padding(
                padding: const EdgeInsets.only(left: 12),
                child: Text(
                  'Log →',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Colors.white54,
                        fontSize: 13,
                      ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ── Pulsing green dot ──────────────────────────────────────────────────────
class _PulseDot extends StatefulWidget {
  @override
  State<_PulseDot> createState() => _PulseDotState();
}

class _PulseDotState extends State<_PulseDot>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
    _anim = Tween<double>(begin: 0.4, end: 1.0).animate(
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
    return FadeTransition(
      opacity: _anim,
      child: Container(
        width: 8,
        height: 8,
        decoration: const BoxDecoration(
          color: Color(0xFF4CAF50),
          shape: BoxShape.circle,
        ),
      ),
    );
  }
}
