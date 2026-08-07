import 'package:flutter_test/flutter_test.dart';

import 'package:uzalteklif/services/quote_code_generator.dart';

void main() {
  test('buildCode yields the compact UZ-YYMMDD-HHMMSS format', () {
    final timestamp = DateTime(2026, 4, 21, 14, 25, 30);

    final code = QuoteCodeGenerator.buildCode(timestamp: timestamp);

    expect(code, 'UZ-260421-142530');
  });

  test('pattern matches generated codes', () {
    final code = QuoteCodeGenerator.buildCode(
      timestamp: DateTime(2026, 1, 3, 9, 5, 7),
    );

    expect(QuoteCodeGenerator.pattern.hasMatch(code), isTrue);
    expect(code, 'UZ-260103-090507');
  });
}
