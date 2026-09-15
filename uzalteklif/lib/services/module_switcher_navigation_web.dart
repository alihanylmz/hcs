// ignore_for_file: deprecated_member_use, avoid_web_libraries_in_flutter
import 'dart:html' as html;

void navigateToModule(String hash) {
  html.window.location.hash = hash;
  html.window.location.reload();
}
