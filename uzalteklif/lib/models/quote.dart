import 'package:intl/intl.dart';

import 'market_rate.dart';

class QuoteLineItem {
  const QuoteLineItem({
    required this.id,
    required this.description,
    required this.quantity,
    required this.unit,
    required this.unitPriceTl,
    this.discountRate = 0,
    this.sectionId = '',
  });

  final String id;
  final String description;
  final double quantity;
  final String unit;
  final double unitPriceTl;
  final double discountRate;

  /// Kalemin ait oldugu kategori (bkz. [QuoteSection]) kimligi. Bos ise
  /// kalem herhangi bir kategoriye atanmamistir ("Genel" kovasi).
  final String sectionId;

  double get netUnitPriceTl => unitPriceTl * (1 - (discountRate / 100));

  double get totalTl => quantity * netUnitPriceTl;

  Map<String, dynamic> toJson() => {
    'id': id,
    'description': description,
    'quantity': quantity,
    'unit': unit,
    'unit_price_tl': unitPriceTl,
    'discount_rate': discountRate,
    'section_id': sectionId,
  };

  factory QuoteLineItem.fromJson(Map<String, dynamic> json) {
    return QuoteLineItem(
      id: json['id'] as String,
      description: json['description'] as String,
      quantity: (json['quantity'] as num).toDouble(),
      unit: json['unit'] as String,
      unitPriceTl: (json['unit_price_tl'] as num).toDouble(),
      discountRate: (json['discount_rate'] as num?)?.toDouble() ?? 0,
      sectionId: (json['section_id'] as String?)?.trim() ?? '',
    );
  }
}

/// Teklif icindeki kalem grubu (kategori). Ornek: "DDC Kontrolleri",
/// "Montaj Malzemeleri". PDF'te ara toplamlarin cikmasi icin kullanilir.
class QuoteSection {
  const QuoteSection({required this.id, required this.name});

  final String id;
  final String name;

  Map<String, dynamic> toJson() => {'id': id, 'name': name};

  factory QuoteSection.fromJson(Map<String, dynamic> json) {
    return QuoteSection(
      id: json['id'] as String? ?? '',
      name: (json['name'] as String? ?? '').trim(),
    );
  }
}

class HiddenCostParameter {
  const HiddenCostParameter({
    required this.label,
    required this.quantity,
    required this.unitPriceTl,
  });

  final String label;
  final double quantity;
  final double unitPriceTl;

  double get totalTl => quantity * unitPriceTl;

  Map<String, dynamic> toJson() => {
    'label': label,
    'quantity': quantity,
    'unit_price_tl': unitPriceTl,
  };

  factory HiddenCostParameter.fromJson(Map<String, dynamic> json) {
    return HiddenCostParameter(
      label: json['label'] as String? ?? '',
      quantity: (json['quantity'] as num?)?.toDouble() ?? 0,
      unitPriceTl: (json['unit_price_tl'] as num?)?.toDouble() ?? 0,
    );
  }
}

class HiddenCostItem {
  const HiddenCostItem({
    required this.id,
    required this.name,
    required this.parameters,
    this.note = '',
  });

  final String id;
  final String name;
  final List<HiddenCostParameter> parameters;
  final String note;

  double get totalTl =>
      parameters.fold(0, (previous, parameter) => previous + parameter.totalTl);

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'note': note,
    'parameters': parameters.map((p) => p.toJson()).toList(),
  };

  factory HiddenCostItem.fromJson(Map<String, dynamic> json) {
    final params = (json['parameters'] as List<dynamic>? ?? const [])
        .cast<Map<String, dynamic>>()
        .map(HiddenCostParameter.fromJson)
        .toList();
    return HiddenCostItem(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      note: json['note'] as String? ?? '',
      parameters: params,
    );
  }
}

class QuoteDocumentProfile {
  const QuoteDocumentProfile({
    required this.companyName,
    required this.companyTagline,
    required this.companyPhone,
    required this.companyEmail,
    required this.companyWebsite,
    required this.companyAddress,
    required this.preparedByName,
    required this.preparedByTitle,
    required this.preparedByPhone,
    required this.preparedByEmail,
    required this.customerContactTitle,
    required this.customerPhone,
    required this.customerEmail,
    required this.validityText,
    required this.paymentTerms,
    required this.deliveryTerms,
    this.companyTaxOffice = '',
    this.companyTaxNumber = '',
    this.companyMersis = '',
    this.bankName = '',
    this.bankBranch = '',
    this.bankAccountName = '',
    this.bankIban = '',
    this.bankSwift = '',
    this.vatRate = 20.0,
  });

