import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:local_notifier/local_notifier.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:tray_manager/tray_manager.dart';
import 'package:window_manager/window_manager.dart';

import '../core/logging/app_logger.dart';
import '../models/notification_item.dart';
import 'notification_service_kanban.dart';

typedef OpenTicketCallback = Future<void> Function(String ticketId);

class WindowsBackgroundNotificationService with WindowListener, TrayListener {
  WindowsBackgroundNotificationService._();

  static final WindowsBackgroundNotificationService instance =
      WindowsBackgroundNotificationService._();

  static const AppLogger _logger = AppLogger(
    'WindowsBackgroundNotificationService',
  );

  final NotificationServiceKanban _notificationService =
      NotificationServiceKanban();

  StreamSubscription<AuthState>? _authSubscription;
  RealtimeChannel? _notificationChannel;

  OpenTicketCallback? _onOpenTicket;
  String? _subscribedUserId;
  bool _initialized = false;
  bool _isQuitting = false;
  bool _backgroundHintShown = false;

  bool get _isSupported => !kIsWeb && Platform.isWindows;

  Future<void> initialize({required OpenTicketCallback onOpenTicket}) async {
    if (_initialized || !_isSupported) {
      return;
    }

    _onOpenTicket = onOpenTicket;

    await localNotifier.setup(
      appName: 'istakip_app',
      shortcutPolicy: ShortcutPolicy.requireCreate,
    );

    windowManager.addListener(this);
    await windowManager.setPreventClose(true);

    trayManager.addListener(this);
    await _initializeTray();

    _authSubscription = Supabase.instance.client.auth.onAuthStateChange.listen((
      state,
    ) {
      unawaited(_handleSessionChanged(state.session));
    });

    await _handleSessionChanged(Supabase.instance.client.auth.currentSession);
    _initialized = true;
  }

  Future<void> _initializeTray() async {
    await trayManager.setIcon('windows/runner/resources/app_icon.ico');
    await trayManager.setToolTip('Is Takip');
    await trayManager.setContextMenu(
      Menu(
        items: [
          MenuItem(key: 'show_window', label: 'Pencereyi Ac'),
          MenuItem.separator(),
          MenuItem(key: 'exit_app', label: 'Cikis'),
        ],
      ),
    );
  }

  Future<void> _handleSessionChanged(Session? session) async {
    final nextUserId = session?.user.id;
    if (nextUserId == _subscribedUserId) {
      return;
    }

    await _unsubscribeFromNotifications();

    if (nextUserId == null) {
      return;
    }

    try {
      _notificationChannel = _notificationService.subscribeToNotifications(
        _onNewNotification,
      );
      _subscribedUserId = nextUserId;
    } catch (error, stackTrace) {
      _logger.error(
        'subscribe_to_windows_notifications_failed',
        data: {'userId': nextUserId},
        error: error,
        stackTrace: stackTrace,
      );
    }
  }

  Future<void> _unsubscribeFromNotifications() async {
    final channel = _notificationChannel;
    _notificationChannel = null;
    _subscribedUserId = null;

    if (channel == null) {
      return;
    }

    try {
      await Supabase.instance.client.removeChannel(channel);
    } catch (error, stackTrace) {
      _logger.error(
        'unsubscribe_from_windows_notifications_failed',
        error: error,
        stackTrace: stackTrace,
      );
    }
  }

  void _onNewNotification(NotificationItem notification) {
    unawaited(_showToastForNotification(notification));
  }

  Future<void> _showToastForNotification(NotificationItem notification) async {
    if (!await _shouldShowToast()) {
      return;
    }

    try {
      final localNotification = LocalNotification(
        title: notification.title,
        body: notification.message,
      );

      localNotification.onClick = () {
        final ticketId = notification.data?['ticket_id']?.toString();
        unawaited(_restoreWindow(ticketId: ticketId));
      };

      await localNotification.show();
    } catch (error, stackTrace) {
      _logger.error(
        'show_windows_toast_failed',
        data: {'notificationId': notification.id},
        error: error,
        stackTrace: stackTrace,
      );
    }
  }

  Future<bool> _shouldShowToast() async {
    try {
      final isVisible = await windowManager.isVisible();
      final isMinimized = await windowManager.isMinimized();
      final isFocused = await windowManager.isFocused();
      return !isVisible || isMinimized || !isFocused;
    } catch (_) {
      return true;
    }
  }

  Future<void> _restoreWindow({String? ticketId}) async {
    await windowManager.show();
    await windowManager.restore();
    await windowManager.focus();

    if (ticketId != null && ticketId.isNotEmpty && _onOpenTicket != null) {
      await _onOpenTicket!(ticketId);
    }
  }

  Future<void> _hideToTray() async {
    await windowManager.hide();

    if (_backgroundHintShown) {
      return;
    }

    _backgroundHintShown = true;

    try {
      final notification = LocalNotification(
        title: 'Is Takip arka planda calisiyor',
        body: 'Yeni bildirimler icin uygulama system trayde acik kalacak.',
      );
      notification.onClick = () {
        unawaited(_restoreWindow());
      };
      await notification.show();
    } catch (error, stackTrace) {
      _logger.error(
        'show_background_hint_failed',
        error: error,
        stackTrace: stackTrace,
      );
    }
  }

  Future<void> exitApplication() async {
    if (_isQuitting) {
      return;
    }

    _isQuitting = true;

    await _unsubscribeFromNotifications();
    await _authSubscription?.cancel();
    _authSubscription = null;

    trayManager.removeListener(this);
    windowManager.removeListener(this);

    try {
      await trayManager.destroy();
    } catch (_) {}

    await windowManager.setPreventClose(false);
    await windowManager.close();
  }

  @override
  void onWindowClose() {
    if (_isQuitting) {
      return;
    }

    unawaited(_hideToTray());
  }

  @override
  void onTrayIconMouseDown() {
    unawaited(_restoreWindow());
  }

  @override
  void onTrayIconRightMouseDown() {
    unawaited(trayManager.popUpContextMenu());
  }

  @override
  void onTrayMenuItemClick(MenuItem menuItem) {
    switch (menuItem.key) {
      case 'show_window':
        unawaited(_restoreWindow());
        break;
      case 'exit_app':
        unawaited(exitApplication());
        break;
    }
  }
}
