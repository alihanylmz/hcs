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

  @override
  void initState() {
    super.initState();
    if (widget.bootstrap.supabaseActive) {
      _authSub = Supabase.instance.client.auth.onAuthStateChange.listen((_) {
        if (mounted) setState(() {});
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
              : MainNavigationShell(
                  bootstrap: widget.bootstrap,
                  onSignOut: widget.bootstrap.supabaseActive ? _signOut : null,
                ),
        );
      },
    );
  }
}
