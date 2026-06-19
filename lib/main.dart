import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'config/app_config.dart';
import 'models/user_profile.dart';
import 'pages/login_page.dart';
import 'pages/ticket_list_page.dart';
import 'platform/platform_startup_stub.dart'
    if (dart.library.io) 'platform/platform_startup_io.dart'
    as platform_startup;
import 'services/notification_navigation_service.dart';
import 'services/update_service.dart';
import 'services/user_service.dart';
import 'theme/app_theme.dart';

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

Future<void> _openNotificationPayload(Map<String, dynamic>? data) async {
  final navigator = navigatorKey.currentState;
  if (navigator == null) {
    return;
  }

  await NotificationNavigationService.openFromData(navigator, data);
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await platform_startup.initializeDesktopWindow();

  try {
    await initializeDateFormatting('tr_TR', null);

    if (!AppConfig.hasSupabaseConfig) {
      throw Exception(
        'Eksik konfigurasyon: ${AppConfig.missingRequiredKeys.join(', ')}\n'
        'Uygulamayi --dart-define ile baslatin.',
      );
    }

    await Supabase.initialize(
      url: AppConfig.supabaseUrl,
      anonKey: AppConfig.supabaseAnonKey,
    );

    platform_startup.initializeMobilePush(_openNotificationPayload);

    await platform_startup.initializeWindowsBackgroundNotifications(
      _openNotificationPayload,
    );

    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
      ),
    );

    runApp(const IsTakipApp());
  } catch (error) {
    runApp(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        home: Scaffold(
          body: Center(
            child: Text(
              'Baslatma Hatasi:\n$error',
              textAlign: TextAlign.center,
            ),
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
      title: 'Is Takip',
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
              child: Text('Oturum durumu okunurken bir hata olustu.'),
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
                  child: Text('Kullanici profili yuklenirken bir hata olustu.'),
                ),
              );
            }

            final userProfile = userSnapshot.data;

            if (userProfile == null) {
              return const Scaffold(
                body: Center(
                  child: Text(
                    'Profiliniz bulunamadi.\nYoneticinizle gorusun.',
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
