import 'package:flutter/material.dart';

import '../models/ticket_backup_record.dart';
import '../utils/formatters.dart';

class TicketBackupRequestData {
  const TicketBackupRequestData({
    required this.requestedBy,
    required this.requestedSavePath,
    required this.requestedAt,
  });

  final String requestedBy;
  final String requestedSavePath;
  final DateTime requestedAt;
}

Future<TicketBackupRequestData?> showTicketBackupRequestDialog(
  BuildContext context, {
  required String suggestedFileName,
  TicketBackupRecord? latestBackup,
  String? currentUserName,
}) async {
  final requestedAt = DateTime.now();
  final requesterController = TextEditingController(
    text:
        latestBackup?.requestedBy?.trim().isNotEmpty == true
            ? latestBackup!.requestedBy!.trim()
            : (currentUserName ?? '').trim(),
  );
  final savePathController = TextEditingController(
    text:
        latestBackup?.requestedSavePath?.trim().isNotEmpty == true
            ? latestBackup!.requestedSavePath!.trim()
            : (latestBackup?.backupPath ?? '').trim(),
  );
  final formKey = GlobalKey<FormState>();

  final result = await showDialog<TicketBackupRequestData>(
    context: context,
    builder: (dialogContext) {
      return AlertDialog(
        title: const Text('Yedek Bilgileri'),
        content: SizedBox(
          width: 420,
          child: Form(
            key: formKey,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Yedek alinmadan once bu bilgiler kaydedilecek. Ardindan dosya kaydetme penceresi acilir.',
                    style: Theme.of(dialogContext).textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Dosya adi: $suggestedFileName',
                    style: Theme.of(dialogContext).textTheme.bodySmall,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: requesterController,
                    textInputAction: TextInputAction.next,
                    decoration: const InputDecoration(
                      labelText: 'Yedegi isteyen',
                      hintText: 'Ornek: Ali Yilmaz / Musteri',
                      border: OutlineInputBorder(),
                    ),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Bu alan bos birakilamaz.';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: savePathController,
                    textInputAction: TextInputAction.done,
                    decoration: const InputDecoration(
                      labelText: 'Kaydedilecek yol veya klasor',
                      hintText: r'Ornek: D:\Yedekler\Mart',
                      border: OutlineInputBorder(),
                    ),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Bu alan bos birakilamaz.';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    initialValue: Formatters.date(
                      requestedAt.toIso8601String(),
                    ),
                    readOnly: true,
                    decoration: const InputDecoration(
                      labelText: 'Talep zamani',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Iptal'),
          ),
          FilledButton(
            onPressed: () {
              final formState = formKey.currentState;
              if (formState == null || !formState.validate()) {
                return;
              }

              Navigator.of(dialogContext).pop(
                TicketBackupRequestData(
                  requestedBy: requesterController.text.trim(),
                  requestedSavePath: savePathController.text.trim(),
                  requestedAt: requestedAt,
                ),
              );
            },
            child: const Text('Yedeklemeyi baslat'),
          ),
        ],
      );
    },
  );

  requesterController.dispose();
  savePathController.dispose();
  return result;
}
