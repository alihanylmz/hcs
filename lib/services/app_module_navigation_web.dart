import 'dart:html' as html;

void navigateToHash(String hash) {
  html.window.location.hash = hash;
  html.window.location.reload();
}
