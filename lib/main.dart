import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'screens/home_screen.dart';
import 'screens/permissions_screen.dart';
import 'screens/app_selection_screen.dart';
import 'theme/app_theme.dart';
import 'services/storage_service.dart';
import 'services/usage_stats_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await StorageService.instance.init();
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
      home: const AppNavigator(),
    );
  }
}

class AppNavigator extends StatefulWidget {
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

    // Step 1 — permission
    if (!_hasPermission) {
      return PermissionsScreen(
        onPermissionGranted: () => setState(() => _hasPermission = true),
      );
    }

    // Step 2 — app selection
    if (!_hasSelectedApps) {
      return AppSelectionScreen(
        onSelectionSaved: () => setState(() => _hasSelectedApps = true),
      );
    }

    // Step 3 — home
    return const HomeScreen();
  }
}
