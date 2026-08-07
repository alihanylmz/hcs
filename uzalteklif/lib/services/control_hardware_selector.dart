import '../models/control_hardware.dart';
import '../models/discovery_project.dart';

enum PanelHardwareRole { controller, remoteIo, unresolved }

extension PanelHardwareRoleX on PanelHardwareRole {
  String get label => switch (this) {
    PanelHardwareRole.controller => 'Bağımsız kontrolör',
    PanelHardwareRole.remoteIo => 'Remote I/O',
    PanelHardwareRole.unresolved => 'Çözüm bulunamadı',
  };
}

class PanelHardwareSolution {
  const PanelHardwareSolution({
    required this.panelCode,
    required this.role,
    required this.controller,
    required this.modules,
    required this.unmetPoints,
    required this.totalDemand,
    required this.matchedPoints,
    required this.parentPanelCode,
    required this.warning,
  });

  final String panelCode;
  final PanelHardwareRole role;
  final ControlHardware? controller;
  final List<ControlHardware> modules;
  final Map<DiscoveryPointType, int> unmetPoints;
  final int totalDemand;
  final int matchedPoints;
  final String parentPanelCode;
  final String warning;

  bool get isSatisfied => unmetPoints.values.every((count) => count == 0);
  int get equipmentCount =>
      (role == PanelHardwareRole.controller && controller != null ? 1 : 0) +
      modules.length;
  int get unmetTotal =>
      unmetPoints.values.fold(0, (total, count) => total + count);
}

class PanelHardwareCapacity {
  const PanelHardwareCapacity({
    required this.requiredPoints,
    required this.matchedPoints,
    required this.unmetPoints,
    required this.totalPhysicalChannels,
  });

  final Map<DiscoveryPointType, int> requiredPoints;
  final Map<DiscoveryPointType, int> matchedPoints;
  final Map<DiscoveryPointType, int> unmetPoints;
  final int totalPhysicalChannels;

  int get requiredTotal =>
      requiredPoints.values.fold(0, (total, count) => total + count);
  int get matchedTotal =>
      matchedPoints.values.fold(0, (total, count) => total + count);
  int get unmetTotal =>
      unmetPoints.values.fold(0, (total, count) => total + count);
  int get remainingChannels =>
      (totalPhysicalChannels - matchedTotal).clamp(0, totalPhysicalChannels);
  bool get isSatisfied => unmetTotal == 0;
}

class ControlHardwareSelectionRules {
  const ControlHardwareSelectionRules({
    this.preferredBrand = '',
    this.reservePercent = 10,
    this.onlyLinkedProductsInStock = true,
    this.inStockProductIds = const {},
  });

  final String preferredBrand;
  final int reservePercent;
  final bool onlyLinkedProductsInStock;
  final Set<String> inStockProductIds;
}

class ControlHardwareSelector {
  const ControlHardwareSelector();

  PanelHardwareCapacity evaluatePanelCapacity({
    required DiscoveryProject project,
    required String panelCode,
    required List<ControlHardware> equipment,
    int reservePercent = 0,
  }) {
    final normalizedPanelCode = panelCode.trim().toUpperCase();
    final devices = project.devices
        .where((device) {
          final code = device.panelCode.trim().isEmpty
              ? 'PANO BELİRTİLMEDİ'
              : device.panelCode.trim().toUpperCase();
          return code == normalizedPanelCode;
        })
        .toList(growable: false);
    final demands = _buildDemands(devices, reservePercent: reservePercent);
    final required = <DiscoveryPointType, int>{};
    for (final demand in demands) {
      required.update(demand.type, (count) => count + 1, ifAbsent: () => 1);
    }
    final allocation = _allocate(demands, equipment);
    final matched = <DiscoveryPointType, int>{};
    for (final entry in required.entries) {
      final count = entry.value - (allocation.unmetPoints[entry.key] ?? 0);
      if (count > 0) matched[entry.key] = count;
    }
    final totalChannels = equipment.fold(
      0,
      (total, item) => total + item.physicalChannelCount,
    );
    return PanelHardwareCapacity(
      requiredPoints: Map.unmodifiable(required),
      matchedPoints: Map.unmodifiable(matched),
      unmetPoints: allocation.unmetPoints,
      totalPhysicalChannels: totalChannels,
    );
  }

