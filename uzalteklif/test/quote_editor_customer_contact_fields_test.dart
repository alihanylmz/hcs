import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:uzalteklif/widgets/quote_editor_customer_contact_fields.dart';

void main() {
  testWidgets('renders customer contact fields', (tester) async {
    final controllers = List.generate(5, (_) => TextEditingController());
    addTearDown(() {
      for (final controller in controllers) {
        controller.dispose();
      }
    });

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: QuoteEditorCustomerContactFields(
            companyController: controllers[0],
            nameController: controllers[1],
            titleController: controllers[2],
            phoneController: controllers[3],
            emailController: controllers[4],
            onCompanyChanged: (_) {},
          ),
        ),
      ),
    );

    expect(find.text('Firma Adi'), findsOneWidget);
    expect(find.text('Yetkili Ad Soyad'), findsOneWidget);
    expect(find.text('Unvan'), findsOneWidget);
    expect(find.text('Telefon'), findsOneWidget);
    expect(find.text('E-posta'), findsOneWidget);
  });
}
