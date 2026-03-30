import 'package:flutter/material.dart';

import '../models/team.dart';

class TeamVisuals {
  const TeamVisuals._();

  static Color colorFromHex(String rawHex) {
    final normalized = Team.normalizeAccentColor(rawHex);
    final hex = normalized.replaceFirst('#', '');
    return Color(int.parse('FF$hex', radix: 16));
  }
}
