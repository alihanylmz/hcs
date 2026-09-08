import 'package:flutter/material.dart';

class QuoteEditorHiddenCostTotalCard extends StatelessWidget {
  const QuoteEditorHiddenCostTotalCard({super.key, required this.amountText});

  final String amountText;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        color: const Color(0xFF4A2C80),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.visibility_off_rounded,
            color: Colors.white,
            size: 18,
          ),
          const SizedBox(width: 8),
          const Expanded(
            child: Text(
              'Gizli yukleme toplami (PDF\'e yansimaz, fiyatlara dagitilir)',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Text(
            amountText,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}
