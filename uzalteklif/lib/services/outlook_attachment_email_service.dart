import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';

class OutlookAttachmentEmailResult {
  const OutlookAttachmentEmailResult({
    required this.opened,
    required this.senderMatched,
  });

  final bool opened;
  final bool senderMatched;
}

class OutlookAttachmentEmailService {
  const OutlookAttachmentEmailService();

  bool get isSupported => !kIsWeb && Platform.isWindows;

  Future<OutlookAttachmentEmailResult> openDraftWithAttachment({
    required String to,
    required String cc,
    required String subject,
    required String body,
    required String attachmentPath,
    String senderEmail = '',
  }) async {
    if (!isSupported) {
      throw UnsupportedError(
        'Outlook attachment flow is only supported on Windows.',
      );
    }

    final attachmentFile = File(attachmentPath);
    if (!await attachmentFile.exists()) {
      throw ArgumentError.value(
        attachmentPath,
        'attachmentPath',
        'Attachment file was not found.',
      );
    }

    final scriptFile = await _writeTemporaryScript();
    try {
      final result = await Process.run('powershell.exe', [
        '-NoProfile',
        '-ExecutionPolicy',
        'Bypass',
        '-File',
        scriptFile.path,
        to,
        cc,
        subject,
        body,
        attachmentFile.path,
        senderEmail,
      ]);

      if (result.exitCode != 0) {
        final stderr = '${result.stderr}'.trim();
        throw ProcessException(
          'powershell.exe',
          const [],
          stderr.isEmpty ? 'Outlook could not be opened.' : stderr,
          result.exitCode,
        );
      }

      final raw = '${result.stdout}'.trim();
      if (raw.isEmpty) {
        return const OutlookAttachmentEmailResult(
          opened: true,
          senderMatched: false,
        );
      }

      final decoded = jsonDecode(raw);
      if (decoded is Map<String, dynamic>) {
        return OutlookAttachmentEmailResult(
          opened: decoded['opened'] == true,
          senderMatched: decoded['senderMatched'] == true,
        );
      }

      return const OutlookAttachmentEmailResult(
        opened: true,
        senderMatched: false,
      );
    } finally {
      try {
        if (await scriptFile.exists()) {
          await scriptFile.delete();
        }
      } catch (_) {
        // Gecici script silinemezse sessiz gec.
      }
    }
  }

  Future<File> _writeTemporaryScript() async {
    final script = '''
param(
  [string]\$ToEmail,
  [string]\$CcEmail,
  [string]\$MailSubject,
  [string]\$MailBody,
  [string]\$AttachmentPath,
  [string]\$SenderEmail
)

\$ErrorActionPreference = 'Stop'
\$outlook = New-Object -ComObject Outlook.Application
\$mail = \$outlook.CreateItem(0)

if (\$ToEmail) { \$mail.To = \$ToEmail }
if (\$CcEmail) { \$mail.CC = \$CcEmail }
if (\$MailSubject) { \$mail.Subject = \$MailSubject }
if (\$MailBody) { \$mail.Body = \$MailBody }

if (-not (Test-Path -LiteralPath \$AttachmentPath)) {
  throw "PDF file not found: \$AttachmentPath"
}
[void]\$mail.Attachments.Add(\$AttachmentPath)

\$senderMatched = \$false
if (\$SenderEmail) {
  foreach (\$account in \$outlook.Session.Accounts) {
    try {
      if (
        \$account.SmtpAddress -and
        \$account.SmtpAddress.ToLowerInvariant() -eq \$SenderEmail.ToLowerInvariant()
      ) {
        \$mail.SendUsingAccount = \$account
        \$senderMatched = \$true
        break
      }
    } catch {
    }
  }

  if (-not \$senderMatched) {
    try {
      [void]\$mail.ReplyRecipients.Add(\$SenderEmail)
    } catch {
    }
  }
}

\$mail.Display()
@{
  opened = \$true
  senderMatched = \$senderMatched
} | ConvertTo-Json -Compress
''';

    final tempDir = await Directory.systemTemp.createTemp('uzal_outlook_');
    final file = File(
      '${tempDir.path}${Platform.pathSeparator}open_outlook_draft.ps1',
    );
    return file.writeAsString(script, flush: true);
  }
}