  final String companyName;
  final String companyTagline;
  final String companyPhone;
  final String companyEmail;
  final String companyWebsite;
  final String companyAddress;
  final String preparedByName;
  final String preparedByTitle;
  final String preparedByPhone;
  final String preparedByEmail;
  final String customerContactTitle;
  final String customerPhone;
  final String customerEmail;
  final String validityText;
  final String paymentTerms;
  final String deliveryTerms;

  final String companyTaxOffice;
  final String companyTaxNumber;
  final String companyMersis;

  final String bankName;
  final String bankBranch;
  final String bankAccountName;
  final String bankIban;
  final String bankSwift;

  final double vatRate;

  Map<String, dynamic> toJson() => {
    'company_name': companyName,
    'company_tagline': companyTagline,
    'company_phone': companyPhone,
    'company_email': companyEmail,
    'company_website': companyWebsite,
    'company_address': companyAddress,
    'prepared_by_name': preparedByName,
    'prepared_by_title': preparedByTitle,
    'prepared_by_phone': preparedByPhone,
    'prepared_by_email': preparedByEmail,
    'customer_contact_title': customerContactTitle,
    'customer_phone': customerPhone,
    'customer_email': customerEmail,
    'validity_text': validityText,
    'payment_terms': paymentTerms,
    'delivery_terms': deliveryTerms,
    'company_tax_office': companyTaxOffice,
    'company_tax_number': companyTaxNumber,
    'company_mersis': companyMersis,
    'bank_name': bankName,
    'bank_branch': bankBranch,
    'bank_account_name': bankAccountName,
    'bank_iban': bankIban,
    'bank_swift': bankSwift,
    'vat_rate': vatRate,
  };

  factory QuoteDocumentProfile.fromJson(Map<String, dynamic> json) {
    return QuoteDocumentProfile(
      companyName: json['company_name'] as String? ?? '',
      companyTagline: json['company_tagline'] as String? ?? '',
      companyPhone: json['company_phone'] as String? ?? '',
      companyEmail: json['company_email'] as String? ?? '',
      companyWebsite: json['company_website'] as String? ?? '',
      companyAddress: json['company_address'] as String? ?? '',
      preparedByName: json['prepared_by_name'] as String? ?? '',
      preparedByTitle: json['prepared_by_title'] as String? ?? '',
      preparedByPhone: json['prepared_by_phone'] as String? ?? '',
      preparedByEmail: json['prepared_by_email'] as String? ?? '',
      customerContactTitle: json['customer_contact_title'] as String? ?? '',
      customerPhone: json['customer_phone'] as String? ?? '',
      customerEmail: json['customer_email'] as String? ?? '',
      validityText: json['validity_text'] as String? ?? '',
      paymentTerms: json['payment_terms'] as String? ?? '',
      deliveryTerms: json['delivery_terms'] as String? ?? '',
      companyTaxOffice: json['company_tax_office'] as String? ?? '',
      companyTaxNumber: json['company_tax_number'] as String? ?? '',
      companyMersis: json['company_mersis'] as String? ?? '',
      bankName: json['bank_name'] as String? ?? '',
      bankBranch: json['bank_branch'] as String? ?? '',
      bankAccountName: json['bank_account_name'] as String? ?? '',
      bankIban: json['bank_iban'] as String? ?? '',
      bankSwift: json['bank_swift'] as String? ?? '',
      vatRate: (json['vat_rate'] as num?)?.toDouble() ?? 20.0,
    );
  }
}

/// Teklifin ic onay surecindeki durumu. Seller teklifi `draft` olarak
/// hazirlar, "Onaya Gonder" ile `pending` yapar; yonetici review ekraninda
/// `approved` / `rejected` olarak kapatabilir ya da revizyon isteyerek
/// `draft`'a geri dusurur (revisionCount artar, approvalNote dolar).
enum QuoteStatus { draft, pending, approved, accepted, rejected, cancelled }

extension QuoteStatusX on QuoteStatus {
  String get storageKey {
    switch (this) {
      case QuoteStatus.draft:
        return 'draft';
      case QuoteStatus.pending:
        return 'sent';
      case QuoteStatus.approved:
        return 'approved';
      case QuoteStatus.accepted:
        return 'accepted';
      case QuoteStatus.rejected:
        return 'rejected';
      case QuoteStatus.cancelled:
        return 'cancelled';
    }
  }

