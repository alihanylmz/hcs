class FaultRecordStatus {
  const FaultRecordStatus._();

  static const String open = 'open';
  static const String monitoring = 'monitoring';
  static const String resolved = 'resolved';
  static const String closed = 'closed';

  static String labelOf(String status) {
    switch (status) {
      case monitoring:
        return 'Izlemede';
      case resolved:
        return 'Cozuldu';
      case closed:
        return 'Kapali';
      case open:
      default:
        return 'Acik';
    }
  }
}

class FaultRecord {
  const FaultRecord({
    required this.id,
    required this.faultCode,
    required this.title,
    required this.body,
    required this.status,
    this.deviceBrand,
    this.deviceModel,
    this.linkedTicketId,
    this.assigneeId,
    this.assigneeName,
    this.createdById,
    this.createdByName,
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final String faultCode;
  final String title;
  final String body;
  final String status;
  final String? deviceBrand;
  final String? deviceModel;
  final String? linkedTicketId;
  final String? assigneeId;
  final String? assigneeName;
  final String? createdById;
  final String? createdByName;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  factory FaultRecord.fromJson(Map<String, dynamic> json) {
    return FaultRecord(
      id: json['id']?.toString() ?? '',
      faultCode: _nullableText(json['fault_code']) ?? '-',
      title: _nullableText(json['title']) ?? 'Ariza kaydi',
      body: _nullableText(json['body']) ?? 'Aciklama girilmedi.',
      status: _nullableText(json['status']) ?? FaultRecordStatus.open,
      deviceBrand: _nullableText(json['device_brand']),
      deviceModel: _nullableText(json['device_model']),
      linkedTicketId: _nullableText(json['linked_ticket_id']),
      assigneeId: _nullableText(json['assignee_id']),
      assigneeName: _nullableText(json['assignee_name']),
      createdById: _nullableText(json['created_by']),
      createdByName: _nullableText(json['created_by_name']),
      createdAt: _parseDate(json['created_at']),
      updatedAt: _parseDate(json['updated_at']),
    );
  }

  bool get hasLinkedTicket => (linkedTicketId ?? '').trim().isNotEmpty;

  String get deviceLabel {
    final brand = (deviceBrand ?? '').trim();
    final model = (deviceModel ?? '').trim();
    if (brand.isEmpty && model.isEmpty) {
      return 'Cihaz bilgisi yok';
    }
    if (brand.isEmpty) return model;
    if (model.isEmpty) return brand;
    return '$brand / $model';
  }

  String get statusLabel => FaultRecordStatus.labelOf(status);

  static String? _nullableText(dynamic value) {
    final text = value?.toString().trim() ?? '';
    return text.isEmpty ? null : text;
  }

  static DateTime? _parseDate(dynamic value) {
    final raw = value?.toString().trim() ?? '';
    if (raw.isEmpty) return null;
    return DateTime.tryParse(raw);
  }
}

class FaultTicketLinkSummary {
  const FaultTicketLinkSummary({
    required this.ticketId,
    required this.faultCount,
    this.latestFaultId,
    this.latestFaultAt,
  });

  final String ticketId;
  final int faultCount;
  final String? latestFaultId;
  final DateTime? latestFaultAt;

  bool get hasLinkedFaults => faultCount > 0;
}
