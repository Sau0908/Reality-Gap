import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/day_model.dart';
import '../models/output_model.dart';

class StorageService {
  static final StorageService instance = StorageService._internal();
  StorageService._internal();

  SharedPreferences? _prefs;

  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
  }

  static const String _daysKey = 'days_data';
  static const String _permissionKey = 'usage_permission_granted';
  static const String _selectedAppsKey = 'selected_apps'; // ✅ new
  static const String _appsSelectedKey = 'apps_selection_done'; // ✅ new

  // ── Permission ──────────────────────────────────────────────
  Future<bool> hasUsagePermission() async {
    return _prefs?.getBool(_permissionKey) ?? false;
  }

  Future<void> setUsagePermission(bool granted) async {
    await _prefs?.setBool(_permissionKey, granted);
  }

  // ── App selection ────────────────────────────────────────────
  Future<bool> hasSelectedApps() async {
    return _prefs?.getBool(_appsSelectedKey) ?? false;
  }

  Future<List<String>> getSelectedApps() async {
    final json = _prefs?.getString(_selectedAppsKey);
    if (json == null || json.isEmpty) return [];
    try {
      return List<String>.from(jsonDecode(json));
    } catch (_) {
      return [];
    }
  }

  Future<void> saveSelectedApps(List<String> packageNames) async {
    await _prefs?.setString(_selectedAppsKey, jsonEncode(packageNames));
    await _prefs?.setBool(_appsSelectedKey, true);
  }

  // ── Days ─────────────────────────────────────────────────────
  Future<List<DayModel>> getAllDays() async {
    final String? jsonString = _prefs?.getString(_daysKey);
    if (jsonString == null || jsonString.isEmpty) return [];
    try {
      final List<dynamic> jsonList = jsonDecode(jsonString);
      return jsonList.map((json) => DayModel.fromJson(json)).toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> saveDays(List<DayModel> days) async {
    final jsonString = jsonEncode(days.map((d) => d.toJson()).toList());
    await _prefs?.setString(_daysKey, jsonString);
  }

  Future<DayModel> getToday() async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final allDays = await getAllDays();
    final todayData = allDays
        .where((d) =>
            d.date.year == today.year &&
            d.date.month == today.month &&
            d.date.day == today.day)
        .firstOrNull;
    return todayData ??
        DayModel(date: today, scrollTimeMinutes: 0, outputs: []);
  }

  Future<void> saveToday(DayModel today) async {
    final allDays = await getAllDays();
    allDays.removeWhere((d) =>
        d.date.year == today.date.year &&
        d.date.month == today.date.month &&
        d.date.day == today.date.day);
    allDays.add(today);
    allDays.sort((a, b) => b.date.compareTo(a.date));
    if (allDays.length > 30) allDays.removeRange(30, allDays.length);
    await saveDays(allDays);
  }

  Future<bool> addOutput(String text, int? durationMinutes) async {
    final today = await getToday();
    if (today.outputs.length >= 3) return false;
    final newOutput = OutputModel(
      text: text,
      durationMinutes: durationMinutes,
      timestamp: DateTime.now(),
    );
    await saveToday(today.copyWith(outputs: [...today.outputs, newOutput]));
    return true;
  }

  Future<void> updateScrollTime(int minutes) async {
    final today = await getToday();
    await saveToday(today.copyWith(scrollTimeMinutes: minutes));
  }

  Future<List<DayModel>> getLast7Days() async {
    final allDays = await getAllDays();
    final sevenDaysAgo = DateTime.now().subtract(const Duration(days: 7));
    return allDays.where((d) => d.date.isAfter(sevenDaysAgo)).toList()
      ..sort((a, b) => b.date.compareTo(a.date));
  }

  Future<void> resetAllData() async {
    await _prefs?.remove(_daysKey);
    await _prefs?.remove(_permissionKey);
    await _prefs?.remove(_selectedAppsKey);
    await _prefs?.remove(_appsSelectedKey);
  }
}
