import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'package:uzalteklif/config/company_profile.dart';
import 'package:uzalteklif/models/market_rate.dart';
import 'package:uzalteklif/models/quote.dart';
import 'package:uzalteklif/services/pdf_export_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    await initializeDateFormatting('tr_TR');
  });

  test('pdf export service builds a non-empty document', () async {
    const service = PdfExportService();
    final quote = _buildSampleQuote();

    final bytes = await service.buildQuotePdfBytes(quote);

    expect(bytes.length, greaterThan(5000));

    // Gelistirme sirasinda tasarimi hizlica gorebilmek icin ornegi diske yaz.
    final outputFile = File('output/pdf/preview_quote.pdf');
    outputFile.parent.createSync(recursive: true);
    await outputFile.writeAsBytes(bytes, flush: true);
  });

  test('pdf export service handles a large quote without failing', () async {
    const service = PdfExportService();
    final base = _buildSampleQuote();
    final largeQuote = Quote(
      id: 'quote-large',
      code: 'UZ-260421-999999',
      customerName: base.customerName,
      customerCompany: base.customerCompany,
      title: 'Buyuk kalemli stres test teklifi',
      note: base.note,
      createdAt: base.createdAt,
      displayUnit: base.displayUnit,
      items: [
        for (var i = 0; i < 120; i++)
          QuoteLineItem(
            id: 'stress-line-$i',
            description:
                'STRESS-${i.toString().padLeft(3, '0')} - Test Kalemi - Marka Model',
            quantity: (i % 7) + 1,
            unit: 'adet',
            unitPriceTl: 1000 + (i * 37),
            discountRate: (i % 5).toDouble(),
          ),
      ],
      marketSnapshot: base.marketSnapshot,
      documentProfile: base.documentProfile,
    );

    final started = DateTime.now();
    final bytes = await service.buildQuotePdfBytes(largeQuote);
    final elapsed = DateTime.now().difference(started);

    expect(bytes.length, greaterThan(20000));
    expect(elapsed, lessThan(const Duration(seconds: 20)));
  });
}

Quote _buildSampleQuote() {
  final now = DateTime(2026, 4, 21, 14, 25);
  return Quote(
    id: 'quote-preview',
    code: 'UZ-260421-142530',
    customerName: 'Ahmet Yilmaz',
    customerCompany: 'Ornek Endustri A.S.',
    title: 'Klima Santrali Otomasyon Revizyon Teklifi',
    note:
        'Montaj oncesi saha kontrolu firmamizca yapilacak olup, kablaj ve pano '
        'baglantilari dahildir. Uc yil uretici garantisi standart olarak sunulur. '
        'Nakliye ve sigorta hizmetleri teklifin dahilindedir.',
    createdAt: now,
    displayUnit: 'EURTRY',
    items: const [
      QuoteLineItem(
        id: 'line-1',
        description:
            'SNS-QAE-2120 - Kanal Tipi Sicaklik Sensoru - Siemens QAE2120.010',
        quantity: 6,
        unit: 'adet',
        unitPriceTl: 1850,
        discountRate: 5,
      ),
      QuoteLineItem(
        id: 'line-2',
        description:
            'DDC-PXC7-E400 - DDC Kontrolor - Siemens PXC7.E400 (24 I/O)',
        quantity: 2,
        unit: 'adet',
        unitPriceTl: 16010.4,
      ),
      QuoteLineItem(
        id: 'line-3',
        description:
            'VLV-MXG461-25 - 3 Yollu Kontrol Vanasi - Siemens MXG461.25-8',
        quantity: 4,
        unit: 'adet',
        unitPriceTl: 4280,
        discountRate: 10,
      ),
      QuoteLineItem(
        id: 'line-4',
        description:
            'INV-V20-22KW - AC Hiz Kontrol Cihazi - Siemens Sinamics V20 22kW',
        quantity: 1,
        unit: 'adet',
        unitPriceTl: 28500,
        discountRate: 7.5,
      ),
      QuoteLineItem(
        id: 'line-5',
        description: 'ISC-MNT-2026 - Montaj, Devreye Alma ve Saha Isciligi',
        quantity: 5,
        unit: 'gun',
        unitPriceTl: 6500,
      ),
    ],
    hiddenCosts: const [
      HiddenCostItem(
        id: 'hidden-1',
        name: 'Devreye Alma',
        parameters: [
          HiddenCostParameter(
            label: 'Pano sayisi',
            quantity: 3,
            unitPriceTl: 2500,
          ),
          HiddenCostParameter(
            label: 'Inverter sayisi',
            quantity: 1,
            unitPriceTl: 1500,
          ),
          HiddenCostParameter(
            label: 'Inverter toplam kW',
            quantity: 22,
            unitPriceTl: 50,
          ),
          HiddenCostParameter(
            label: 'Saha gunu',
            quantity: 2,
            unitPriceTl: 3500,
          ),
        ],
      ),
    ],
    marketSnapshot: [
      MarketRate(
        code: 'USDTRY',
        label: 'Dolar',
        unitLabel: '1 USD',
        value: 38.24,
        updatedAt: now,
      ),
      MarketRate(
        code: 'EURTRY',
        label: 'Euro',
        unitLabel: '1 EUR',
        value: 41.67,
        updatedAt: now,
      ),
    ],
    documentProfile: const QuoteDocumentProfile(
      companyName: CompanyProfile.name,
      companyTagline: CompanyProfile.tagline,
      companyPhone: CompanyProfile.phone,
      companyEmail: CompanyProfile.email,
      companyWebsite: CompanyProfile.website,
      companyAddress: CompanyProfile.address,
      preparedByName: 'Alihan Uzal',
      preparedByTitle: 'Satis Muhendisi',
      preparedByPhone: '+90 532 145 78 90',
      preparedByEmail: 'alihan@uzalteknik.com.tr',
      customerContactTitle: 'Satinalma Sorumlusu',
      customerPhone: '+90 532 000 00 00',
      customerEmail: 'ahmet.yilmaz@ornekendustri.com.tr',
      validityText: '15 gun',
      paymentTerms: '%50 pesin, %50 teslimden once',
      deliveryTerms: '7 is gunu (stoktan teslim)',
      companyTaxOffice: CompanyProfile.taxOffice,
      companyTaxNumber: CompanyProfile.taxNumber,
      companyMersis: CompanyProfile.mersis,
      bankName: CompanyProfile.bankName,
      bankBranch: CompanyProfile.bankBranch,
      bankAccountName: CompanyProfile.bankAccountName,
      bankIban: CompanyProfile.bankIban,
      bankSwift: CompanyProfile.bankSwift,
      vatRate: CompanyProfile.defaultVatRate,
    ),
  );
}
