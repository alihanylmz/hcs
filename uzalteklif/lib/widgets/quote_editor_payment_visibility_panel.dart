import 'package:flutter/material.dart';

import '../models/quote.dart';

class QuoteEditorPaymentVisibilityPanel extends StatelessWidget {
  const QuoteEditorPaymentVisibilityPanel({
    super.key,
    required this.paymentMethod,
    required this.paymentTermDaysController,
    required this.hidePrices,
    required this.onPaymentMethodChanged,
    required this.onHidePricesChanged,
  });

  final QuotePaymentMethod paymentMethod;
  final TextEditingController paymentTermDaysController;
  final bool hidePrices;
  final ValueChanged<QuotePaymentMethod> onPaymentMethodChanged;
  final ValueChanged<bool> onHidePricesChanged;

  @override
  Widget build(BuildContext context) {
    const ink = Color(0xFF17304C);
    const slate = Color(0xFF5B6F7F);
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            color: Colors.white,
            border: Border.all(color: const Color(0xFFD7DEE6)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Odeme Yontemi',
                style: TextStyle(fontWeight: FontWeight.w800, color: ink),
              ),
              const SizedBox(height: 10),
              SegmentedButton<QuotePaymentMethod>(
                segments: const [
                  ButtonSegment(
                    value: QuotePaymentMethod.cash,
                    label: Text('Nakit'),
                  ),
                  ButtonSegment(
                    value: QuotePaymentMethod.creditCard,
                    label: Text('Kart'),
                  ),
                  ButtonSegment(
                    value: QuotePaymentMethod.installment,
                    label: Text('Vadeli'),
                  ),
                ],
                selected: {paymentMethod},
                onSelectionChanged: (values) {
                  if (values.isNotEmpty) onPaymentMethodChanged(values.first);
                },
                showSelectedIcon: false,
              ),
              if (paymentMethod == QuotePaymentMethod.installment)
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: TextFormField(
                    controller: paymentTermDaysController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Vade Gunu',
                      suffixText: 'gun',
                      isDense: true,
                    ),
                    validator: (value) {
                      final parsed = int.tryParse(value?.trim() ?? '');
                      return parsed == null || parsed < 0 || parsed > 365
                          ? '0-365 arasi bir deger girin'
                          : null;
                    },
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        SwitchListTile.adaptive(
          value: hidePrices,
          onChanged: onHidePricesChanged,
          title: const Text('Fiyatlari Gizle'),
          subtitle: Text(
            hidePrices
                ? 'PDF sadece malzeme listesi: aciklama, birim, miktar.'
                : 'Kapali: tum fiyat ve toplam sutunlari gosterilir.',
            style: const TextStyle(color: slate),
          ),
        ),
      ],
    );
  }
}
