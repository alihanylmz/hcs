// lib/models/service_form.dart
// Servis Öncesi Onay Formu - Model Sınıfları

/// Form şablonundaki tek bir onay maddesi
class ServiceFormCheckbox {
  final String label;
  final bool required;

  const ServiceFormCheckbox({required this.label, this.required = true});

  factory ServiceFormCheckbox.fromJson(Map<String, dynamic> json) {
    return ServiceFormCheckbox(
      label: json['label'] as String? ?? '',
      required: json['required'] as bool? ?? true,
    );
  }

  Map<String, dynamic> toJson() => {
        'label': label,
        'required': required,
      };
}

/// Yönetici tarafından oluşturulan form şablonu (Jetfan, Nem Alma, AHU vb.)
class ServiceFormTemplate {
  final String id;
  final String name;
  final String? description;
  final String contentText;
  final List<ServiceFormCheckbox> checkboxes;
  final bool isActive;
  final String? createdBy;
  final DateTime createdAt;

  const ServiceFormTemplate({
    required this.id,
    required this.name,
    this.description,
    required this.contentText,
    required this.checkboxes,
    this.isActive = true,
    this.createdBy,
    required this.createdAt,
  });

  factory ServiceFormTemplate.fromJson(Map<String, dynamic> json) {
    final rawCheckboxes = json['checkboxes'];
    List<ServiceFormCheckbox> checkboxes = [];
    if (rawCheckboxes is List) {
      checkboxes = rawCheckboxes
          .whereType<Map<String, dynamic>>()
          .map((e) => ServiceFormCheckbox.fromJson(e))
          .toList();
    }

    return ServiceFormTemplate(
      id: json['id'] as String,
      name: json['name'] as String,
      description: json['description'] as String?,
      contentText: json['content_text'] as String? ?? '',
      checkboxes: checkboxes,
      isActive: json['is_active'] as bool? ?? true,
      createdBy: json['created_by'] as String?,
      createdAt: DateTime.tryParse(json['created_at'] as String? ?? '') ??
          DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() => {
        'name': name,
        'description': description,
        'content_text': contentText,
        'checkboxes': checkboxes.map((e) => e.toJson()).toList(),
        'is_active': isActive,
      };
}

/// Bir iş emrine bağlı gönderilen spesifik bir form (1 ticket → N form)
class TicketServiceForm {
  final String id;
  final int ticketId;
  final String templateId;
  final String status; // 'pending' | 'signed' | 'cancelled'
  final String? customerName;
  final String? signatureData; // Base64 PNG
  final List<int> checkedItems; // İşaretlenen maddelerin index listesi
  final String? customerIp;
  final DateTime? signedAt;
  final String? createdBy;
  final DateTime createdAt;
  final DateTime? cancelledAt;
  final String? cancelReason;

  // İlişkili şablon (JOIN ile çekilirse dolu olur)
  final ServiceFormTemplate? template;

  const TicketServiceForm({
    required this.id,
    required this.ticketId,
    required this.templateId,
    required this.status,
    this.customerName,
    this.signatureData,
    this.checkedItems = const [],
    this.customerIp,
    this.signedAt,
    this.createdBy,
    required this.createdAt,
    this.cancelledAt,
    this.cancelReason,
    this.template,
  });

  bool get isPending => status == 'pending';
  bool get isSigned => status == 'signed';
  bool get isCancelled => status == 'cancelled';

  factory TicketServiceForm.fromJson(Map<String, dynamic> json) {
    final rawChecked = json['checked_items'];
    List<int> checked = [];
    if (rawChecked is List) {
      checked = rawChecked.map((e) => (e as num).toInt()).toList();
    }

    ServiceFormTemplate? template;
    if (json['service_form_templates'] is Map<String, dynamic>) {
      template = ServiceFormTemplate.fromJson(
        json['service_form_templates'] as Map<String, dynamic>,
      );
    }

    return TicketServiceForm(
      id: json['id'] as String,
      ticketId: (json['ticket_id'] as num).toInt(),
      templateId: json['template_id'] as String,
      status: json['status'] as String? ?? 'pending',
      customerName: json['customer_name'] as String?,
      signatureData: json['signature_data'] as String?,
      checkedItems: checked,
      customerIp: json['customer_ip'] as String?,
      signedAt: json['signed_at'] != null
          ? DateTime.tryParse(json['signed_at'] as String)
          : null,
      createdBy: json['created_by'] as String?,
      createdAt:
          DateTime.tryParse(json['created_at'] as String? ?? '') ??
              DateTime.now(),
      cancelledAt: json['cancelled_at'] != null
          ? DateTime.tryParse(json['cancelled_at'] as String)
          : null,
      cancelReason: json['cancel_reason'] as String?,
      template: template,
    );
  }
}
