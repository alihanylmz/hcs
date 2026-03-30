import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:onesignal_flutter/onesignal_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:window_manager/window_manager.dart';

import 'config/app_config.dart';
import 'models/user_profile.dart';
import 'pages/login_page.dart';
import 'pages/ticket_detail_page.dart';
import 'pages/ticket_list_page.dart';
import 'services/windows_background_notification_service.dart';
import 'services/update_service.dart';
import 'services/user_service.dart';
import 'theme/app_theme.dart';

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  if (!kIsWeb && (Platform.isWindows || Platform.isLinux || Platform.isMacOS)) {
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

  if (!kIsWeb &&
      AppConfig.hasOneSignalConfig &&
      (Platform.isIOS || Platform.isAndroid)) {
    OneSignal.Debug.setLogLevel(OSLogLevel.verbose);
    OneSignal.initialize(AppConfig.oneSignalAppId);
    OneSignal.Notifications.requestPermission(true);

    OneSignal.Notifications.addClickListener((event) {
      try {
        final data = event.notification.additionalData;
        if (data != null && data.containsKey('ticket_id')) {
          final ticketId = data['ticket_id'].toString();
          navigatorKey.currentState?.push(
            MaterialPageRoute(
              builder: (context) => TicketDetailPage(ticketId: ticketId),
            ),
          );
        }
      } catch (e) {
        debugPrint('Bildirim tıklama hatası: $e');
      }
    });
  }

  try {
    await initializeDateFormatting('tr_TR', null);

    if (!AppConfig.hasSupabaseConfig) {
      throw Exception(
        'Eksik konfigürasyon: ${AppConfig.missingRequiredKeys.join(', ')}\n'
        'Uygulamayı --dart-define ile başlatın.',
      );
    }

    await Supabase.initialize(
      url: AppConfig.supabaseUrl,
      anonKey: AppConfig.supabaseAnonKey,
    );

    if (!kIsWeb && Platform.isWindows) {
      await WindowsBackgroundNotificationService.instance.initialize(
        onOpenTicket: (ticketId) async {
          final navigator = navigatorKey.currentState;
          if (navigator == null) {
            return;
          }

          navigator.push(
            MaterialPageRoute(
              builder: (context) => TicketDetailPage(ticketId: ticketId),
            ),
          );
        },
      );
    }

    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
      ),
    );

    runApp(const IsTakipApp());
  } catch (e) {
    runApp(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        home: Scaffold(
          body: Center(
            child: Text('Başlatma Hatası:\n$e', textAlign: TextAlign.center),
          ),
        ),
      ),
    );
  }
}

class IsTakipApp extends StatefulWidget {
  const IsTakipApp({super.key});

  static IsTakipAppState? of(BuildContext context) =>
      context.findAncestorStateOfType<IsTakipAppState>();

  @override
  State<IsTakipApp> createState() => IsTakipAppState();
}

class IsTakipAppState extends State<IsTakipApp> {
  ThemeMode _themeMode = ThemeMode.system;
  SharedPreferences? _prefs;

  Brightness get _systemBrightness =>
      WidgetsBinding.instance.platformDispatcher.platformBrightness;

  @override
  void initState() {
    super.initState();
    _loadTheme();
  }

  Future<void> _loadTheme() async {
    final prefs = await SharedPreferences.getInstance();
    final savedTheme = prefs.getString('theme_mode');

    if (!mounted) {
      _prefs = prefs;
      return;
    }

    setState(() {
      _prefs = prefs;
      if (savedTheme == 'light') {
        _themeMode = ThemeMode.light;
      } else if (savedTheme == 'dark') {
        _themeMode = ThemeMode.dark;
      } else {
        _themeMode = ThemeMode.system;
      }
    });
  }

  Future<void> toggleTheme() async {
    final nextMode = isDarkMode ? ThemeMode.light : ThemeMode.dark;

    setState(() {
      _themeMode = nextMode;
    });

    final prefs = _prefs ?? await SharedPreferences.getInstance();
    _prefs = prefs;

    await prefs.setString(
      'theme_mode',
      nextMode == ThemeMode.dark ? 'dark' : 'light',
    );
  }

  bool get isDarkMode {
    if (_themeMode == ThemeMode.system) {
      return _systemBrightness == Brightness.dark;
    }
    return _themeMode == ThemeMode.dark;
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: navigatorKey,
      title: 'İş Takip',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: _themeMode,
      themeAnimationDuration: Duration.zero,
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [Locale('tr', 'TR')],
      locale: const Locale('tr', 'TR'),
      home: const AuthGate(),
    );
  }
}

class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  bool _isHandlingPendingSession = false;
  final UserService _userService = UserService();
  Future<UserProfile?>? _profileFuture;
  String? _profileUserId;

  @override
  void initState() {
    super.initState();
    if (AppConfig.shouldRunStartupChecks) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        UpdateService().checkVersion(context);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<AuthState>(
      stream: Supabase.instance.client.auth.onAuthStateChange,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return const Scaffold(
            body: Center(
              child: Text('Oturum durumu okunurken bir hata oluştu.'),
            ),
          );
        }

        final session =
            snapshot.data?.session ??
            Supabase.instance.client.auth.currentSession;

        if (session == null) {
          _profileFuture = null;
          _profileUserId = null;
          return const LoginPage();
        }

        if (_profileFuture == null || _profileUserId != session.user.id) {
          _profileUserId = session.user.id;
          _profileFuture = _userService.getCurrentUserProfile();
        }

        return FutureBuilder<UserProfile?>(
          future: _profileFuture,
          builder: (context, userSnapshot) {
            if (userSnapshot.connectionState == ConnectionState.waiting) {
              return const Scaffold(
                body: Center(child: CircularProgressIndicator()),
              );
            }

            if (userSnapshot.hasError) {
              return const Scaffold(
                body: Center(
                  child: Text('Kullanıcı profili yüklenirken bir hata oluştu.'),
                ),
              );
            }

            final userProfile = userSnapshot.data;

            if (userProfile == null) {
              return const Scaffold(
                body: Center(
                  child: Text(
                    'Profiliniz bulunamadı.\nYöneticinizle görüşün.',
                    textAlign: TextAlign.center,
                  ),
                ),
              );
            }

            if (userProfile.isPending) {
              if (!_isHandlingPendingSession) {
                _isHandlingPendingSession = true;
                WidgetsBinding.instance.addPostFrameCallback((_) async {
                  await Supabase.instance.client.auth.signOut();
                  if (mounted) {
                    setState(() {
                      _isHandlingPendingSession = false;
                    });
                  }
                });
              }

              return const Scaffold(
                body: Center(
                  child: Padding(
                    padding: EdgeInsets.all(24),
                    child: Text(
                      'Hesabiniz kayit bekliyor.\nYonetici onayi tamamlanmadan giris yapamazsiniz.',
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
              );
            }

            return const TicketListPage();
          },
        );
      },
    );
  }
}
