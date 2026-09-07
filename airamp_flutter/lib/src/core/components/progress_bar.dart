import 'package:flutter/material.dart';

class ProgressBar extends StatelessWidget {
  final double value;
  final String? label;
  const ProgressBar({super.key, required this.value, this.label});

  @override
  Widget build(BuildContext context) {
    final clamped = value.clamp(0.0, 1.0);
    final percent = (clamped * 100).toStringAsFixed(0);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: clamped,
            minHeight: 6,
            backgroundColor: Colors.white12,
          ),
        ),
        const SizedBox(height: 4),
        Text(label ?? '$percent%', style: const TextStyle(fontSize: 12, color: Colors.white70)),
      ],
    );
  }
}
