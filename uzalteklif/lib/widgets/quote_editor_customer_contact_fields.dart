import 'package:flutter/material.dart';

import '../models/cari_account.dart';

/// Sihirbazin 1. adimindaki musteri iletisim alanlari.
///
/// Firma alani duz bir metin kutusu degil, kayitli cariler arasinda arama
/// yapan bir [RawAutocomplete]'tir: yazdikca eslesenler listelenir, listeden
/// secilince [onCariSelected] ile cari bilgileri forma doldurulur. Kullanici
/// listede olmayan bir isim yazarsa kayit sirasinda yeni cari acilir.
///
/// `Autocomplete` yerine `RawAutocomplete` kullaniliyor cunku metin kutusunun
/// controller'i disaridan veriliyor; sayfa `_customerCompanyController`'i
/// baska yerlerde de okuyup yaziyor ve tek kaynak olmasi gerekiyor.
class QuoteEditorCustomerContactFields extends StatelessWidget {
  const QuoteEditorCustomerContactFields({
    super.key,
    required this.companyController,
    required this.companyFocusNode,
    required this.nameController,
    required this.titleController,
    required this.phoneController,
    required this.emailController,
    required this.onCompanyChanged,
    required this.cariler,
    required this.onCariSelected,
  });

  final TextEditingController companyController;
  final FocusNode companyFocusNode;
  final TextEditingController nameController;
  final TextEditingController titleController;
  final TextEditingController phoneController;
  final TextEditingController emailController;
  final ValueChanged<String> onCompanyChanged;

  /// Aramada kullanilacak kayitli cariler. Bos ise alan duz metin kutusu gibi
  /// davranir, acilir liste gosterilmez.
  final List<CariAccount> cariler;

  /// Listeden bir cari secildiginde cagrilir.
  final ValueChanged<CariAccount> onCariSelected;

  static const int _maxOptions = 12;

  String? _required(String? value) =>
      value == null || value.trim().isEmpty ? 'Zorunlu alan' : null;

  Iterable<CariAccount> _options(TextEditingValue value) {
    final query = value.text.trim().toLowerCase();
    if (query.isEmpty) return cariler.take(_maxOptions);
    return cariler
        .where((c) => c.companyName.trim().toLowerCase().contains(query))
        .take(_maxOptions);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        RawAutocomplete<CariAccount>(
          textEditingController: companyController,
          focusNode: companyFocusNode,
          displayStringForOption: (cari) => cari.companyName,
          optionsBuilder: _options,
          onSelected: onCariSelected,
          fieldViewBuilder:
              (context, textController, focusNode, onFieldSubmitted) {
                return TextFormField(
                  controller: textController,
                  focusNode: focusNode,
                  decoration: InputDecoration(
                    labelText: 'Firma Adi',
                    hintText: cariler.isEmpty
                        ? null
                        : 'Yazarak arayin veya listeden secin',
                    suffixIcon: cariler.isEmpty
                        ? null
                        : const Icon(Icons.arrow_drop_down_rounded),
                  ),
                  validator: _required,
                  onFieldSubmitted: (_) => onFieldSubmitted(),
                  onChanged: onCompanyChanged,
                );
              },
          optionsViewBuilder: (context, onSelected, options) {
            final values = options.toList(growable: false);
            return Align(
              alignment: Alignment.topLeft,
              child: Material(
                elevation: 8,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(
                    maxWidth: 420,
                    maxHeight: 240,
                  ),
                  child: ListView.builder(
                    padding: EdgeInsets.zero,
                    shrinkWrap: true,
                    itemCount: values.length,
                    itemBuilder: (context, index) => ListTile(
                      dense: true,
                      title: Text(values[index].menuLabel),
                      onTap: () => onSelected(values[index]),
                    ),
                  ),
                ),
              ),
            );
          },
        ),
        const SizedBox(height: 12),
        TextFormField(
          controller: nameController,
          decoration: const InputDecoration(labelText: 'Yetkili Ad Soyad'),
          validator: _required,
        ),
        const SizedBox(height: 12),
        TextFormField(
          controller: titleController,
          decoration: const InputDecoration(labelText: 'Unvan'),
        ),
        const SizedBox(height: 12),
        TextFormField(
          controller: phoneController,
          decoration: const InputDecoration(labelText: 'Telefon'),
        ),
        const SizedBox(height: 12),
        TextFormField(
          controller: emailController,
          decoration: const InputDecoration(labelText: 'E-posta'),
        ),
      ],
    );
  }
}
