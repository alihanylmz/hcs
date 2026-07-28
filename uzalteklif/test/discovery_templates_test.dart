import 'package:flutter_test/flutter_test.dart';
import 'package:uzalteklif/config/discovery_templates.dart';
import 'package:uzalteklif/models/discovery_project.dart';

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
}
