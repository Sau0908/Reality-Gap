import 'package:flutter/material.dart';
import 'package:reality_gap/components/duration_picker.dart';
import '../services/storage_service.dart';

class LogOutputScreen extends StatefulWidget {
  const LogOutputScreen({Key? key}) : super(key: key);

  @override
  State<LogOutputScreen> createState() => _LogOutputScreenState();
}

class _LogOutputScreenState extends State<LogOutputScreen> {
  final _formKey = GlobalKey<FormState>();
  final _textController = TextEditingController();
  bool _isLoading = false;

  // null = not yet picked; required before save
  DurationResult? _selectedDuration;

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  Future<void> _pickDuration() async {
    final result = await DurationPickerWidget.showPicker(
      context: context,
      initialHours: _selectedDuration?.hours ?? 0,
      initialMinutes: _selectedDuration?.minutes ?? 0,
    );
    // result is null if sheet was dismissed without confirming — keep old value
    if (result != null) {
      setState(() => _selectedDuration = result);
    }
  }

  Future<void> _saveOutput() async {
    if (!_formKey.currentState!.validate()) return;

    // Duration is mandatory
    if (_selectedDuration == null || _selectedDuration!.totalMinutes == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please set a duration before saving'),
          backgroundColor: Color(0xFFFF4444),
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    final success = await StorageService.instance.addOutput(
      _textController.text.trim(),
      _selectedDuration!.totalMinutes,
    );

    setState(() => _isLoading = false);

    if (!mounted) return;

    if (success) {
      Navigator.pop(context);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Maximum 6 outputs per day'),
          backgroundColor: Color(0xFFFF4444),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final hasDuration =
        _selectedDuration != null && _selectedDuration!.totalMinutes > 0;

    return Scaffold(
      appBar: AppBar(title: const Text('Log Output')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'What did you actually produce?',
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              const SizedBox(height: 32),

              // ── Description (mandatory) ────────────────────────────────
              TextFormField(
                controller: _textController,
                decoration: const InputDecoration(
                  hintText: 'Describe what you produced',
                ),
                maxLines: 3,
                maxLength: 200,
                textCapitalization: TextCapitalization.sentences,
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Description is required';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 24),

              // ── Duration (mandatory) ───────────────────────────────────
              Text(
                'DURATION',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Colors.white60,
                      fontSize: 11,
                      letterSpacing: 1.2,
                    ),
              ),
              const SizedBox(height: 8),

              GestureDetector(
                onTap: _pickDuration,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: double.infinity,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  decoration: BoxDecoration(
                    color: const Color(0xFF111111),
                    border: Border.all(
                      color: hasDuration
                          ? const Color(0xFF444444)
                          : const Color(0xFF2A2A2A),
                    ),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        // Shows formatted value once picked, placeholder before
                        hasDuration
                            ? _selectedDuration!.formatted
                            : 'Tap to set duration',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: hasDuration
                                  ? Colors.white
                                  : const Color(0xFF555555),
                              fontSize: 15,
                            ),
                      ),
                      Icon(
                        Icons.schedule,
                        size: 18,
                        color: hasDuration
                            ? const Color(0xFF888888)
                            : const Color(0xFF3A3A3A),
                      ),
                    ],
                  ),
                ),
              ),

              if (!hasDuration) ...[
                const SizedBox(height: 6),
                Text(
                  'Required',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: const Color(0xFF555555),
                        fontSize: 11,
                      ),
                ),
              ],

              const SizedBox(height: 48),

              // ── Save ───────────────────────────────────────────────────
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _saveOutput,
                  child: _isLoading
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.black,
                          ),
                        )
                      : const Text('Save'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