  PanelHardwareSolution recommendPanelSolution({
    required DiscoveryProject project,
    required String panelCode,
    required ControlHardware controller,
    required List<ControlHardware> availableModules,
    int reservePercent = 0,
  }) {
    final normalizedPanelCode = panelCode.trim().toUpperCase();
    final devices = project.devices
        .where((device) {
          final code = device.panelCode.trim().isEmpty
              ? 'PANO BELİRTİLMEDİ'
              : device.panelCode.trim().toUpperCase();
          return code == normalizedPanelCode;
        })
        .toList(growable: false);
    final demands = _buildDemands(devices, reservePercent: reservePercent);
    return _controllerCandidate(
      panelCode: normalizedPanelCode,
      controller: controller,
      demands: demands,
      modules: availableModules
          .where(
            (module) =>
                module.isActive && module.type == ControlHardwareType.ioModule,
          )
          .toList(growable: false),
    );
  }

  bool isModuleCompatible({
    required ControlHardware module,
    required ControlHardware controller,
  }) {
    return _isCompatible(module, controller);
  }

  List<PanelHardwareSolution> select({
    required DiscoveryProject project,
    required List<ControlHardware> hardware,
    ControlHardwareSelectionRules rules = const ControlHardwareSelectionRules(
      onlyLinkedProductsInStock: false,
      reservePercent: 0,
    ),
  }) {
    final preferredBrand = rules.preferredBrand.trim().toLowerCase();
    final forcedControllerIds = project.panelSettings
        .map((settings) => settings.controllerHardwareId.trim())
        .where((id) => id.isNotEmpty)
        .toSet();
    final activeHardware = hardware.where((item) {
      if (!item.isActive) return false;
      if (rules.onlyLinkedProductsInStock &&
          !rules.inStockProductIds.contains(item.productId.trim())) {
        return false;
      }
      if (preferredBrand.isNotEmpty &&
          item.type == ControlHardwareType.controller &&
          !forcedControllerIds.contains(item.id) &&
          item.brand.trim().toLowerCase() != preferredBrand) {
        return false;
      }
      return true;
    }).toList();
    final controllers = activeHardware
        .where((item) => item.type == ControlHardwareType.controller)
        .toList(growable: false);
    final modules = activeHardware
        .where((item) => item.type == ControlHardwareType.ioModule)
        .toList(growable: false);
    final panels = _panelDevices(project);
    final results = <PanelHardwareSolution>[];
    final usedExpansionSlots = <String, int>{};

    for (final panelEntry in panels.entries) {
      final panelCode = panelEntry.key;
      final settings = project.settingsForPanel(panelCode);
      final demands = _buildDemands(
        panelEntry.value,
        reservePercent: rules.reservePercent,
      );
      final standalone = _bestStandalone(
        panelCode: panelCode,
        demands: demands,
        controllers: controllers,
        modules: modules,
        forcedControllerId: settings.controllerHardwareId,
      );

      final parentResult = _resolveParent(
        settings: settings,
        previousResults: results,
      );
      final remote = parentResult == null
          ? null
          : _bestRemote(
              panelCode: panelCode,
              parent: parentResult,
              demands: demands,
              modules: modules,
              alreadyUsedSlots: usedExpansionSlots[parentResult.panelCode] ?? 0,
            );

      final selected = _chooseByMode(
        panelCode: panelCode,
        settings: settings,
        standalone: standalone,
        remote: remote,
        totalDemand: demands.length,
      );
      results.add(selected);
      if (selected.role == PanelHardwareRole.remoteIo &&
          selected.parentPanelCode.isNotEmpty) {
        usedExpansionSlots.update(
          selected.parentPanelCode,
          (value) => value + selected.modules.length,
          ifAbsent: () => selected.modules.length,
        );
      } else if (selected.role == PanelHardwareRole.controller) {
        usedExpansionSlots[selected.panelCode] = selected.modules.length;
      }
    }
    return results;
  }

