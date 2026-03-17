import '../../../core/logging/app_logger.dart';
import '../../../models/ticket_status.dart';
import '../../../services/notification_service.dart';
import '../../../services/user_service.dart';
import '../data/ticket_repository.dart';

class TicketNotificationCoordinator {
  TicketNotificationCoordinator({
    TicketRepository? repository,
    NotificationService? notificationService,
    UserService? userService,
  }) : _repository = repository ?? TicketRepository(),
       _notificationService = notificationService ?? NotificationService(),
       _userService = userService ?? UserService();

  static const AppLogger _logger = AppLogger('TicketNotificationCoordinator');
  final TicketRepository _repository;
  final NotificationService _notificationService;
  final UserService _userService;

  Future<void> handleTicketUpdated({
    required Map<String, dynamic> oldTicket,
    required Map<String, dynamic> payload,
    required String ticketId,
  }) async {
    final ticketTitle = oldTicket['title'] as String? ?? 'Is Emri';
    final jobCode = oldTicket['job_code'] as String?;
    final currentUser = await _userService.getCurrentUserProfile();
    final userName = currentUser?.fullName ?? 'Kullanici';

    if (payload.containsKey('status')) {
      final oldStatus = oldTicket['status'] as String? ?? TicketStatus.open;
      final newStatus = payload['status'] as String?;

      if (newStatus != null && oldStatus != newStatus) {
        if (oldStatus == TicketStatus.draft &&
            TicketStatus.activeStatuses.contains(newStatus)) {
          await _notificationService.notifyTicketCreated(
            ticketId: ticketId,
            ticketTitle: ticketTitle,
            jobCode: jobCode,
            createdBy: userName,
          );
        } else {
          await _notificationService.notifyTicketStatusChanged(
            ticketId: ticketId,
            ticketTitle: ticketTitle,
            oldStatus: oldStatus,
            newStatus: newStatus,
            changedBy: userName,
            jobCode: jobCode,
          );
        }

        final partnerId = oldTicket['partner_id'] as int?;
        if (partnerId != null &&
            TicketStatus.partnerNotificationStatuses.contains(newStatus)) {
          _logger.info(
            'partner_notification_triggered',
            data: {
              'partnerId': partnerId,
              'newStatus': newStatus,
              'ticketId': ticketId,
            },
          );
        }
      }
    }

    if (payload.containsKey('priority')) {
      final oldPriority = oldTicket['priority'] as String? ?? 'normal';
      final newPriority = payload['priority'] as String?;
      if (newPriority != null && oldPriority != newPriority) {
        await _notificationService.notifyPriorityChanged(
          ticketId: ticketId,
          ticketTitle: ticketTitle,
          oldPriority: oldPriority,
          newPriority: newPriority,
          jobCode: jobCode,
        );
      }
    }
  }

  Future<void> handleNoteAdded({
    required String ticketId,
    required bool isPartnerNote,
  }) async {
    try {
      final ticket = await _repository.getTicket(ticketId);
      if (ticket == null) return;

      final ticketTitle = ticket['title'] as String? ?? 'Is Emri';
      final jobCode = ticket['job_code'] as String?;
      final currentUser = await _userService.getCurrentUserProfile();
      final userName = currentUser?.fullName ?? 'Kullanici';

      if (isPartnerNote) {
        await _notificationService.notifyPartnerNoteAdded(
          ticketId: ticketId,
          ticketTitle: ticketTitle,
          noteAuthor: userName,
          jobCode: jobCode,
        );
        return;
      }

      await _notificationService.notifyNoteAdded(
        ticketId: ticketId,
        ticketTitle: ticketTitle,
        noteAuthor: userName,
        jobCode: jobCode,
      );
    } catch (error, stackTrace) {
      _logger.error(
        'note_notification_failed',
        data: {'ticketId': ticketId, 'isPartnerNote': isPartnerNote},
        error: error,
        stackTrace: stackTrace,
      );
    }
  }
}
