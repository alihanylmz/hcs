import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../widgets/workspace_background.dart';

/// Supabase Auth > Providers bolumunde **Email** acik olmalidir.
class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _formKey = GlobalKey<FormState>();
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  bool _obscure = true;
  bool _busy = false;
  /// false = giris, true = kayit (ilk hesap olusturma).
  bool _registerMode = false;

  static const _ink = Color(0xFF15304A);
  static const _brass = Color(0xFFC98E4B);

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    setState(() => _busy = true);
    try {
      if (_registerMode) {
        await _submitRegister();
      } else {
        await Supabase.instance.client.auth.signInWithPassword(
          email: _emailCtrl.text.trim(),
          password: _passwordCtrl.text,
        );
      }
    } on AuthException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_mapAuthMessage(e.message)),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Baglanti hatasi. Internet veya sunucu ayarlarini kontrol edin.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _submitRegister() async {
    final res = await Supabase.instance.client.auth.signUp(
      email: _emailCtrl.text.trim(),
      password: _passwordCtrl.text,
    );
    if (!mounted) return;
    if (res.session != null) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'Kayit alindi. E-postanizdaki dogrulama baglantisina tiklayin; '
          'ardindan buradan giris yapin. (Dogrulama kapaliysa direkt giris sekmesine gecin.)',
        ),
        behavior: SnackBarBehavior.floating,
        duration: Duration(seconds: 8),
      ),
    );
    setState(() => _registerMode = false);
  }

  Future<void> _forgotPassword() async {
    final email = _emailCtrl.text.trim();
    if (email.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Sifre sifirlama icin once e-posta adresinizi yazin.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }
    setState(() => _busy = true);
    try {
      await Supabase.instance.client.auth.resetPasswordForEmail(email);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Sifre sifirlama baglantisi e-postaniza gonderildi (gecerliyse).'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } on AuthException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_mapAuthMessage(e.message)),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Istek gonderilemedi.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  String _mapAuthMessage(String raw) {
    final lower = raw.toLowerCase();
    if (lower.contains('invalid login')) {
      return 'E-posta veya sifre hatali.';
    }
    if (lower.contains('email not confirmed')) {
      return 'E-posta henuz dogrulanmamis. Gelen kutunuzu kontrol edin.';
    }
    if (lower.contains('already registered') || lower.contains('user already')) {
      return 'Bu e-posta ile zaten hesap var. Giris sekmesinden deneyin.';
    }
    if (lower.contains('password') && lower.contains('least')) {
      return 'Sifre cok kisa; en az 6 karakter kullanin.';
    }
    return raw.isNotEmpty ? raw : 'Islem basarisiz.';
  }

  String? _validatePassword(String? v) {
    if (v == null || v.isEmpty) return 'Sifre gerekli.';
    if (_registerMode && v.length < 6) {
      return 'Kayit icin sifre en az 6 karakter olmali.';
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final size = MediaQuery.sizeOf(context);

    return Scaffold(
      body: WorkspaceBackground(
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 420),
                child: Column(
                  children: [
                    SizedBox(height: size.height < 640 ? 8 : 32),
                    _LogoCard(theme: theme),
                    const SizedBox(height: 28),
                    Text(
                      'Uzal Teklif',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.headlineMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                        color: _ink,
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Kurumsal teklif, stok ve kur yonetimi',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodyLarge?.copyWith(
                        color: const Color(0xFF5C7080),
                        height: 1.35,
                      ),
                    ),
                    const SizedBox(height: 28),
                    SegmentedButton<bool>(
                      style: ButtonStyle(
                        visualDensity: VisualDensity.compact,
                        foregroundColor: WidgetStateProperty.resolveWith((s) {
                          if (s.contains(WidgetState.selected)) {
                            return Colors.white;
                          }
                          return _ink;
                        }),
                      ),
                      segments: const [
                        ButtonSegment<bool>(
                          value: false,
                          label: Text('Giris'),
                          icon: Icon(Icons.login_rounded, size: 18),
                        ),
                        ButtonSegment<bool>(
                          value: true,
                          label: Text('Kayit ol'),
                          icon: Icon(Icons.person_add_rounded, size: 18),
                        ),
                      ],
                      selected: {_registerMode},
                      onSelectionChanged: (s) {
                        setState(() => _registerMode = s.first);
                      },
                      multiSelectionEnabled: false,
                      emptySelectionAllowed: false,
                    ),
                    const SizedBox(height: 20),
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(26, 28, 26, 24),
                        child: Form(
                          key: _formKey,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Text(
                                _registerMode
                                    ? 'Ilk hesabinizi olusturun'
                                    : 'Hesabinizla giris yapin',
                                style: theme.textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.w800,
                                  color: _ink,
                                ),
                              ),
                              if (_registerMode) ...[
                                const SizedBox(height: 10),
                                Text(
                                  'Supabase projesinde Email provider acik olmali. '
                                  'E-posta dogrulamasi aciksa gelen kutunuzu kontrol edin.',
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: const Color(0xFF5C7080),
                                    height: 1.35,
                                  ),
                                ),
                              ],
                              const SizedBox(height: 22),
                              TextFormField(
                                controller: _emailCtrl,
                                keyboardType: TextInputType.emailAddress,
                                autofillHints: const [AutofillHints.email],
                                textInputAction: TextInputAction.next,
                                decoration: const InputDecoration(
                                  labelText: 'E-posta',
                                  prefixIcon: Icon(Icons.mail_outline_rounded),
                                ),
                                validator: (v) {
                                  final t = v?.trim() ?? '';
                                  if (t.isEmpty) return 'E-posta gerekli.';
                                  if (!t.contains('@')) return 'Gecerli bir e-posta girin.';
                                  return null;
                                },
                              ),
                              const SizedBox(height: 16),
                              TextFormField(
                                controller: _passwordCtrl,
                                obscureText: _obscure,
                                autofillHints: const [AutofillHints.password],
                                textInputAction: TextInputAction.done,
                                onFieldSubmitted: (_) => _busy ? null : _submit(),
                                decoration: InputDecoration(
                                  labelText: 'Sifre',
                                  prefixIcon: const Icon(Icons.lock_outline_rounded),
                                  suffixIcon: IconButton(
                                    tooltip: _obscure ? 'Goster' : 'Gizle',
                                    onPressed: () => setState(() => _obscure = !_obscure),
                                    icon: Icon(
                                      _obscure
                                          ? Icons.visibility_outlined
                                          : Icons.visibility_off_outlined,
                                    ),
                                  ),
                                ),
                                validator: _validatePassword,
                              ),
                              if (!_registerMode) ...[
                                const SizedBox(height: 10),
                                Align(
                                  alignment: Alignment.centerRight,
                                  child: TextButton(
                                    onPressed: _busy ? null : _forgotPassword,
                                    child: const Text('Sifremi unuttum'),
                                  ),
                                ),
                              ] else
                                const SizedBox(height: 8),
                              FilledButton(
                                onPressed: _busy ? null : _submit,
                                style: FilledButton.styleFrom(
                                  backgroundColor: _ink,
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(vertical: 16),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(18),
                                  ),
                                ),
                                child: _busy
                                    ? const SizedBox(
                                        height: 22,
                                        width: 22,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2.2,
                                          color: Colors.white,
                                        ),
                                      )
                                    : Text(_registerMode ? 'Hesap olustur' : 'Giris yap'),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.verified_user_outlined, size: 18, color: _brass.withValues(alpha: 0.9)),
                        const SizedBox(width: 8),
                        Flexible(
                          child: Text(
                            'Oturumunuz guvenli baglanti uzerinden Supabase ile dogrulanir.',
                            textAlign: TextAlign.center,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: const Color(0xFF7A8C99),
                              height: 1.4,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _LogoCard extends StatelessWidget {
  const _LogoCard({required this.theme});

  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        color: Colors.white.withValues(alpha: 0.92),
        border: Border.all(color: const Color(0xFFD8E0E8)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF15304A).withValues(alpha: 0.08),
            blurRadius: 32,
            offset: const Offset(0, 14),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            width: 112,
            height: 112,
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(22),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  const Color(0xFFC98E4B).withValues(alpha: 0.15),
                  const Color(0xFF4E907A).withValues(alpha: 0.12),
                ],
              ),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Image.asset(
                'lib/assest/logo/uzal.png',
                fit: BoxFit.contain,
              ),
            ),
          ),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            decoration: BoxDecoration(
              color: const Color(0xFFF0E8DC),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              'UZAL TEKNIK',
              style: theme.textTheme.labelLarge?.copyWith(
                fontWeight: FontWeight.w800,
                letterSpacing: 1.2,
                color: const Color(0xFF15304A),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
