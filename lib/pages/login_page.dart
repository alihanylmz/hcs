import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:onesignal_flutter/onesignal_flutter.dart';
import 'dart:developer' as developer; // Logları daha profesyonel görmek için
import '../services/user_service.dart';
import '../models/user_profile.dart'; // UserRole için
import 'dashboard_page.dart';
import 'ticket_list_page.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  
  bool _isLoading = false;
  bool _rememberMe = false;
  bool _isPasswordVisible = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadSavedCredentials();
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _loadSavedCredentials() async {
    final prefs = await SharedPreferences.getInstance();
    final email = prefs.getString('saved_email');
    final remember = prefs.getBool('remember_me') ?? false;
    
    if (remember && email != null) {
      setState(() {
        _emailController.text = email;
        _rememberMe = true;
      });
    }
  }

  Future<void> _saveCredentials() async {
    final prefs = await SharedPreferences.getInstance();
    if (_rememberMe) {
      await prefs.setString('saved_email', _emailController.text.trim());
      await prefs.setBool('remember_me', true);
    } else {
      await prefs.remove('saved_email');
      await prefs.setBool('remember_me', false);
    }
  }

  Future<void> _signIn() async {
    // 1. Klavye kapat
    FocusScope.of(context).unfocus();

    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();

    // 2. Validation (Exception fırlatmadan temiz kontrol)
    if (email.isEmpty || password.isEmpty) {
      setState(() {
        _errorMessage = 'Lütfen e-posta ve şifrenizi giriniz.';
        _isLoading = false;
      });
      return; // Fonksiyonu burada kesiyoruz
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      // 3. Supabase Girişi
      final response = await Supabase.instance.client.auth.signInWithPassword(
        email: email,
        password: password,
      );

      // Session kontrolü (Null safety)
      if (response.session != null && response.user != null) {
        
        // OneSignal ID Eşleme
        try {
          await OneSignal.login(response.user!.id);
        } catch (osError) {
          // OneSignal hatası login'i engellemesin, sadece loglayalım
          developer.log("OneSignal Login Hatası: $osError");
        }

        // 4. Rol Kontrolü (Pending kullanıcısı girmesin)
        // Not: Bu 'Double Query'dir ama UX için gereklidir.
        final userService = UserService();
        final profile = await userService.getCurrentUserProfile();

        // Profil yoksa veya pending ise giriş yapamaz
        if (profile == null) {
          await Supabase.instance.client.auth.signOut();
          if (mounted) {
            setState(() {
              _errorMessage = 'Profiliniz bulunamadı. Yöneticinizle görüşün.';
              _isLoading = false;
            });
          }
          return;
        }

        if (profile.role == UserRole.pending) {
          await Supabase.instance.client.auth.signOut();
          if (mounted) {
            setState(() {
              _errorMessage = 'Hesabınız onay beklemektedir. Yöneticinizle görüşün.';
              _isLoading = false;
            });
          }
          return;
        }

        // Başarılı giriş
        await _saveCredentials();
        
        // AuthGate stream'i bazen gecikebilir, bu yüzden doğrudan yönlendirme yapıyoruz
        if (mounted) {
          // Profil bilgisine göre doğrudan yönlendirme yap
          if (profile.role == UserRole.admin || profile.role == UserRole.manager) {
            Navigator.of(context).pushReplacement(
              MaterialPageRoute(builder: (_) => const DashboardPage()),
            );
          } else {
            Navigator.of(context).pushReplacement(
              MaterialPageRoute(builder: (_) => const TicketListPage()),
            );
          }
        }

      } else {
        // Session gelmediyse garip bir durum var
        throw const AuthException("Giriş başarısız, oturum açılamadı.");
      }

    } on AuthException catch (e) {
      // Supabase'den gelen bilinen hatalar (Şifre yanlış vs.)
      setState(() {
        _errorMessage = e.message; 
      });
    } catch (e) {
      // Beklenmedik teknik hatalar
      developer.log("Login Hatası: $e"); // Geliştirici görsün
      setState(() {
        _errorMessage = 'Beklenmedik bir hata oluştu. Lütfen bağlantınızı kontrol edip tekrar deneyin.';
      });
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    // GestureDetector tüm sayfayı sarıyor
    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: Scaffold(
        body: Stack(
          children: [
            Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 400),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.work_outline_rounded, size: 64, color: theme.primaryColor),
                      const SizedBox(height: 24),
                      Text(
                        'İŞ TAKİP PORTALI',
                        style: theme.textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1.5,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Teknisyen & Yönetim Paneli',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.textTheme.bodySmall?.color,
                        ),
                      ),
                      const SizedBox(height: 40),

                      // Hata Mesajı Alanı
                      if (_errorMessage != null)
                        Container(
                          margin: const EdgeInsets.only(bottom: 16),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.red.withOpacity(0.1),
                            border: Border.all(color: Colors.red.withOpacity(0.5)),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.error_outline, color: Colors.red, size: 20),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  _errorMessage!,
                                  style: const TextStyle(color: Colors.red, fontSize: 13),
                                ),
                              ),
                            ],
                          ),
                        ),

                      _buildLoginForm(theme),
                      
                      const SizedBox(height: 24),
                      Text(
                        'Hesabınız yoksa sistem yöneticinizle iletişime geçiniz.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            
            Positioned(
              right: 20,
              bottom: 20,
              child: Opacity(
                opacity: 0.1,
                child: SvgPicture.asset(
                  'assets/images/log.svg',
                  width: 100,
                  height: 100,
                  // Placeholder: Asset yoksa hata vermemesi için
                  placeholderBuilder: (context) => const SizedBox(), 
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLoginForm(ThemeData theme) {
    return AutofillGroup(
      child: Column(
        children: [
          TextField(
            controller: _emailController,
            keyboardType: TextInputType.emailAddress,
            textInputAction: TextInputAction.next,
            autofillHints: const [AutofillHints.email],
            decoration: const InputDecoration(
              labelText: 'E-posta Adresi',
              prefixIcon: Icon(Icons.email_outlined),
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _passwordController,
            obscureText: !_isPasswordVisible,
            textInputAction: TextInputAction.done,
            autofillHints: const [AutofillHints.password],
            onSubmitted: (_) => _signIn(),
            decoration: InputDecoration(
              labelText: 'Şifre',
              prefixIcon: const Icon(Icons.lock_outline),
              border: const OutlineInputBorder(),
              suffixIcon: IconButton(
                icon: Icon(_isPasswordVisible ? Icons.visibility_off : Icons.visibility),
                onPressed: () => setState(() => _isPasswordVisible = !_isPasswordVisible),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              SizedBox(
                height: 24,
                width: 24,
                child: Checkbox(
                  value: _rememberMe, 
                  onChanged: (val) => setState(() => _rememberMe = val ?? false),
                  activeColor: theme.colorScheme.primary,
                ),
              ),
              const SizedBox(width: 8),
              GestureDetector(
                onTap: () => setState(() => _rememberMe = !_rememberMe),
                child: const Text('Beni Hatırla'),
              ),
            ],
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton(
              onPressed: _isLoading ? null : _signIn,
              style: ElevatedButton.styleFrom(
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              child: _isLoading 
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) 
                : const Text('GİRİŞ YAP', style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1)),
            ),
          ),
        ],
      ),
    );
  }
}