  Map<String, List<DiscoveryDevice>> _panelDevices(DiscoveryProject project) {
    final result = <String, List<DiscoveryDevice>>{};
    for (final device in project.devices) {
      final code = device.panelCode.trim().isEmpty
          ? 'PANO BELİRTİLMEDİ'
          : device.panelCode.trim().toUpperCase();
      result.putIfAbsent(code, () => <DiscoveryDevice>[]).add(device);
    }
    return result;
  }

  List<_DemandUnit> _buildDemands(
    List<DiscoveryDevice> devices, {
    required int reservePercent,
  }) {
    final result = <_DemandUnit>[];
    for (final device in devices) {
      for (final point in device.points) {
        if (!_isPhysicalIo(point.type)) continue;
        for (var index = 0; index < point.quantity; index++) {
          result.add(
            _DemandUnit(
              type: point.type,
              requires420mA:
                  point.type == DiscoveryPointType.aiActive &&
                  point.analogSignal != DiscoveryAnalogSignal.voltage0To10,
            ),
          );
        }
      }
    }
    final normalizedReserve = reservePercent.clamp(0, 50);
    if (normalizedReserve > 0 && result.isNotEmpty) {
      final groups = <String, List<_DemandUnit>>{};
      for (final demand in result) {
        final key = '${demand.type.storageKey}:${demand.requires420mA}';
        groups.putIfAbsent(key, () => []).add(demand);
      }
      for (final group in groups.values) {
        final extra = (group.length * normalizedReserve / 100).ceil();
        for (var index = 0; index < extra; index++) {
          result.add(group.first);
        }
      }
    }
    return result;
  }

  bool _isPhysicalIo(DiscoveryPointType type) {
    return switch (type) {
      DiscoveryPointType.aiActive ||
      DiscoveryPointType.aiPassive ||
      DiscoveryPointType.ao ||
      DiscoveryPointType.di ||
      DiscoveryPointType.doOutput => true,
      _ => false,
    };
  }

  PanelHardwareSolution _bestStandalone({
    required String panelCode,
    required List<_DemandUnit> demands,
    required List<ControlHardware> controllers,
    required List<ControlHardware> modules,
    required String forcedControllerId,
  }) {
    PanelHardwareSolution? best;
    final requestedId = forcedControllerId.trim();
    final candidates = requestedId.isEmpty
        ? controllers
        : controllers
              .where((controller) => controller.id == requestedId)
              .toList(growable: false);
    for (final controller in candidates) {
      final candidate = _controllerCandidate(
        panelCode: panelCode,
        controller: controller,
        demands: demands,
        modules: modules,
      );
      if (best == null || _isBetter(candidate, best)) best = candidate;
    }
    return best ??
        _unresolved(
          panelCode,
          demands,
          requestedId.isEmpty
              ? 'Kütüphanede aktif kontrolör bulunmuyor.'
              : 'Bu pano için seçilen kontrolör aktif, stokta veya filtre '
                    'kurallarına uygun değil.',
        );
  }