  String get displayLabel {
    switch (this) {
      case QuoteStatus.draft:
        return 'Taslak';
      case QuoteStatus.pending:
        return 'Onaya Gönderildi';
      case QuoteStatus.approved:
        return 'İç Onaylandı';
      case QuoteStatus.accepted:
        return 'Anlaşıldı';
      case QuoteStatus.rejected:
        return 'Reddedildi';
      case QuoteStatus.cancelled:
        return 'İptal Edildi';
    }
  }

  static QuoteStatus fromStorageKey(String? raw) {
    switch (raw) {
      case 'sent':
      case 'pending':
        return QuoteStatus.pending;
      case 'approved':
        return QuoteStatus.approved;
      case 'accepted':
        return QuoteStatus.accepted;
      case 'rejected':
        return QuoteStatus.rejected;
      case 'cancelled':
        return QuoteStatus.cancelled;
      default:
        return QuoteStatus.draft;
    }
  }
}

/// Teklifin odeme yontemini yapilandirilmis sekilde tutar. `paymentTerms`
/// free-text alani hala korunur (geriye donuk uyumluluk ve ozel notlar icin)
/// ancak PDF ve linkler bu enum'a gore davranir.
enum QuotePaymentMethod { cash, creditCard, installment }

extension QuotePaymentMethodX on QuotePaymentMethod {
  String get storageKey {
    switch (this) {
      case QuotePaymentMethod.cash:
        return 'cash';
      case QuotePaymentMethod.creditCard:
        return 'credit_card';
      case QuotePaymentMethod.installment:
        return 'installment';
    }
  }

  /// Turkce kullanici arayuzu ve PDF icin kisa etiket.
  String get displayLabel {
    switch (this) {
      case QuotePaymentMethod.cash:
        return 'Nakit';
      case QuotePaymentMethod.creditCard:
        return 'Kredi Karti';
      case QuotePaymentMethod.installment:
        return 'Vadeli';
    }
  }

  static QuotePaymentMethod fromStorageKey(String? raw) {
    switch (raw) {
      case 'credit_card':
        return QuotePaymentMethod.creditCard;
      case 'installment':
        return QuotePaymentMethod.installment;
      default:
        return QuotePaymentMethod.cash;
    }
  }
}

class Quote {
  Quote({
    required this.id,
    required this.code,
    required this.customerName,
    required this.customerCompany,
    required this.title,
    required this.note,
    required this.createdAt,
    required this.displayUnit,
    required this.items,
    required this.marketSnapshot,
    required this.documentProfile,
    this.hiddenCosts = const [],
    this.publicToken = '',
    this.paymentMethod = QuotePaymentMethod.cash,
    this.paymentTermDays = 0,
    this.hidePrices = false,
    this.sections = const [],
    this.status = QuoteStatus.draft,
    this.submittedAt,
    this.approvedAt,
    this.approvedBy,
    this.approvedByName = '',
    this.approvalNote = '',
    this.acceptedTotalTl,
    this.acceptedAmount,
    this.acceptedCurrencyCode = 'TL',
    this.acceptedFxRate,
    this.acceptedNote = '',
    this.acceptedAt,
    this.acceptedBy,
    this.acceptedByName = '',
    this.revisionCount = 0,
    this.cariId = '',
    this.createdBy,
    this.createdByName = '',
    this.archivedAt,
  });

  final String id;
  final String code;
  final String customerName;
  final String customerCompany;

  /// [customer_accounts] kaydi; bos ise manuel musteri girisi.
  final String cariId;
  final String title;
  final String note;
  final DateTime createdAt;
  final String displayUnit;
  final List<QuoteLineItem> items;
  final List<MarketRate> marketSnapshot;
  final QuoteDocumentProfile documentProfile;
  final List<HiddenCostItem> hiddenCosts;

  /// Teklifin herkese acik linkinde kullanilan, tahmin edilemez kisa parca.
  /// Bos ise teklif henuz "paylasilabilir" halde kaydedilmemistir; PDF
  /// katmani bu durumda QR/link alanini gizler.
  final String publicToken;

  /// Teklifin odeme yontemi: nakit, kart veya vadeli.
  final QuotePaymentMethod paymentMethod;

