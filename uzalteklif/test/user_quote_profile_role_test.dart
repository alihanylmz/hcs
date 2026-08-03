import 'package:flutter_test/flutter_test.dart';
import 'package:uzalteklif/models/user_quote_profile.dart';

void main() {
  test('teklif rolleri şirket hiyerarşisini doğru gösterir', () {
    expect(UserQuoteProfile.roleLabel('admin'), 'Genel Müdür');
    expect(UserQuoteProfile.roleLabel('manager'), 'Patron');
    expect(UserQuoteProfile.roleLabel('sales'), 'Satış');
  });

  test('yalnızca genel müdür sistem kullanıcılarını yönetir', () {
    final generalManager = _profile('admin');
    final owner = _profile('manager');

    expect(generalManager.canManageUsers, isTrue);
    expect(owner.isManager, isTrue);
    expect(owner.canManageUsers, isFalse);
  });
}

UserQuoteProfile _profile(String role) {
  return UserQuoteProfile(
    userId: 'user-$role',
    preparedByName: '',
    preparedByTitle: '',
    preparedByPhone: '',
    preparedByEmail: '',
    companyName: '',
    companyTagline: '',
    companyPhone: '',
    companyEmail: '',
    companyWebsite: '',
    companyAddress: '',
    companyTaxOffice: '',
    companyTaxNumber: '',
    companyMersis: '',
    bankName: '',
    bankBranch: '',
    bankAccountName: '',
    bankIban: '',
    bankSwift: '',
    defaultValidityText: '',
    defaultPaymentTerms: '',
    defaultDeliveryTerms: '',
    defaultVatRate: 20,
    role: role,
  );
}