  PanelHardwareSolution _controllerCandidate({
    required String panelCode,
    required ControlHardware controller,
    required List<_DemandUnit> demands,
    required List<ControlHardware> modules,
  }) {
    final compatibleModules = modules
        .where((module) => _isCompatible(module, controller))
        .toList(growable: false);
    final selectedModules = <ControlHardware>[];
    var allocation = _allocate(demands, [controller, ...selectedModules]);
    final maxModules = controller.maxExpansionModules.clamp(0, 12);

    while (allocation.unmetTotal > 0 &&
        selectedModules.length < maxModules &&
        compatibleModules.isNotEmpty) {
      ControlHardware? bestModule;
      _AllocationResult? bestAllocation;
      for (final module in compatibleModules) {
        final candidateAllocation = _allocate(demands, [
          controller,
          ...selectedModules,
          module,
        ]);
        if (bestAllocation == null ||
            candidateAllocation.unmetTotal < bestAllocation.unmetTotal ||
            (candidateAllocation.unmetTotal == bestAllocation.unmetTotal &&
                module.physicalChannelCount <
                    (bestModule?.physicalChannelCount ?? 1 << 20))) {
          bestModule = module;
          bestAllocation = candidateAllocation;
        }
      }
      if (bestModule == null ||
          bestAllocation == null ||
          bestAllocation.unmetTotal >= allocation.unmetTotal) {
        break;
      }
      selectedModules.add(bestModule);
      allocation = bestAllocation;
    }

    return PanelHardwareSolution(
      panelCode: panelCode,
      role: PanelHardwareRole.controller,
      controller: controller,
      modules: List.unmodifiable(selectedModules),
      unmetPoints: allocation.unmetPoints,
      totalDemand: demands.length,
      matchedPoints: allocation.matchedPoints,
      parentPanelCode: '',
      warning: allocation.unmetTotal == 0
          ? ''
          : 'Kontrolör ve izin verilen modüller bütün noktaları karşılamıyor.',
    );
  }

  PanelHardwareSolution? _bestRemote({
    required String panelCode,
    required PanelHardwareSolution parent,
    required List<_DemandUnit> demands,
    required List<ControlHardware> modules,
    required int alreadyUsedSlots,
  }) {
    final controller = parent.controller;
    if (controller == null || !parent.isSatisfied) return null;
    final remainingSlots = controller.maxExpansionModules - alreadyUsedSlots;
    if (remainingSlots <= 0) return null;

    final compatibleModules = modules
        .where((module) => _isCompatible(module, controller))
        .toList(growable: false);
    if (compatibleModules.isEmpty) return null;

    final selectedModules = <ControlHardware>[];
    var allocation = _allocate(demands, const []);
    while (allocation.unmetTotal > 0 &&
        selectedModules.length < remainingSlots) {
      ControlHardware? bestModule;
      _AllocationResult? bestAllocation;
      for (final module in compatibleModules) {
        final candidateAllocation = _allocate(demands, [
          ...selectedModules,
          module,
        ]);
        if (bestAllocation == null ||
            candidateAllocation.unmetTotal < bestAllocation.unmetTotal ||
            (candidateAllocation.unmetTotal == bestAllocation.unmetTotal &&
                module.physicalChannelCount <
                    (bestModule?.physicalChannelCount ?? 1 << 20))) {
          bestModule = module;
          bestAllocation = candidateAllocation;
        }
      }
      if (bestModule == null ||
          bestAllocation == null ||
          bestAllocation.unmetTotal >= allocation.unmetTotal) {
        break;
      }
      selectedModules.add(bestModule);
      allocation = bestAllocation;
    }
    if (selectedModules.isEmpty) return null;

    return PanelHardwareSolution(
      panelCode: panelCode,
      role: PanelHardwareRole.remoteIo,
      controller: controller,
      modules: List.unmodifiable(selectedModules),
      unmetPoints: allocation.unmetPoints,
      totalDemand: demands.length,
      matchedPoints: allocation.matchedPoints,
      parentPanelCode: parent.panelCode,
      warning: allocation.unmetTotal == 0
          ? 'Bu pano ${parent.panelCode} kontrolörüne bağlıdır; bağlantı '
                'kesilirse bağımsız çalışamaz.'
          : 'Uyumlu Remote I/O modülleri bütün noktaları karşılamıyor.',
    );
  }

