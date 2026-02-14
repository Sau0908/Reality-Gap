import 'package:flutter/material.dart';

// ─────────────────────────────────────────────────────────────────────────────
// DurationPickerWidget — scroll-wheel style hour + minute picker
//
// Usage (inline):
//   DurationPickerWidget(
//     initialHours: 0,
//     initialMinutes: 30,
//     onChanged: (hours, minutes) { ... },
//   )
//
// Usage (bottom-sheet modal):
//   final result = await DurationPickerWidget.showPicker(
//     context: context,
//     initialHours: 0,
//     initialMinutes: 0,
//   );
//   if (result != null) print(result.formatted); // e.g. "1h 30m"
// ─────────────────────────────────────────────────────────────────────────────

class DurationResult {
  final int hours;
  final int minutes;

  const DurationResult({required this.hours, required this.minutes});

  int get totalMinutes => hours * 60 + minutes;

  String get formatted {
    if (hours == 0 && minutes == 0) return '0m';
    if (hours == 0) return '${minutes}m';
    if (minutes == 0) return '${hours}h';
    return '${hours}h ${minutes}m';
  }

  @override
  String toString() => formatted;
}

// ─────────────────────────────────────────────────────────────────────────────
// Public widget — inline embed only (no confirm button here)
// The sheet below owns the confirm button so it always reads fresh state.
// ─────────────────────────────────────────────────────────────────────────────
class DurationPickerWidget extends StatefulWidget {
  final int initialHours;
  final int initialMinutes;
  final void Function(int hours, int minutes)? onChanged;

  const DurationPickerWidget({
    Key? key,
    this.initialHours = 0,
    this.initialMinutes = 0,
    this.onChanged,
  }) : super(key: key);

  /// Opens a bottom-sheet and returns the selected [DurationResult],
  /// or null if the user dismisses without confirming.
  static Future<DurationResult?> showPicker({
    required BuildContext context,
    int initialHours = 0,
    int initialMinutes = 0,
  }) {
    return showModalBottomSheet<DurationResult>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => _DurationPickerSheet(
        initialHours: initialHours,
        initialMinutes: initialMinutes,
      ),
    );
  }

  @override
  State<DurationPickerWidget> createState() => _DurationPickerWidgetState();
}

class _DurationPickerWidgetState extends State<DurationPickerWidget> {
  late int _hours;
  late int _minutes;

  late FixedExtentScrollController _hourController;
  late FixedExtentScrollController _minuteController;

  @override
  void initState() {
    super.initState();
    _hours = widget.initialHours.clamp(0, 23);
    _minutes = widget.initialMinutes.clamp(0, 59);
    _hourController = FixedExtentScrollController(initialItem: _hours);
    _minuteController = FixedExtentScrollController(initialItem: _minutes);
  }

  @override
  void dispose() {
    _hourController.dispose();
    _minuteController.dispose();
    super.dispose();
  }

  void _onHourChanged(int index) {
    _hours = index;
    widget.onChanged?.call(_hours, _minutes);
  }

  void _onMinuteChanged(int index) {
    _minutes = index;
    widget.onChanged?.call(_hours, _minutes);
  }

