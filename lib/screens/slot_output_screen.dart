// screens/slot_output_screen.dart

import 'package:flutter/material.dart';
import '../models/tracker_slot_model.dart';
import '../services/tracker_service.dart';
import '../components/duration_picker.dart';

/// Opened when a Time Tracker notification is tapped, or when the user
/// taps [Log →] on an unlogged slot card inside TimeTrackerScreen.
///
/// Pre-fills the duration with the slot's interval length but lets the
/// user adjust it. Output text is required before saving.
class SlotOutputScreen extends StatefulWidget {
  final TrackerSlotModel slot;

  const SlotOutputScreen({Key? key, required this.slot}) : super(key: key);

  @override
  State<SlotOutputScreen> createState() => _SlotOutputScreenState();
}

class _SlotOutputScreenState extends State<SlotOutputScreen> {
  final _formKey = GlobalKey<FormState>();
  final _textController = TextEditingController();
  bool _isLoading = false;

  // Pre-fill with slot interval — user can still change it
  late DurationResult _selectedDuration;

  @override
  void initState() {
    super.initState();
    _selectedDuration = DurationResult(
      hours: widget.slot.intervalMinutes ~/ 60,
      minutes: widget.slot.intervalMinutes % 60,
    );
  }

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  Future<void> _pickDuration() async {
    final result = await DurationPickerWidget.showPicker(
      context: context,
      initialHours: _selectedDuration.hours,
      initialMinutes: _selectedDuration.minutes,
    );
    if (result != null) {
      setState(() => _selectedDuration = result);
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    if (_selectedDuration.totalMinutes == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please set a duration'),
          backgroundColor: Color(0xFFFF4444),
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    await TrackerService.instance.addSlotOutput(
      widget.slot.id,
      _textController.text.trim(),
      _selectedDuration.totalMinutes,
    );

    // Schedule the next interval now that this slot is logged
    await TrackerService.instance.scheduleNextAfterSlot();

    setState(() => _isLoading = false);
    if (!mounted) return;
    Navigator.pop(context, true); // true = logged successfully
  }

  @override
  Widget build(BuildContext context) {
    final hasDuration = _selectedDuration.totalMinutes > 0;

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.slot.timeRange),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Slot context ─────────────────────────────────────────────
              Text(
                'What did you produce?',
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              const SizedBox(height: 8),
              Text(
                '${widget.slot.intervalMinutes}m focus slot',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Colors.white38,
                    ),
              ),
              const SizedBox(height: 32),

              // ── Output description ────────────────────────────────────────
              TextFormField(
                controller: _textController,
                decoration: const InputDecoration(
                  hintText: 'Describe what you produced',
                ),
                maxLines: 3,
                maxLength: 200,
                textCapitalization: TextCapitalization.sentences,
                validator: (v) {
                  if (v == null || v.trim().isEmpty) {
                    return 'Description is required';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 24),

              // ── Duration ──────────────────────────────────────────────────
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
                        _selectedDuration.formatted,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: Colors.white,
                              fontSize: 15,
                            ),
                      ),
                      const Icon(
                        Icons.schedule,
                        size: 18,
                        color: Color(0xFF888888),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 48),

              // ── Save ──────────────────────────────────────────────────────
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _save,
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
