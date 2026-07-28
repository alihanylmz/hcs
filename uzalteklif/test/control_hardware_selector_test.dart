import 'package:flutter_test/flutter_test.dart';
import 'package:uzalteklif/config/control_hardware_defaults.dart';
import 'package:uzalteklif/models/control_hardware.dart';
import 'package:uzalteklif/models/discovery_project.dart';
import 'package:uzalteklif/services/control_hardware_selector.dart';

void main() {
  DiscoveryProject project({
    required List<DiscoveryDevice> devices,
    List<DiscoveryPanelSettings> panelSettings = const [],
  }) {
    final now = DateTime.utc(2026, 7, 27);
    return DiscoveryProject(
      id: 'project',
      projectName: 'Test',
      projectCode: 'T-01',
      revision: '00',
      preparedBy: 'Test',
      devices: devices,
      panelSettings: panelSettings,
      createdAt: now,
      updatedAt: now,
    );
  }

  DiscoveryDevice device(
    String id,
    String panelCode,
    List<DiscoveryPoint> points,
  ) {
    return DiscoveryDevice(
      id: id,
      templateKey: 'custom',
      name: id,
      panelCode: panelCode,
      deviceCode: id,
      points: points,
    );
  }

  DiscoveryPoint point(
    String id,
    DiscoveryPointType type,
    int quantity, {
    DiscoveryAnalogSignal signal = DiscoveryAnalogSignal.unspecified,
  }) {
    return DiscoveryPoint(
      id: id,
      name: id,
      type: type,
      quantity: quantity,
      analogSignal: signal,
    );
  }

  test('4-20 mA AI-A ihtiyacı ABB UIO kanalına atanmaz', () {
    final input = project(
      devices: [
        device('sensor', 'DDC-01', [
          point(
            'current',
            DiscoveryPointType.aiActive,
            9,
            signal: DiscoveryAnalogSignal.current4To20,
          ),
        ]),
      ],
    );

    final result = const ControlHardwareSelector().select(
      project: input,
      hardware: [
        ControlHardwareDefaults.abbFbxi8r8,
        ControlHardwareDefaults.honeywellUnitary16,
      ],
    );

    expect(result.single.isSatisfied, true);
    expect(result.single.controller?.brand, 'Honeywell');
    expect(result.single.matchedPoints, 9);
  });

  test('0-10 V AI-A ABB UIO dahil bütün uygun kanalları kullanabilir', () {
    final input = project(
      devices: [
        device('sensor', 'DDC-01', [
          point(
            'voltage',
            DiscoveryPointType.aiActive,
            12,
            signal: DiscoveryAnalogSignal.voltage0To10,
          ),
        ]),
      ],
    );

    final result = const ControlHardwareSelector().select(
      project: input,
      hardware: [ControlHardwareDefaults.abbFbxi8r8],
    );

    expect(result.single.isSatisfied, true);
    expect(result.single.controller?.brand, 'ABB');
    expect(result.single.matchedPoints, 12);
  });

  test('ikinci pano uyumlu modülle birinci panoya Remote I/O bağlanır', () {
    final controller = ControlHardwareDefaults.honeywellUnitary16.copyWith(
      maxExpansionModules: 3,
    );
    final remoteModule = ControlHardware(
      id: 'remote-uio',
      type: ControlHardwareType.ioModule,
      brand: 'Universal',
      model: 'Remote UIO 8',
      family: 'Remote',
      channelPools: const [
        HardwareChannelPool(
          id: 'remote-pool',
          name: 'UIO',
          quantity: 8,
          supportedPointTypes: {
            DiscoveryPointType.aiActive,
            DiscoveryPointType.aiPassive,
            DiscoveryPointType.ao,
            DiscoveryPointType.di,
            DiscoveryPointType.doOutput,
          },
        ),
      ],
      compatibilityMode: HardwareCompatibilityMode.selectedFamilies,
      connectionProtocol: 'Modbus TCP',
      compatibleFamilies: const ['Unitary'],
      maxExpansionModules: 0,
      isActive: true,
      updatedAt: DateTime.utc(2026, 7, 27),
    );
    final input = project(
      devices: [
        device('pump-1', 'DDC-01', [
          point('di-1', DiscoveryPointType.di, 3),
          point('do-1', DiscoveryPointType.doOutput, 1),
        ]),
        device('pump-2', 'DDC-02', [
          point('di-2', DiscoveryPointType.di, 3),
          point('do-2', DiscoveryPointType.doOutput, 1),
        ]),
      ],
      panelSettings: const [
        DiscoveryPanelSettings(
          panelCode: 'DDC-01',
          mode: DiscoveryPanelMode.controllerRequired,
        ),
        DiscoveryPanelSettings(
          panelCode: 'DDC-02',
          mode: DiscoveryPanelMode.remoteAllowed,
          parentPanelCode: 'DDC-01',
        ),
      ],
    );

    expect(
      const ControlHardwareSelector().isModuleCompatible(
        module: remoteModule,
        controller: controller,
      ),
      true,
    );
    final result = const ControlHardwareSelector().select(
      project: input,
      hardware: [controller, remoteModule],
    );

    expect(result, hasLength(2));
    expect(result.first.role, PanelHardwareRole.controller);
    expect(result.last.role, PanelHardwareRole.remoteIo);
    expect(result.last.parentPanelCode, 'DDC-01');
    expect(result.last.modules.single.model, 'Remote UIO 8');
    expect(result.last.isSatisfied, true);
  });

  test('uyumlu Remote modül yoksa ikinci panoya ayrı kontrolör seçilir', () {
    final controller = ControlHardwareDefaults.honeywellUnitary16.copyWith(
      maxExpansionModules: 3,
    );
    final input = project(
      devices: [
        device('pump-1', 'DDC-01', [
          point('di-1', DiscoveryPointType.di, 3),
          point('do-1', DiscoveryPointType.doOutput, 1),
        ]),
        device('pump-2', 'DDC-02', [
          point('di-2', DiscoveryPointType.di, 3),
          point('do-2', DiscoveryPointType.doOutput, 1),
        ]),
      ],
      panelSettings: const [
        DiscoveryPanelSettings(
          panelCode: 'DDC-02',
          mode: DiscoveryPanelMode.remoteAllowed,
          parentPanelCode: 'DDC-01',
        ),
      ],
    );

    final result = const ControlHardwareSelector().select(
      project: input,
      hardware: [controller],
    );

    expect(result.last.role, PanelHardwareRole.controller);
    expect(result.last.isSatisfied, true);
  });

  test('AI sinyal tipi ve pano topolojisi proje kaydında korunur', () {
    final source = project(
      devices: [
        device('sensor', 'DDC-02', [
          point(
            'current',
            DiscoveryPointType.aiActive,
            1,
            signal: DiscoveryAnalogSignal.current4To20,
          ),
        ]),
      ],
      panelSettings: const [
        DiscoveryPanelSettings(
          panelCode: 'DDC-02',
          mode: DiscoveryPanelMode.remoteOnly,
          parentPanelCode: 'DDC-01',
          controllerHardwareId: 'controller-1',
          ioModuleHardwareIds: ['module-1', 'module-1'],
        ),
      ],
    );

    final restored = DiscoveryProject.fromJson(source.toJson());

    expect(
      restored.devices.single.points.single.analogSignal,
      DiscoveryAnalogSignal.current4To20,
    );
    expect(
      restored.settingsForPanel('DDC-02').mode,
      DiscoveryPanelMode.remoteOnly,
    );
    expect(restored.settingsForPanel('DDC-02').parentPanelCode, 'DDC-01');
    expect(
      restored.settingsForPanel('DDC-02').controllerHardwareId,
      'controller-1',
    );
    expect(restored.settingsForPanel('DDC-02').ioModuleHardwareIds, [
      'module-1',
      'module-1',
    ]);
  });

  test('panoya elle eşleştirilen kontrolör otomatik adayların önüne geçer', () {
    final abb = ControlHardwareDefaults.abbFbxi8r8;
    final honeywell = ControlHardwareDefaults.honeywellUnitary16;
    final input = project(
      devices: [
        device('pump', 'DDC-01', [
          point('di', DiscoveryPointType.di, 3),
          point('do', DiscoveryPointType.doOutput, 1),
        ]),
      ],
      panelSettings: [
        DiscoveryPanelSettings(
          panelCode: 'DDC-01',
          mode: DiscoveryPanelMode.controllerRequired,
          controllerHardwareId: abb.id,
        ),
      ],
    );

    final result = const ControlHardwareSelector().select(
      project: input,
      hardware: [honeywell, abb],
      rules: const ControlHardwareSelectionRules(
        preferredBrand: 'Honeywell',
        onlyLinkedProductsInStock: false,
        reservePercent: 0,
      ),
    );

    expect(result.single.controller?.id, abb.id);
    expect(result.single.isSatisfied, isTrue);
  });

  test('stok ve marka kuralları aday kontrolörleri sınırlar', () {
    final input = project(
      devices: [
        device('pump', 'DDC-01', [
          point('di', DiscoveryPointType.di, 3),
          point('do', DiscoveryPointType.doOutput, 1),
        ]),
      ],
    );
    final abb = ControlHardwareDefaults.abbFbxi8r8.copyWith(
      productId: 'stock-abb',
    );
    final honeywell = ControlHardwareDefaults.honeywellUnitary16.copyWith(
      productId: 'stock-honeywell',
    );

    final result = const ControlHardwareSelector().select(
      project: input,
      hardware: [abb, honeywell],
      rules: const ControlHardwareSelectionRules(
        preferredBrand: 'Honeywell',
        reservePercent: 0,
        onlyLinkedProductsInStock: true,
        inStockProductIds: {'stock-honeywell'},
      ),
    );

    expect(result.single.isSatisfied, true);
    expect(result.single.controller?.brand, 'Honeywell');
  });
}