  PanelHardwareSolution? _resolveParent({
    required DiscoveryPanelSettings settings,
    required List<PanelHardwareSolution> previousResults,
  }) {
    final requestedParent = settings.parentPanelCode.trim().toUpperCase();
    if (requestedParent.isNotEmpty) {
      for (final result in previousResults) {
        if (result.panelCode == requestedParent &&
            result.role == PanelHardwareRole.controller) {
          return result;
        }
      }
      return null;
    }
    for (final result in previousResults) {
      if (result.role == PanelHardwareRole.controller && result.isSatisfied) {
        return result;
      }
    }
    return null;
  }

  PanelHardwareSolution _chooseByMode({
    required String panelCode,
    required DiscoveryPanelSettings settings,
    required PanelHardwareSolution standalone,
    required PanelHardwareSolution? remote,
    required int totalDemand,
  }) {
    switch (settings.mode) {
      case DiscoveryPanelMode.controllerRequired:
        return standalone;
      case DiscoveryPanelMode.remoteOnly:
        return remote ??
            _unresolved(
              panelCode,
              const [],
              'Seçilen ana panoya uygun Remote I/O çözümü bulunamadı.',
              totalDemand: totalDemand,
            );
      case DiscoveryPanelMode.remoteAllowed:
      case DiscoveryPanelMode.automatic:
        if (remote != null && remote.isSatisfied) {
          if (!standalone.isSatisfied ||
              remote.equipmentCount <= standalone.equipmentCount) {
            return remote;
          }
        }
        return standalone;
    }
  }

  bool _isCompatible(ControlHardware module, ControlHardware controller) {
    if (module.type != ControlHardwareType.ioModule) return false;
    final moduleFamily = module.family.trim().toLowerCase();
    final controllerFamily = controller.family.trim().toLowerCase();
    final sameBrand =
        module.brand.trim().toLowerCase() ==
        controller.brand.trim().toLowerCase();

    switch (module.compatibilityMode) {
      case HardwareCompatibilityMode.sameFamily:
        return sameBrand &&
            moduleFamily.isNotEmpty &&
            moduleFamily == controllerFamily;
      case HardwareCompatibilityMode.selectedFamilies:
        final candidates = {
          controllerFamily,
          '${controller.brand} ${controller.family}'.trim().toLowerCase(),
          controller.model.trim().toLowerCase(),
        };
        return module.compatibleFamilies.any(
          (family) => candidates.contains(family.trim().toLowerCase()),
        );
      case HardwareCompatibilityMode.universalProtocol:
        final moduleProtocols = _protocolTokens(module.connectionProtocol);
        final controllerProtocols = _protocolTokens(
          controller.connectionProtocol,
        );
        return moduleProtocols.intersection(controllerProtocols).isNotEmpty;
    }
  }

  Set<String> _protocolTokens(String value) {
    return value
        .split(RegExp(r'[,;/|]+'))
        .map((item) => item.trim().toLowerCase())
        .where((item) => item.isNotEmpty)
        .toSet();
  }

  bool _isBetter(
    PanelHardwareSolution candidate,
    PanelHardwareSolution current,
  ) {
    if (candidate.isSatisfied != current.isSatisfied) {
      return candidate.isSatisfied;
    }
    if (candidate.unmetTotal != current.unmetTotal) {
      return candidate.unmetTotal < current.unmetTotal;
    }
    if (candidate.equipmentCount != current.equipmentCount) {
      return candidate.equipmentCount < current.equipmentCount;
    }
    final candidateChannels = [
      if (candidate.controller != null) candidate.controller!,
      ...candidate.modules,
    ].fold(0, (total, item) => total + item.physicalChannelCount);
    final currentChannels = [
      if (current.controller != null) current.controller!,
      ...current.modules,
    ].fold(0, (total, item) => total + item.physicalChannelCount);
    return candidateChannels < currentChannels;
  }

