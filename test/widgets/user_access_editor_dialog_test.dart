import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:istakip_app/models/user_app_access.dart';
import 'package:istakip_app/models/user_profile.dart';
import 'package:istakip_app/widgets/user_access_editor_dialog.dart';

void main() {
  const user = UserProfile(
    id: 'user-1',
    email: 'satis@uzalteknik.com',
    fullName: 'Satış Kullanıcısı',
    role: UserRole.user,
  );
  const draft = UserAccessDraft(
    isTakipActive: true,
    isTakipRole: UserRole.user,
    teklifActive: true,
    teklifRole: 'sales',
  );

  Future<void> pumpDialog(WidgetTester tester, Size size) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: UserAccessEditorDialog(
            user: user,
            initialDraft: draft,
            partners: [],
            isCurrentUser: false,
            readOnly: false,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('mobil ekranda iki uygulama yetkisini tasmasiz gosterir', (
    tester,
  ) async {
    await pumpDialog(tester, const Size(390, 800));

    expect(find.text('İş Takip'), findsOneWidget);
    expect(find.text('Teklif'), findsOneWidget);
    expect(find.text('Yetkileri Kaydet'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('genis ekranda iki uygulama yetkisini gosterir', (tester) async {
    await pumpDialog(tester, const Size(1200, 900));

    expect(find.text('İş Takip'), findsOneWidget);
    expect(find.text('Teklif'), findsOneWidget);
    expect(find.text('Satış Kullanıcısı'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
