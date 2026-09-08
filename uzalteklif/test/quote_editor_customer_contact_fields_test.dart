import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:uzalteklif/models/cari_account.dart';
import 'package:uzalteklif/widgets/quote_editor_customer_contact_fields.dart';

CariAccount _cari({required String id, required String companyName}) {
  return CariAccount(
    id: id,
    companyName: companyName,
    contactName: 'Yetkili $id',
    contactTitle: '',
    phone: '',
    email: '',
    taxOffice: '',
    taxNumber: '',
    address: '',
    notes: '',
    updatedAt: DateTime(2026, 1, 1),
  );
}

void main() {
  late List<TextEditingController> controllers;
  late FocusNode focusNode;

  setUp(() {
    controllers = List.generate(5, (_) => TextEditingController());
    focusNode = FocusNode();
  });

  tearDown(() {
    for (final c in controllers) {
      c.dispose();
    }
    focusNode.dispose();
  });

  Future<void> pump(
    WidgetTester tester, {
    List<CariAccount> cariler = const [],
    ValueChanged<CariAccount>? onCariSelected,
    ValueChanged<String>? onCompanyChanged,
  }) {
    return tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: QuoteEditorCustomerContactFields(
            companyController: controllers[0],
            companyFocusNode: focusNode,
            nameController: controllers[1],
            titleController: controllers[2],
            phoneController: controllers[3],
            emailController: controllers[4],
            onCompanyChanged: onCompanyChanged ?? (_) {},
            cariler: cariler,
            onCariSelected: onCariSelected ?? (_) {},
          ),
        ),
      ),
    );
  }

  testWidgets('tum alanlari cizer', (tester) async {
    await pump(tester);

    expect(find.text('Firma Adi'), findsOneWidget);
    expect(find.text('Yetkili Ad Soyad'), findsOneWidget);
    expect(find.text('Unvan'), findsOneWidget);
    expect(find.text('Telefon'), findsOneWidget);
    expect(find.text('E-posta'), findsOneWidget);
  });

  testWidgets('yazilan metne gore carileri filtreler', (tester) async {
    await pump(
      tester,
      cariler: [
        _cari(id: 'c1', companyName: 'UZAL TEKNIK'),
        _cari(id: 'c2', companyName: 'Enerji Sistemleri'),
        _cari(id: 'c3', companyName: 'Kontrol Teknolojileri'),
      ],
    );

    // Kucuk harfle yazilsa da eslesmeli.
    await tester.enterText(find.byType(TextFormField).first, 'teknolo');
    await tester.pumpAndSettle();

    expect(find.textContaining('Kontrol Teknolojileri'), findsOneWidget);
    expect(find.textContaining('Enerji Sistemleri'), findsNothing);
  });

  testWidgets('listeden secince onCariSelected cagrilir', (tester) async {
    CariAccount? selected;
    await pump(
      tester,
      cariler: [
        _cari(id: 'c1', companyName: 'UZAL TEKNIK'),
        _cari(id: 'c2', companyName: 'Enerji Sistemleri'),
      ],
      onCariSelected: (c) => selected = c,
    );

    await tester.enterText(find.byType(TextFormField).first, 'uzal');
    await tester.pumpAndSettle();
    await tester.tap(find.textContaining('UZAL TEKNIK').last);
    await tester.pumpAndSettle();

    expect(selected, isNotNull);
    expect(selected!.id, 'c1');
  });

  testWidgets('eslesme yoksa liste cikmaz; yeni firma adi serbestce yazilir', (
    tester,
  ) async {
    // Faz 3.4'un temel senaryosu: listede olmayan bir firma adi yazmak
    // engellenmemeli, kayit sirasinda yeni cari acilacak.
    var lastTyped = '';
    await pump(
      tester,
      cariler: [_cari(id: 'c1', companyName: 'UZAL TEKNIK')],
      onCompanyChanged: (v) => lastTyped = v,
    );

    await tester.enterText(find.byType(TextFormField).first, 'Yepyeni Firma');
    await tester.pumpAndSettle();

    expect(lastTyped, 'Yepyeni Firma');
    expect(find.byType(ListTile), findsNothing);
    expect(controllers[0].text, 'Yepyeni Firma');
  });

  testWidgets('cari listesi bosken acilir liste ikonu gosterilmez', (
    tester,
  ) async {
    await pump(tester, cariler: const []);

    expect(find.byIcon(Icons.arrow_drop_down_rounded), findsNothing);
  });
}
