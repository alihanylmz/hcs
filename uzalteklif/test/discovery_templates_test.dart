import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uzalteklif/config/discovery_templates.dart';
import 'package:uzalteklif/models/discovery_project.dart';
import 'package:uzalteklif/models/user_quote_profile.dart';
import 'package:uzalteklif/services/discovery_repository.dart';

void main() {
  var id = 0;
  String buildId(String prefix) => '$prefix-${id++}';

  DiscoveryDevice instantiate(DiscoveryDeviceTemplate template) {
    return template.instantiate(
      id: buildId('device'),
      panelCode: 'DDC-01',
      deviceCode: template.key.toUpperCase(),
      idBuilder: buildId,
    );
  }

  test('pompa şablonu 3 DI ve 1 DO üretir', () {
    final device = instantiate(DiscoveryTemplates.pump);

    expect(device.countFor(DiscoveryPointType.di), 3);
    expect(device.countFor(DiscoveryPointType.doOutput), 1);
    expect(device.totalPoints, 4);
  });

  test('kazan şablonu 2 AI-P, 3 DI ve 1 DO üretir', () {
    final device = instantiate(DiscoveryTemplates.boiler);

    expect(device.countFor(DiscoveryPointType.aiPassive), 2);
    expect(device.countFor(DiscoveryPointType.di), 3);
    expect(device.countFor(DiscoveryPointType.doOutput), 1);
    expect(device.totalPoints, 6);
  });

  test('klima santrali şablonu kesinleşen 25 noktayı üretir', () {
    final device = instantiate(DiscoveryTemplates.airHandlingUnit);

    expect(device.countFor(DiscoveryPointType.aiPassive), 5);
    expect(device.countFor(DiscoveryPointType.ao), 2);
    expect(device.countFor(DiscoveryPointType.di), 11);
    expect(device.countFor(DiscoveryPointType.doOutput), 7);
    expect(device.totalPoints, 25);
    expect(
      device.points
          .where((point) => point.name.contains('FİLTRE KİRLİLİK'))
          .length,
      2,
    );
  });

  test('keşfe özel düzenleme şablon listesini değiştirmez', () {
    final device = instantiate(DiscoveryTemplates.pump);
    final editedPoints = [
      ...device.points,
      DiscoveryPoint(
        id: buildId('point'),
        name: 'POMPA HIZ REFERANSI',
        type: DiscoveryPointType.ao,
      ),
    ];
    final editedDevice = device.copyWith(points: editedPoints);
    final freshDevice = instantiate(DiscoveryTemplates.pump);

    expect(editedDevice.totalPoints, 5);
    expect(editedDevice.countFor(DiscoveryPointType.ao), 1);
    expect(freshDevice.totalPoints, 4);
    expect(freshDevice.countFor(DiscoveryPointType.ao), 0);
  });

  test('pano kodu önerileri mevcut ve sıradaki DDC kodlarını üretir', () {
    final suggestions = DiscoveryPanelCodeSuggestions.build([
      'DDC-02',
      'ÖZEL-PANO',
      'ddc-01',
      'DDC-02',
    ]);

    expect(suggestions, [
      'DDC-01',
      'DDC-02',
      'ÖZEL-PANO',
      'DDC-03',
      'DDC-04',
      'DDC-05',
    ]);
    expect(
      DiscoveryPanelCodeSuggestions.initialValue(['DDC-01', 'DDC-02']),
      'DDC-02',
    );
    expect(DiscoveryPanelCodeSuggestions.initialValue(const []), 'DDC-01');
  });

  test('cihaz şablonları kullanıcıya çoğul kategori adlarını verir', () {
    expect(DiscoveryTemplates.pump.categoryName, 'Pompalar');
    expect(DiscoveryTemplates.boiler.categoryName, 'Isıtma Kazanları');
    expect(
      DiscoveryTemplates.airHandlingUnit.categoryName,
      'Klima Santralleri',
    );
  });

  test('manuel cihaz seçenekleri özel cihaz şablonunu içerir', () {
    expect(DiscoveryTemplates.values, contains(DiscoveryTemplates.custom));
    expect(DiscoveryTemplates.custom.points, isEmpty);
    expect(DiscoveryTemplates.boiler.name, 'Isıtma Kazanı');
  });

  test('ekli kütüphanedeki 80 cihaz şablonu keşifte kullanılabilir', () {
    final imported = DiscoveryTemplates.values
        .where((template) => template.key.startsWith('library-'))
        .toList(growable: false);

    expect(imported, hasLength(80));
    expect(imported.every((template) => template.points.isNotEmpty), isTrue);
    expect(imported.map((template) => template.key).toSet(), hasLength(80));
    expect(
      imported
          .expand((template) => template.points)
          .any((point) => point.name == 'YEDEK' || point.name == 'SPARE'),
      isFalse,
    );
  });

  test('sensör ve kazan varyasyonları doğru I/O tiplerine dönüşür', () {
    final sensor = DiscoveryTemplates.values.singleWhere(
      (template) => template.name == 'DIŞ HAVA SICAKLIK VE NEM SENSÖRÜ',
    );
    final boilerWithValve = DiscoveryTemplates.values.singleWhere(
      (template) => template.name == 'ISITMA KAZANI + MOTORLU VANA KONTROLÜ',
    );

    expect(sensor.points, hasLength(2));
    expect(
      sensor.points.every((point) => point.type == DiscoveryPointType.aiActive),
      isTrue,
    );
    expect(
      boilerWithValve.points.where(
        (point) => point.type == DiscoveryPointType.aiPassive,
      ),
      hasLength(2),
    );
    expect(
      boilerWithValve.points.where(
        (point) => point.type == DiscoveryPointType.di,
      ),
      hasLength(3),
    );
    expect(
      boilerWithValve.points.where(
        (point) => point.type == DiscoveryPointType.doOutput,
      ),
      hasLength(3),
    );
  });

  test('I/O sütunu boş damper start stop satırları DO kabul edilir', () {
    final shelterAhu = DiscoveryTemplates.values.singleWhere(
      (template) => template.name.startsWith('SIĞINAK TAZE HAVA SANTRALİ'),
    );
    final damper = shelterAhu.points.singleWhere(
      (point) => point.name == 'TAZE HAVA DAMPER MOTORU START/STOP',
    );

    expect(damper.type, DiscoveryPointType.doOutput);
  });

  test('kullanıcı cihaz şablonu noktalarıyla json kaydında korunur', () {
    const template = DiscoveryDeviceTemplate(
      key: 'user-template-1',
      name: 'Boyler',
      categoryName: 'Boylerler',
      points: [
        DiscoveryTemplatePoint(
          'BOYLER SICAKLIĞI',
          DiscoveryPointType.aiActive,
          analogSignal: DiscoveryAnalogSignal.current4To20,
        ),
      ],
    );

    final restored = DiscoveryDeviceTemplate.fromJson(template.toJson());

    expect(restored.isUserDefined, isTrue);
    expect(restored.name, 'Boyler');
    expect(restored.points.single.name, 'BOYLER SICAKLIĞI');
    expect(
      restored.points.single.analogSignal,
      DiscoveryAnalogSignal.current4To20,
    );
  });

  test('kullanıcı cihaz şablonu yerel kayıtta tekrar yüklenir', () async {
    SharedPreferences.setMockInitialValues({});
    final repository = DiscoveryRepository();
    const template = DiscoveryDeviceTemplate(
      key: 'user-template-local',
      name: 'Eşanjör',
      categoryName: 'Eşanjörler',
      points: [
        DiscoveryTemplatePoint(
          'EŞANJÖR GİDİŞ SICAKLIĞI',
          DiscoveryPointType.aiPassive,
        ),
      ],
    );

    await repository.saveDeviceTemplate(template);
    final restored = await DiscoveryRepository().fetchDeviceTemplates();

    expect(
      restored.any(
        (item) =>
            item.key == template.key &&
            item.points.single.name == 'EŞANJÖR GİDİŞ SICAKLIĞI',
      ),
      isTrue,
    );
  });

  test('ortak kullanıcı ayarı kimlik ve rol alanlarını tekrar yazmaz', () {
    const profile = UserQuoteProfile(
      userId: 'user-1',
      role: 'manager',
      preparedByName: 'Ali Yılmaz',
      preparedByTitle: 'Satış Müdürü',
      preparedByPhone: '555',
      preparedByEmail: 'ali@example.com',
      companyName: '',
      companyTagline: '',
      companyPhone: '',
      companyEmail: '',
      companyWebsite: '',
      companyAddress: '',
      companyTaxOffice: '',
      companyTaxNumber: '',
      companyMersis: '',
      bankName: '',
      bankBranch: '',
      bankAccountName: '',
      bankIban: '',
      bankSwift: '',
      defaultValidityText: '15 gün',
      defaultPaymentTerms: 'Peşin',
      defaultDeliveryTerms: 'Termin teyidi ile',
      defaultVatRate: 20,
    );

    final row = profile.toUnifiedSettingsRow();

    expect(row['user_id'], 'user-1');
    expect(row['prepared_by_title'], 'Satış Müdürü');
    expect(row.containsKey('prepared_by_name'), isFalse);
    expect(row.containsKey('role'), isFalse);
  });
}
