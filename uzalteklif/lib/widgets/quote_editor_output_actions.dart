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
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: disabled ? null : onExportPdf,
                icon: const Icon(Icons.picture_as_pdf_rounded),
                label: const Text('PDF Cikart'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: disabled ? null : onExportExcel,
                icon: const Icon(Icons.grid_on_rounded),
                label: const Text('Excel Cikart'),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: disabled ? null : onExportMaterialRequestPdf,
                icon: const Icon(Icons.inventory_2_outlined),
                label: const Text('Istek PDF'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: disabled ? null : onExportMaterialRequestExcel,
                icon: const Icon(Icons.list_alt_rounded),
                label: const Text('Istek Excel'),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
