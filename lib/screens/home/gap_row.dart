import 'package:flutter/material.dart';

class GapRow extends StatelessWidget {
  final int gap;

  const GapRow({Key? key, required this.gap}) : super(key: key);

  bool get _isWinning => gap <= 0;

  String get _label {
    if (gap == 0) return 'Balanced';
    return _isWinning ? 'Ahead' : 'Gap';
  }

  String _formatTime(int minutes) {
    if (minutes < 60) return '${minutes}m';
    final hours = minutes ~/ 60;
    final mins = minutes % 60;
    return mins == 0 ? '${hours}h' : '${hours}h ${mins}m';
  }

  @override
  Widget build(BuildContext context) {
    final gapColor = _isWinning
        ? const Color(0xFF4CAF50) // green when winning
        : const Color(0xFFFF4444); // red when behind

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.baseline,
      textBaseline: TextBaseline.alphabetic,
      children: [
        Text(
          _label,
          style: Theme.of(context).textTheme.headlineMedium,
        ),
        Text(
          _formatTime(gap.abs()),
          style: Theme.of(context).textTheme.displayMedium?.copyWith(
                color: gapColor,
              ),
        ),
      ],
    );
  }
}