  /// `paymentMethod == installment` ise vade gunu; aksi halde 0. 0 degeri
  /// "vade belirtilmedi" anlamina gelir.
  final int paymentTermDays;

  /// `true` oldugunda PDF'te fiyat, iskonto ve toplam sutunlari gizlenir;
  /// musteriye yalnizca malzeme listesi (aciklama/birim/miktar) gonderilir.
  final bool hidePrices;

  /// Teklifteki kategori/grup tanimlari. Sira aynen korunur. Bos liste veya
  /// tum kalemlerin `sectionId`'si bos ise PDF gruplar olmadan eski duzende
  /// cikar.
  final List<QuoteSection> sections;

  /// Ic onay surecinin durumu. Varsayilan `draft`. `approved` olan teklifler
  /// editorde read-only hale gelir ve PDF'e kase basilir.
  final QuoteStatus status;

  /// Seller'in "Onaya Gonder" dedigi an. `status == draft` iken null.
  final DateTime? submittedAt;

  /// Yoneticinin onaylayip/reddettigi an. Sadece `approved` veya `rejected`
  /// statulerinde doludur.
  final DateTime? approvedAt;

  /// Onaylayan yoneticinin Supabase `auth.users` kimligi.
  final String? approvedBy;

  /// Onaylayan yoneticinin adi (PDF ve UI'da gorunur). Onay dialog'unda
  /// bos birakilirsa `QuoteDocumentProfile.preparedByName` fallback olarak
  /// kullanilir.
  final String approvedByName;

  /// Onay/revizyon/red notu. Revizyona gonderildiyse seller'in gorecegi
  /// yonetici yorumu; reddedildiyse red gerekcesi.
  final String approvalNote;

  /// Pazarlik/nihai mutabakat sonrasi kabul edilen toplam tutar (TL).
  /// Null ise teklif henuz "kabul tutari" ile sonuclandirilmamistir.
  final double? acceptedTotalTl;

  /// Kullaniciya gorunen mutabakat tutari (secili para birimindeki ham deger).
  final double? acceptedAmount;

  /// Mutabakat tutarinin kaydedildigi para birimi (`TL`, `USDTRY`, `EURTRY`).
  final String acceptedCurrencyCode;

  /// Mutabakat aninda kullanilan sabit kur.
  /// TL icin 1.0, USD/EUR icin o andaki TL karsiligi.
  final double? acceptedFxRate;

  /// Kabul tutarina ait not (pazarlik kosulu, indirim aciklamasi, vb.).
  final String acceptedNote;

  /// Kabul tutari sisteme ilk kez girildigi an.
  final DateTime? acceptedAt;

  /// Kabul tutarini giren/kayda gecen kullanicinin kimligi.
  final String? acceptedBy;

  /// Kabul tutarini giren kisinin gorunen adi.
  final String acceptedByName;

  /// Kac kez revizyona gonderilip tekrar onaya sunuldugu. Sadece metadata;
  /// UI'da "Revizyon #2" gibi etiketler gostermek icin.
  final int revisionCount;

  /// Supabase `auth.users` kimligi; offline/memory'de bos olabilir.
  final String? createdBy;

  /// Olusturan kisinin gorunen adi (PDF hazirlayan ile ayni olabilir).
  final String createdByName;

  /// Dolu ise teklif arsivlenmistir; aktif listelerde gosterilmez.
  final DateTime? archivedAt;

  /// Kalemleri kategori sirasina gore gruplandirir. Bir kategoriye ait hic
  /// kalem yoksa grup listeye eklenmez. Son olarak hicbir `sections` icindeki
  /// id'ye denk gelmeyen kalemler (veya bos `sectionId`) varsa onlari
  /// `null` basligi altinda bir ek grup olarak ekler.
  List<QuoteSectionGroup> get sectionedItems {
    final groups = <QuoteSectionGroup>[];
    final seenSectionIds = <String>{};

    for (final section in sections) {
      final bucket = items
          .where((item) => item.sectionId == section.id)
          .toList(growable: false);
      if (bucket.isEmpty) continue;
      groups.add(QuoteSectionGroup(section: section, items: bucket));
      seenSectionIds.add(section.id);
    }

    final orphaned = items
        .where((item) => !seenSectionIds.contains(item.sectionId))
        .toList(growable: false);
    if (orphaned.isNotEmpty) {
      groups.add(QuoteSectionGroup(section: null, items: orphaned));
    }

    return groups;
  }

