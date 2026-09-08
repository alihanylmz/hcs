import 'package:flutter/material.dart';

/// Üç aşamalı teklif editörü navigasyon header'ı.
/// Step 0: Müşteri ve konu
/// Step 1: Kalemler ve fiyat
/// Step 2: Koşullar, ön izleme ve kayıt
class QuoteEditorStepHeader extends StatelessWidget {
  const QuoteEditorStepHeader({
    required this.currentStep,
    required this.onStepSelected,
    super.key,
  });

  final int currentStep;
  final ValueChanged<int> onStepSelected;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final steps = [
      (title: '1. Müşteri ve konu', key: 'quote-step-0'),
      (title: '2. Kalemler ve fiyat', key: 'quote-step-1'),
      (title: '3. Koşullar, ön izleme ve kayıt', key: 'quote-step-2'),
    ];

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Step chips
          Row(
            children: List.generate(
              steps.length,
              (index) {
                final isActive = currentStep == index;
                final isCompleted = index < currentStep;

                return Expanded(
                  child: Row(
                    children: [
                      // Step chip
                      Expanded(
                        child: GestureDetector(
                          onTap: () => onStepSelected(index),
                          child: Container(
                            key: ValueKey(steps[index].key),
                            decoration: BoxDecoration(
                              color: isActive
                                  ? theme.colorScheme.primary
                                  : (isCompleted
                                      ? theme.colorScheme.primary
                                          .withOpacity(0.3)
                                      : theme.colorScheme.surfaceVariant),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 10,
                            ),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  steps[index].title,
                                  textAlign: TextAlign.center,
                                  style: theme.textTheme.labelSmall?.copyWith(
                                    color: isActive || isCompleted
                                        ? Colors.white
                                        : theme.colorScheme.onSurfaceVariant,
                                    fontWeight: isActive
                                        ? FontWeight.bold
                                        : FontWeight.normal,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      // Connector line (except after last step)
                      if (index < steps.length - 1) ...[
                        SizedBox(
                          width: 4,
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 4),
                            child: Container(
                              height: 2,
                              color: isCompleted
                                  ? theme.colorScheme.primary
                                  : theme.colorScheme.outlineVariant,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 12),
          // Progress indicator
          LinearProgressIndicator(
            value: (currentStep + 1) / steps.length,
            minHeight: 4,
            backgroundColor: theme.colorScheme.surfaceVariant,
            valueColor: AlwaysStoppedAnimation(theme.colorScheme.primary),
          ),
        ],
      ),
    );
  }
}
