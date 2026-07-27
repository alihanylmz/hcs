import 'package:flutter_test/flutter_test.dart';
import 'package:uzalteklif/config/control_hardware_defaults.dart';
import 'package:uzalteklif/models/control_hardware.dart';
import 'package:uzalteklif/models/discovery_project.dart';

void main() {
  test('ABB FBXi 8R8 kanal havuzları doğru yetenekleri taşır', () {
    final controller = ControlHardwareDefaults.abbFbxi8r8;
    final ui = controller.channelPools.first;
    final uio = controller.channelPools.last;

    expect(controller.physicalChannelCount, 16);
    expect(ui.quantity, 8);
    expect(ui.supports(DiscoveryPointType.aiActive, requires420mA: true), true);
    expect(ui.supports(DiscoveryPointType.di), true);
    expect(ui.supports(DiscoveryPointType.ao), false);

    expect(uio.quantity, 8);
    expect(uio.supports(DiscoveryPointType.ao), true);
    expect(uio.supports(DiscoveryPointType.doOutput), true);
    expect(
      uio.supports(DiscoveryPointType.aiActive, requires420mA: true),
      false,
    );
  });

  test('Honeywell Unitary 16 universal 16 kanal ve ek 8 DO taşır', () {
    final controller = ControlHardwareDefaults.honeywellUnitary16;
    final universal = controller.channelPools.first;
    final dedicatedDo = controller.channelPools.last;

    expect(controller.physicalChannelCount, 24);
    expect(universal.quantity, 16);
    expect(
      universal.supportedPointTypes,
      containsAll([
        DiscoveryPointType.aiActive,
        DiscoveryPointType.aiPassive,
        DiscoveryPointType.ao,
        DiscoveryPointType.di,
        DiscoveryPointType.doOutput,
      ]),
    );
    expect(dedicatedDo.quantity, 8);
    expect(dedicatedDo.supportedPointTypes, {DiscoveryPointType.doOutput});
  });

  test('kontrol donanımı JSON dönüşümünde kanal ve uyumluluk korunur', () {
    final module = ControlHardware(
      id: 'module-1',
      type: ControlHardwareType.ioModule,
      brand: 'Universal',
      model: 'Remote IO',
      family: 'Remote',
      channelPools: const [
        HardwareChannelPool(
          id: 'pool-1',
          name: 'DI',
          quantity: 8,
          supportedPointTypes: {DiscoveryPointType.di},
        ),
      ],
      compatibilityMode: HardwareCompatibilityMode.selectedFamilies,
      connectionProtocol: 'Modbus TCP',
      compatibleFamilies: const ['FBXi', 'Unitary'],
      maxExpansionModules: 0,
      isActive: true,
      note: 'Doğrulanmış iki aile',
      updatedAt: DateTime.utc(2026, 7, 27),
    );

    final restored = ControlHardware.fromJson(module.toJson());

    expect(restored.type, ControlHardwareType.ioModule);
    expect(restored.connectionProtocol, 'Modbus TCP');
    expect(restored.compatibleFamilies, ['FBXi', 'Unitary']);
    expect(restored.channelPools.single.quantity, 8);
    expect(restored.channelPools.single.supportedPointTypes, {
      DiscoveryPointType.di,
    });
  });
}
