class TicketPart {
  final int id;
  final String ticketId; // UUID olduğu için String
  final int inventoryId;
  final int quantity;
  final DateTime createdAt;
  
  // Join ile gelen veriler (Opsiyonel)
  final String? inventoryName;
  final String? category;

  TicketPart({
    required this.id,
    required this.ticketId,
    required this.inventoryId,
    required this.quantity,
    required this.createdAt,
    this.inventoryName,
    this.category,
  });

  factory TicketPart.fromJson(Map<String, dynamic> json) {
    // Join edilmiş inventory verisi varsa alalım
    final inv = json['inventory'] as Map<String, dynamic>?;

    return TicketPart(
      id: json['id'] as int,
      ticketId: json['ticket_id'] as String, // UUID
      inventoryId: json['inventory_id'] as int,
      quantity: json['quantity'] as int,
      createdAt: DateTime.parse(json['created_at'] as String),
      inventoryName: inv?['name'] as String?,
      category: inv?['category'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'ticket_id': ticketId,
      'inventory_id': inventoryId,
      'quantity': quantity,
    };
  }
}
