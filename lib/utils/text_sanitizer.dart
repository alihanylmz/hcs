/// Small UI helper to avoid missing glyph warnings on Web when data contains emoji.
class TextSanitizer {
  static String stripEmoji(String input) {
    // Remove common emoji ranges + variation selectors, keep normal text.
    return input
        // Variation selectors
        .replaceAll(RegExp(r'[\uFE0E\uFE0F]'), '')
        // Most non-BMP symbols (emoji etc.)
        .replaceAll(RegExp(r'[\u{1F000}-\u{1FAFF}]', unicode: true), '')
        // Additional symbols/pictographs
        .replaceAll(RegExp(r'[\u{2600}-\u{27BF}]', unicode: true), '')
        .trim();
  }
}


