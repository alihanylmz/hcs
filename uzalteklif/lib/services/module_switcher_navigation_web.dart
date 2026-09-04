import 'dart:html' as html;

void navigateToModule(String hash) {
  html.window.location.hash = hash;
  html.window.location.reload();
}
