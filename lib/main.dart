import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'pages/login_page.dart';
import 'pages/ticket_list_page.dart';
import 'pages/dashboard_page.dart'; // Dashboard eklendi
import 'services/user_service.dart'; // User Service eklendi
import 'theme/app_theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    await dotenv.load(fileName: ".env");

    await Supabase.initialize(
      url: dotenv.env['SUPABASE_URL']!,
      anonKey: dotenv.env['SUPABASE_KEY']!,
    );

    runApp(const IsTakipApp());
  } catch (e) {
    runApp(MaterialApp(
      home: Scaffold(
        body: Center(
          child: Text("Başlatma Hatası: $e"),
        ),
      ),
    ));
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
        if (savedTheme == 'light') _themeMode = ThemeMode.light;
        if (savedTheme == 'dark') _themeMode = ThemeMode.dark;
      });
    }
  }

  void toggleTheme() async {
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
  bool _initialized = false;

  @override
  void initState() {
    super.initState();
    _checkSession();
  }

  Future<void> _checkSession() async {
    await Future.delayed(Duration.zero); 
    if (mounted) {
      setState(() {
        _initialized = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_initialized) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return StreamBuilder<AuthState>(
      stream: Supabase.instance.client.auth.onAuthStateChange,
      builder: (context, snapshot) {
        final session = Supabase.instance.client.auth.currentSession;

        if (session != null) {
          // Kullanıcı giriş yapmışsa rolünü kontrol et
          return FutureBuilder(
            future: UserService().getCurrentUserProfile(),
            builder: (context, userSnapshot) {
              if (userSnapshot.connectionState == ConnectionState.waiting) {
                return const Scaffold(body: Center(child: CircularProgressIndicator()));
              }

              final userProfile = userSnapshot.data;
              // Admin veya Manager olsa bile her zaman TicketListPage açılacak
              return const TicketListPage();
            },
          );
        } else {
          return const LoginPage();
        }
      },
    );
  }
}
