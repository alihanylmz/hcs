import 'discovery_project.dart';

enum ControlHardwareType { controller, ioModule }

extension ControlHardwareTypeX on ControlHardwareType {
  String get storageKey => switch (this) {
    ControlHardwareType.controller => 'controller',
    ControlHardwareType.ioModule => 'io_module',
  };

  String get label => switch (this) {
    ControlHardwareType.controller => 'Kontrolör',
    ControlHardwareType.ioModule => 'I/O Modülü',
  };

  static ControlHardwareType fromStorageKey(String? value) {
    return value == 'io_module'
        ? ControlHardwareType.ioModule
        : ControlHardwareType.controller;
  }
}

enum HardwareCompatibilityMode {
  sameFamily,
  selectedFamilies,
  universalProtocol,
}

extension HardwareCompatibilityModeX on HardwareCompatibilityMode {
  String get storageKey => switch (this) {
    HardwareCompatibilityMode.sameFamily => 'same_family',
    HardwareCompatibilityMode.selectedFamilies => 'selected_families',
    HardwareCompatibilityMode.universalProtocol => 'universal_protocol',
  };

  String get label => switch (this) {
    HardwareCompatibilityMode.sameFamily => 'Yalnız kendi ailesi',
    HardwareCompatibilityMode.selectedFamilies => 'Belirli aileler',
    HardwareCompatibilityMode.universalProtocol => 'Universal protokol',
  };

  static HardwareCompatibilityMode fromStorageKey(String? value) {
    return switch (value) {
      'selected_families' => HardwareCompatibilityMode.selectedFamilies,
      'universal_protocol' => HardwareCompatibilityMode.universalProtocol,
      _ => HardwareCompatibilityMode.sameFamily,
    };
  }
}

class HardwareChannelPool {
  const HardwareChannelPool({
    required this.id,
    required this.name,
    required this.quantity,
    required this.supportedPointTypes,
    this.supportsAiActive420mA = true,
  });

  final String id;
  final String name;
  final int quantity;
  final Set<DiscoveryPointType> supportedPointTypes;

  /// `false` ise kanal AI-A olarak atanabilir ancak 4–20 mA aktif analog
  /// sinyali kabul etmez. 0–10 V gibi desteklenen aktif sinyaller için
  /// cihaz dokümanı ayrıca kontrol edilmelidir.
  final bool supportsAiActive420mA;

  bool supports(DiscoveryPointType type, {bool requires420mA = false}) {
    if (!supportedPointTypes.contains(type)) return false;
    if (type == DiscoveryPointType.aiActive && requires420mA) {
      return supportsAiActive420mA;
    }
    return true;
  }

  HardwareChannelPool copyWith({
    String? id,
    String? name,
    int? quantity,
    Set<DiscoveryPointType>? supportedPointTypes,
    bool? supportsAiActive420mA,
  }) {
    return HardwareChannelPool(
      id: id ?? this.id,
      name: name ?? this.name,
      quantity: quantity ?? this.quantity,
      supportedPointTypes: supportedPointTypes ?? this.supportedPointTypes,
      supportsAiActive420mA:
          supportsAiActive420mA ?? this.supportsAiActive420mA,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'quantity': quantity,
    'supported_point_types': supportedPointTypes
        .map((type) => type.storageKey)
        .toList(growable: false),
    'supports_ai_active_4_20ma': supportsAiActive420mA,
  };

  factory HardwareChannelPool.fromJson(Map<String, dynamic> json) {
    final rawTypes =
        json['supported_point_types'] as List<dynamic>? ?? const [];
    return HardwareChannelPool(
      id: json['id'] as String? ?? '',
      name: (json['name'] as String?)?.trim() ?? '',
      quantity: (json['quantity'] as num?)?.toInt() ?? 0,
      supportedPointTypes: rawTypes
          .map((value) => DiscoveryPointTypeX.fromStorageKey(value as String?))
          .toSet(),
      supportsAiActive420mA: json['supports_ai_active_4_20ma'] as bool? ?? true,
    );
  }
}

class ControlHardware {
  const ControlHardware({
    required this.id,
    required this.type,
    required this.brand,
    required this.model,
    required this.family,
    required this.channelPools,
    required this.compatibilityMode,
    required this.connectionProtocol,
    required this.compatibleFamilies,
    required this.maxExpansionModules,
    required this.isActive,
    required this.updatedAt,
    this.productId = '',
    this.note = '',
    this.createdBy,
  });

