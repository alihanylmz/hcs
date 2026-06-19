import 'package:flutter/material.dart';

import '../pages/ticket_detail_page.dart';

class NotificationNavigationService {
  const NotificationNavigationService._();

  static Future<void> openFromData(
    NavigatorState navigator,
    Map<String, dynamic>? data,
  ) async {
    if (data == null || data.isEmpty) {
      return;
    }

    final ticketId = data['ticket_id']?.toString().trim();
    if (ticketId != null && ticketId.isNotEmpty) {
      await navigator.push(
        MaterialPageRoute(
          builder: (context) => TicketDetailPage(ticketId: ticketId),
        ),
      );
      return;
    }

    // Takim modulu kullanici arayuzunden kaldirildi. Eski takim bildirimleri
    // gelirse uygulamayi artik takim ekranina tasimiyoruz.
  }
}
