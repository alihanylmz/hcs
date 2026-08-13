import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/market_rate.dart';
import '../models/product.dart';
import '../models/quote.dart';
import '../services/cari_repository.dart';
import '../services/pdf_export_service.dart';
import '../services/own_company_repository.dart';
import '../services/price_adjustment_rule_repository.dart';
import '../services/product_repository.dart';
import '../services/quote_repository.dart';
import '../services/user_profile_repository.dart';
import '../widgets/workspace_background.dart';
import 'quote_editor_page.dart';

/// Teklifin yonetici tarafindan onaylandigi/reddedildigi/revizyona
/// yollandigi read-only inceleme ekrani.
///
/// - `pending` statusunde: altta Onayla/Revizyon/Reddet aksiyon cubugu.
/// - `approved`: onay bilgisi kartta gorulur, aksiyon yok ("Revize Et"
///   engellenir cunku final durum).
/// - `draft` / `rejected`: seller revizyon/yeniden olusturma icin
///   "Duzenle" butonuyla editore gecebilir.
class QuoteReviewPage extends StatefulWidget {
  const QuoteReviewPage({
    super.key,
    required this.quote,
    required this.quoteRepository,
    required this.productRepository,
    required this.initialRates,
    required this.availableProducts,
    required this.userProfileRepository,
    required this.cariRepository,
    required this.ownCompanyRepository,
    required this.priceAdjustmentRuleRepository,
    required this.isManager,
  });

  final Quote quote;
  final QuoteRepository quoteRepository;
  final ProductRepository productRepository;
  final List<MarketRate> initialRates;
  final List<Product> availableProducts;
  final UserProfileRepository userProfileRepository;
  final CariRepository cariRepository;
  final OwnCompanyRepository ownCompanyRepository;
  final PriceAdjustmentRuleRepository priceAdjustmentRuleRepository;
  final bool isManager;

  @override
  State<QuoteReviewPage> createState() => _QuoteReviewPageState();
}

class _QuoteReviewPageState extends State<QuoteReviewPage> {
  static const _ink = Color(0xFF17304C);
  static const _slate = Color(0xFF5B6F7F);
  static const _accent = Color(0xFFB8843C);

  final _pdfService = const PdfExportService();

  late Quote _quote;
  bool _isBusy = false;

  @override
  void initState() {
    super.initState();
    _quote = widget.quote;
  }

