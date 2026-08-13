import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'dart:html' as html;

class ModuleSwitcher {
  static void switchToTask(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('İş Takip & Atölye Sistemine Geçiliyor...'),
        duration: Duration(milliseconds: 800),
        backgroundColor: Color(0xFF2B82C9),
      ),
    );

    if (kIsWeb) {
      Future.delayed(const Duration(milliseconds: 300), () {
        html.window.location.hash = '#/tickets';
        html.window.location.reload();
      });
    } else {
      Navigator.of(context).popUntil((route) => route.isFirst);
    }
  }

  static void switchToQuote(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Uzal Teklif & Keşif Sistemine Geçiliyor...'),
        duration: Duration(milliseconds: 800),
        backgroundColor: Color(0xFF2B82C9),
      ),
    );

    if (kIsWeb) {
      Future.delayed(const Duration(milliseconds: 300), () {
        html.window.location.hash = '#/';
        html.window.location.reload();
      });
    } else {
      Navigator.of(context).popUntil((route) => route.isFirst);
    }
  }
}
