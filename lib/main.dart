import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:reality_gap/app_shell.dart';
import 'screens/permissions_screen.dart';
import 'screens/app_selection_screen.dart';
import 'theme/app_theme.dart';
import 'services/storage_service.dart';
import 'services/usage_stats_service.dart';
import 'services/tracker_service.dart'; // ← new

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await StorageService.instance.init();

  // Initialise the notification plugin before runApp so the tap handler
  // is registered even when the app is launched cold from a notification.
  await TrackerService.instance.init();

  // Wire up notification tap → jump to Tracker tab (index 1)
  // Uses a GlobalKey so we can call setState outside the widget tree.
  TrackerService.onNotificationTap = (slotId) {
    AppNavigator.navigatorKey.currentState?.pushAndRemoveUntil(
      MaterialPageRoute(
        builder: (_) => const AppShell(initialIndex: 1),
      ),
      (route) => false,
    );
  };

  SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  runApp(const TimeTrackerApp());
}

class TimeTrackerApp extends StatelessWidget {
  const TimeTrackerApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Reality Gap',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.darkTheme,
      navigatorKey: AppNavigator.navigatorKey, // ← needed for cold-launch nav
      home: const AppNavigator(),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// AppNavigator — onboarding gate
// Shows permission screen → app selection → then the full shell
// ─────────────────────────────────────────────────────────────────────────────
class AppNavigator extends StatefulWidget {
  static final navigatorKey = GlobalKey<NavigatorState>();

  const AppNavigator({Key? key}) : super(key: key);

  @override
  State<AppNavigator> createState() => _AppNavigatorState();
}

class _AppNavigatorState extends State<AppNavigator>
    with WidgetsBindingObserver {
  bool _hasPermission = false;
  bool _hasSelectedApps = false;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _checkState();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Re-check when user comes back from Settings after granting permission
    if (state == AppLifecycleState.resumed && !_hasPermission) {
      _checkState();
    }
  }

  Future<void> _checkState() async {
    setState(() => _isLoading = true);

    final hasPermission = await UsageStatsService.instance.hasPermission();
    if (hasPermission) {
      await StorageService.instance.setUsagePermission(true);
    }
    final hasSelectedApps = await StorageService.instance.hasSelectedApps();

    setState(() {
      _hasPermission = hasPermission;
      _hasSelectedApps = hasSelectedApps;
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        backgroundColor: Colors.black,
        body: Center(child: CircularProgressIndicator(color: Colors.white)),
      );
    }

    // Step 1 — usage permission
    if (!_hasPermission) {
      return PermissionsScreen(
        onPermissionGranted: () => setState(() => _hasPermission = true),
      );
    }

    // Step 2 — tracked app selection
    if (!_hasSelectedApps) {
      return AppSelectionScreen(
        onSelectionSaved: () => setState(() => _hasSelectedApps = true),
      );
    }

    // Step 3 — main app with bottom nav
    return const AppShell();
  }
}
