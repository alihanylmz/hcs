// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:istakip_app/main.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});

    await Supabase.initialize(
      url: 'https://nlrsfyhstocyjkrodhky.supabase.co',
      anonKey:
          'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Im5scnNmeWhzdG9jeWprcm9kaGt5Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjMyNzExMjYsImV4cCI6MjA3ODg0NzEyNn0.ROt_LxE8YHLA9e-TxcQOLAYr3OemlRPTI_xvJdnC25M',
    );
  });

  testWidgets('app renders without crashing', (WidgetTester tester) async {
    await tester.pumpWidget(const IsTakipApp());

    expect(find.byType(IsTakipApp), findsOneWidget);
  });
}
