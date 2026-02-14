import 'package:flutter/material.dart';
import '../services/usage_stats_service.dart';
import '../services/storage_service.dart';
import 'app_selection_screen.dart';

class PermissionsScreen extends StatefulWidget {
  final VoidCallback onPermissionGranted;
  final bool showBackButton;

  const PermissionsScreen({
    Key? key,
    required this.onPermissionGranted,
    this.showBackButton = false,
  }) : super(key: key);

  @override
  State<PermissionsScreen> createState() => _PermissionsScreenState();
}

class _PermissionsScreenState extends State<PermissionsScreen> {
  bool _isChecking = false;

  Future<void> _requestPermission() async {
    setState(() => _isChecking = true);
    await UsageStatsService.instance.requestPermission();
    await Future.delayed(const Duration(seconds: 1));
    final hasPermission = await UsageStatsService.instance.hasPermission();

    if (hasPermission) {
      await StorageService.instance.setUsagePermission(true);
      if (mounted) {
        setState(() => _isChecking = false);
        widget.onPermissionGranted();
        if (widget.showBackButton) Navigator.pop(context);
      }
    } else {
      if (mounted) {
        setState(() => _isChecking = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
                'Permission not granted. Please enable Usage Access in Settings.'),
            backgroundColor: Color(0xFFFF4444),
          ),
        );
      }
    }
  }

  Future<void> _resetData() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF333333),
        title: const Text('Reset All Data'),
        content: const Text(
            'This will delete all your logged outputs and reset the app. This cannot be undone.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child:
                const Text('Reset', style: TextStyle(color: Color(0xFFFF4444))),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await StorageService.instance.resetAllData();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('All data has been reset'),
            backgroundColor: Colors.white,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar:
          widget.showBackButton ? AppBar(title: const Text('Settings')) : null,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (!widget.showBackButton) ...[
                const SizedBox(height: 48),
                Text('Reality Gap',
                    style: Theme.of(context).textTheme.displayMedium),
                const SizedBox(height: 48),
              ],
              Text('Usage Access Required',
                  style: Theme.of(context).textTheme.headlineMedium),
              const SizedBox(height: 24),
              Text(
                'This app needs permission to access your device usage statistics to track screen time.',
                style: Theme.of(context).textTheme.bodyLarge,
              ),
              const SizedBox(height: 24),
              Text(
                'We do not block apps. We only show where your time goes.',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 48),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isChecking ? null : _requestPermission,
                  child: _isChecking
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.black))
                      : const Text('Grant Permission'),
                ),
              ),
              if (widget.showBackButton) ...[
                const SizedBox(height: 48),
                const Divider(),
                const SizedBox(height: 24),

                // ── Tracked Apps ────────────────────────────────
                Text('Tracked Apps',
                    style: Theme.of(context).textTheme.headlineMedium),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => AppSelectionScreen(
                            onSelectionSaved: () {},
                            showBackButton: true,
                          ),
                        ),
                      );
                    },
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Color(0xFF444444)),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 32, vertical: 16),
                    ),
                    child: const Text('Manage Apps'),
                  ),
                ),

                const SizedBox(height: 24),
                const Divider(),
                const SizedBox(height: 24),

                // ── Data Management ─────────────────────────────
                Text('Data Management',
                    style: Theme.of(context).textTheme.headlineMedium),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
                    onPressed: _resetData,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFFFF4444),
                      side: const BorderSide(color: Color(0xFFFF4444)),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 32, vertical: 16),
                    ),
                    child: const Text('Reset All Data'),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
