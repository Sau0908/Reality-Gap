import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/day_model.dart';
import '../models/app_info.dart';
import '../services/storage_service.dart';
import '../services/usage_stats_service.dart';

class WeeklySummaryScreen extends StatefulWidget {
  const WeeklySummaryScreen({Key? key}) : super(key: key);

  @override
  State<WeeklySummaryScreen> createState() => _WeeklySummaryScreenState();
}

class _WeeklySummaryScreenState extends State<WeeklySummaryScreen> {
  List<DayModel> _days = [];
  Map<String, int> _weeklyBreakdown = {};
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);

    final now = DateTime.now();
    final sevenDaysAgo = DateTime(now.year, now.month, now.day)
        .subtract(const Duration(days: 6));

    final results = await Future.wait([
      StorageService.instance.getLast7Days(),
      UsageStatsService.instance.getBreakdownForRange(sevenDaysAgo, now),
    ]);

    setState(() {
      _days = results[0] as List<DayModel>;
      _weeklyBreakdown = results[1] as Map<String, int>;
      _isLoading = false;
    });
  }

  String _formatTime(int minutes) {
    if (minutes < 60) return '${minutes}m';
    final hours = minutes ~/ 60;
    final mins = minutes % 60;
    return mins == 0 ? '${hours}h' : '${hours}h ${mins}m';
  }

  String _formatGap(int gap) {
    final absGap = gap.abs();
    final sign = gap < 0 ? '−' : '+';
    return '$sign${_formatTime(absGap)}';
  }

  int get _totalScrollTime =>
      _days.fold(0, (sum, day) => sum + day.scrollTimeMinutes);
  int get _totalOutputTime =>
      _days.fold(0, (sum, day) => sum + day.outputTimeMinutes);
  int get _netGap => _totalScrollTime - _totalOutputTime;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Weekly Summary')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Colors.white))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Last 7 Days',
                      style: Theme.of(context).textTheme.headlineMedium),
                  const SizedBox(height: 32),

                  _buildStatRow(
                      context, 'Total Scroll', _formatTime(_totalScrollTime)),
                  const SizedBox(height: 24),
                  _buildStatRow(
                      context, 'Total Output', _formatTime(_totalOutputTime)),
                  const SizedBox(height: 24),
                  const Divider(),
                  const SizedBox(height: 24),
                  _buildStatRow(context, 'Net Gap', _formatGap(_netGap),
                      isGap: true),

                  // ── Per-app weekly breakdown ──────────────────
                  if (_weeklyBreakdown.isNotEmpty) ...[
                    const SizedBox(height: 48),
                    Text('By App',
                        style: Theme.of(context).textTheme.headlineMedium),
                    const SizedBox(height: 16),
                    ..._buildAppBreakdown(context),
                  ],

                  const SizedBox(height: 48),

                  if (_days.isNotEmpty) ...[
                    Text('Daily Breakdown',
                        style: Theme.of(context).textTheme.titleLarge),
                    const SizedBox(height: 16),
                    ..._days.map((day) => _buildDayCard(context, day)).toList(),
                  ] else
                    Center(
                      child: Padding(
                        padding: const EdgeInsets.all(32),
                        child: Text('No data for the past 7 days',
                            style: Theme.of(context).textTheme.bodyMedium),
                      ),
                    ),
                ],
              ),
            ),
    );
  }

  List<Widget> _buildAppBreakdown(BuildContext context) {
    // Sort by most time first, filter out zero entries
    final entries = _weeklyBreakdown.entries.where((e) => e.value > 0).toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    if (entries.isEmpty) {
      return [
        Text('No usage recorded this week.',
            style: Theme.of(context)
                .textTheme
                .bodyMedium
                ?.copyWith(color: Colors.white38))
      ];
    }

    final maxVal = entries.first.value;

    return entries.map((entry) {
      final info = AppInfo.fromPackage(entry.key);
      final label = info != null
          ? '${info.emoji} ${info.displayName}'
          : entry.key.split('.').last;
      final fraction = maxVal > 0 ? entry.value / maxVal : 0.0;

      return Padding(
        padding: const EdgeInsets.only(bottom: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(label, style: Theme.of(context).textTheme.bodyLarge),
                Text(_formatTime(entry.value),
                    style: Theme.of(context).textTheme.bodyLarge),
              ],
            ),
            const SizedBox(height: 6),
            // Progress bar
            ClipRRect(
              borderRadius: BorderRadius.circular(2),
              child: LinearProgressIndicator(
                value: fraction,
                minHeight: 3,
                backgroundColor: const Color(0xFF333333),
                valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
              ),
            ),
          ],
        ),
      );
    }).toList();
  }

  Widget _buildStatRow(BuildContext context, String label, String value,
      {bool isGap = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.baseline,
      textBaseline: TextBaseline.alphabetic,
      children: [
        Text(label, style: Theme.of(context).textTheme.titleLarge),
        Text(
          value,
          style: isGap
              ? Theme.of(context).textTheme.displaySmall?.copyWith(
                  color: _netGap < 0 ? const Color(0xFFFF4444) : Colors.white)
              : Theme.of(context).textTheme.displaySmall,
        ),
      ],
    );
  }

  Widget _buildDayCard(BuildContext context, DayModel day) {
    final dateFormat = DateFormat('EEE, MMM d');
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: Border.all(color: const Color(0xFF333333)),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(dateFormat.format(day.date),
              style: Theme.of(context).textTheme.bodyMedium),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Scroll: ${_formatTime(day.scrollTimeMinutes)}',
                  style: Theme.of(context).textTheme.bodyLarge),
              Text('Output: ${_formatTime(day.outputTimeMinutes)}',
                  style: Theme.of(context).textTheme.bodyLarge),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Gap: ${_formatGap(day.realityGap)}',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: day.realityGap < 0
                      ? const Color(0xFFFF4444)
                      : const Color(0xFF666666),
                ),
          ),
        ],
      ),
    );
  }
}