  final String id;
  final ControlHardwareType type;
  final String brand;
  final String model;
  final String family;
  final String productId;
  final List<HardwareChannelPool> channelPools;
  final HardwareCompatibilityMode compatibilityMode;
  final String connectionProtocol;
  final List<String> compatibleFamilies;
  final int maxExpansionModules;
  final bool isActive;
  final String note;
  final DateTime updatedAt;
  final String? createdBy;

  String get displayName {
    final values = [
      brand.trim(),
      model.trim(),
    ].where((value) => value.isNotEmpty).toList(growable: false);
    return values.isEmpty ? 'İsimsiz ekipman' : values.join(' ');
  }

  int get physicalChannelCount =>
      channelPools.fold(0, (total, pool) => total + pool.quantity);

  bool get isController => type == ControlHardwareType.controller;

  ControlHardware copyWith({
    String? id,
    ControlHardwareType? type,
    String? brand,
    String? model,
    String? family,
    String? productId,
    List<HardwareChannelPool>? channelPools,
    HardwareCompatibilityMode? compatibilityMode,
    String? connectionProtocol,
    List<String>? compatibleFamilies,
    int? maxExpansionModules,
    bool? isActive,
    String? note,
    DateTime? updatedAt,
    String? createdBy,
  }) {
    return ControlHardware(
      id: id ?? this.id,
      type: type ?? this.type,
      brand: brand ?? this.brand,
      model: model ?? this.model,
      family: family ?? this.family,
      productId: productId ?? this.productId,
      channelPools: channelPools ?? this.channelPools,
      compatibilityMode: compatibilityMode ?? this.compatibilityMode,
      connectionProtocol: connectionProtocol ?? this.connectionProtocol,
      compatibleFamilies: compatibleFamilies ?? this.compatibleFamilies,
      maxExpansionModules: maxExpansionModules ?? this.maxExpansionModules,
      isActive: isActive ?? this.isActive,
      note: note ?? this.note,
      updatedAt: updatedAt ?? this.updatedAt,
      createdBy: createdBy ?? this.createdBy,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'equipment_type': type.storageKey,
    'brand': brand,
    'model': model,
    'family': family,
    'product_id': productId,
    'channel_pools': channelPools.map((pool) => pool.toJson()).toList(),
    'compatibility_mode': compatibilityMode.storageKey,
    'connection_protocol': connectionProtocol,
    'compatible_families': compatibleFamilies,
    'max_expansion_modules': maxExpansionModules,
    'is_active': isActive,
    'note': note,
    'updated_at': updatedAt.toIso8601String(),
    'created_by': createdBy,
  };

  factory ControlHardware.fromJson(Map<String, dynamic> json) {
    final rawPools = json['channel_pools'] as List<dynamic>? ?? const [];
    final rawFamilies =
        json['compatible_families'] as List<dynamic>? ?? const [];
    return ControlHardware(
      id: json['id'] as String? ?? '',
      type: ControlHardwareTypeX.fromStorageKey(
        json['equipment_type'] as String?,
      ),
      brand: (json['brand'] as String?)?.trim() ?? '',
      model: (json['model'] as String?)?.trim() ?? '',
      family: (json['family'] as String?)?.trim() ?? '',
      productId: (json['product_id'] as String?)?.trim() ?? '',
      channelPools: rawPools
          .whereType<Map>()
          .map(
            (pool) =>
                HardwareChannelPool.fromJson(Map<String, dynamic>.from(pool)),
          )
          .toList(growable: false),
      compatibilityMode: HardwareCompatibilityModeX.fromStorageKey(
        json['compatibility_mode'] as String?,
      ),
      connectionProtocol:
          (json['connection_protocol'] as String?)?.trim() ?? '',
      compatibleFamilies: rawFamilies
          .map((value) => value.toString().trim())
          .where((value) => value.isNotEmpty)
          .toList(growable: false),
      maxExpansionModules:
          (json['max_expansion_modules'] as num?)?.toInt() ?? 0,
      isActive: json['is_active'] as bool? ?? true,
      note: (json['note'] as String?)?.trim() ?? '',
      updatedAt:
          DateTime.tryParse(json['updated_at'] as String? ?? '') ??
          DateTime.now(),
      createdBy: (json['created_by'] as String?)?.trim(),
    );
  }
}
