import 'package:flutter/material.dart';

import '../utils/tabular_paste_parser.dart';

/// Excel/Sheets'ten kopyalanan satirlari teklife aktarmadan once gosteren
/// dialog.
///
/// Onizleme bilerek var: yapistirilan metnin sutun sirasi yanlissa fiyat ile
/// miktar yer degistirir ve bu, kaydedildikten sonra fark edilmesi zor bir
/// hata olur. Kullanici eklemeden once ne olusacagini gorur.
class QuoteEditorPasteLinesDialog extends StatefulWidget {
  const QuoteEditorPasteLinesDialog({super.key});

  @override
  State<QuoteEditorPasteLinesDialog> createState() =>
      _QuoteEditorPasteLinesDialogState();
}

class _QuoteEditorPasteLinesDialogState
    extends State<QuoteEditorPasteLinesDialog> {
  final _controller = TextEditingController();
  bool _skipHeader = false;
  bool _headerAutoDetected = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onTextChanged(String value) {
    setState(() {
      // Baslik satirini bir kez otomatik isaretliyoruz; sonrasinda kullanici
      // ne dediyse ona uyuyoruz, her tusta kararini geri almiyoruz.
      if (!_headerAutoDetected && value.trim().isNotEmpty) {
        _headerAutoDetected = true;
        _skipHeader = TabularPasteParser.looksLikeHeader(value);
      }
    });
  }

  List<TabularPasteRow> get _rows =>
      TabularPasteParser.parse(_controller.text, skipHeader: _skipHeader);

  @override
  Widget build(BuildContext context) {
    final rows = _rows;
    final text = Theme.of(context).textTheme;

    return AlertDialog(
      title: const Text('Excel’den satır yapıştır'),
      content: SizedBox(
        // AlertDialog kendi kenar bosluklarini biraktigi icin sabit 720
        // dar ekranlarda tasiyor; ekrana gore kisitliyoruz.
        width: (MediaQuery.sizeOf(context).width - 120).clamp(280.0, 720.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Sütun sırası ekrandaki tabloyla aynı olmalı: '
              'Açıklama, Miktar, Birim, Birim Fiyat, İskonto. '
              'Eksik sütunlar varsayılanla doldurulur.',
              style: text.bodySmall?.copyWith(color: const Color(0xFF5B6F7F)),
            ),
            const SizedBox(height: 10),
            TextField(
              key: const ValueKey('paste-lines-input'),
              controller: _controller,
              onChanged: _onTextChanged,
              maxLines: 6,
              minLines: 4,
              decoration: const InputDecoration(
                hintText: 'Excel’de satırları seçip kopyalayın, buraya yapıştırın.',
                border: OutlineInputBorder(),
              ),
            ),
            CheckboxListTile(
              key: const ValueKey('paste-lines-skip-header'),
              value: _skipHeader,
              onChanged: (v) => setState(() => _skipHeader = v ?? false),
              controlAffinity: ListTileControlAffinity.leading,
              contentPadding: EdgeInsets.zero,
              dense: true,
              title: const Text('İlk satır başlık'),
            ),
            const SizedBox(height: 4),
            Text(
              rows.isEmpty
                  ? 'Önizlenecek satır yok.'
                  : '${rows.length} satır eklenecek:',
              style: text.bodyMedium?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 6),
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 200),
              child: SingleChildScrollView(
                child: Column(
                  children: [
                    for (final row in rows)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 3),
                        child: Row(
                          children: [
                            Expanded(flex: 4, child: Text(row.description)),
                            Expanded(
                              child: Text(
                                '${_num(row.quantity)} ${row.unit}',
                                textAlign: TextAlign.end,
                              ),
                            ),
                            Expanded(
                              child: Text(
                                _num(row.unitPrice),
                                textAlign: TextAlign.end,
                              ),
                            ),
                            Expanded(
                              child: Text(
                                '%${_num(row.discount)}',
                                textAlign: TextAlign.end,
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Vazgeç'),
        ),
        FilledButton(
          key: const ValueKey('paste-lines-confirm'),
          onPressed: rows.isEmpty ? null : () => Navigator.pop(context, rows),
          child: Text(
            rows.isEmpty ? 'Ekle' : '${rows.length} satırı ekle',
          ),
        ),
      ],
    );
  }

  static String _num(double v) =>
      v == v.truncateToDouble() ? v.toStringAsFixed(0) : v.toStringAsFixed(2);
}
