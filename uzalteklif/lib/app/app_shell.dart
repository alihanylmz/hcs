import 'dart:async';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'main_navigation_shell.dart';
import '../screens/login_page.dart';
import '../theme/app_theme.dart';
import 'bootstrap.dart';

class AppShell extends StatefulWidget {
  const AppShell({super.key, required this.bootstrap});

  final AppBootstrap bootstrap;

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  StreamSubscription<AuthState>? _authSub;
  Future<bool>? _accessFuture;
  String? _accessUserId;

  @override
  void initState() {
    super.initState();
    if (widget.bootstrap.supabaseActive) {
      _authSub = Supabase.instance.client.auth.onAuthStateChange.listen((_) {
        if (mounted) {
          setState(() {
            _accessFuture = null;
            _accessUserId = null;
          });
        }
      });
    }
  }

  @override
  void dispose() {
    _authSub?.cancel();
    super.dispose();
  }

  bool get _requiresLogin {
    if (!widget.bootstrap.supabaseActive) return false;
    return Supabase.instance.client.auth.currentSession == null;
  }

  Future<void> _signOut() async {
    await Supabase.instance.client.auth.signOut();
  }

  Widget _authenticatedHome() {
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) return const LoginPage();
    if (_accessFuture == null || _accessUserId != userId) {
      _accessUserId = userId;
      _accessFuture = widget.bootstrap.userProfileRepository
          .canAccessQuoteApp();
    }

    return FutureBuilder<bool>(
      future: _accessFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        if (snapshot.hasError) {
          return _AccessMessage(
            title: 'Yetki kontrolü yapılamadı',
            message:
                'Bağlantıyı kontrol edip tekrar deneyin. Sorun devam ederse '
                'yöneticinize başvurun.',
            actionLabel: 'Tekrar Dene',
            onAction: () {
              setState(() {
                _accessFuture = null;
                _accessUserId = null;
              });
            },
          );
        }
        if (snapshot.data != true) {
          return _AccessMessage(
            title: 'Teklif erişiminiz bulunmuyor',
            message:
                'Hesabınız aktif; ancak Teklif uygulaması için yetki '
                'tanımlanmamış.',
            actionLabel: 'Çıkış Yap',
            onAction: _signOut,
          );
        }
        return MainNavigationShell(
          bootstrap: widget.bootstrap,
          onSignOut: _signOut,
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.bootstrap.themePreferenceService,
      builder: (context, _) {
        return MaterialApp(
          debugShowCheckedModeBanner: false,
          title: 'Uzal Teklif',
          theme: AppTheme.light,
          darkTheme: AppTheme.light,
          themeMode: widget.bootstrap.themePreferenceService.mode,
          home: _requiresLogin
              ? const LoginPage()
              : widget.bootstrap.supabaseActive
              ? _authenticatedHome()
              : MainNavigationShell(bootstrap: widget.bootstrap),
        );
      },
    );
  }
}

class _AccessMessage extends StatelessWidget {
  const _AccessMessage({
    required this.title,
    required this.message,
    required this.actionLabel,
    required this.onAction,
  });

  final String title;
  final String message;
  final String actionLabel;
  final FutureOr<void> Function() onAction;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 440),
          child: Padding(
            padding: const EdgeInsets.all(28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.admin_panel_settings_outlined, size: 52),
                const SizedBox(height: 18),
                Text(
                  title,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 10),
                Text(message, textAlign: TextAlign.center),
                const SizedBox(height: 22),
                FilledButton(
                  onPressed: () => onAction(),
                  child: Text(actionLabel),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
