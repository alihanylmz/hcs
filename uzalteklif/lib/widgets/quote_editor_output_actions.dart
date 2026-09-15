import 'package:flutter/material.dart';

class QuoteEditorOutputActions extends StatelessWidget {
  const QuoteEditorOutputActions({
    super.key,
    required this.isSubmitting,
    required this.canCompleteQuote,
    required this.isRevision,
    required this.onSubmitForApproval,
    required this.onSave,
    required this.onExportPdf,
    required this.onExportExcel,
    required this.onExportMaterialRequestPdf,
    required this.onExportMaterialRequestExcel,
  });

  final bool isSubmitting;
  final bool canCompleteQuote;
  final bool isRevision;
  final VoidCallback onSubmitForApproval;
  final VoidCallback onSave;
  final VoidCallback onExportPdf;
  final VoidCallback onExportExcel;
  final VoidCallback onExportMaterialRequestPdf;
  final VoidCallback onExportMaterialRequestExcel;

  @override
  Widget build(BuildContext context) {
    final disabled = isSubmitting;
    return Column(
      children: [
        if (canCompleteQuote) ...[
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: disabled ? null : onSubmitForApproval,
              icon: disabled
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.send_rounded, size: 18),
              label: Text(isRevision ? 'Revizyonu Tamamla' : 'Teklifi Tamamla'),
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFFB8843C),
                foregroundColor: Colors.white,
                alignment: Alignment.center,
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
              ),
            ),
          ),
          const SizedBox(height: 10),
        ],
        SizedBox(
          width: double.infinity,
          child: FilledButton.tonalIcon(
            onPressed: disabled ? null : onSave,
            icon: const Icon(Icons.archive_outlined, size: 18),
            label: const Text('Taslak Olarak Kaydet'),
            style: FilledButton.styleFrom(
              alignment: Alignment.center,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            ),
          ),
        ),
        const SizedBox(height: 16),
        const _OutputSectionDivider(label: 'MÜŞTERİ TEKLİFİ'),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: disabled ? null : onExportPdf,
                icon: const Icon(Icons.picture_as_pdf_rounded, size: 18),
                label: const Text('PDF'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: disabled ? null : onExportExcel,
                icon: const Icon(Icons.grid_on_rounded, size: 18),
                label: const Text('Excel'),
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        const _OutputSectionDivider(label: 'MALZEME İSTEĞİ (DAHİLİ)'),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: disabled ? null : onExportMaterialRequestPdf,
                icon: const Icon(Icons.inventory_2_outlined, size: 18),
                label: const Text('PDF'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: disabled ? null : onExportMaterialRequestExcel,
                icon: const Icon(Icons.list_alt_rounded, size: 18),
                label: const Text('Excel'),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

/// Çıktı butonlarını ikiye ayıran küçük başlık - eskiden "PDF Çıkart" ve
/// "İstek PDF" hiçbir ayrım olmadan aynı ağırlıkta, üst üste iki satırda
/// duruyordu; hangisinin müşteriye giden teklif, hangisinin dahili
/// malzeme isteği olduğu belli değildi.
class _OutputSectionDivider extends StatelessWidget {
  const _OutputSectionDivider({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).textTheme.bodySmall?.color;
    return Row(
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 10.5,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.5,
            color: color?.withValues(alpha: 0.7),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Divider(color: color?.withValues(alpha: 0.25), height: 1),
        ),
      ],
    );
  }
}
