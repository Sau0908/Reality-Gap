import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/day_model.dart';
import '../services/storage_service.dart';
import '../services/usage_stats_service.dart';

import 'log_output_screen.dart';

import 'home/stat.dart';
import 'home/app_card.dart';
import 'home/gap_row.dart';
import 'home/banner.dart';
import 'home/output_section.dart';

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

  Future<void> _goToLogOutput() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const LogOutputScreen()),
    );
    _loadData();
  }

  String _formatTime(int minutes) {
    if (minutes < 60) return '${minutes}m';
    final hours = minutes ~/ 60;
    final mins = minutes % 60;
    return mins == 0 ? '${hours}h' : '${hours}h ${mins}m';
  }

  int get _scrollMinutes => _today?.scrollTimeMinutes ?? 0;
  int get _outputMinutes => _today?.outputTimeMinutes ?? 0;
  int get _gap => _today?.realityGap ?? 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Reality Gap'),
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: Colors.white),
            )
          : RefreshIndicator(
              onRefresh: _loadData,
              color: Colors.white,
              backgroundColor: Colors.black,
              child: _buildBody(context),
            ),
    );
  }

  Widget _buildBody(BuildContext context) {
    final now = DateTime.now();

    // e.g. "MON" and "Jan 6"
    final dayName = DateFormat('EEE').format(now).toUpperCase();
    final monthDay = DateFormat('MMM d').format(now);

    // "Today" only — no need to show year on the home screen
    final isToday = true;

    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Date pill ────────────────────────────────────────────────────
          _DateChip(dayName: dayName, monthDay: monthDay, isToday: isToday),
          const SizedBox(height: 48),
          StatRow(label: 'Scroll', value: _formatTime(_scrollMinutes)),
          const SizedBox(height: 12),
          AppBreakdownCards(breakdown: _breakdown),
          const SizedBox(height: 32),
          StatRow(label: 'Output', value: _formatTime(_outputMinutes)),
          const SizedBox(height: 32),
          const Divider(),
          const SizedBox(height: 32),
          GapRow(gap: _gap),
          const SizedBox(height: 16),
          EncouragementBanner(
            scrollMinutes: _scrollMinutes,
            outputMinutes: _outputMinutes,
            gap: _gap,
          ),
          const SizedBox(height: 48),
          OutputsSection(
            outputs: _today?.outputs ?? [],
            onLogPressed: _goToLogOutput,
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}

class _DateChip extends StatelessWidget {
  final String dayName;
  final String monthDay;
  final bool isToday;

  const _DateChip({
    required this.dayName,
    required this.monthDay,
    required this.isToday,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A1A),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF2E2E2E)),
      ),
      child: Row(
        children: [
          // Day abbreviation — dimmer, acts as a label
          Text(
            dayName,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              letterSpacing: 1.0,
              color: Color(0xFF666666),
            ),
          ),
          // Subtle separator dot
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 8),
            child: Text(
              '·',
              style: TextStyle(
                fontSize: 14,
                color: Color(0xFF444444),
              ),
            ),
          ),
          // Month + day — brighter
          Text(
            monthDay,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: Color(0xFFCCCCCC),
              letterSpacing: 0.2,
            ),
          ),
          const Spacer(),
          // "Today" accent dot — only shown when viewing current day
          if (isToday)
            Row(
              children: [
                const Text(
                  'Today',
                  style: TextStyle(
                    fontSize: 12,
                    color: Color(0xFF4CAF50),
                    fontWeight: FontWeight.w500,
                    letterSpacing: 0.2,
                  ),
                ),
                const SizedBox(width: 6),
                Container(
                  width: 6,
                  height: 6,
                  decoration: const BoxDecoration(
                    color: Color(0xFF4CAF50),
                    shape: BoxShape.circle,
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }
}
