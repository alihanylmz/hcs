import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:onesignal_flutter/onesignal_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:window_manager/window_manager.dart';

import '../config/app_config.dart';
import '../services/notification_service_kanban.dart';
import '../services/windows_background_notification_service.dart';

typedef NotificationPayloadOpener =
    Future<void> Function(Map<String, dynamic>? data);

bool get _supportsMobilePush =>
    !kIsWeb &&
    AppConfig.hasOneSignalConfig &&
    (Platform.isIOS || Platform.isAndroid);

Future<void> initializeDesktopWindow() async {
  if (kIsWeb || !(Platform.isWindows || Platform.isLinux || Platform.isMacOS)) {
    return;
  }

  await windowManager.ensureInitialized();
  const windowOptions = WindowOptions(
    size: Size(1280, 720),
    minimumSize: Size(800, 600),
    center: true,
    backgroundColor: Colors.transparent,
    skipTaskbar: false,
    titleBarStyle: TitleBarStyle.normal,
  );
  windowManager.waitUntilReadyToShow(windowOptions, () async {
    await windowManager.show();
    await windowManager.focus();
  });
}

void initializeMobilePush(NotificationPayloadOpener openPayload) {
  if (!_supportsMobilePush) {
    return;
  }

  OneSignal.Debug.setLogLevel(OSLogLevel.verbose);
  OneSignal.initialize(AppConfig.oneSignalAppId);
  OneSignal.Notifications.requestPermission(true);
  _configureOneSignalBindings(openPayload);
}

Future<void> initializeWindowsBackgroundNotifications(
  NotificationPayloadOpener openPayload,
) async {
  if (kIsWeb || !Platform.isWindows) {
    return;
  }

  await WindowsBackgroundNotificationService.instance.initialize(
    onOpenNotification: (data) async {
      await openPayload(data);
    },
  );
}

Future<void> _syncOneSignalSession() async {
  if (!_supportsMobilePush) {
    return;
  }

  final userId = Supabase.instance.client.auth.currentUser?.id;

  try {
    if (userId == null || userId.isEmpty) {
      await OneSignal.logout();
    } else {
      await OneSignal.login(userId);
    }
  } catch (error) {
    debugPrint('OneSignal session sync failed: $error');
  }
}

void _configureOneSignalBindings(NotificationPayloadOpener openPayload) {
  if (!_supportsMobilePush) {
    return;
  }

  final tokenService = NotificationServiceKanban();

  OneSignal.Notifications.addClickListener((event) {
    try {
      final rawData = event.notification.additionalData;
      final data =
          rawData is Map ? Map<String, dynamic>.from(rawData as Map) : null;
      unawaited(openPayload(data));
    } catch (error) {
      debugPrint('Bildirim tiklama hatasi: $error');
    }
  });

  OneSignal.User.pushSubscription.addObserver((state) {
    final playerId = state.current.id;
    if (playerId == null || playerId.trim().isEmpty) {
      return;
    }

    unawaited(
      tokenService.savePlayerID(
        playerId,
        Platform.isAndroid ? 'android' : 'ios',
      ),
    );
  });

  Supabase.instance.client.auth.onAuthStateChange.listen((_) {
    unawaited(_syncOneSignalSession());
  });

  unawaited(_syncOneSignalSession());
}
