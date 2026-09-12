// TicketDetailPage icin minimal bir "coker mi" testi.
//
// ticket_detail_page.dart 6300+ satirlik tek bir State sinifi ve bu dosyaya
// dokunulmadan once onu render eden HICBIR test yoktu. Bu dosya, sonraki
// bolme (extraction) adimlarinin bir seyi bozup bozmadigini gorebilmemiz
// icin asgari bir regresyon sinyali kurar.
//
// Gercek bir Supabase projesine baglanmiyoruz (sahte URL kullaniliyor, tipki
// test/widget_test.dart'taki gibi); bu yuzden veri yuklemesi basarisiz olup
// sayfa hata durumuna dusecek. Onemli olan sayfanin cokmeden bu hata
// durumunu gostermesi - build metodlarindan hicbirinin exception atmadigini
// dogrular.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:istakip_app/pages/ticket_detail_page.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await Supabase.initialize(
      url: 'https://example.supabase.co',
      anonKey: 'test-anon-key',
    );
  });

  testWidgets('ticket detail page coker olmadan hata durumunu gosterir', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(home: TicketDetailPage(ticketId: 'smoke-test-id')),
    );

    // Yukleniyor durumu.
    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    // Sahte Supabase'e istek basarisiz olana kadar bekle.
    await tester.pumpAndSettle(const Duration(seconds: 5));

    // Coktu ise burada bir exception firlar ve test basarisiz olur; asil
    // regresyon sinyali budur. Ayrica hata ekraninin gorunur oldugunu da
    // dogruluyoruz.
    expect(find.text('Tekrar Dene'), findsOneWidget);
  });
}
