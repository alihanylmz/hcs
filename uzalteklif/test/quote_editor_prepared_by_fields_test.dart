import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:uzalteklif/widgets/quote_editor_prepared_by_fields.dart';

void main() {
  testWidgets('renders prepared-by fields', (tester) async {
    final name = TextEditingController(text: 'Ali');
    final title = TextEditingController(text: 'Satis');
    final phone = TextEditingController();
    final email = TextEditingController();
    addTearDown(name.dispose);
    addTearDown(title.dispose);
    addTearDown(phone.dispose);
    addTearDown(email.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: QuoteEditorPreparedByFields(
            nameController: name,
            titleController: title,
            phoneController: phone,
            emailController: email,
          ),
        ),
      ),
    );

    expect(find.text('Ad Soyad'), findsOneWidget);
    expect(find.text('Unvan'), findsOneWidget);
    expect(find.text('Telefon'), findsOneWidget);
    expect(find.text('E-posta'), findsOneWidget);
  });
}
