typedef NotificationPayloadOpener =
    Future<void> Function(Map<String, dynamic>? data);

Future<void> initializeDesktopWindow() async {}

void initializeMobilePush(NotificationPayloadOpener openPayload) {}

Future<void> initializeWindowsBackgroundNotifications(
  NotificationPayloadOpener openPayload,
) async {}
