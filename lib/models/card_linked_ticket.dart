class CardLinkedTicket {
  const CardLinkedTicket({
    required this.id,
    required this.jobCode,
    required this.title,
    this.status,
  });

  final String id;
  final String jobCode;
  final String title;
  final String? status;

  String get displayLabel {
    if (jobCode.trim().isEmpty) {
      return title.trim().isEmpty ? id : title;
    }
    if (title.trim().isEmpty) {
      return jobCode;
    }
    return '$jobCode - $title';
  }

  factory CardLinkedTicket.fromJson(Map<String, dynamic> json) {
    return CardLinkedTicket(
      id: json['id'].toString(),
      jobCode: (json['job_code'] as String? ?? '').trim(),
      title: (json['title'] as String? ?? '').trim(),
      status: json['status']?.toString(),
    );
  }
}
