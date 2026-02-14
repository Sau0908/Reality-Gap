import 'package:flutter/material.dart';

class EncouragementBanner extends StatelessWidget {
  final int scrollMinutes;
  final int outputMinutes;
  final int gap;

  const EncouragementBanner({
    Key? key,
    required this.scrollMinutes,
    required this.outputMinutes,
    required this.gap,
  }) : super(key: key);

  bool get _isWinning => gap <= 0;

  String get _message {
    if (outputMinutes == 0 && scrollMinutes == 0) {
      return 'Log your first output today.';
    }
    if (outputMinutes == 0) {
      return 'You\'ve been scrolling. Time to create something.';
    }
    if (gap == 0) return 'Perfectly balanced. Keep going.';

    if (_isWinning) {
      final ahead = gap.abs();
      if (ahead < 30) return 'Slightly ahead. Solid start.';
      if (ahead < 60) return 'Output is winning. Keep the streak.';
      return 'You\'re crushing it today. 🔥';
    } else {
      if (gap < 30) return 'Close. One more output closes the gap.';
      if (gap < 60) return 'Scroll is winning. Log what you\'ve done.';
      return 'Big gap today. Small outputs count too.';
    }
  }

  @override
  Widget build(BuildContext context) {
    if (scrollMinutes == 0 && outputMinutes == 0)
      return const SizedBox.shrink();

    final bgColor =
        _isWinning ? const Color(0xFF1A2E1A) : const Color(0xFF2E1A1A);
    final borderColor =
        _isWinning ? const Color(0xFF2E5C2E) : const Color(0xFF5C2E2E);
    final accentColor =
        _isWinning ? const Color(0xFF81C784) : const Color(0xFFEF9A9A);

    final total = scrollMinutes + outputMinutes;
    final outputFraction =
        total > 0 ? (outputMinutes / total).clamp(0.0, 1.0) : 0.0;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: bgColor,
        border: Border.all(color: borderColor),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _message,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: accentColor,
                ),
          ),
          if (gap != 0) ...[
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(2),
              child: LinearProgressIndicator(
                value: outputFraction,
                minHeight: 3,
                backgroundColor: const Color(0x33FFFFFF),
                valueColor: AlwaysStoppedAnimation<Color>(accentColor),
              ),
            ),
            const SizedBox(height: 6),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Output ${(outputFraction * 100).round()}%',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Colors.white38,
                        fontSize: 11,
                      ),
                ),
                Text(
                  'Scroll ${((1 - outputFraction) * 100).round()}%',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Colors.white38,
                        fontSize: 11,
                      ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
