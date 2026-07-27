import '../models/control_hardware.dart';
import '../models/discovery_project.dart';

abstract final class ControlHardwareDefaults {
  static final abbFbxi8r8 = ControlHardware(
    id: 'seed-abb-fbxi-8r8',
    type: ControlHardwareType.controller,
    brand: 'ABB',
    model: 'FBXi 8R8',
    family: 'FBXi',
    channelPools: const [
      HardwareChannelPool(
        id: 'abb-fbxi-8r8-ui',
        name: 'UI',
        quantity: 8,
        supportedPointTypes: {
          DiscoveryPointType.aiActive,
          DiscoveryPointType.aiPassive,
          DiscoveryPointType.di,
        },
      ),
      HardwareChannelPool(
        id: 'abb-fbxi-8r8-uio',
        name: 'UIO',
        quantity: 8,
        supportedPointTypes: {
          DiscoveryPointType.aiActive,
          DiscoveryPointType.aiPassive,
          DiscoveryPointType.ao,
          DiscoveryPointType.di,
          DiscoveryPointType.doOutput,
        },
        supportsAiActive420mA: false,
      ),
    ],
    compatibilityMode: HardwareCompatibilityMode.sameFamily,
    connectionProtocol: '',
    compatibleFamilies: const [],
    maxExpansionModules: 0,
    isActive: true,
    note: 'UIO grubunda AI-A 4–20 mA desteklenmez.',
    updatedAt: DateTime(2026, 7, 27),
  );

  static final honeywellUnitary16 = ControlHardware(
    id: 'seed-honeywell-unitary-16',
    type: ControlHardwareType.controller,
    brand: 'Honeywell',
    model: 'Unitary 16',
    family: 'Unitary',
    channelPools: const [
      HardwareChannelPool(
        id: 'honeywell-unitary-16-universal',
        name: 'Universal I/O',
        quantity: 16,
        supportedPointTypes: {
          DiscoveryPointType.aiActive,
          DiscoveryPointType.aiPassive,
          DiscoveryPointType.ao,
          DiscoveryPointType.di,
          DiscoveryPointType.doOutput,
        },
      ),
      HardwareChannelPool(
        id: 'honeywell-unitary-16-do',
        name: 'DO',
        quantity: 8,
        supportedPointTypes: {DiscoveryPointType.doOutput},
      ),
    ],
    compatibilityMode: HardwareCompatibilityMode.sameFamily,
    connectionProtocol: '',
    compatibleFamilies: const [],
    maxExpansionModules: 0,
    isActive: true,
    note: '',
    updatedAt: DateTime(2026, 7, 27),
  );

  static List<ControlHardware> get values => [abbFbxi8r8, honeywellUnitary16];
}
