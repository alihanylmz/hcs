class ServiceFormLinks {
  const ServiceFormLinks._();

  static const String baseUrl = String.fromEnvironment(
    'PUBLIC_SERVICE_FORM_BASE_URL',
    defaultValue: 'https://uzalteknikservis.com/is-takip',
  );

  static String formUrl(String formId) => '$baseUrl/#/service-form?id=$formId';

  static String customerMessage({
    required String customerName,
    required String ticketNo,
    required String templateName,
    required String formUrl,
  }) {
    return 'Sayın $customerName,\n\n'
        'İş No: $ticketNo - $templateName formunu doldurup imzalamanız gerekmektedir.\n\n'
        'Lütfen aşağıdaki bağlantıya tıklayınız:\n$formUrl\n\n'
        'Saygılarımızla.';
  }
}
