import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/day_model.dart';
import '../models/app_info.dart';
import '../services/storage_service.dart';
import '../services/usage_stats_service.dart';
import 'log_output_screen.dart';
import 'weekly_summary_screen.dart';
import 'permissions_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({Key? key}) : super(key: key);

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  DayModel? _today;
  Map<String, int> _breakdown = {};
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);

    final today = await StorageService.instance.getToday();

    final results = await Future.wait([
      UsageStatsService.instance.getTodayScreenTime(),
      UsageStatsService.instance.getTodayBreakdown(),
    ]);

    final screenTime = results[0] as int;
    final breakdown = results[1] as Map<String, int>;

    final updatedToday = today.copyWith(scrollTimeMinutes: screenTime);
    await StorageService.instance.saveToday(updatedToday);

    setState(() {
      _today = updatedToday;
      _breakdown = breakdown;
      _isLoading = false;
    });
  }

  String _formatTime(int minutes) {
    if (minutes < 60) return '${minutes}m';
    final hours = minutes ~/ 60;
    final mins = minutes % 60;
    return mins == 0 ? '${hours}h' : '${hours}h ${mins}m';
  }

  // Gap is always shown as positive — framing changes instead
  String _formatGap(int gap) {
    final absGap = gap.abs();
    return _formatTime(absGap);
  }

  // Positive gap = output > scroll (winning), negative = losing
  bool get _isWinning => (_today?.realityGap ?? 0) <= 0;

  String get _gapLabel {
    final gap = _today?.realityGap ?? 0;
    if (gap == 0) return 'Balanced';
    return _isWinning ? 'Ahead' : 'Gap';
  }

  String get _encouragementText {
    final gap = _today?.realityGap ?? 0;
    final scroll = _today?.scrollTimeMinutes ?? 0;
    final output = _today?.outputTimeMinutes ?? 0;

    if (output == 0 && scroll == 0) return 'Log your first output today.';
    if (output == 0) return 'You\'ve been scrolling. Time to create something.';
    if (gap == 0) return 'Perfectly balanced. Keep going.';

    if (_isWinning) {
      final aheadMins = gap.abs();
      if (aheadMins < 30) return 'Slightly ahead. Solid start.';
      if (aheadMins < 60) return 'Output is winning. Keep the streak.';
      return 'You\'re crushing it today. 🔥';
    } else {
      final behindMins = gap;
      if (behindMins < 30) return 'Close. One more output closes the gap.';
      if (behindMins < 60) return 'Scroll is winning. Log what you\'ve done.';
      return 'Big gap today. Small outputs count too.';
    }
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final dateFormat = DateFormat('EEEE, MMMM d');

    return Scaffold(
      appBar: AppBar(
        title: const Text('Reality Gap'),
        actions: [
          IconButton(
            icon: const Icon(Icons.calendar_today),
            onPressed: () async {
              await Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (context) => const WeeklySummaryScreen()),
              );
              _loadData();
            },
          ),
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () async {
              await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => PermissionsScreen(
                    onPermissionGranted: () {},
                    showBackButton: true,
                  ),
                ),
              );
              _loadData();
            },
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Colors.white))
          : RefreshIndicator(
              onRefresh: _loadData,
              color: Colors.white,
              backgroundColor: Colors.black,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      dateFormat.format(now),
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    const SizedBox(height: 48),

                    // ── Scroll ──────────────────────────────────
                    _buildStatRow(
                      context,
                      'Scroll',
                      _formatTime(_today?.scrollTimeMinutes ?? 0),
                    ),
                    const SizedBox(height: 12),

                    // ── App breakdown cards ─────────────────────
                    _buildAppBreakdownCards(context),

                    const SizedBox(height: 32),

                    // ── Output ──────────────────────────────────
                    _buildStatRow(
                      context,
                      'Output',
                      _formatTime(_today?.outputTimeMinutes ?? 0),
                    ),
                    const SizedBox(height: 32),

                    // ── Gap ─────────────────────────────────────
                    const Divider(),
                    const SizedBox(height: 32),
                    _buildGapRow(context),
                    const SizedBox(height: 16),

                    // ── Encouragement ────────────────────────────
                    _buildEncouragementBanner(context),

                    const SizedBox(height: 48),

                    // ── Outputs logged ───────────────────────────
                    Text(
                      'Outputs today: ${_today?.outputs.length ?? 0}/6',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    const SizedBox(height: 16),

                    if (_today?.outputs.isNotEmpty ?? false)
                      ..._today!.outputs
                          .map((o) => _buildOutputCard(context, o))
                          .toList(),

                    const SizedBox(height: 32),

                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: (_today?.outputs.length ?? 0) < 6
                            ? () async {
                                await Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => const LogOutputScreen(),
                                  ),
                                );
                                _loadData();
                              }
                            : null,
                        child: const Text('Log Output'),
                      ),
                    ),

                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
    );
  }

  // ── Per-app cards below Scroll ────────────────────────────────
  Widget _buildAppBreakdownCards(BuildContext context) {
    final entries = _breakdown.entries.where((e) => e.value > 0).toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    if (entries.isEmpty) return const SizedBox.shrink();

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: entries.map((entry) {
        final info = AppInfo.fromPackage(entry.key);
        final label = info != null
            ? '${info.emoji} ${info.displayName}'
            : entry.key.split('.').last;

        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            border: Border.all(color: const Color(0xFF333333)),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Colors.white60,
                      fontSize: 13,
                    ),
              ),
              const SizedBox(width: 8),
              Text(
                _formatTime(entry.value),
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  // ── Gap row — always positive, label changes ──────────────────
  Widget _buildGapRow(BuildContext context) {
    final gapColor = _isWinning
        ? const Color(0xFF4CAF50) // green when winning
        : const Color(0xFFFF4444); // red when behind

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.baseline,
      textBaseline: TextBaseline.alphabetic,
      children: [
        Text(
          _gapLabel,
          style: Theme.of(context).textTheme.headlineMedium,
        ),
        Text(
          _formatGap(_today?.realityGap ?? 0),
          style: Theme.of(context).textTheme.displayMedium?.copyWith(
                color: gapColor,
              ),
        ),
      ],
    );
  }

  // ── Encouragement banner ──────────────────────────────────────
  Widget _buildEncouragementBanner(BuildContext context) {
    final isWinning = _isWinning;
    final gap = _today?.realityGap ?? 0;
    final hasAnyData = (_today?.scrollTimeMinutes ?? 0) > 0 ||
        (_today?.outputTimeMinutes ?? 0) > 0;

    if (!hasAnyData) return const SizedBox.shrink();

    final bgColor = isWinning
        ? const Color(0xFF1A2E1A) // dark green tint
        : const Color(0xFF2E1A1A); // dark red tint
    final borderColor =
        isWinning ? const Color(0xFF2E5C2E) : const Color(0xFF5C2E2E);
    final textColor =
        isWinning ? const Color(0xFF81C784) : const Color(0xFFEF9A9A);

    // Show progress bar only when there's scroll data
    final scroll = _today?.scrollTimeMinutes ?? 0;
    final output = _today?.outputTimeMinutes ?? 0;
    final total = scroll + output;
    final outputFraction = total > 0 ? (output / total).clamp(0.0, 1.0) : 0.0;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: bgColor,
        border: Border.all(color: borderColor),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _encouragementText,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: textColor,
                ),
          ),
          if (gap != 0) ...[
            const SizedBox(height: 12),
            // Output vs Scroll bar
            ClipRRect(
              borderRadius: BorderRadius.circular(2),
              child: LinearProgressIndicator(
                value: outputFraction,
                minHeight: 3,
                backgroundColor: const Color(0x33FFFFFF),
                valueColor: AlwaysStoppedAnimation<Color>(
                  isWinning ? const Color(0xFF81C784) : const Color(0xFFEF9A9A),
                ),
              ),
            ),
            const SizedBox(height: 6),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Output ${(outputFraction * 100).round()}%',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Colors.white38,
                        fontSize: 11,
                      ),
                ),
                Text(
                  'Scroll ${((1 - outputFraction) * 100).round()}%',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Colors.white38,
                        fontSize: 11,
                      ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildStatRow(BuildContext context, String label, String value,
      {bool isGap = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.baseline,
      textBaseline: TextBaseline.alphabetic,
      children: [
        Text(label, style: Theme.of(context).textTheme.headlineMedium),
        Text(value, style: Theme.of(context).textTheme.displayMedium),
      ],
    );
  }

  Widget _buildOutputCard(BuildContext context, output) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: Border.all(color: const Color(0xFF333333)),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(output.text, style: Theme.of(context).textTheme.bodyLarge),
          if (output.durationMinutes != null) ...[
            const SizedBox(height: 8),
            Text(
              _formatTime(output.durationMinutes!),
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ],
        ],
      ),
    );
  }
}
