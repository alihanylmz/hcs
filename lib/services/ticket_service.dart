import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';

import '../core/logging/app_logger.dart';
import '../features/tickets/application/ticket_notification_coordinator.dart';
import '../features/tickets/data/ticket_repository.dart';

class TicketService {
  factory TicketService({
    TicketRepository? repository,
    TicketNotificationCoordinator? notificationCoordinator,
  }) {
    final repo = repository ?? TicketRepository();
    return TicketService._(
      repository: repo,
      notificationCoordinator:
          notificationCoordinator ??
          TicketNotificationCoordinator(repository: repo),
    );
  }

  TicketService._({
    required TicketRepository repository,
    required TicketNotificationCoordinator notificationCoordinator,
  }) : _repository = repository,
       _notificationCoordinator = notificationCoordinator;

  static const AppLogger _logger = AppLogger('TicketService');
  final TicketRepository _repository;
  final TicketNotificationCoordinator _notificationCoordinator;

  Future<Map<String, dynamic>?> getTicket(String ticketId) {
    return _repository.getTicket(ticketId);
  }

  Future<void> updateTicket(
    String ticketId,
    Map<String, dynamic> payload,
  ) async {
    final oldTicket = await _repository.getTicket(ticketId);
    await _repository.updateTicket(ticketId, payload);

    if (oldTicket != null) {
      _notificationCoordinator
          .handleTicketUpdated(
            oldTicket: oldTicket,
            payload: payload,
            ticketId: ticketId,
          )
          .catchError((Object error, StackTrace stackTrace) {
            _logger.error(
              'ticket_update_notification_failed',
              data: {'ticketId': ticketId},
              error: error,
              stackTrace: stackTrace,
            );
          });
    }
  }

  Future<List<Map<String, dynamic>>> getNotes(String ticketId) {
    return _repository.getNotes(ticketId);
  }

  Future<void> addNote(
    String ticketId,
    String note, [
    List<String>? imageUrls,
  ]) async {
    await _repository.addNote(
      ticketId: ticketId,
      note: note,
      noteType: 'service_note',
      imageUrls: imageUrls,
    );

    _notificationCoordinator
        .handleNoteAdded(ticketId: ticketId, isPartnerNote: false)
        .catchError((Object error, StackTrace stackTrace) {
          _logger.error(
            'service_note_notification_failed',
            data: {'ticketId': ticketId},
            error: error,
            stackTrace: stackTrace,
          );
        });
  }

  Future<void> addPartnerNote(
    String ticketId,
    String note, [
    List<String>? imageUrls,
  ]) async {
    await _repository.addNote(
      ticketId: ticketId,
      note: note,
      noteType: 'partner_note',
      imageUrls: imageUrls,
    );

    _notificationCoordinator
        .handleNoteAdded(ticketId: ticketId, isPartnerNote: true)
        .catchError((Object error, StackTrace stackTrace) {
          _logger.error(
            'partner_note_notification_failed',
            data: {'ticketId': ticketId},
            error: error,
            stackTrace: stackTrace,
          );
        });
  }

  Future<void> updateNote(int noteId, String note) {
    return _repository.updateNote(noteId, note);
  }

  Future<Uint8List?> compressImage(Uint8List bytes) {
    return _repository.compressImage(bytes);
  }

  Future<List<String>> uploadImages(String ticketId, List<PlatformFile> files) {
    return _repository.uploadImages(ticketId, files);
  }

  Future<String?> uploadFile(String ticketId, PlatformFile file) {
    return _repository.uploadFile(ticketId, file);
  }
}
