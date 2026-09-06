import 'package:flutter/material.dart';

class QuoteEditorLineTableHeader extends StatelessWidget {
  const QuoteEditorLineTableHeader({
    super.key,
    required this.priceCurrencyLabel,
  });
  final String priceCurrencyLabel;

  @override
  Widget build(BuildContext context) {
    final style = Theme.of(context).textTheme.labelMedium?.copyWith(
      color: const Color(0xFF17304C),
      fontWeight: FontWeight.w900,
    );
    Widget cell(
      String text,
      double width, {
      TextAlign align = TextAlign.left,
    }) => SizedBox(
      width: width,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8),
        child: Text(text, textAlign: align, style: style),
      ),
    );
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 1120) return const SizedBox.shrink();
        return Container(
          height: 36,
          decoration: BoxDecoration(
            color: const Color(0xFFE9EEF5),
            border: Border.all(color: const Color(0xFFC6D0DA)),
          ),
          child: Row(
            children: [
              cell('#', 32, align: TextAlign.center),
              const SizedBox(width: 1),
              cell('Urun kodu', 150),
              const SizedBox(width: 1),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: Text('Kalem aciklamasi', style: style),
                ),
              ),
              const SizedBox(width: 1),
              cell('Birim', 72),
              const SizedBox(width: 1),
              cell('Miktar', 78, align: TextAlign.right),
              const SizedBox(width: 1),
              cell(
                'Birim fiyat ($priceCurrencyLabel)',
                112,
                align: TextAlign.right,
              ),
              const SizedBox(width: 1),
              cell('Isk. %', 80, align: TextAlign.right),
              const SizedBox(width: 1),
              cell('Satir toplami', 116, align: TextAlign.right),
              const SizedBox(width: 97),
            ],
          ),
        );
      },
    );
  }
}
