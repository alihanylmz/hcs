import '../models/discovery_project.dart';

class DiscoveryDeviceTemplate {
  const DiscoveryDeviceTemplate({
    required this.key,
    required this.name,
    required this.points,
  });

  final String key;
  final String name;
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
    points: [
      DiscoveryTemplatePoint('POMPA START/STOP-1', DiscoveryPointType.doOutput),
      DiscoveryTemplatePoint('POMPA ÇALIŞMA BİLGİSİ-1', DiscoveryPointType.di),
      DiscoveryTemplatePoint('POMPA ARIZA BİLGİSİ-1', DiscoveryPointType.di),
      DiscoveryTemplatePoint('POMPA PAKO OTO BİLGİSİ-1', DiscoveryPointType.di),
    ],
  );

  static const boiler = DiscoveryDeviceTemplate(
    key: 'boiler',
    name: 'Kazan',
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

  static const values = [pump, boiler, airHandlingUnit];
}
