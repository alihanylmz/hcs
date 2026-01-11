import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../theme/app_colors.dart';

class DailyHeroSummaryCard extends StatelessWidget {
  final DateTime selectedDate;
  final double progress; // 0..1
  final int completedSteps;
  final int totalSteps;
  final VoidCallback onCtaPressed;
  final bool isLoading;

  const DailyHeroSummaryCard({
    super.key,
    required this.selectedDate,
    required this.progress,
    required this.completedSteps,
    required this.totalSteps,
    required this.onCtaPressed,
    required this.isLoading,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isNarrow = constraints.maxWidth < 380;
        final percent = (progress * 100).clamp(0, 100).toInt();
        final subtitle = DateFormat('d MMMM yyyy', 'tr_TR').format(selectedDate);

        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppColors.primary.withOpacity(0.08)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.06),
                blurRadius: 16,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: isNarrow
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _LeftTexts(subtitle: subtitle, completedSteps: completedSteps, totalSteps: totalSteps),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        _ProgressRing(percent: percent, progress: progress, isLoading: isLoading),
                        const SizedBox(width: 14),
                        Expanded(child: _CtaButton(onPressed: onCtaPressed)),
                      ],
                    ),
                  ],
                )
              : Row(
                  children: [
                    Expanded(
                      child: _LeftTexts(subtitle: subtitle, completedSteps: completedSteps, totalSteps: totalSteps),
                    ),
                    const SizedBox(width: 14),
                    _ProgressRing(percent: percent, progress: progress, isLoading: isLoading),
                    const SizedBox(width: 12),
                    _CtaButton(onPressed: onCtaPressed),
                  ],
                ),
        );
      },
    );
  }
}

class _LeftTexts extends StatelessWidget {
  final String subtitle;
  final int completedSteps;
  final int totalSteps;

  const _LeftTexts({
    required this.subtitle,
    required this.completedSteps,
    required this.totalSteps,
  });

  @override
  Widget build(BuildContext context) {
    final statText = totalSteps == 0 ? 'Bugün için iş yok' : '$completedSteps / $totalSteps adım';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Günün Durumu',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w900,
            color: AppColors.textDark,
            letterSpacing: 0.2,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          subtitle,
          style: const TextStyle(
            fontSize: 12.5,
            fontWeight: FontWeight.w600,
            color: AppColors.textLight,
          ),
        ),
        const SizedBox(height: 10),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: AppColors.backgroundGrey,
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: AppColors.primary.withOpacity(0.08)),
          ),
          child: Text(
            statText,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: AppColors.textDark,
            ),
          ),
        ),
      ],
    );
  }
}

class _ProgressRing extends StatelessWidget {
  final int percent;
  final double progress;
  final bool isLoading;

  const _ProgressRing({
    required this.percent,
    required this.progress,
    required this.isLoading,
  });

  @override
  Widget build(BuildContext context) {
    final color = progress >= 1.0 ? AppColors.statusDone : AppColors.primary;

    return SizedBox(
      width: 62,
      height: 62,
      child: Stack(
        alignment: Alignment.center,
        children: [
          CircularProgressIndicator(
            value: isLoading ? null : progress,
            strokeWidth: 6,
            backgroundColor: AppColors.primary.withOpacity(0.08),
            color: color,
          ),
          Text(
            '$percent%',
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w900,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }
}

class _CtaButton extends StatelessWidget {
  final VoidCallback onPressed;
  const _CtaButton({required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return FilledButton.icon(
      onPressed: onPressed,
      style: FilledButton.styleFrom(
        backgroundColor: AppColors.corporateNavy,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
      icon: const Icon(Icons.list_alt_rounded, size: 18),
      label: const Text(
        'Detay',
        style: TextStyle(fontWeight: FontWeight.w800, letterSpacing: 0.2),
      ),
    );
  }
}


