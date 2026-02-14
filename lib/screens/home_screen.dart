import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:reality_gap/screens/home/app_card.dart';
import 'package:reality_gap/screens/home/banner.dart';
import 'package:reality_gap/screens/home/gap_row.dart';
import 'package:reality_gap/screens/home/output_section.dart';
import 'package:reality_gap/screens/home/stat.dart';

import '../models/day_model.dart';
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

  Future<void> _goToLogOutput() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const LogOutputScreen()),
    );
    _loadData();
  }

  Future<void> _goToWeeklySummary() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const WeeklySummaryScreen()),
    );
    _loadData();
  }

  Future<void> _goToSettings() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PermissionsScreen(
          onPermissionGranted: () {},
          showBackButton: true,
        ),
      ),
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
        actions: [
          IconButton(
            icon: const Icon(Icons.calendar_today),
            onPressed: _goToWeeklySummary,
          ),
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: _goToSettings,
          ),
        ],
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
    final dateFormat = DateFormat('EEEE, MMMM d');

    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            dateFormat.format(DateTime.now()),
            style: Theme.of(context).textTheme.bodyMedium,
          ),
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
