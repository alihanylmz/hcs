import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'app_module_navigation.dart';

class AppModuleService {
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
        navigateToHash('#/');
      });
    } else {
      Navigator.of(context).popUntil((route) => route.isFirst);
    }
  }

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
        navigateToHash('#/tickets');
      });
    } else {
      Navigator.of(context).popUntil((route) => route.isFirst);
    }
  }
}
