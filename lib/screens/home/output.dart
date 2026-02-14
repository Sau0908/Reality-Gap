import 'package:flutter/material.dart';
import '../../models/output_model.dart';

class OutputCard extends StatelessWidget {
  final OutputModel output;

  const OutputCard({Key? key, required this.output}) : super(key: key);

  String _formatTime(int minutes) {
    if (minutes < 60) return '${minutes}m';
    final hours = minutes ~/ 60;
    final mins = minutes % 60;
    return mins == 0 ? '${hours}h' : '${hours}h ${mins}m';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: Border.all(color: const Color(0xFF333333)),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(output.text, style: Theme.of(context).textTheme.bodyLarge),
          if (output.durationMinutes != null) ...[
            const SizedBox(height: 8),
            Text(
              _formatTime(output.durationMinutes!),
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ],
        ],
      ),
    );
  }
}