  _AllocationResult _allocate(
    List<_DemandUnit> demands,
    List<ControlHardware> equipment,
  ) {
    final slots = <_ChannelSlot>[];
    for (final item in equipment) {
      for (final pool in item.channelPools) {
        for (var index = 0; index < pool.quantity; index++) {
          slots.add(
            _ChannelSlot(
              supportedTypes: pool.supportedPointTypes,
              supportsAiActive420mA: pool.supportsAiActive420mA,
            ),
          );
        }
      }
    }

    final orderedDemands = List<_DemandUnit>.from(demands)
      ..sort((left, right) {
        final leftOptions = slots.where((slot) => slot.supports(left)).length;
        final rightOptions = slots.where((slot) => slot.supports(right)).length;
        return leftOptions.compareTo(rightOptions);
      });
    final assignedDemandBySlot = List<int?>.filled(slots.length, null);
    final matchedDemands = <int>{};

    bool assign(int demandIndex, Set<int> visitedSlots) {
      for (var slotIndex = 0; slotIndex < slots.length; slotIndex++) {
        if (visitedSlots.contains(slotIndex) ||
            !slots[slotIndex].supports(orderedDemands[demandIndex])) {
          continue;
        }
        visitedSlots.add(slotIndex);
        final currentDemand = assignedDemandBySlot[slotIndex];
        if (currentDemand == null || assign(currentDemand, visitedSlots)) {
          assignedDemandBySlot[slotIndex] = demandIndex;
          return true;
        }
      }
      return false;
    }

    for (
      var demandIndex = 0;
      demandIndex < orderedDemands.length;
      demandIndex++
    ) {
      if (assign(demandIndex, <int>{})) matchedDemands.add(demandIndex);
    }

    final unmet = <DiscoveryPointType, int>{};
    for (var index = 0; index < orderedDemands.length; index++) {
      if (matchedDemands.contains(index)) continue;
      unmet.update(
        orderedDemands[index].type,
        (count) => count + 1,
        ifAbsent: () => 1,
      );
    }
    return _AllocationResult(
      matchedPoints: matchedDemands.length,
      unmetPoints: Map.unmodifiable(unmet),
    );
  }

  PanelHardwareSolution _unresolved(
    String panelCode,
    List<_DemandUnit> demands,
    String warning, {
    int? totalDemand,
  }) {
    final unmet = <DiscoveryPointType, int>{};
    for (final demand in demands) {
      unmet.update(demand.type, (count) => count + 1, ifAbsent: () => 1);
    }
    return PanelHardwareSolution(
      panelCode: panelCode,
      role: PanelHardwareRole.unresolved,
      controller: null,
      modules: const [],
      unmetPoints: unmet,
      totalDemand: totalDemand ?? demands.length,
      matchedPoints: 0,
      parentPanelCode: '',
      warning: warning,
    );
  }
}

class _DemandUnit {
  const _DemandUnit({required this.type, required this.requires420mA});

  final DiscoveryPointType type;
  final bool requires420mA;
}

class _ChannelSlot {
  const _ChannelSlot({
    required this.supportedTypes,
    required this.supportsAiActive420mA,
  });

  final Set<DiscoveryPointType> supportedTypes;
  final bool supportsAiActive420mA;

  bool supports(_DemandUnit demand) {
    if (!supportedTypes.contains(demand.type)) return false;
    if (demand.type == DiscoveryPointType.aiActive &&
        demand.requires420mA &&
        !supportsAiActive420mA) {
      return false;
    }
    return true;
  }
}

class _AllocationResult {
  const _AllocationResult({
    required this.matchedPoints,
    required this.unmetPoints,
  });

  final int matchedPoints;
  final Map<DiscoveryPointType, int> unmetPoints;

  int get unmetTotal =>
      unmetPoints.values.fold(0, (total, count) => total + count);
}
