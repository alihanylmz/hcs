import 'package:flutter/material.dart';
import '../../theme/app_colors.dart';

class EmptyActivitiesState extends StatelessWidget {
  const EmptyActivitiesState({super.key});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: const BoxDecoration(
              color: Colors.blueAccent,
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.assignment_add, size: 48, color: Colors.white.withOpacity(0.9)),
          ),
          const SizedBox(height: 24),
          const Text(
            'Bugün için iş paketi yok.',
            style: TextStyle(color: AppColors.textDark, fontSize: 18, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          const Text(
            'Projelerini yönetmeye başla!',
            style: TextStyle(color: AppColors.textLight, fontSize: 14),
          ),
        ],
      ),
    );
  }
}
