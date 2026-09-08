import 'package:flutter/material.dart';

class QuoteEditorHiddenCostSummary extends StatelessWidget {
  const QuoteEditorHiddenCostSummary({super.key, required this.amountText});

  final String amountText;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFF3EEFB),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFD6C8EC)),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.visibility_off_rounded,
            size: 16,
            color: Color(0xFF4A2C80),
          ),
          const SizedBox(width: 8),
          const Expanded(
            child: Text(
              'Gizli yukleme (PDF\'e yansimaz)',
              style: TextStyle(
                color: Color(0xFF4A2C80),
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          Text(
            amountText,
            style: const TextStyle(
              color: Color(0xFF4A2C80),
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}
