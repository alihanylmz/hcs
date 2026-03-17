class TicketStatusDefinition {
  const TicketStatusDefinition({
    required this.key,
    required this.label,
    required this.description,
    required this.order,
    this.isTerminal = false,
  });

  final String key;
  final String label;
  final String description;
  final int order;
  final bool isTerminal;
}

class TicketStatus {
  const TicketStatus._();

  static const String draft = 'draft';
  static const String open = 'open';
  static const String inProgress = 'in_progress';
  static const String panelDoneStock = 'panel_done_stock';
  static const String panelDoneSent = 'panel_done_sent';
  static const String done = 'done';
  static const String archived = 'archived';
  static const String cancelled = 'cancelled';

  static const List<TicketStatusDefinition> lifecycle = [
    TicketStatusDefinition(
      key: draft,
      label: 'Taslak',
      description:
          'Yonetici tarafinda hazirlanan ancak henuz yayinlanmayan is.',
      order: 0,
    ),
    TicketStatusDefinition(
      key: open,
      label: 'Acik',
      description: 'Aktif olarak bekleyen veya planlanan is.',
      order: 1,
    ),
    TicketStatusDefinition(
      key: inProgress,
      label: 'Serviste',
      description: 'Saha ya da servis ekibi tarafindan uzerinde calisilan is.',
      order: 2,
    ),
    TicketStatusDefinition(
      key: panelDoneStock,
      label: 'Panosu Yapildi Stokta',
      description: 'Panel hazirlandi ve stokta bekliyor.',
      order: 3,
    ),
    TicketStatusDefinition(
      key: panelDoneSent,
      label: 'Panosu Yapildi Gonderildi',
      description: 'Panel hazirlandi ve sevk edildi.',
      order: 4,
    ),
    TicketStatusDefinition(
      key: done,
      label: 'Is Tamamlandi',
      description: 'Is emri operasyonel olarak tamamlandi.',
      order: 5,
      isTerminal: true,
    ),
    TicketStatusDefinition(
      key: archived,
      label: 'Arsivde',
      description: 'Tamamlanan isin okunur arsiv kaydi.',
      order: 6,
      isTerminal: true,
    ),
    TicketStatusDefinition(
      key: cancelled,
      label: 'Iptal',
      description: 'Operasyonel akistan cikarilan veya kapatilan is.',
      order: 7,
      isTerminal: true,
    ),
  ];

  static const Set<String> activeStatuses = {
    open,
    inProgress,
    panelDoneStock,
    panelDoneSent,
  };

  static const Set<String> partnerNotificationStatuses = {
    panelDoneStock,
    panelDoneSent,
    done,
  };

  static const Map<String, Set<String>> allowedTransitions = {
    draft: {open, cancelled},
    open: {inProgress, panelDoneStock, panelDoneSent, done, cancelled},
    inProgress: {panelDoneStock, panelDoneSent, done, cancelled},
    panelDoneStock: {panelDoneSent, done, archived},
    panelDoneSent: {done, archived},
    done: {archived},
    archived: <String>{},
    cancelled: <String>{},
  };

  static Map<String, String> get labels => {
    for (final status in lifecycle) status.key: status.label,
  };

  static List<String> get orderedKeys => [
    for (final status in lifecycle) status.key,
  ];

  static List<String> get terminalStatuses => [
    for (final status in lifecycle)
      if (status.isTerminal) status.key,
  ];

  static String labelOf(String status) {
    return labels[status] ?? status;
  }

  static String descriptionOf(String status) {
    for (final definition in lifecycle) {
      if (definition.key == status) {
        return definition.description;
      }
    }
    return status;
  }

  static bool isValid(String status) {
    return labels.containsKey(status);
  }

  static bool canTransition(String from, String to) {
    final validTargets = allowedTransitions[from];
    if (validTargets == null) {
      return false;
    }
    return validTargets.contains(to);
  }
}
