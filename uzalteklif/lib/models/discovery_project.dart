enum DiscoveryPointType {
  aiActive,
  aiPassive,
  ao,
  di,
  doOutput,
  modbusRtu,
  modbusTcp,
  bacnetMstp,
  bacnetIp,
}

extension DiscoveryPointTypeX on DiscoveryPointType {
  String get storageKey => switch (this) {
    DiscoveryPointType.aiActive => 'ai_active',
    DiscoveryPointType.aiPassive => 'ai_passive',
    DiscoveryPointType.ao => 'ao',
    DiscoveryPointType.di => 'di',
    DiscoveryPointType.doOutput => 'do',
    DiscoveryPointType.modbusRtu => 'modbus_rtu',
    DiscoveryPointType.modbusTcp => 'modbus_tcp',
    DiscoveryPointType.bacnetMstp => 'bacnet_mstp',
    DiscoveryPointType.bacnetIp => 'bacnet_ip',
  };

  String get label => switch (this) {
    DiscoveryPointType.aiActive => 'AI-A',
    DiscoveryPointType.aiPassive => 'AI-P',
    DiscoveryPointType.ao => 'AO',
    DiscoveryPointType.di => 'DI',
    DiscoveryPointType.doOutput => 'DO',
    DiscoveryPointType.modbusRtu => 'Modbus RTU',
    DiscoveryPointType.modbusTcp => 'Modbus TCP',
    DiscoveryPointType.bacnetMstp => 'BACnet MSTP',
    DiscoveryPointType.bacnetIp => 'BACnet IP',
  };

  static DiscoveryPointType fromStorageKey(String? value) {
    return DiscoveryPointType.values.firstWhere(
      (type) => type.storageKey == value,
      orElse: () => DiscoveryPointType.di,
    );
  }
}

enum DiscoveryAnalogSignal { unspecified, voltage0To10, current4To20 }

extension DiscoveryAnalogSignalX on DiscoveryAnalogSignal {
  String get storageKey => switch (this) {
    DiscoveryAnalogSignal.unspecified => 'unspecified',
    DiscoveryAnalogSignal.voltage0To10 => '0_10v',
    DiscoveryAnalogSignal.current4To20 => '4_20ma',
  };

  String get label => switch (this) {
    DiscoveryAnalogSignal.unspecified => 'Belirtilmedi',
    DiscoveryAnalogSignal.voltage0To10 => '0–10 V',
    DiscoveryAnalogSignal.current4To20 => '4–20 mA',
  };

  static DiscoveryAnalogSignal fromStorageKey(String? value) {
    return switch (value) {
      '0_10v' => DiscoveryAnalogSignal.voltage0To10,
      '4_20ma' => DiscoveryAnalogSignal.current4To20,
      _ => DiscoveryAnalogSignal.unspecified,
    };
  }
}

class DiscoveryPoint {
  const DiscoveryPoint({
    required this.id,
    required this.name,
    required this.type,
    this.quantity = 1,
    this.analogSignal = DiscoveryAnalogSignal.unspecified,
  });

  final String id;
  final String name;
  final DiscoveryPointType type;
  final int quantity;
  final DiscoveryAnalogSignal analogSignal;

  DiscoveryPoint copyWith({
    String? id,
    String? name,
    DiscoveryPointType? type,
    int? quantity,
    DiscoveryAnalogSignal? analogSignal,
  }) {
    return DiscoveryPoint(
      id: id ?? this.id,
      name: name ?? this.name,
      type: type ?? this.type,
      quantity: quantity ?? this.quantity,
      analogSignal: analogSignal ?? this.analogSignal,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'type': type.storageKey,
    'quantity': quantity,
    'analog_signal': analogSignal.storageKey,
  };

  factory DiscoveryPoint.fromJson(Map<String, dynamic> json) {
    return DiscoveryPoint(
      id: json['id'] as String? ?? '',
      name: (json['name'] as String?)?.trim() ?? '',
      type: DiscoveryPointTypeX.fromStorageKey(json['type'] as String?),
      quantity: (json['quantity'] as num?)?.toInt() ?? 1,
      analogSignal: DiscoveryAnalogSignalX.fromStorageKey(
        json['analog_signal'] as String?,
      ),
    );
  }
}

class DiscoveryDevice {
  const DiscoveryDevice({
    required this.id,
    required this.templateKey,
    required this.name,
    required this.panelCode,
    required this.deviceCode,
    required this.points,
  });

