import 'package:flutter/material.dart';

class QuoteEditorOfferFields extends StatelessWidget {
  const QuoteEditorOfferFields({
    super.key,
    required this.titleController,
    required this.noteController,
    required this.composedTitle,
    required this.onTitleChanged,
  });

  final TextEditingController titleController;
  final TextEditingController noteController;
  final String composedTitle;
  final ValueChanged<String> onTitleChanged;

  String? _required(String? value) =>
      value == null || value.trim().isEmpty ? 'Zorunlu alan' : null;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        TextFormField(
          controller: titleController,
          decoration: const InputDecoration(
            labelText: 'Konu',
            hintText: 'Jetfan Otopark, Chiller Bakim, DDC Pano...',
          ),
          validator: _required,
          onChanged: onTitleChanged,
        ),
        const SizedBox(height: 8),
        Align(
          alignment: Alignment.centerLeft,
          child: Text(
            'Kayit adi: $composedTitle',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: const Color(0xFF5B6F7F),
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        const SizedBox(height: 12),
        TextFormField(
          controller: noteController,
          minLines: 6,
          maxLines: 14,
          keyboardType: TextInputType.multiline,
          decoration: InputDecoration(
            labelText: 'Teklif ayrintilari / notlar',
            alignLabelWithHint: true,
            helper: ValueListenableBuilder<TextEditingValue>(
              valueListenable: noteController,
              builder: (context, value, child) => Text(
                '${value.text.runes.length} karakter - karakter siniri yok',
              ),
            ),
          ),
        ),
      ],
    );
  }
}
