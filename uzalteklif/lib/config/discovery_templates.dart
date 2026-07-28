import '../models/discovery_project.dart';

class DiscoveryDeviceTemplate {
  const DiscoveryDeviceTemplate({
    required this.key,
    required this.name,
    required this.categoryName,
    required this.points,
  });

  final String key;
  final String name;
  final String categoryName;
  final List<DiscoveryTemplatePoint> points;

  DiscoveryDevice instantiate({
    required String id,
    required String panelCode,
    required String deviceCode,
    required String Function(String prefix) idBuilder,
  }) {
    return DiscoveryDevice(
      id: id,
      templateKey: key,
      name: name,
      panelCode: panelCode,
      deviceCode: deviceCode,
      points: points
          .map(
            (point) => DiscoveryPoint(
              id: idBuilder('point'),
              name: point.name,
              type: point.type,
              quantity: point.quantity,
            ),
          )
          .toList(growable: false),
    );
  }
}

class DiscoveryTemplatePoint {
  const DiscoveryTemplatePoint(this.name, this.type, {this.quantity = 1});

  final String name;
  final DiscoveryPointType type;
  final int quantity;
}

abstract final class DiscoveryTemplates {
  static const pump = DiscoveryDeviceTemplate(
    key: 'pump',
    name: 'Pompa',
    categoryName: 'Pompalar',
    points: [
      DiscoveryTemplatePoint('POMPA START/STOP-1', DiscoveryPointType.doOutput),
      DiscoveryTemplatePoint('POMPA ÇALIŞMA BİLGİSİ-1', DiscoveryPointType.di),
      DiscoveryTemplatePoint('POMPA ARIZA BİLGİSİ-1', DiscoveryPointType.di),
      DiscoveryTemplatePoint('POMPA PAKO OTO BİLGİSİ-1', DiscoveryPointType.di),
    ],
  );

  static const boiler = DiscoveryDeviceTemplate(
    key: 'boiler',
    name: 'Isıtma Kazanı',
    categoryName: 'Isıtma Kazanları',
    points: [
      DiscoveryTemplatePoint(
        'KAZAN GİDİŞ SUYU SICAKLIK BİLGİSİ',
        DiscoveryPointType.aiPassive,
      ),
      DiscoveryTemplatePoint(
        'KAZAN DÖNÜŞ SUYU SICAKLIK BİLGİSİ',
        DiscoveryPointType.aiPassive,
      ),
      DiscoveryTemplatePoint(
        'YÜKSEK SICAKLIK ALARM BİLGİSİ',
        DiscoveryPointType.di,
      ),
      DiscoveryTemplatePoint('BRÜLÖR START/STOP', DiscoveryPointType.doOutput),
      DiscoveryTemplatePoint(
        'BRÜLÖR ÇALIŞMA BİLGİSİ (220V)',
        DiscoveryPointType.di,
      ),
      DiscoveryTemplatePoint(
        'BRÜLÖR ARIZA BİLGİSİ (220V)',
        DiscoveryPointType.di,
      ),
    ],
  );

