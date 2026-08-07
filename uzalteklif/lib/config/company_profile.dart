/// Uygulama genelinde kullanilan firma kimlik bilgileri.
///
/// Supabase entegrasyonu tamamlanana kadar bu degerler ornek (dummy)
/// olarak kullanilir. Tum alanlar kurumsal teklif pdf'inde gorunur
/// oldugu icin gercekci ornek verilerle doldurulmustur.
class CompanyProfile {
  const CompanyProfile._();

  static const name = 'UZAL TEKNIK MUHENDISLIK LTD. STI.';
  static const shortName = 'UZAL TEKNIK';
  static const tagline = 'Endustriyel Otomasyon ve Mekanik Cozumler';

  static const phone = '+90 216 555 34 78';
  static const fax = '+90 216 555 34 79';
  static const email = 'teklif@uzalteknik.com.tr';
  static const website = 'www.uzalteknik.com.tr';
  static const address =
      'Dudullu OSB Mah. 3. Cadde No:12 Kat:2 Umraniye / Istanbul';

  static const taxOffice = 'Umraniye Vergi Dairesi';
  static const taxNumber = '1234567890';
  static const mersis = '0123456789012345';
  static const tradeRegistryNumber = '987654-5';

  static const bankName = 'Ziraat Bankasi';
  static const bankBranch = 'Umraniye Subesi';
  static const bankAccountName = 'UZAL TEKNIK MUH. LTD. STI.';
  static const bankIban = 'TR00 0000 0000 0000 0000 0000 00';
  static const bankSwift = 'TCZBTR2A';

  static const defaultVatRate = 20.0;
}