  final String id;
  final String templateKey;
  final String name;
  final String panelCode;
  final String deviceCode;
  final List<DiscoveryPoint> points;

  int countFor(DiscoveryPointType type) => points
      .where((point) => point.type == type)
      .fold(0, (total, point) => total + point.quantity);

  int get totalPoints =>
      points.fold(0, (total, point) => total + point.quantity);

  DiscoveryDevice copyWith({
    String? id,
    String? templateKey,
    String? name,
    String? panelCode,
    String? deviceCode,
    List<DiscoveryPoint>? points,
  }) {
    return DiscoveryDevice(
      id: id ?? this.id,
      templateKey: templateKey ?? this.templateKey,
      name: name ?? this.name,
      panelCode: panelCode ?? this.panelCode,
      deviceCode: deviceCode ?? this.deviceCode,
      points: points ?? this.points,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'template_key': templateKey,
    'name': name,
    'panel_code': panelCode,
    'device_code': deviceCode,
    'points': points.map((point) => point.toJson()).toList(),
  };

  factory DiscoveryDevice.fromJson(Map<String, dynamic> json) {
    final rawPoints = json['points'] as List<dynamic>? ?? const [];
    return DiscoveryDevice(
      id: json['id'] as String? ?? '',
      templateKey: json['template_key'] as String? ?? '',
      name: (json['name'] as String?)?.trim() ?? '',
      panelCode: (json['panel_code'] as String?)?.trim() ?? '',
      deviceCode: (json['device_code'] as String?)?.trim() ?? '',
      points: rawPoints
          .whereType<Map>()
          .map(
            (point) =>
                DiscoveryPoint.fromJson(Map<String, dynamic>.from(point)),
          )
          .toList(growable: false),
    );
  }
}

enum DiscoveryPanelMode {
  automatic,
  controllerRequired,
  remoteAllowed,
  remoteOnly,
}

extension DiscoveryPanelModeX on DiscoveryPanelMode {
  String get storageKey => switch (this) {
    DiscoveryPanelMode.automatic => 'automatic',
    DiscoveryPanelMode.controllerRequired => 'controller_required',
    DiscoveryPanelMode.remoteAllowed => 'remote_allowed',
    DiscoveryPanelMode.remoteOnly => 'remote_only',
  };

  String get label => switch (this) {
    DiscoveryPanelMode.automatic => 'Otomatik karar ver',
    DiscoveryPanelMode.controllerRequired => 'Kontrolör zorunlu',
    DiscoveryPanelMode.remoteAllowed => 'Remote I/O kullanılabilir',
    DiscoveryPanelMode.remoteOnly => 'Yalnız Remote I/O',
  };

  static DiscoveryPanelMode fromStorageKey(String? value) {
    return switch (value) {
      'controller_required' => DiscoveryPanelMode.controllerRequired,
      'remote_allowed' => DiscoveryPanelMode.remoteAllowed,
      'remote_only' => DiscoveryPanelMode.remoteOnly,
      _ => DiscoveryPanelMode.automatic,
    };
  }
}

class DiscoveryPanelSettings {
  const DiscoveryPanelSettings({
    required this.panelCode,
    this.mode = DiscoveryPanelMode.automatic,
    this.parentPanelCode = '',
  });

  final String panelCode;
  final DiscoveryPanelMode mode;
  final String parentPanelCode;

  DiscoveryPanelSettings copyWith({
    String? panelCode,
    DiscoveryPanelMode? mode,
    String? parentPanelCode,
  }) {
    return DiscoveryPanelSettings(
      panelCode: panelCode ?? this.panelCode,
      mode: mode ?? this.mode,
      parentPanelCode: parentPanelCode ?? this.parentPanelCode,
    );
  }

  Map<String, dynamic> toJson() => {
    'panel_code': panelCode,
    'mode': mode.storageKey,
    'parent_panel_code': parentPanelCode,
  };

