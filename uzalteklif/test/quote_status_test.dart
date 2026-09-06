import 'package:flutter_test/flutter_test.dart';
import 'package:uzalteklif/models/quote.dart';

void main() {
  test('quote statuses use the phase 2 sales pipeline dictionary', () {
    expect(QuoteStatus.draft.displayLabel, 'Taslak');
    expect(QuoteStatus.approvalPending.displayLabel, 'Onay Bekliyor');
    expect(QuoteStatus.approved.displayLabel, 'Şirket İçinde Onaylandı');
    expect(QuoteStatus.sent.displayLabel, 'Gönderildi');
    expect(QuoteStatus.viewed.displayLabel, 'Görüntülendi');
    expect(QuoteStatus.negotiating.displayLabel, 'Pazarlıkta');
    expect(QuoteStatus.won.displayLabel, 'Kazanıldı');
    expect(QuoteStatus.lost.displayLabel, 'Kaybedildi');
    expect(QuoteStatus.expired.displayLabel, 'Süresi Doldu');
    expect(QuoteStatus.cancelled.displayLabel, 'İptal');

    expect(QuoteStatus.approvalPending.storageKey, 'approval_pending');
    expect(QuoteStatus.sent.storageKey, 'sent');
    expect(QuoteStatusX.fromStorageKey('sent'), QuoteStatus.sent);
    expect(QuoteStatusX.fromStorageKey('accepted'), QuoteStatus.won);
    expect(QuoteStatusX.fromStorageKey('rejected'), QuoteStatus.lost);
  });
}
