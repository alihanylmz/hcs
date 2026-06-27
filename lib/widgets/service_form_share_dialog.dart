import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../theme/app_colors.dart';

Future<void> showServiceFormShareDialog(
  BuildContext context, {
  required String formUrl,
  required String whatsAppMessage,
  String title = 'Form Oluşturuldu',
}) {
  return showDialog<void>(
    context: context,
    builder: (dialogContext) {
      Future<void> copyLink() async {
        await Clipboard.setData(ClipboardData(text: formUrl));
        if (dialogContext.mounted) {
          ScaffoldMessenger.of(dialogContext).showSnackBar(
            const SnackBar(content: Text('Form linki kopyalandı.')),
          );
        }
      }

      Future<void> openUrl(String url, {bool external = false}) async {
        final uri = Uri.parse(url);
        final mode = external
            ? LaunchMode.externalApplication
            : LaunchMode.platformDefault;
        if (await canLaunchUrl(uri)) {
          await launchUrl(uri, mode: mode);
          return;
        }
        if (dialogContext.mounted) {
          ScaffoldMessenger.of(dialogContext).showSnackBar(
            SnackBar(content: Text('Bağlantı açılamadı: $url')),
          );
        }
      }

      final whatsAppUrl =
          'https://wa.me/?text=${Uri.encodeComponent(whatsAppMessage)}';

      return AlertDialog(
        title: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: Colors.green.shade50,
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.check_circle, color: Colors.green),
            ),
            const SizedBox(width: 10),
            Expanded(child: Text(title)),
          ],
        ),
        content: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Müşteri form linki hazır. WhatsApp ile gönderebilir, linki kopyalayabilir veya formu önizleyebilirsiniz.',
                style: TextStyle(color: Colors.grey.shade700, height: 1.35),
              ),
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: SelectableText(
                  formUrl,
                  style: const TextStyle(fontSize: 13),
                ),
              ),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: () => openUrl(whatsAppUrl, external: true),
                icon: const Icon(Icons.chat_outlined),
                label: const Text('WhatsApp ile Gönder'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                ),
              ),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: copyLink,
                icon: const Icon(Icons.copy_outlined),
                label: const Text('Linki Kopyala'),
              ),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: () => openUrl(formUrl),
                icon: const Icon(Icons.open_in_new_outlined),
                label: const Text('Formu Önizle'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.corporateBlue,
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Kapat'),
          ),
        ],
      );
    },
  );
}