  /// Odeme bilgisi icin kisa, okunabilir bir metin uretir. PDF'te "Odeme"
  /// teriminin altinda gorunur.
  String get paymentSummaryLine {
    switch (paymentMethod) {
      case QuotePaymentMethod.cash:
        return 'Pesin (Nakit)';
      case QuotePaymentMethod.creditCard:
        return 'Kredi karti';
      case QuotePaymentMethod.installment:
        if (paymentTermDays > 0) {
          return '$paymentTermDays gun vadeli';
        }
        return 'Vadeli';
    }
  }

  /// `UZ-260421-104500-a7f9` gibi link icinde kullanilabilen benzersiz slug.
  /// Token uretilmediyse yalnizca teklif kodu doner.
  String get publicShareSlug {
    final token = publicToken.trim();
    if (token.isEmpty) return code;
    return '$code-$token';
  }

  /// Verilen kok URL'yi slug ile birlestirerek paylasilabilir linki uretir.
  /// Kok bos ise sadece slug doner (offline kopya / manuel yerlestirme icin).
  String publicShareUrl(String baseUrl) {
    final trimmedBase = baseUrl.trim();
    final cleanedBase = trimmedBase.endsWith('/')
        ? trimmedBase.substring(0, trimmedBase.length - 1)
        : trimmedBase;
    if (cleanedBase.isEmpty) return publicShareSlug;
    return '$cleanedBase/$publicShareSlug';
  }

  /// Görünür kalemlerin ham alt toplamı (iskontolu fiyat × miktar).
  double get visibleSubtotalTl =>
      items.fold(0, (previousValue, item) => previousValue + item.totalTl);

  /// PDF'te ayrı satır olarak gözükmeyen, görünür kalemlere dağıtılacak ek tutar.
  double get hiddenSubtotalTl => hiddenCosts.fold(
    0,
    (previousValue, item) => previousValue + item.totalTl,
  );

  /// Müşteriye yansıyan genel ara toplam (görünür + gizli).
  double get subtotalTl => visibleSubtotalTl + hiddenSubtotalTl;

  /// Ticari olarak esas alınacak toplam (TL).
  /// Pazarlık sonrası anlaşılan tutar girildiyse onu, aksi halde teklif
  /// toplamını döner.
  double get commercialTotalTl => acceptedTotalTl ?? subtotalTl;

  /// Görünür kalem fiyatlarını gizli yüklemelerle ne oranda büyüteceğimiz.
  double get upliftFactor {
    final base = visibleSubtotalTl;
    if (base <= 0) return 1.0;
    return (base + hiddenSubtotalTl) / base;
  }

  /// Her görünür kalemin uplift sonrası efektif tutarı (TL).
  double effectiveLineTotalTl(QuoteLineItem item) =>
      item.totalTl * upliftFactor;

  /// Her görünür kalemin uplift sonrası efektif birim fiyatı (TL, iskontolu).
  double effectiveNetUnitPriceTl(QuoteLineItem item) =>
      item.netUnitPriceTl * upliftFactor;

  /// Uplift sonrası efektif birim fiyat (iskontosuz, PDF'te "birim fiyat" sütunu için).
  double effectiveUnitPriceTl(QuoteLineItem item) =>
      item.unitPriceTl * upliftFactor;

  String get formattedDate =>
      DateFormat('dd.MM.yyyy HH:mm', 'tr_TR').format(createdAt);

  Map<String, double> get rateLookup {
    return {'TL': 1, for (final rate in marketSnapshot) rate.code: rate.value};
  }

  double totalFor(String targetCode) {
    final rates = rateLookup;
    final targetRate = rates[targetCode];
    if (targetRate == null || targetRate == 0) {
      return commercialTotalTl;
    }

    return commercialTotalTl / targetRate;
  }

  String formattedTotal(String targetCode) {
    final amount = totalFor(targetCode);
    final formatter = NumberFormat.currency(
      locale: 'tr_TR',
      symbol: switch (targetCode) {
        'USDTRY' => r'$ ',
        'EURTRY' => 'EUR ',
        'XAUTRY_GRAM' => 'gr ',
        'XAGTRY_GRAM' => 'gr ',
        _ => 'TL ',
      },
      decimalDigits: targetCode == 'TL' ? 2 : 4,
    );
    return formatter.format(amount);
  }

