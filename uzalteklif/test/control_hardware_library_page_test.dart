import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uzalteklif/screens/control_hardware_library_page.dart';
import 'package:uzalteklif/services/control_hardware_repository.dart';
import 'package:uzalteklif/theme/app_theme.dart';

void main() {
  testWidgets('DDC/I/O kütüphanesi başlangıç kontrolörlerini gösterir', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    await tester.binding.setSurfaceSize(const Size(1440, 960));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: ControlHardwareLibraryPage(
          repository: ControlHardwareRepository(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('DDC ve I/O Kütüphanesi'), findsOneWidget);
    expect(find.text('ABB FBXi 8R8'), findsOneWidget);
    expect(find.text('Honeywell Unitary 16'), findsOneWidget);
    expect(find.text('AI-A 4–20 mA desteklenmez'), findsOneWidget);
    expect(find.text('Kontrolör Ekle'), findsOneWidget);
    expect(find.text('I/O Modülü Ekle'), findsOneWidget);
  });
}