  static const airHandlingUnit = DiscoveryDeviceTemplate(
    key: 'ahu',
    name: 'Klima Santrali',
    categoryName: 'Klima Santralleri',
    points: [
      DiscoveryTemplatePoint(
        'TAZE HAVA SICAKLIĞI',
        DiscoveryPointType.aiPassive,
      ),
      DiscoveryTemplatePoint(
        'ÜFLEME HAVASI SICAKLIĞI',
        DiscoveryPointType.aiPassive,
      ),
      DiscoveryTemplatePoint(
        'DÖNÜŞ HAVASI SICAKLIĞI',
        DiscoveryPointType.aiPassive,
      ),
      DiscoveryTemplatePoint('IGK SICAKLIĞI', DiscoveryPointType.aiPassive),
      DiscoveryTemplatePoint(
        'G4 FİLTRE KİRLİLİK ALARMI',
        DiscoveryPointType.di,
      ),
      DiscoveryTemplatePoint(
        'F7 FİLTRE KİRLİLİK ALARMI',
        DiscoveryPointType.di,
      ),
      DiscoveryTemplatePoint(
        'TAZE HAVA DAMPER MOTORU START/STOP',
        DiscoveryPointType.doOutput,
      ),
      DiscoveryTemplatePoint(
        'EGZOZ HAVA DAMPER MOTORU START/STOP',
        DiscoveryPointType.doOutput,
      ),
      DiscoveryTemplatePoint(
        'BYPASS HAVA DAMPER MOTORU KONUMLANDIRMA',
        DiscoveryPointType.ao,
      ),
      DiscoveryTemplatePoint(
        'VANTİLATÖR START/STOP',
        DiscoveryPointType.doOutput,
      ),
      DiscoveryTemplatePoint(
        'VANTİLATÖR HAVA AKIŞ BİLGİSİ',
        DiscoveryPointType.di,
      ),
      DiscoveryTemplatePoint('VANTİLATÖR ARIZA BİLGİSİ', DiscoveryPointType.di),
      DiscoveryTemplatePoint(
        'VANTİLATÖR PAKO OTO BİLGİSİ',
        DiscoveryPointType.di,
      ),
      DiscoveryTemplatePoint(
        'ASPİRATÖR START/STOP',
        DiscoveryPointType.doOutput,
      ),
      DiscoveryTemplatePoint(
        'ASPİRATÖR HAVA AKIŞ BİLGİSİ',
        DiscoveryPointType.di,
      ),
      DiscoveryTemplatePoint('ASPİRATÖR ARIZA BİLGİSİ', DiscoveryPointType.di),
      DiscoveryTemplatePoint(
        'ASPİRATÖR PAKO OTO BİLGİSİ',
        DiscoveryPointType.di,
      ),
      DiscoveryTemplatePoint(
        'DX BATARYA START/STOP',
        DiscoveryPointType.doOutput,
      ),
      DiscoveryTemplatePoint(
        'DX BATARYA ÇALIŞMA BİLGİSİ',
        DiscoveryPointType.di,
      ),
      DiscoveryTemplatePoint('DX BATARYA ARIZA BİLGİSİ', DiscoveryPointType.di),
      DiscoveryTemplatePoint('DX BATARYA KONUMLANDIRMA', DiscoveryPointType.ao),
      DiscoveryTemplatePoint(
        'DX BATARYA YAZ MOD SEÇİMİ',
        DiscoveryPointType.doOutput,
      ),
      DiscoveryTemplatePoint(
        'DX BATARYA KIŞ MOD SEÇİMİ',
        DiscoveryPointType.doOutput,
      ),
      DiscoveryTemplatePoint(
        'DX BATARYA DEFROST BİLGİSİ',
        DiscoveryPointType.di,
      ),
      DiscoveryTemplatePoint(
        'DX HAVASI GİRİŞ SICAKLIĞI',
        DiscoveryPointType.aiPassive,
      ),
    ],
  );

  static const custom = DiscoveryDeviceTemplate(
    key: 'custom',
    name: 'Özel Cihaz',
    categoryName: 'Özel Cihazlar',
    points: [],
  );

  static const values = [pump, boiler, airHandlingUnit, custom];

  static DiscoveryDeviceTemplate? findByKey(String key) {
    for (final template in values) {
      if (template.key == key) return template;
    }
    return null;
  }
}

abstract final class DiscoveryPanelCodeSuggestions {
  static final RegExp _ddcPattern = RegExp(
    r'^DDC[-\s]?(\d+)$',
    caseSensitive: false,
  );

  static List<String> build(Iterable<String> existingCodes) {
    final existing = <String>[];
    var highestDdcNumber = 0;

    for (final rawCode in existingCodes) {
      final code = rawCode.trim().toUpperCase();
      if (code.isEmpty || existing.contains(code)) continue;
      existing.add(code);
      final match = _ddcPattern.firstMatch(code);
      final number = int.tryParse(match?.group(1) ?? '');
      if (number != null && number > highestDdcNumber) {
        highestDdcNumber = number;
      }
    }

    existing.sort(_naturalPanelCompare);
    final result = <String>[...existing];
    for (var offset = 1; offset <= 3; offset++) {
      final number = highestDdcNumber + offset;
      final suggestion = 'DDC-${number.toString().padLeft(2, '0')}';
      if (!result.contains(suggestion)) result.add(suggestion);
    }
    return result;
  }

  static String initialValue(Iterable<String> existingCodes) {
    final existing = existingCodes
        .map((code) => code.trim().toUpperCase())
        .where((code) => code.isNotEmpty)
        .toList(growable: false);
    if (existing.isNotEmpty) return existing.last;
    return 'DDC-01';
  }

  static int _naturalPanelCompare(String left, String right) {
    final leftMatch = _ddcPattern.firstMatch(left);
    final rightMatch = _ddcPattern.firstMatch(right);
    final leftNumber = int.tryParse(leftMatch?.group(1) ?? '');
    final rightNumber = int.tryParse(rightMatch?.group(1) ?? '');
    if (leftNumber != null && rightNumber != null) {
      return leftNumber.compareTo(rightNumber);
    }
    if (leftNumber != null) return -1;
    if (rightNumber != null) return 1;
    return left.compareTo(right);
  }
}