  @override
  Widget build(BuildContext context) {
    const double itemHeight = 48.0;
    const double pickerHeight = itemHeight * 5;

    return SizedBox(
      height: pickerHeight,
      child: Row(
        children: [
          // ── Hours wheel ────────────────────────────────────────────────
          Expanded(
            child: Stack(
              alignment: Alignment.center,
              children: [
                const _SelectionBand(itemHeight: itemHeight),
                ListWheelScrollView.useDelegate(
                  controller: _hourController,
                  itemExtent: itemHeight,
                  physics: const FixedExtentScrollPhysics(),
                  perspective: 0.003,
                  diameterRatio: 2.5,
                  onSelectedItemChanged: _onHourChanged,
                  childDelegate: ListWheelChildBuilderDelegate(
                    childCount: 24,
                    builder: (context, index) => _WheelItem(
                      label: index.toString().padLeft(2, '0'),
                      unit: 'h',
                      isSelected: index == _hours,
                    ),
                  ),
                ),
              ],
            ),
          ),

          const _Separator(),

          // ── Minutes wheel ──────────────────────────────────────────────
          Expanded(
            child: Stack(
              alignment: Alignment.center,
              children: [
                const _SelectionBand(itemHeight: itemHeight),
                ListWheelScrollView.useDelegate(
                  controller: _minuteController,
                  itemExtent: itemHeight,
                  physics: const FixedExtentScrollPhysics(),
                  perspective: 0.003,
                  diameterRatio: 2.5,
                  onSelectedItemChanged: _onMinuteChanged,
                  childDelegate: ListWheelChildBuilderDelegate(
                    childCount: 60,
                    builder: (context, index) => _WheelItem(
                      label: index.toString().padLeft(2, '0'),
                      unit: 'm',
                      isSelected: index == _minutes,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Single row in a wheel column
// ─────────────────────────────────────────────────────────────────────────────
class _WheelItem extends StatelessWidget {
  final String label;
  final String unit;
  final bool isSelected;

  const _WheelItem({
    required this.label,
    required this.unit,
    required this.isSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.baseline,
        textBaseline: TextBaseline.alphabetic,
        children: [
          AnimatedDefaultTextStyle(
            duration: const Duration(milliseconds: 150),
            style: TextStyle(
              fontSize: isSelected ? 28 : 22,
              fontWeight: isSelected ? FontWeight.w400 : FontWeight.w300,
              color: isSelected ? Colors.white : const Color(0xFF444444),
              letterSpacing: -0.5,
            ),
            child: Text(label),
          ),
          const SizedBox(width: 2),
          AnimatedDefaultTextStyle(
            duration: const Duration(milliseconds: 150),
            style: TextStyle(
              fontSize: isSelected ? 13 : 11,
              color: isSelected
                  ? const Color(0xFF888888)
                  : const Color(0xFF333333),
            ),
            child: Text(unit),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Highlight band behind the centre row
// ─────────────────────────────────────────────────────────────────────────────
class _SelectionBand extends StatelessWidget {
  final double itemHeight;

  const _SelectionBand({required this.itemHeight});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        height: itemHeight,
        decoration: const BoxDecoration(
          color: Color(0xFF1A1A1A),
          border: Border.symmetric(
            horizontal: BorderSide(color: Color(0xFF2A2A2A)),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Colon separator between the two wheels
// ─────────────────────────────────────────────────────────────────────────────
class _Separator extends StatelessWidget {
  const _Separator();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(horizontal: 6),
      child: Text(
        ':',
        style: TextStyle(
          fontSize: 26,
          fontWeight: FontWeight.w200,
          color: Color(0xFF333333),
          height: 1,
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Bottom-sheet wrapper
//
// KEY FIX: _hours / _minutes live HERE (in the sheet's own state).
// The picker fires onChanged → we update our local fields.
// The confirm button reads those fields at press time — never stale.
// ─────────────────────────────────────────────────────────────────────────────
class _DurationPickerSheet extends StatefulWidget {
  final int initialHours;
  final int initialMinutes;

  const _DurationPickerSheet({
    required this.initialHours,
    required this.initialMinutes,
  });

  @override
  State<_DurationPickerSheet> createState() => _DurationPickerSheetState();
}

class _DurationPickerSheetState extends State<_DurationPickerSheet> {
  // These are the single source of truth for the current selection.
  late int _hours;
  late int _minutes;

  @override
  void initState() {
    super.initState();
    _hours = widget.initialHours.clamp(0, 23);
    _minutes = widget.initialMinutes.clamp(0, 59);
  }

  void _onPickerChanged(int h, int m) {
    // No setState needed — we only need fresh values at confirm time.
    // The picker re-renders itself; the header preview uses setState below.
    _hours = h;
    _minutes = m;
    // Rebuild just the header preview
    setState(() {});
  }

  void _confirm() {
    Navigator.of(context).pop(
      DurationResult(hours: _hours, minutes: _minutes),
    );
  }

  @override
  Widget build(BuildContext context) {
    final preview = DurationResult(hours: _hours, minutes: _minutes);

    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF111111),
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
        border: Border(top: BorderSide(color: Color(0xFF1E1E1E))),
      ),
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // ── Handle bar ─────────────────────────────────────────────────
          Container(
            width: 36,
            height: 3,
            decoration: BoxDecoration(
              color: const Color(0xFF333333),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 20),

          // ── Header with live preview ────────────────────────────────────
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Duration',
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 180),
                child: Text(
                  preview.totalMinutes > 0 ? preview.formatted : '',
                  key: ValueKey(preview.formatted),
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: const Color(0xFF888888),
                      ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // ── Picker wheels (no confirm button inside) ───────────────────
          DurationPickerWidget(
            initialHours: _hours,
            initialMinutes: _minutes,
            onChanged: _onPickerChanged, // always updates _hours/_minutes here
          ),

          const SizedBox(height: 20),

          // ── Confirm button lives HERE — always reads fresh _hours/_minutes
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _confirm,
              child: Text(
                preview.totalMinutes > 0
                    ? 'Set  ${preview.formatted}'
                    : 'Confirm',
              ),
            ),
          ),
        ],
      ),
    );
  }
}
