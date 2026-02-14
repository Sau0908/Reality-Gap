import 'package:usage_stats/usage_stats.dart';
import 'storage_service.dart';

class UsageStatsService {
  static final UsageStatsService instance = UsageStatsService._internal();
  UsageStatsService._internal();

  Future<bool> hasPermission() async {
    try {
      return await UsageStats.checkUsagePermission() ?? false;
    } catch (_) {
      return false;
    }
  }

  Future<void> requestPermission() async {
    try {
      await UsageStats.grantUsagePermission();
    } catch (_) {}
  }

  Future<Set<String>> _getTrackedPackages() async {
    final saved = await StorageService.instance.getSelectedApps();
    return saved.toSet();
  }

  // ── Core: calculate per-app time from raw events ──────────────
  //
  // queryUsageStats returns cumulative/unreliable totals on many
  // Android versions. Instead we pull raw FOREGROUND/BACKGROUND
  // events and sum only the sessions that fall within [start, end].
  Future<Map<String, int>> _calcBreakdown(
      DateTime start, DateTime end, Set<String> packages) async {
    try {
      final events = await UsageStats.queryEvents(start, end) ?? [];
      final result = <String, int>{for (final p in packages) p: 0};

      // Track when each package moved to foreground
      final Map<String, DateTime> foregroundStart = {};

      for (final event in events) {
        final pkg = event.packageName ?? '';
        if (!packages.contains(pkg)) continue;

        final ts = event.timeStamp;
        if (ts == null) continue;

        // timeStamp comes as milliseconds-since-epoch string on some versions
        DateTime? eventTime;
        try {
          final ms = int.parse(ts);
          eventTime = DateTime.fromMillisecondsSinceEpoch(ms);
        } catch (_) {
          try {
            eventTime = DateTime.parse(ts);
          } catch (_) {
            continue;
          }
        }

        final eventType = event.eventType;

        // MOVE_TO_FOREGROUND = "1", MOVE_TO_BACKGROUND = "2"
        if (eventType == '1') {
          foregroundStart[pkg] = eventTime;
        } else if (eventType == '2') {
          final fgStart = foregroundStart[pkg];
          if (fgStart != null) {
            final sessionMs = eventTime.millisecondsSinceEpoch -
                fgStart.millisecondsSinceEpoch;
            if (sessionMs > 0) {
              result[pkg] =
                  (result[pkg] ?? 0) + (sessionMs / 1000 / 60).round();
            }
            foregroundStart.remove(pkg);
          }
        }
      }

      // If an app is still in foreground at query time, count up to `end`
      for (final entry in foregroundStart.entries) {
        final pkg = entry.key;
        final fgStart = entry.value;
        final sessionMs =
            end.millisecondsSinceEpoch - fgStart.millisecondsSinceEpoch;
        if (sessionMs > 0) {
          result[pkg] = (result[pkg] ?? 0) + (sessionMs / 1000 / 60).round();
        }
      }

      return result;
    } catch (_) {
      return {for (final p in packages) p: 0};
    }
  }

  // ── Today ─────────────────────────────────────────────────────
  Future<int> getTodayScreenTime() async {
    final breakdown = await getTodayBreakdown();
    return breakdown.values.fold<int>(0, (sum, v) => sum + v);
  }

  Future<Map<String, int>> getTodayBreakdown() async {
    final packages = await _getTrackedPackages();
    if (packages.isEmpty) return {};
    final now = DateTime.now();
    final startOfDay = DateTime(now.year, now.month, now.day);
    return _calcBreakdown(startOfDay, now, packages);
  }

  // ── Arbitrary range ───────────────────────────────────────────
  Future<int> getScreenTimeForRange(DateTime start, DateTime end) async {
    final breakdown = await getBreakdownForRange(start, end);
    return breakdown.values.fold<int>(0, (sum, v) => sum + v);
  }

  Future<Map<String, int>> getBreakdownForRange(
      DateTime start, DateTime end) async {
    final packages = await _getTrackedPackages();
    if (packages.isEmpty) return {};
    return _calcBreakdown(start, end, packages);
  }
}