  Future<void> _approve() async {
    await _runBusy(() async {
      final profile = await widget.userProfileRepository.fetchMine();
      final approverFromProfile = profile?.preparedByName.trim() ?? '';
      final approverName = approverFromProfile.isNotEmpty
          ? approverFromProfile
          : (_quote.createdByName.trim().isNotEmpty
                ? _quote.createdByName.trim()
                : (_quote.documentProfile.preparedByName.trim().isNotEmpty
                      ? _quote.documentProfile.preparedByName.trim()
                      : 'Satış Yetkilisi'));
      final updated = _quote.copyWith(
        status: QuoteStatus.approved,
        approvedAt: DateTime.now(),
        approvedByName: approverName,
        approvalNote: '',
        archivedAt: DateTime.now().toUtc(),
      );
      await widget.quoteRepository.saveQuote(updated);
      if (!mounted) return;
      setState(() => _quote = updated);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Teklif müşteriye gönderildi olarak işaretlendi.'),
        ),
      );
    }, 'Durum güncellenemedi');
  }

  Future<void> _markAccepted() async {
    final agreed = await _askAcceptedDeal();
    if (agreed == null) return;

    await _runBusy(() async {
      final profile = await widget.userProfileRepository.fetchMine();
      final actorName = profile?.preparedByName.trim().isNotEmpty == true
          ? profile!.preparedByName.trim()
          : (_quote.approvedByName.trim().isNotEmpty
                ? _quote.approvedByName.trim()
                : 'Yetkili');
      final updated = _quote.copyWith(
        status: QuoteStatus.accepted,
        acceptedTotalTl: agreed.totalTl,
        acceptedAmount: agreed.amount,
        acceptedCurrencyCode: agreed.currencyCode,
        acceptedFxRate: agreed.fxRate,
        acceptedNote: agreed.note,
        acceptedAt: DateTime.now(),
        acceptedByName: actorName,
        archivedAt: DateTime.now().toUtc(),
      );
      await widget.quoteRepository.saveQuote(updated);
      if (!mounted) return;
      setState(() => _quote = updated);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Teklif anlaşıldı olarak kaydedildi.')),
      );
    }, 'Anlaşma kaydedilemedi');
  }

  Future<void> _setStatusManually(QuoteStatus status) async {
    if (status == QuoteStatus.accepted) {
      await _markAccepted();
      return;
    }
    if (status == QuoteStatus.rejected) {
      await _reject();
      return;
    }
    if (status == QuoteStatus.cancelled) {
      await _cancelQuote();
      return;
    }

    await _runBusy(() async {
      final now = DateTime.now();
      final profile = await widget.userProfileRepository.fetchMine();
      final actorName = profile?.preparedByName.trim().isNotEmpty == true
          ? profile!.preparedByName.trim()
          : (_quote.approvedByName.trim().isNotEmpty
                ? _quote.approvedByName.trim()
                : 'Yetkili');
      final updated = _quote.copyWith(
        status: status,
        submittedAt: status == QuoteStatus.pending
            ? (_quote.submittedAt ?? now)
            : _quote.submittedAt,
        approvedAt: status == QuoteStatus.approved ? now : _quote.approvedAt,
        approvedByName: status == QuoteStatus.approved
            ? actorName
            : _quote.approvedByName,
        archivedAt: status == QuoteStatus.approved
            ? now.toUtc()
            : _quote.archivedAt,
        clearArchivedAt:
            status == QuoteStatus.draft || status == QuoteStatus.pending,
      );
      await widget.quoteRepository.saveQuote(updated);
      if (!mounted) return;
      setState(() => _quote = updated);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Durum güncellendi: ${status.displayLabel}')),
      );
    }, 'Durum güncellenemedi');
  }

  PopupMenuItem<String> _statusMenuItem(QuoteStatus status) {
    return PopupMenuItem(
      value: 'status:${status.storageKey}',
      child: Text(status.displayLabel),
    );
  }

  Future<void> _requestRevision() async {
    final note = await _askNote(
      title: 'Revizyon talebi',
      hint:
          'Hazırlayanın görmesi gereken maddeleri net ve kayıt altına uygun şekilde yazın.',
      confirmLabel: 'Revizyona gönder',
    );
    if (note == null) return;

    await _runBusy(() async {
      final updated = _quote.copyWith(
        status: QuoteStatus.draft,
        approvalNote: note,
      );
      await widget.quoteRepository.saveQuote(updated);
      if (!mounted) return;
      setState(() => _quote = updated);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Revizyon talebi kayda geçti; hazırlayan bilgilendirildi.',
          ),
        ),
      );
      Navigator.of(context).pop(updated);
    }, 'Revizyon gonderilemedi');
  }

  Future<void> _reject() async {
    final note = await _askNote(
      title: 'Kaybedilme Gerekçesi',
      hint: 'Kaybedilme sebebi satış analizi için kayıtlarda saklanacaktır.',
      confirmLabel: 'Kaybedildi olarak kaydet',
      destructive: true,
    );
    if (note == null) return;

    await _runBusy(() async {
      final updated = _quote.copyWith(
        status: QuoteStatus.rejected,
        approvalNote: note,
        approvedAt: DateTime.now(),
      );
      await widget.quoteRepository.saveQuote(updated);
      if (!mounted) return;
      setState(() => _quote = updated);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Teklif kaybedildi olarak kaydedildi.')),
      );
      Navigator.of(context).pop(updated);
    }, 'Durum kaydedilemedi');
  }

  Future<void> _cancelQuote() async {
    final note = await _askNote(
      title: 'Teklifi iptal et',
      hint: 'İptal sebebi kayıtlarda saklanır.',
      confirmLabel: 'İptal et',
      destructive: true,
    );
    if (note == null) return;

    await _runBusy(() async {
      final updated = _quote.copyWith(
        status: QuoteStatus.cancelled,
        approvalNote: note,
        approvedAt: DateTime.now(),
      );
      await widget.quoteRepository.saveQuote(updated);
      if (!mounted) return;
      setState(() => _quote = updated);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Teklif iptal edildi.')));
      Navigator.of(context).pop(updated);
    }, 'İptal işlemi başarısız');
  }

  Future<void> _toggleArchive(bool archive) async {
    await _runBusy(() async {
      final updated = archive
          ? _quote.copyWith(archivedAt: DateTime.now().toUtc())
          : _quote.copyWith(clearArchivedAt: true);
      await widget.quoteRepository.saveQuote(updated);
      if (!mounted) return;
      setState(() => _quote = updated);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            archive
                ? 'Teklif Gönderilen Teklifler listesine taşındı; aktif listelerden çıkarıldı.'
                : 'Teklif yeniden aktif listelere alındı.',
          ),
        ),
      );
      Navigator.of(context).pop(updated);
    }, 'Kapanış durumu güncellenemedi');
  }

  Future<void> _editQuote() async {
    final requiresRevision =
        _quote.status != QuoteStatus.draft &&
        _quote.status != QuoteStatus.rejected;
    if (requiresRevision) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Yeni revizyon oluşturulsun mu?'),
          content: Text(
            '${_quote.code} artık doğrudan düzenlenemez. Mevcut sürüm '
            'geçmişte korunarak yeni bir revizyon açılacak.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Vazgeç'),
            ),
            FilledButton.icon(
              onPressed: () => Navigator.of(context).pop(true),
              icon: const Icon(Icons.restore_page_rounded),
              label: const Text('Yeni Revizyon'),
            ),
          ],
        ),
      );
      if (confirmed != true || !mounted) return;
    }

    final result = await Navigator.of(context).push<Quote>(
      MaterialPageRoute(
        builder: (context) => QuoteEditorPage(
          quoteRepository: widget.quoteRepository,
          productRepository: widget.productRepository,
          initialRates: widget.initialRates,
          availableProducts: widget.availableProducts,
          quoteToRevise: _quote,
          revisionMode: requiresRevision,
          userProfileRepository: widget.userProfileRepository,
          cariRepository: widget.cariRepository,
          ownCompanyRepository: widget.ownCompanyRepository,
          priceAdjustmentRuleRepository: widget.priceAdjustmentRuleRepository,
        ),
      ),
    );
    if (result != null && mounted) {
      setState(() => _quote = result);
    }
  }

  Future<void> _copyQuote() async {
    await Navigator.of(context).push<Quote>(
      MaterialPageRoute(
        builder: (context) => QuoteEditorPage(
          quoteRepository: widget.quoteRepository,
          productRepository: widget.productRepository,
          initialRates: widget.initialRates,
          availableProducts: widget.availableProducts,
          quoteToCopy: _quote,
          userProfileRepository: widget.userProfileRepository,
          cariRepository: widget.cariRepository,
          ownCompanyRepository: widget.ownCompanyRepository,
          priceAdjustmentRuleRepository: widget.priceAdjustmentRuleRepository,
        ),
      ),
    );
  }

  Future<void> _exportPdf() async {
    await _runBusy(() async {
      final messenger = ScaffoldMessenger.of(context);
      final path = await _pdfService.exportQuote(
        _quote,
        onAfterSaveLocation: () {
          if (!mounted) return;
          messenger.showSnackBar(
            const SnackBar(
              content: Text('PDF üretiliyor...'),
              duration: Duration(minutes: 1),
            ),
          );
        },
      );
      messenger.hideCurrentSnackBar();
      if (!mounted || path == null) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('PDF kaydedildi: $path')));
    }, 'PDF çıkarılamadı');
  }

  Future<void> _runBusy(
    Future<void> Function() action,
    String errorPrefix,
  ) async {
    if (_isBusy) return;
    setState(() => _isBusy = true);
    try {
      await action();
    } catch (error, stack) {
      debugPrint('$errorPrefix: $error');
      debugPrintStack(stackTrace: stack);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('$errorPrefix: $error')));
      }
    } finally {
      if (mounted) setState(() => _isBusy = false);
    }
  }

  /// Sistemin e-posta istemcisini acar, gonderim kaydeder (Alici & Gonderen hesap secim dialogu).
  Future<void> _sendEmail([String? initialEmail]) async {
    final availableEmails = <String>{};
    if (initialEmail != null && initialEmail.trim().isNotEmpty) {
      availableEmails.add(initialEmail.trim());
    }
    if (_quote.documentProfile.customerEmail.trim().isNotEmpty) {
      availableEmails.add(_quote.documentProfile.customerEmail.trim());
    }

    final emailList = availableEmails.toList();
    String selectedToEmail = emailList.isNotEmpty ? emailList.first : '';
    final customEmailCtrl = TextEditingController();

    final companyEmail = _quote.documentProfile.companyEmail.trim();
    final preparedByEmail = _quote.documentProfile.preparedByEmail.trim();
    String selectedSenderAccount = 'default'; // 'default', 'preparedBy', 'company', 'custom'
    final customSenderCtrl = TextEditingController();

    final result = await showDialog<Map<String, String>>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDlgState) => AlertDialog(
          title: Row(
            children: [
              const Icon(Icons.mark_email_read_rounded, color: Color(0xFF2B82C9)),
              const SizedBox(width: 8),
              Text('Teklif E-postası Gönder (${_quote.code})'),
            ],
          ),
          content: SizedBox(
            width: 480,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'ALICI E-POSTA ADRESİ (MÜŞTERİ)',
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.w900, color: Color(0xFF5B6F7F)),
                ),
                const SizedBox(height: 6),
                if (emailList.isNotEmpty) ...[
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: emailList.map((e) {
                      final isSelected = selectedToEmail == e;
                      return ChoiceChip(
                        label: Text(e, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                        selected: isSelected,
                        selectedColor: const Color(0xFF2B82C9).withValues(alpha: 0.18),
                        onSelected: (val) {
                          if (val) setDlgState(() => selectedToEmail = e);
                        },
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 8),
                ],
                TextField(
                  controller: customEmailCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Veya Farklı E-posta Yazın',
                    hintText: 'ornek@musteri.com',
                    prefixIcon: Icon(Icons.alternate_email_rounded, size: 18),
                  ),
                  onChanged: (val) {
                    if (val.trim().isNotEmpty) {
                      setDlgState(() => selectedToEmail = val.trim());
                    }
                  },
                ),
                const SizedBox(height: 16),
                const Text(
                  'BİLGİ (CC) / OTOMATİK ARŞİV HESABI',
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.w900, color: Color(0xFF5B6F7F)),
                ),
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE6F2FB),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFFB8D0ED)),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.copy_rounded, size: 16, color: Color(0xFF2B82C9)),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'teklif@uzalteknik.com (Otomatik kopyalanır)',
                          style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w800, color: Color(0xFF17304C)),
                        ),
                      ),
                      Icon(Icons.check_rounded, size: 16, color: Color(0xFF29956F)),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'GÖNDEREN E-POSTA YÖNTEMİ / HESABI',
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.w900, color: Color(0xFF5B6F7F)),
                ),
                const SizedBox(height: 6),
                Container(
                  decoration: BoxDecoration(
                    color: const Color(0xFFF6F8FA),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFFD7DEE6)),
                  ),
                  child: Column(
                    children: [
                      InkWell(
                        onTap: () => setDlgState(() => selectedSenderAccount = 'default'),
                        borderRadius: const BorderRadius.vertical(top: Radius.circular(10)),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          child: Row(
                            children: [
                              Icon(
                                selectedSenderAccount == 'default'
                                    ? Icons.radio_button_checked_rounded
                                    : Icons.radio_button_off_rounded,
                                size: 18,
                                color: selectedSenderAccount == 'default'
                                    ? const Color(0xFF29956F)
                                    : const Color(0xFF5B6F7F),
                              ),
                              const SizedBox(width: 8),
                              const Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text('Varsayılan İstemci (Outlook/Mail App)', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: Color(0xFF17304C))),
                                    Text('Cihazınızda açık olan varsayılan e-posta hesabınız kullanılır.', style: TextStyle(fontSize: 10, color: Color(0xFF5B6F7F))),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      if (preparedByEmail.isNotEmpty) ...[
                        const Divider(height: 1),
                        InkWell(
                          onTap: () => setDlgState(() => selectedSenderAccount = 'preparedBy'),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                            child: Row(
                              children: [
                                Icon(
                                  selectedSenderAccount == 'preparedBy'
                                      ? Icons.radio_button_checked_rounded
                                      : Icons.radio_button_off_rounded,
                                  size: 18,
                                  color: selectedSenderAccount == 'preparedBy'
                                      ? const Color(0xFF2B82C9)
                                      : const Color(0xFF5B6F7F),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const Text('Hazırlayan Personel Hesabı', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: Color(0xFF17304C))),
                                      Text(preparedByEmail, style: const TextStyle(fontSize: 10.5, color: Color(0xFF9D5C1D), fontWeight: FontWeight.w700)),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                      if (companyEmail.isNotEmpty) ...[
                        const Divider(height: 1),
                        InkWell(
                          onTap: () => setDlgState(() => selectedSenderAccount = 'company'),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                            child: Row(
                              children: [
                                Icon(
                                  selectedSenderAccount == 'company'
                                      ? Icons.radio_button_checked_rounded
                                      : Icons.radio_button_off_rounded,
                                  size: 18,
                                  color: selectedSenderAccount == 'company'
                                      ? const Color(0xFF2B82C9)
                                      : const Color(0xFF5B6F7F),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const Text('Kurumsal Şirket Hesabı', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: Color(0xFF17304C))),
                                      Text(companyEmail, style: const TextStyle(fontSize: 10.5, color: Color(0xFF2B82C9), fontWeight: FontWeight.w700)),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                      const Divider(height: 1),
                      InkWell(
                        onTap: () => setDlgState(() => selectedSenderAccount = 'custom'),
                        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(10)),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Icon(
                                    selectedSenderAccount == 'custom'
                                        ? Icons.radio_button_checked_rounded
                                        : Icons.radio_button_off_rounded,
                                    size: 18,
                                    color: selectedSenderAccount == 'custom'
                                        ? const Color(0xFF8B5CC7)
                                        : const Color(0xFF5B6F7F),
                                  ),
                                  const SizedBox(width: 8),
                                  const Text('➕ Farklı Gönderen E-posta Adresi Ekle', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: Color(0xFF8B5CC7))),
                                ],
                              ),
                              if (selectedSenderAccount == 'custom') ...[
                                const SizedBox(height: 8),
                                TextField(
                                  controller: customSenderCtrl,
                                  decoration: const InputDecoration(
                                    labelText: 'Gönderen E-posta Adresiniz',
                                    hintText: 'ad.soyad@firma.com',
                                    prefixIcon: Icon(Icons.mark_email_unread_rounded, size: 16),
                                    isDense: true,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, null),
              child: const Text('Vazgeç'),
            ),
            FilledButton.icon(
              onPressed: () {
                final target = customEmailCtrl.text.trim().isNotEmpty
                    ? customEmailCtrl.text.trim()
                    : selectedToEmail;
                if (target.isEmpty) return;

                String senderAddr = '';
                if (selectedSenderAccount == 'preparedBy') senderAddr = preparedByEmail;
                if (selectedSenderAccount == 'company') senderAddr = companyEmail;
                if (selectedSenderAccount == 'custom') senderAddr = customSenderCtrl.text.trim();

                Navigator.pop(ctx, {
                  'toEmail': target,
                  'senderEmail': senderAddr,
                });
              },
              icon: const Icon(Icons.send_rounded, size: 16),
              label: const Text('E-posta Gönder'),
              style: FilledButton.styleFrom(backgroundColor: const Color(0xFF2B82C9)),
            ),
          ],
        ),
      ),
    );

    if (result == null || !result.containsKey('toEmail')) return;
    final finalToEmail = result['toEmail']!;
    final selectedSender = result['senderEmail'] ?? '';
    final quoteUrl = _quote.publicShareSlug.isNotEmpty 
        ? _quote.publicShareSlug 
        : 'https://uzalteknikservis.info/#/quote/${_quote.id}';

    // Standart Dart Uri yapisi - tum bosluk ve turkce karakterleri otomatik ve hatasiz encode eder
    final uri = Uri(
      scheme: 'mailto',
      path: finalToEmail,
      queryParameters: {
        'cc': 'teklif@uzalteknik.com',
        'subject': 'Teklif: ${_quote.code} - Uzal Teklif',
        'body': 'Sayin ${_quote.customerName.trim().isNotEmpty ? _quote.customerName.trim() : "Yetkili"},\n\n'
            '${_quote.code} kodlu teklifimizi incelemenize sunuyoruz.\n\n'
            '📄 Teklifi Çevrimiçi Görüntülemek ve PDF Olarak İndirmek İçin Bağlantıya Tıklayın:\n'
            '$quoteUrl\n\n'
            'Teklif ile ilgili sorularınız veya revizyon talepleriniz için bu e-postaya yanıt verebilirsiniz.\n\n'
            'Bilgilerinize saygılarımızla,\n'
            'Uzal Teknik Servis',
      },
    );

    try {
      bool launched = false;
      try {
        launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
      } catch (_) {
        launched = await launchUrl(uri);
      }

      if (launched) {
        await widget.quoteRepository.markEmailSent(_quote.id, finalToEmail);
        final updated = _quote.copyWith(
          emailSentAt: DateTime.now().toUtc(),
          emailSentTo: finalToEmail,
        );
        if (!mounted) return;
        setState(() => _quote = updated);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'E-posta istemcisi açıldı.${selectedSender.isNotEmpty ? " (Gönderen: $selectedSender)" : ""} Alıcı: $finalToEmail',
            ),
            backgroundColor: const Color(0xFF29956F),
          ),
        );
      } else {
        throw Exception('Launch failed');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('E-posta istemcisi açılamadı ($finalToEmail). Lütfen cihazınızda aktif mail istemcisi tanımlı olduğundan emin olun.'),
            backgroundColor: Colors.red.shade700,
          ),
        );
      }
    }
  }

  Future<void> _markCustomerResponse(CustomerResponse response) async {
    await widget.quoteRepository.updateCustomerResponse(_quote.id, response);
    if (!mounted) return;
    setState(() => _quote = _quote.copyWith(customerResponse: response));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Musteri karari guncellendi: ${response.displayLabel}')),
    );
  }

  Future<_AgreedDealResult?> _askAcceptedDeal() async {
    return showDialog<_AgreedDealResult>(
      context: context,
      builder: (ctx) => _AcceptedDealDialog(
        initialAmount: _quote.acceptedAmount,
        initialCurrencyCode: _quote.acceptedCurrencyCode,
        initialFxRate: _quote.acceptedFxRate,
        rateLookup: _quote.rateLookup,
        initialNote: _quote.acceptedNote,
      ),
    );
  }

  Future<String?> _askNote({
    required String title,
    required String hint,
    required String confirmLabel,
    bool destructive = false,
  }) async {
    return showDialog<String>(
      context: context,
      builder: (ctx) => _ApprovalNoteDialog(
        title: title,
        hint: hint,
        confirmLabel: confirmLabel,
        destructive: destructive,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final compact = MediaQuery.sizeOf(context).width < 700;
    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Teklif incelemesi',
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                color: Colors.white.withValues(alpha: 0.85),
                fontWeight: FontWeight.w700,
              ),
            ),
            Text(
              _quote.code,
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900),
            ),
          ],
        ),
        actions: [
          PopupMenuButton<String>(
            enabled: !_isBusy,
            onSelected: (v) {
              if (v.startsWith('status:')) {
                final status = QuoteStatusX.fromStorageKey(v.substring(7));
                _setStatusManually(status);
                return;
              }
              if (v == 'cancel') _cancelQuote();
              if (v == 'accepted') _markAccepted();
              if (v == 'arch') _toggleArchive(true);
              if (v == 'unarch') _toggleArchive(false);
              if (v == 'copy') _copyQuote();
            },
            itemBuilder: (ctx) => [
              const PopupMenuItem(
                value: 'copy',
                child: ListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(Icons.copy_all_rounded),
                  title: Text('Teklifi kopyala'),
                ),
              ),
              const PopupMenuDivider(),
              _statusMenuItem(QuoteStatus.draft),
              _statusMenuItem(QuoteStatus.pending),
              _statusMenuItem(QuoteStatus.approved),
              _statusMenuItem(QuoteStatus.accepted),
              _statusMenuItem(QuoteStatus.rejected),
              if (_quote.status != QuoteStatus.cancelled)
                const PopupMenuItem(value: 'cancel', child: Text('İptal et')),
              if (_quote.archivedAt == null)
                const PopupMenuItem(
                  value: 'arch',
                  child: Text('Gönderilen Tekliflere Taşı'),
                ),
              if (_quote.archivedAt != null)
                const PopupMenuItem(
                  value: 'unarch',
                  child: Text('Aktif tekliflere al'),
                ),
            ],
          ),
          IconButton(
            tooltip: 'PDF oluştur',
            onPressed: _isBusy ? null : _exportPdf,
            icon: const Icon(Icons.picture_as_pdf_rounded),
          ),
          const SizedBox(width: 6),
          if (compact)
            IconButton(
              tooltip:
                  _quote.status == QuoteStatus.draft ||
                      _quote.status == QuoteStatus.rejected
                  ? 'Düzenle'
                  : 'Yeni Revizyon',
              onPressed: _isBusy ? null : _editQuote,
              icon: const Icon(Icons.edit_rounded, size: 19),
            )
          else
            TextButton.icon(
              onPressed: _isBusy ? null : _editQuote,
              icon: const Icon(Icons.edit_rounded, size: 18),
              label: Text(
                _quote.status == QuoteStatus.draft ||
                        _quote.status == QuoteStatus.rejected
                    ? 'Düzenle'
                    : 'Yeni Revizyon',
              ),
            ),
          const SizedBox(width: 8),
        ],
      ),
      body: WorkspaceBackground(
        child: SafeArea(
          child: Padding(
            padding: EdgeInsets.fromLTRB(
              compact ? 8 : 20,
              compact ? 8 : 16,
              compact ? 8 : 20,
              compact ? 10 : 16,
            ),
            child: Column(
              children: [
                Expanded(
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _buildWorkflowCard(),
                        const SizedBox(height: 12),
                        _buildStatusCard(),
                        const SizedBox(height: 12),
                        _buildSummaryCard(),
                        const SizedBox(height: 12),
                        _buildItemsCard(),
                        if (_quote.approvalNote.isNotEmpty) ...[
                          const SizedBox(height: 12),
                          _buildNoteCard(),
                        ],
                      ],
                    ),
                  ),
                ),
                if (_quote.status == QuoteStatus.pending &&
                    widget.isManager) ...[
                  const SizedBox(height: 12),
                  _buildActionBar(),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStatusCard() {
    final status = _quote.status;
    final (label, color, bg, iconData) = switch (status) {
      QuoteStatus.draft => (
        'TASLAK',
        _slate,
        const Color(0xFFF1F4F8),
        Icons.edit_note_rounded,
      ),
      QuoteStatus.pending => (
        'GÖNDERİME HAZIR',
        const Color(0xFF9D5C1D),
        const Color(0xFFFFF4E0),
        Icons.hourglass_top_rounded,
      ),
      QuoteStatus.approved => (
        'MÜŞTERİYE GÖNDERİLDİ',
        const Color(0xFF2C6957),
        const Color(0xFFE5F1EC),
        Icons.verified_rounded,
      ),
      QuoteStatus.accepted => (
        'KAZANILDI',
        const Color(0xFF9D5C1D),
        const Color(0xFFFFF4E0),
        Icons.handshake_rounded,
      ),
      QuoteStatus.rejected => (
        'KAYBEDİLDİ',
        const Color(0xFF8A2626),
        const Color(0xFFFBE4E4),
        Icons.block_rounded,
      ),
      QuoteStatus.cancelled => (
        'IPTAL EDILDI',
        const Color(0xFF705C49),
        const Color(0xFFF3EFEA),
        Icons.cancel_schedule_send_rounded,
      ),
    };

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: bg,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(iconData, color: color, size: 22),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      color: color,
                      fontWeight: FontWeight.w900,
                      fontSize: 13,
                      letterSpacing: 0.8,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    _statusDescription(status),
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: _slate,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
            if (_quote.revisionCount > 0)
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF4E0),
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: const Color(0xFFE3B86C)),
                ),
                child: Text(
                  'Rev ${_quote.revisionCount}',
                  style: const TextStyle(
                    color: Color(0xFF9D5C1D),
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  String _statusDescription(QuoteStatus status) {
    switch (status) {
      case QuoteStatus.draft:
        return 'Hazırlama aşaması; içerik satış yetkisiyle güncellenir.';
      case QuoteStatus.pending:
        return _quote.submittedAt != null
            ? 'Teklif tamamlandı ve müşteriye gönderilmeye hazır (${_friendly(_quote.submittedAt!)})'
            : 'Teklif tamamlandı ve müşteriye gönderilmeye hazır.';
      case QuoteStatus.approved:
        final when = _quote.approvedAt;
        return when != null
            ? 'Müşteriye gönderim tarihi: ${_friendly(when)}'
            : 'Teklif müşteriye gönderildi; geri dönüş takip ediliyor.';
      case QuoteStatus.accepted:
        return 'Teklif kazanıldı; mutabık kalınan tutar satış kaydına işlendi.';
      case QuoteStatus.rejected:
        return 'Teklif kaybedildi; gerekçe aşağıdadır.';
      case QuoteStatus.cancelled:
        return 'Teklif iptal edildi; gerekçe kayıtlarda saklanır.';
    }
  }

  String _friendly(DateTime dt) =>
      DateFormat('dd.MM.yyyy HH:mm', 'tr_TR').format(dt);

  Widget _buildWorkflowCard() {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: const BorderSide(color: Color(0xFFD7DEE6)),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 18, 16, 18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Satış süreci',
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w900,
                color: _ink,
                letterSpacing: 0.15,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Aşağıdaki adımlar kayıt tarihlerine göre sıralanır.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: _slate,
                fontWeight: FontWeight.w600,
                height: 1.35,
              ),
            ),
            const SizedBox(height: 16),
            _workflowStep(
              title: 'Teklif oluşturuldu',
              subtitle: _friendly(_quote.createdAt),
              icon: Icons.description_outlined,
              color: _ink,
            ),
            if (_quote.submittedAt != null) ...[
              _workflowConnector(),
              _workflowStep(
                title: 'Gönderime hazırlandı',
                subtitle: _friendly(_quote.submittedAt!),
                icon: Icons.forward_to_inbox_outlined,
                color: const Color(0xFF9D5C1D),
              ),
            ],
            if (_quote.approvedAt != null) ...[
              _workflowConnector(),
              _workflowStep(
                title: 'Müşteriye gönderildi',
                subtitle:
                    '${_friendly(_quote.approvedAt!)} — ${_quote.approvedByName.trim().isEmpty ? 'Satış yetkilisi' : _quote.approvedByName.trim()}',
                icon: Icons.send_outlined,
                color: const Color(0xFF2C6957),
              ),
            ],
            // E-posta gonderim adimi
            if (_quote.emailSentAt != null) ...[
              _workflowConnector(),
              _workflowStep(
                title: 'E-posta gönderildi',
                subtitle: '${_friendly(_quote.emailSentAt!)} — ${_quote.emailSentTo}',
                icon: Icons.email_rounded,
                color: const Color(0xFF2B82C9),
              ),
            ],
            // Musteri cevap adimi
            if (_quote.emailSentAt != null &&
                _quote.customerResponse != CustomerResponse.pending) ...[
              _workflowConnector(),
              _workflowStep(
                title: 'Müşteri kararı: ${_quote.customerResponse.displayLabel}',
                subtitle: switch (_quote.customerResponse) {
                  CustomerResponse.accepted => 'Müşteri kabul etti.',
                  CustomerResponse.rejected => 'Müşteri reddetti.',
                  CustomerResponse.noResponse => 'Cevap alınamadı.',
                  CustomerResponse.pending => '',
                },
                icon: switch (_quote.customerResponse) {
                  CustomerResponse.accepted => Icons.thumb_up_rounded,
                  CustomerResponse.rejected => Icons.thumb_down_rounded,
                  _ => Icons.do_not_disturb_alt_rounded,
                },
                color: switch (_quote.customerResponse) {
                  CustomerResponse.accepted => const Color(0xFF29956F),
                  CustomerResponse.rejected => const Color(0xFF9D2C2C),
                  _ => const Color(0xFF5B6F7F),
                },
              ),
            ],
            if (_quote.status == QuoteStatus.rejected &&
                _quote.approvedAt != null) ...[
              _workflowConnector(),
              _workflowStep(
                title: 'Kaybedildi',
                subtitle: _friendly(_quote.approvedAt!),
                icon: Icons.cancel_outlined,
                color: const Color(0xFF8A2626),
              ),
            ],
            if (_quote.status == QuoteStatus.accepted &&
                _quote.acceptedAt != null) ...[
              _workflowConnector(),
              _workflowStep(
                title: 'Kazanıldı',
                subtitle: _friendly(_quote.acceptedAt!),
                icon: Icons.emoji_events_outlined,
                color: const Color(0xFF2C6957),
              ),
            ],
            if (_quote.status == QuoteStatus.cancelled &&
                _quote.approvedAt != null) ...[
              _workflowConnector(),
              _workflowStep(
                title: 'İptal edildi',
                subtitle: _friendly(_quote.approvedAt!),
                icon: Icons.cancel_schedule_send_outlined,
                color: const Color(0xFF705C49),
              ),
            ],
            // Revizyon / Yönetici Notu (Varsa)
            if (_quote.approvalNote.trim().isNotEmpty) ...[
              const SizedBox(height: 14),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF9EE),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFFE8C88B)),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(
                      Icons.note_alt_outlined,
                      size: 18,
                      color: Color(0xFF9D5C1D),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Süreç / Revizyon Notu:',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w900,
                              color: Color(0xFF9D5C1D),
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            _quote.approvalNote.trim(),
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF3D2C1D),
                              height: 1.3,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _workflowConnector() {
    return Padding(
      padding: const EdgeInsets.only(left: 11, top: 2, bottom: 2),
      child: Container(
        width: 2,
        height: 12,
        decoration: BoxDecoration(
          color: const Color(0xFFD7DEE6),
          borderRadius: BorderRadius.circular(1),
        ),
      ),
    );
  }

  Widget _workflowStep({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 24, color: color),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontWeight: FontWeight.w800,
                  color: _ink,
                  fontSize: 13.5,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: const TextStyle(
                  color: _slate,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  height: 1.3,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSummaryCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Ticari özet',
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                fontWeight: FontWeight.w900,
                color: _slate,
                letterSpacing: 0.4,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              _quote.title.isEmpty ? 'Başlıksız teklif' : _quote.title,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w900,
                color: _ink,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '${_quote.customerCompany.isEmpty ? "Firma bilgisi girilmedi" : _quote.customerCompany} — ${_quote.customerName}',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: _slate,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 14),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                _buildMiniChip('Teklif No', _quote.code),
                _buildMiniChip('Tarih', _quote.formattedDate),
                _buildMiniChip('Durum', _quote.status.displayLabel),
                _buildMiniChip('Toplam', _formatTotal(_quote)),
                if (_quote.acceptedTotalTl != null)
                  _buildMiniChip(
                    'Anlaşılan Toplam',
                    _formatAcceptedTotal(_quote),
                  ),
                if (_quote.createdByName.trim().isNotEmpty)
                  _buildMiniChip('Teklif Sorumlusu', _quote.createdByName),
                // E-posta takip chip'leri
                if (_quote.emailSentAt != null)
                  _buildMiniChip(
                    'E-posta Gönderildi',
                    '${_friendly(_quote.emailSentAt!)} — ${_quote.emailSentTo}',
                  ),
                if (_quote.emailSentAt != null)
                  _buildMiniChip(
                    'Müşteri Kararı',
                    _quote.customerResponse.displayLabel,
                  ),
              ],
            ),
            // E-posta gonderim butonu (status approved ise)
            if (_quote.status == QuoteStatus.approved) ...[
              const SizedBox(height: 16),
              _buildEmailSendRow(),
            ],
          ],
        ),
      ),
    );
  }

  /// Onayli tekliflerde e-posta gonderim ve musteri cevap satiri.
  Widget _buildEmailSendRow() {
    final emails = <String>{};
    if (_quote.documentProfile.customerEmail.trim().isNotEmpty) {
      emails.add(_quote.documentProfile.customerEmail.trim());
    }
    final alreadySent = _quote.emailSentAt != null;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF0F6FF),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFB8D0ED)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                alreadySent
                    ? Icons.mark_email_read_rounded
                    : Icons.forward_to_inbox_rounded,
                size: 18,
                color: const Color(0xFF2B82C9),
              ),
              const SizedBox(width: 8),
              Text(
                alreadySent ? 'E-posta Gönderildi' : 'E-posta ile Gönder',
                style: const TextStyle(
                  fontWeight: FontWeight.w900,
                  fontSize: 13,
                  color: Color(0xFF1A4A7A),
                ),
              ),
            ],
          ),
          if (alreadySent) ...[
            const SizedBox(height: 6),
            Text(
              '${DateFormat('dd.MM.yyyy HH:mm', 'tr_TR').format(_quote.emailSentAt!)} — ${_quote.emailSentTo}',
              style: const TextStyle(
                fontSize: 12,
                color: Color(0xFF2B82C9),
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                const Text(
                  'Müşteri kararı:',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF17304C),
                  ),
                ),
                const SizedBox(width: 8),
                PopupMenuButton<CustomerResponse>(
                  tooltip: 'Karar güncelle',
                  itemBuilder: (ctx) => CustomerResponse.values
                      .map(
                        (r) => PopupMenuItem<CustomerResponse>(
                          value: r,
                          child: Text(r.displayLabel),
                        ),
                      )
                      .toList(),
                  onSelected: _markCustomerResponse,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFFB8D0ED)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          _quote.customerResponse.displayLabel,
                          style: const TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 12,
                            color: Color(0xFF17304C),
                          ),
                        ),
                        const SizedBox(width: 4),
                        const Icon(
                          Icons.arrow_drop_down_rounded,
                          size: 18,
                          color: Color(0xFF5B6F7F),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: FilledButton.icon(
                    onPressed: () => _sendEmail(),
                    icon: const Icon(Icons.refresh_rounded, size: 16),
                    label: Text(
                      'Tekrar E-posta Gönder (${_quote.emailSentTo.isNotEmpty ? _quote.emailSentTo : "Müşteriye"})',
                      overflow: TextOverflow.ellipsis,
                    ),
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFF2B82C9),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800),
                    ),
                  ),
                ),
              ],
            ),
          ] else if (emails.isNotEmpty) ...[
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: emails
                  .map(
                    (e) => FilledButton.icon(
                      onPressed: () => _sendEmail(e),
                      icon: const Icon(Icons.send_rounded, size: 16),
                      label: Text(e),
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFF2B82C9),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 8,
                        ),
                        textStyle: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  )
                  .toList(),
            ),
          ] else ...[
            const SizedBox(height: 6),
            const Text(
              'Bu teklifte kayıtlı müşteri e-postası yok. '
              'Teklif seçeneklerinden ekleyebilirsiniz.',
              style: TextStyle(
                fontSize: 12,
                color: Color(0xFF5B6F7F),
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildMiniChip(String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFFF1F4F8),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFD7DEE6)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label.toUpperCase(),
            style: const TextStyle(
              color: _slate,
              fontSize: 10,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.6,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: const TextStyle(
              color: _ink,
              fontSize: 13,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }

  String _formatTotal(Quote quote) {
    final formatter = NumberFormat.currency(
      locale: 'tr_TR',
      symbol: switch (quote.displayUnit) {
        'USDTRY' => r'$ ',
        'EURTRY' => 'EUR ',
        _ => 'TL ',
      },
      decimalDigits: 2,
    );
    return formatter.format(quote.totalFor(quote.displayUnit));
  }

  String _formatAcceptedTotal(Quote quote) {
    final agreed = quote.acceptedAmount;
    if (agreed == null) return '-';
    final currencyCode = quote.acceptedCurrencyCode.trim().isEmpty
        ? 'TL'
        : quote.acceptedCurrencyCode.trim();
    final formatter = NumberFormat.currency(
      locale: 'tr_TR',
      symbol: switch (quote.displayUnit) {
        'USDTRY' => r'$ ',
        'EURTRY' => 'EUR ',
        _ => 'TL ',
      },
      decimalDigits: 2,
    );
    final agreedFormatter = NumberFormat.currency(
      locale: 'tr_TR',
      symbol: switch (currencyCode) {
        'USDTRY' => r'$ ',
        'EURTRY' => 'EUR ',
        _ => 'TL ',
      },
      decimalDigits: 2,
    );
    final commercial = formatter.format(quote.totalFor(quote.displayUnit));
    return '${agreedFormatter.format(agreed)} ($commercial)';
  }

  Widget _buildItemsCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Kalem detayı (${_quote.items.length})',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w900,
                color: _ink,
              ),
            ),
            const SizedBox(height: 12),
            ..._quote.items.map((item) => _buildItemRow(item)),
          ],
        ),
      ),
    );
  }

  Widget _buildItemRow(QuoteLineItem item) {
    final unitPrice = item.unitPriceTl;
    final total = item.totalTl;
    final moneyFmt = NumberFormat.currency(
      locale: 'tr_TR',
      symbol: 'TL ',
      decimalDigits: 2,
    );

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: const Color(0xFFF7F9FC),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: const Color(0xFFE4E8EC)),
        ),
        child: Row(
          children: [
            Expanded(
              flex: 3,
              child: Text(
                item.description,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: _ink,
                  fontWeight: FontWeight.w800,
                  fontSize: 13,
                  height: 1.25,
                ),
              ),
            ),
            const SizedBox(width: 8),
            SizedBox(
              width: 60,
              child: Text(
                '${item.quantity.toStringAsFixed(item.quantity.truncateToDouble() == item.quantity ? 0 : 2)} ${item.unit}',
                textAlign: TextAlign.end,
                style: const TextStyle(
                  color: _slate,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            const SizedBox(width: 8),
            SizedBox(
              width: 110,
              child: Text(
                moneyFmt.format(unitPrice),
                textAlign: TextAlign.end,
                style: const TextStyle(
                  color: _slate,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            const SizedBox(width: 8),
            SizedBox(
              width: 120,
              child: Text(
                moneyFmt.format(total),
                textAlign: TextAlign.end,
                style: const TextStyle(
                  color: _ink,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNoteCard() {
    final isRejected = _quote.status == QuoteStatus.rejected;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  isRejected ? Icons.block_rounded : Icons.history_rounded,
                  color: isRejected
                      ? const Color(0xFF8A2626)
                      : const Color(0xFF9D5C1D),
                  size: 20,
                ),
                const SizedBox(width: 8),
                Text(
                  isRejected ? 'Red gerekçesi' : 'Kurumsal not',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w900,
                    color: _ink,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              _quote.approvalNote,
              style: const TextStyle(
                color: _ink,
                fontSize: 14,
                fontWeight: FontWeight.w700,
                height: 1.35,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionBar() {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: const BorderSide(color: Color(0xFFD7DEE6)),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Satış Aksiyonları',
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w900,
                color: _ink,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Teklifi müşteriye gönderildi, revizyonda veya kaybedildi olarak güncelleyin.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: _slate,
                fontWeight: FontWeight.w600,
                height: 1.35,
              ),
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _isBusy ? null : _reject,
                    icon: const Icon(Icons.block_rounded),
                    label: const Text('Kaybedildi'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF8A2626),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _isBusy ? null : _requestRevision,
                    icon: const Icon(Icons.edit_note_rounded),
                    label: const Text('Revizyona al'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF9D5C1D),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  flex: 2,
                  child: FilledButton.icon(
                    onPressed: _isBusy ? null : _approve,
                    icon: _isBusy
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.verified_rounded),
                    label: const Text('Müşteriye gönderildi'),
                    style: FilledButton.styleFrom(
                      backgroundColor: _accent,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _AgreedDealResult {
  const _AgreedDealResult({
    required this.totalTl,
    required this.amount,
    required this.currencyCode,
    required this.fxRate,
    required this.note,
  });

  final double? totalTl;
  final double? amount;
  final String currencyCode;
  final double? fxRate;
  final String note;
}

class _AcceptedDealDialog extends StatefulWidget {
  const _AcceptedDealDialog({
    required this.initialAmount,
    required this.initialCurrencyCode,
    required this.initialFxRate,
    required this.rateLookup,
    required this.initialNote,
  });

  final double? initialAmount;
  final String initialCurrencyCode;
  final double? initialFxRate;
  final Map<String, double> rateLookup;
  final String initialNote;

  @override
  State<_AcceptedDealDialog> createState() => _AcceptedDealDialogState();
}

class _AcceptedDealDialogState extends State<_AcceptedDealDialog> {
  late final TextEditingController _totalController;
  late final TextEditingController _noteController;
  late String _currencyCode;
  double _fxRate = 1.0;

  @override
  void initState() {
    super.initState();
    _totalController = TextEditingController(
      text: widget.initialAmount == null
          ? ''
          : widget.initialAmount!.toStringAsFixed(2),
    );
    _noteController = TextEditingController(text: widget.initialNote);
    _currencyCode = switch (widget.initialCurrencyCode) {
      'USDTRY' => 'USDTRY',
      'EURTRY' => 'EURTRY',
      _ => 'TL',
    };
    _fxRate = _resolveFxRate(_currencyCode);
  }

  @override
  void dispose() {
    _totalController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  void _submit() {
    final totalRaw = _totalController.text.trim().replaceAll(',', '.');
    double? amount;
    double? totalTl;
    if (totalRaw.isNotEmpty) {
      amount = double.tryParse(totalRaw);
      if (amount == null || amount < 0) return;
      final rate = _currencyCode == 'TL'
          ? 1.0
          : (widget.rateLookup[_currencyCode] ?? 1.0);
      totalTl = amount * rate;
    }
    Navigator.of(context).pop(
      _AgreedDealResult(
        totalTl: totalTl,
        amount: amount,
        currencyCode: _currencyCode,
        fxRate: amount == null ? null : _resolveFxRate(_currencyCode),
        note: _noteController.text.trim(),
      ),
    );
  }

  double _resolveFxRate(String code) {
    if (code == 'TL') return 1.0;
    final fromQuote = widget.rateLookup[code];
    if (fromQuote != null && fromQuote > 0) return fromQuote;
    if (widget.initialFxRate != null && widget.initialFxRate! > 0) {
      return widget.initialFxRate!;
    }
    return 1.0;
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Kazanılan satış tutarı'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Align(
            alignment: Alignment.centerLeft,
            child: Text(
              'Müşteriyle mutabık kalınan nihai tutarı ve para birimini kaydedin.',
            ),
          ),
          const SizedBox(height: 10),
          DropdownButtonFormField<String>(
            initialValue: _currencyCode,
            items: const [
              DropdownMenuItem(value: 'TL', child: Text('TL')),
              DropdownMenuItem(value: 'USDTRY', child: Text('USD')),
              DropdownMenuItem(value: 'EURTRY', child: Text('EUR')),
            ],
            onChanged: (value) {
              if (value == null) return;
              setState(() {
                _currencyCode = value;
                _fxRate = _resolveFxRate(value);
              });
            },
            decoration: const InputDecoration(labelText: 'Para birimi'),
          ),
          const SizedBox(height: 6),
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              _currencyCode == 'TL'
                  ? 'Kullanilan kur: 1.000000'
                  : 'Kullanilan kur (${_currencyCode == 'USDTRY' ? 'USD/TRY' : 'EUR/TRY'}): ${_fxRate.toStringAsFixed(6)}',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _totalController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(
              labelText:
                  'Anlaşılan toplam (${_currencyCode == 'USDTRY'
                      ? 'USD'
                      : _currencyCode == 'EURTRY'
                      ? 'EUR'
                      : 'TL'})',
              hintText: 'Orn. 125000',
            ),
            onSubmitted: (_) => _submit(),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _noteController,
            maxLines: 3,
            decoration: const InputDecoration(
              labelText: 'Mutabakat notu',
              hintText: 'Opsiyonel aciklama',
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(null),
          child: const Text('Vazgec'),
        ),
        FilledButton(
          onPressed: _submit,
          child: const Text('Kazanıldı olarak kaydet'),
        ),
      ],
    );
  }
}

/// Revizyon veya red notu girisi icin dialog. Bos metinle onay verilemez.
class _ApprovalNoteDialog extends StatefulWidget {
  const _ApprovalNoteDialog({
    required this.title,
    required this.hint,
    required this.confirmLabel,
    required this.destructive,
  });

  final String title;
  final String hint;
  final String confirmLabel;
  final bool destructive;

  @override
  State<_ApprovalNoteDialog> createState() => _ApprovalNoteDialogState();
}

class _ApprovalNoteDialogState extends State<_ApprovalNoteDialog> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    final trimmed = _controller.text.trim();
    if (trimmed.isEmpty) return;
    Navigator.of(context).pop(trimmed);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title),
      content: TextField(
        controller: _controller,
        autofocus: true,
        maxLines: 4,
        decoration: InputDecoration(hintText: widget.hint),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(null),
          child: const Text('Vazgec'),
        ),
        FilledButton(
          onPressed: _submit,
          style: widget.destructive
              ? FilledButton.styleFrom(backgroundColor: const Color(0xFF8A2626))
              : null,
          child: Text(widget.confirmLabel),
        ),
      ],
    );
  }
}
