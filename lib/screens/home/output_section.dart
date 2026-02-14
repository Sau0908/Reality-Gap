import 'package:flutter/material.dart';
import 'package:reality_gap/screens/home/output.dart';
import '../../models/output_model.dart';

class OutputsSection extends StatelessWidget {
  final List<OutputModel> outputs;
  final VoidCallback onLogPressed;
  final int maxOutputs;

  const OutputsSection({
    Key? key,
    required this.outputs,
    required this.onLogPressed,
    this.maxOutputs = 6,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final atLimit = outputs.length >= maxOutputs;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Outputs today: ${outputs.length}/$maxOutputs',
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        const SizedBox(height: 16),
        ...outputs.map((o) => OutputCard(output: o)),
        const SizedBox(height: 32),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: atLimit ? null : onLogPressed,
            child: const Text('Log Output'),
          ),
        ),
      ],
    );
  }
}
