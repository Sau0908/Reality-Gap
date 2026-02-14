import 'package:flutter/material.dart';
import '../models/app_info.dart';
import '../services/storage_service.dart';

class AppSelectionScreen extends StatefulWidget {
  final VoidCallback onSelectionSaved;
  final bool showBackButton;

  const AppSelectionScreen({
    Key? key,
    required this.onSelectionSaved,
    this.showBackButton = false,
  }) : super(key: key);

  @override
  State<AppSelectionScreen> createState() => _AppSelectionScreenState();
}

class _AppSelectionScreenState extends State<AppSelectionScreen> {
  final Set<String> _selected = {};
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _loadExisting();
  }

  Future<void> _loadExisting() async {
    final saved = await StorageService.instance.getSelectedApps();
    setState(() => _selected.addAll(saved));
  }

  Future<void> _save() async {
    if (_selected.isEmpty) return;
    setState(() => _isSaving = true);
    await StorageService.instance.saveSelectedApps(_selected.toList());
    if (mounted) {
      setState(() => _isSaving = false);
      widget.onSelectionSaved();
      if (widget.showBackButton) Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar:
          widget.showBackButton ? AppBar(title: const Text('Your Apps')) : null,
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

              Text('Where do you lose time?',
                  style: Theme.of(context).textTheme.headlineMedium),
              const SizedBox(height: 8),
              Text(
                'Select the apps you mindlessly scroll. We\'ll only track these.',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 32),

              // App grid
              Expanded(
                child: GridView.builder(
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    childAspectRatio: 2.8,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                  ),
                  itemCount: AppInfo.catalogue.length,
                  itemBuilder: (context, index) {
                    final app = AppInfo.catalogue[index];
                    final isSelected = _selected.contains(app.packageName);
                    return GestureDetector(
                      onTap: () => setState(() {
                        if (isSelected) {
                          _selected.remove(app.packageName);
                        } else {
                          _selected.add(app.packageName);
                        }
                      }),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 150),
                        decoration: BoxDecoration(
                          color: isSelected ? Colors.white : Colors.transparent,
                          border: Border.all(
                            color: isSelected
                                ? Colors.white
                                : const Color(0xFF444444),
                          ),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 8),
                        child: Row(
                          children: [
                            Text(app.emoji,
                                style: const TextStyle(fontSize: 18)),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                app.displayName,
                                style: TextStyle(
                                  color:
                                      isSelected ? Colors.black : Colors.white,
                                  fontWeight: isSelected
                                      ? FontWeight.w600
                                      : FontWeight.normal,
                                  fontSize: 14,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),

              const SizedBox(height: 16),

              // Selection count hint
              if (_selected.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Text(
                    '${_selected.length} app${_selected.length == 1 ? '' : 's'} selected',
                    style: Theme.of(context)
                        .textTheme
                        .bodyMedium
                        ?.copyWith(color: Colors.white38),
                  ),
                ),

              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: (_selected.isEmpty || _isSaving) ? null : _save,
                  child: _isSaving
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.black))
                      : const Text('Done'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
