import 'package:flutter_test/flutter_test.dart';

import 'package:uzalteklif/models/quote.dart';

void main() {
  test('quote statuses use sales pipeline labels with legacy storage keys', () {
    expect(QuoteStatus.draft.displayLabel, 'Taslak');
    expect(QuoteStatus.pending.displayLabel, 'Gönderime Hazır');
    expect(QuoteStatus.approved.displayLabel, 'Müşteriye Gönderildi');
    expect(QuoteStatus.accepted.displayLabel, 'Kazanıldı');
    expect(QuoteStatus.rejected.displayLabel, 'Kaybedildi');
    expect(QuoteStatus.cancelled.displayLabel, 'İptal');

    expect(QuoteStatus.pending.storageKey, 'sent');
    expect(QuoteStatusX.fromStorageKey('sent'), QuoteStatus.pending);
    expect(QuoteStatusX.fromStorageKey('approved'), QuoteStatus.approved);
  });
}
