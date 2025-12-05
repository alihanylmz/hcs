import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:onesignal_flutter/onesignal_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'pages/login_page.dart';
import 'pages/ticket_list_page.dart';
import 'pages/dashboard_page.dart';
import 'pages/ticket_detail_page.dart';
import 'services/user_service.dart';
import 'services/update_service.dart';
import 'theme/app_theme.dart';
import 'models/user_profile.dart'; // UserRole için

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // --- OneSignal Ayarları ---
  OneSignal.Debug.setLogLevel(OSLogLevel.verbose);
  OneSignal.initialize("faeed989-8a81-4fe0-9c73-2eb9ed2144a7");
  OneSignal.Notifications.requestPermission(true);

  OneSignal.Notifications.addClickListener((event) {
    try {
      final data = event.notification.additionalData;
      if (data != null && data.containsKey('ticket_id')) {
        final ticketId = data['ticket_id'].toString();
        print("🔔 Bildirime tıklandı, Ticket ID: $ticketId");
        
        navigatorKey.currentState?.push(
          MaterialPageRoute(
            builder: (context) => TicketDetailPage(ticketId: ticketId),
          ),
        );
      }
    } catch (e) {
      print("❌ Bildirim tıklama hatası: $e");
    }
  });

  try {
    // Ortam değişkenlerini yükle
    await dotenv.load(fileName: ".env");

    // Tarih formatı (TR)
    await initializeDateFormatting('tr_TR', null);

    // Supabase init
    final supabaseUrl = dotenv.env['SUPABASE_URL'];
    final supabaseKey = dotenv.env['SUPABASE_KEY'];

    if (supabaseUrl == null || supabaseKey == null) {
      throw Exception("SUPABASE_URL veya SUPABASE_KEY .env dosyasında tanımlı değil.");
    }

    await Supabase.initialize(
      url: supabaseUrl,
      anonKey: supabaseKey,
    );

    // Status bar stil ayarı
    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
    ));

    runApp(const IsTakipApp());
  } catch (e) {
    runApp(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        home: Scaffold(
          body: Center(
            child: Text(
              "Başlatma Hatası:\n$e",
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

  static _IsTakipAppState? of(BuildContext context) =>
      context.findAncestorStateOfType<_IsTakipAppState>();

  @override
  State<IsTakipApp> createState() => _IsTakipAppState();
}

class _IsTakipAppState extends State<IsTakipApp> {
  ThemeMode _themeMode = ThemeMode.system;

  @override
  void initState() {
    super.initState();
    _loadTheme();
  }

  Future<void> _loadTheme() async {
    final prefs = await SharedPreferences.getInstance();
    final savedTheme = prefs.getString('theme_mode');
    if (savedTheme != null) {
      setState(() {
        if (savedTheme == 'light') {
          _themeMode = ThemeMode.light;
        } else if (savedTheme == 'dark') {
          _themeMode = ThemeMode.dark;
        }
      });
    }
  }

  Future<void> toggleTheme() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      if (_themeMode == ThemeMode.dark) {
        _themeMode = ThemeMode.light;
        prefs.setString('theme_mode', 'light');
      } else {
        _themeMode = ThemeMode.dark;
        prefs.setString('theme_mode', 'dark');
      }
    });
  }

  bool get isDarkMode => _themeMode == ThemeMode.dark;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: navigatorKey,
      title: 'İş Takip',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: _themeMode,
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
  @override
  void initState() {
    super.initState();
    // Uygulama açıldığında versiyon kontrolü yap
    WidgetsBinding.instance.addPostFrameCallback((_) {
      UpdateService().checkVersion(context);
    });
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<AuthState>(
      stream: Supabase.instance.client.auth.onAuthStateChange,
      builder: (context, snapshot) {
        // Hata durumu
        if (snapshot.hasError) {
          return const Scaffold(
            body: Center(
              child: Text("Oturum durumu okunurken bir hata oluştu."),
            ),
          );
        }

        final session = snapshot.data?.session ?? Supabase.instance.client.auth.currentSession;

        // Kullanıcı oturumu yoksa → Login
        if (session == null) {
          return const LoginPage();
        }

        // Oturum varsa → Kullanıcı profilini oku
        return FutureBuilder(
          future: UserService().getCurrentUserProfile(),
          builder: (context, userSnapshot) {
            if (userSnapshot.connectionState == ConnectionState.waiting) {
              return const Scaffold(
                body: Center(child: CircularProgressIndicator()),
              );
            }

            if (userSnapshot.hasError) {
              return const Scaffold(
                body: Center(
                  child: Text("Kullanıcı profili yüklenirken bir hata oluştu."),
                ),
              );
            }

            final userProfile = userSnapshot.data;

            // Profil hiç yoksa: Senaryo A (Admin onayı gerekli)
            // Profil yoksa kullanıcı giriş yapamaz (LoginPage'de kontrol ediliyor)
            // Ama yine de burada da güvenlik için kontrol ediyoruz
            if (userProfile == null) {
              return const Scaffold(
                body: Center(
                  child: Text(
                    "Profiliniz bulunamadı.\nYöneticinizle görüşün.",
                    textAlign: TextAlign.center,
                  ),
                ),
              );
            }

            // Rol tabanlı yönlendirme
            if (userProfile.role == UserRole.admin || userProfile.role == UserRole.manager) {
              return const DashboardPage();
            } else {
              return const TicketListPage();
            }
          },
        );
      },
    );
  }
}
