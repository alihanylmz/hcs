import 'package:flutter/material.dart';

import '../models/cari_account.dart';

class QuoteEditorCariDropdown extends StatelessWidget {
  const QuoteEditorCariDropdown({
    super.key,
    required this.cariler,
    required this.selectedValue,
    required this.onChanged,
  });

  final List<CariAccount> cariler;
  final String selectedValue;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 280,
      child: InputDecorator(
        decoration: const InputDecoration(
          labelText: 'Kayitli cari',
          isDense: true,
          contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        ),
        child: DropdownButtonHideUnderline(
          child: DropdownButton<String>(
            isExpanded: true,
            value: selectedValue,
            items: [
              const DropdownMenuItem<String>(
                value: '',
                child: Text('Manuel giris'),
              ),
              ...cariler.map(
                (cari) => DropdownMenuItem<String>(
                  value: cari.id,
                  child: Text(cari.menuLabel, overflow: TextOverflow.ellipsis),
                ),
              ),
            ],
            onChanged: onChanged,
          ),
        ),
      ),
    );
  }
}