  factory DiscoveryPanelSettings.fromJson(Map<String, dynamic> json) {
    return DiscoveryPanelSettings(
      panelCode: (json['panel_code'] as String?)?.trim().toUpperCase() ?? '',
      mode: DiscoveryPanelModeX.fromStorageKey(json['mode'] as String?),
      parentPanelCode:
          (json['parent_panel_code'] as String?)?.trim().toUpperCase() ?? '',
    );
  }
}

class DiscoveryProject {
  const DiscoveryProject({
    required this.id,
    required this.projectName,
    required this.projectCode,
    required this.revision,
    required this.preparedBy,
    required this.devices,
    required this.createdAt,
    required this.updatedAt,
    this.panelSettings = const [],
    this.createdBy,
  });

  final String id;
  final String projectName;
  final String projectCode;
  final String revision;
  final String preparedBy;
  final List<DiscoveryDevice> devices;
  final DateTime createdAt;
  final DateTime updatedAt;
  final List<DiscoveryPanelSettings> panelSettings;
  final String? createdBy;

  int countFor(DiscoveryPointType type) =>
      devices.fold(0, (total, device) => total + device.countFor(type));

  int get totalPoints =>
      devices.fold(0, (total, device) => total + device.totalPoints);

  DiscoveryPanelSettings settingsForPanel(String panelCode) {
    final normalized = panelCode.trim().toUpperCase();
    for (final settings in panelSettings) {
      if (settings.panelCode.trim().toUpperCase() == normalized) {
        return settings;
      }
    }
    return DiscoveryPanelSettings(panelCode: normalized);
  }

  DiscoveryProject copyWith({
    String? id,
    String? projectName,
    String? projectCode,
    String? revision,
    String? preparedBy,
    List<DiscoveryDevice>? devices,
    DateTime? createdAt,
    DateTime? updatedAt,
    List<DiscoveryPanelSettings>? panelSettings,
    String? createdBy,
  }) {
    return DiscoveryProject(
      id: id ?? this.id,
      projectName: projectName ?? this.projectName,
      projectCode: projectCode ?? this.projectCode,
      revision: revision ?? this.revision,
      preparedBy: preparedBy ?? this.preparedBy,
      devices: devices ?? this.devices,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      panelSettings: panelSettings ?? this.panelSettings,
      createdBy: createdBy ?? this.createdBy,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'project_name': projectName,
    'project_code': projectCode,
    'revision': revision,
    'prepared_by': preparedBy,
    'devices': devices.map((device) => device.toJson()).toList(),
    'panel_settings': panelSettings
        .map((settings) => settings.toJson())
        .toList(),
    'created_at': createdAt.toIso8601String(),
    'updated_at': updatedAt.toIso8601String(),
    'created_by': createdBy,
  };

  factory DiscoveryProject.fromJson(Map<String, dynamic> json) {
    final rawDevices = json['devices'] as List<dynamic>? ?? const [];
    final rawPanelSettings =
        json['panel_settings'] as List<dynamic>? ?? const [];
    return DiscoveryProject(
      id: json['id'] as String? ?? '',
      projectName: (json['project_name'] as String?)?.trim() ?? '',
      projectCode: (json['project_code'] as String?)?.trim() ?? '',
      revision: (json['revision'] as String?)?.trim() ?? '00',
      preparedBy: (json['prepared_by'] as String?)?.trim() ?? '',
      devices: rawDevices
          .whereType<Map>()
          .map(
            (device) =>
                DiscoveryDevice.fromJson(Map<String, dynamic>.from(device)),
          )
          .toList(growable: false),
      createdAt:
          DateTime.tryParse(json['created_at'] as String? ?? '') ??
          DateTime.now(),
      updatedAt:
          DateTime.tryParse(json['updated_at'] as String? ?? '') ??
          DateTime.now(),
      panelSettings: rawPanelSettings
          .whereType<Map>()
          .map(
            (settings) => DiscoveryPanelSettings.fromJson(
              Map<String, dynamic>.from(settings),
            ),
          )
          .toList(growable: false),
      createdBy: (json['created_by'] as String?)?.trim(),
    );
  }
}
