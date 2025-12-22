import 'package:flutter/material.dart';
import '../../theme/app_colors.dart';

class ProgressSummary extends StatelessWidget {
  final double progress;

  const ProgressSummary({super.key, required this.progress});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                "Genel İlerleme",
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: AppColors.textLight),
              ),
              Text(
                "%${(progress * 100).toInt()}",
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                  color: progress == 1.0 ? AppColors.statusDone : AppColors.primary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: progress,
              backgroundColor: Colors.grey.shade200,
              color: progress == 1.0 ? AppColors.statusDone : AppColors.primary,
              minHeight: 8,
            ),
          ),
        ],
      ),
    );
  }
}