  /// Yalnizca belirli alanlari degistirilmis bir kopyasi doner. Onay
  /// akisinda (Onayla/Revize/Reddet) `status` ve metadata alanlarini
  /// degistirirken geri kalan teklif verisini korumak icin kullanilir.
  Quote copyWith({
    QuoteStatus? status,
    DateTime? submittedAt,
    DateTime? approvedAt,
    String? approvedBy,
    String? approvedByName,
    String? approvalNote,
    double? acceptedTotalTl,
    double? acceptedAmount,
    String? acceptedCurrencyCode,
    double? acceptedFxRate,
    String? acceptedNote,
    DateTime? acceptedAt,
    String? acceptedBy,
    String? acceptedByName,
    int? revisionCount,
    String? cariId,
    String? createdBy,
    String? createdByName,
    DateTime? archivedAt,
    bool clearArchivedAt = false,
  }) {
    return Quote(
      id: id,
      code: code,
      customerName: customerName,
      customerCompany: customerCompany,
      title: title,
      note: note,
      createdAt: createdAt,
      displayUnit: displayUnit,
      items: items,
      marketSnapshot: marketSnapshot,
      documentProfile: documentProfile,
      hiddenCosts: hiddenCosts,
      publicToken: publicToken,
      paymentMethod: paymentMethod,
      paymentTermDays: paymentTermDays,
      hidePrices: hidePrices,
      sections: sections,
      status: status ?? this.status,
      submittedAt: submittedAt ?? this.submittedAt,
      approvedAt: approvedAt ?? this.approvedAt,
      approvedBy: approvedBy ?? this.approvedBy,
      approvedByName: approvedByName ?? this.approvedByName,
      approvalNote: approvalNote ?? this.approvalNote,
      acceptedTotalTl: acceptedTotalTl ?? this.acceptedTotalTl,
      acceptedAmount: acceptedAmount ?? this.acceptedAmount,
      acceptedCurrencyCode: acceptedCurrencyCode ?? this.acceptedCurrencyCode,
      acceptedFxRate: acceptedFxRate ?? this.acceptedFxRate,
      acceptedNote: acceptedNote ?? this.acceptedNote,
      acceptedAt: acceptedAt ?? this.acceptedAt,
      acceptedBy: acceptedBy ?? this.acceptedBy,
      acceptedByName: acceptedByName ?? this.acceptedByName,
      revisionCount: revisionCount ?? this.revisionCount,
      cariId: cariId ?? this.cariId,
      createdBy: createdBy ?? this.createdBy,
      createdByName: createdByName ?? this.createdByName,
      archivedAt: clearArchivedAt ? null : (archivedAt ?? this.archivedAt),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'code': code,
    'customer_name': customerName,
    'customer_company': customerCompany,
    'title': title,
    'note': note,
    'display_unit': displayUnit,
    'subtotal_tl': subtotalTl,
    'created_at': createdAt.toIso8601String(),
    'items': items.map((item) => item.toJson()).toList(),
    'hidden_costs': hiddenCosts.map((item) => item.toJson()).toList(),
    'market_snapshot': marketSnapshot.map((rate) => rate.toJson()).toList(),
    'document_profile': documentProfile.toJson(),
    'public_token': publicToken,
    'payment_method': paymentMethod.storageKey,
    'payment_term_days': paymentTermDays,
    'hide_prices': hidePrices,
    'sections': sections.map((section) => section.toJson()).toList(),
    'status': status.storageKey,
    'submitted_at': submittedAt?.toIso8601String(),
    'approved_at': approvedAt?.toIso8601String(),
    'approved_by': approvedBy,
    'approved_by_name': approvedByName,
    'approval_note': approvalNote,
    'accepted_total_tl': acceptedTotalTl,
    'accepted_amount': acceptedAmount,
    'accepted_currency_code': acceptedCurrencyCode,
    'accepted_fx_rate': acceptedFxRate,
    'accepted_note': acceptedNote,
    'accepted_at': acceptedAt?.toIso8601String(),
    'accepted_by': acceptedBy,
    'accepted_by_name': acceptedByName,
    'revision_count': revisionCount,
    'cari_id': cariId,
    'created_by': createdBy,
    'created_by_name': createdByName,
    'archived_at': archivedAt?.toIso8601String(),
  };

  factory Quote.fromJson(Map<String, dynamic> json) {
    final itemsJson = (json['items'] as List<dynamic>? ?? const [])
        .cast<Map<String, dynamic>>();
    final hiddenCostsJson = (json['hidden_costs'] as List<dynamic>? ?? const [])
        .cast<Map<String, dynamic>>();
    final marketSnapshotJson =
        (json['market_snapshot'] as List<dynamic>? ?? const [])
            .cast<Map<String, dynamic>>();
    final documentProfileJson =
        (json['document_profile'] as Map<String, dynamic>?) ?? const {};
    final sectionsJson = (json['sections'] as List<dynamic>? ?? const [])
        .cast<Map<String, dynamic>>();

    return Quote(
      id: json['id'] as String,
      code: json['code'] as String,
      customerName: json['customer_name'] as String? ?? '',
      customerCompany: json['customer_company'] as String? ?? '',
      title: json['title'] as String? ?? '',
      note: json['note'] as String? ?? '',
      displayUnit: json['display_unit'] as String? ?? 'TL',
      createdAt: DateTime.parse(json['created_at'] as String),
      items: itemsJson.map(QuoteLineItem.fromJson).toList(),
      hiddenCosts: hiddenCostsJson.map(HiddenCostItem.fromJson).toList(),
      marketSnapshot: marketSnapshotJson.map(MarketRate.fromJson).toList(),
      documentProfile: QuoteDocumentProfile.fromJson(documentProfileJson),
      publicToken: (json['public_token'] as String?)?.trim() ?? '',
      paymentMethod: QuotePaymentMethodX.fromStorageKey(
        json['payment_method'] as String?,
      ),
      paymentTermDays: (json['payment_term_days'] as num?)?.toInt() ?? 0,
      hidePrices: json['hide_prices'] as bool? ?? false,
      sections: sectionsJson.map(QuoteSection.fromJson).toList(),
      status: QuoteStatusX.fromStorageKey(json['status'] as String?),
      submittedAt: _parseDateTime(json['submitted_at']),
      approvedAt: _parseDateTime(json['approved_at']),
      approvedBy: _parseOptionalUuid(json['approved_by']),
      approvedByName: (json['approved_by_name'] as String?)?.trim() ?? '',
      approvalNote: (json['approval_note'] as String?) ?? '',
      acceptedTotalTl: (json['accepted_total_tl'] as num?)?.toDouble(),
      acceptedAmount: (json['accepted_amount'] as num?)?.toDouble(),
      acceptedCurrencyCode:
          (json['accepted_currency_code'] as String?)?.trim().isNotEmpty == true
          ? (json['accepted_currency_code'] as String).trim()
          : 'TL',
      acceptedFxRate: (json['accepted_fx_rate'] as num?)?.toDouble(),
      acceptedNote: (json['accepted_note'] as String?) ?? '',
      acceptedAt: _parseDateTime(json['accepted_at']),
      acceptedBy: _parseOptionalUuid(json['accepted_by']),
      acceptedByName: (json['accepted_by_name'] as String?)?.trim() ?? '',
      revisionCount: (json['revision_count'] as num?)?.toInt() ?? 0,
      cariId: (json['cari_id'] as String?)?.trim() ?? '',
      createdBy: _parseOptionalUuid(json['created_by']),
      createdByName: (json['created_by_name'] as String?)?.trim() ?? '',
      archivedAt: _parseDateTime(json['archived_at']),
    );
  }

  static DateTime? _parseDateTime(dynamic raw) {
    if (raw is String && raw.trim().isNotEmpty) {
      return DateTime.tryParse(raw);
    }
    return null;
  }

  static String? _parseOptionalUuid(dynamic raw) {
    if (raw == null) return null;
    final s = raw is String ? raw.trim() : raw.toString().trim();
    return s.isEmpty ? null : s;
  }
}

/// PDF ve UI tarafinin kullandigi, kategori basligi altinda kalem listesi
/// tasiyan yardimci yapi. `section == null` ise bu grup "Kategorisiz"
/// kalemleri temsil eder.
class QuoteSectionGroup {
  const QuoteSectionGroup({required this.section, required this.items});

  final QuoteSection? section;
  final List<QuoteLineItem> items;

  String get displayName => section?.name.trim().isNotEmpty == true
      ? section!.name.trim()
      : 'Kategorisiz';

  double get subtotalTl =>
      items.fold(0, (previous, item) => previous + item.totalTl);
}
