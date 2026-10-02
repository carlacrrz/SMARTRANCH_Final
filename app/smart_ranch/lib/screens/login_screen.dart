import 'package:flutter/material.dart';
import '../config/app_theme.dart';
import '../services/auth_service.dart';
import 'register_screen.dart';

/// Login screen with brand identity, login form, registration, and demo mode.
class LoginScreen extends StatefulWidget {
  final VoidCallback onAuthenticated;
  const LoginScreen({super.key, required this.onAuthenticated});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> with SingleTickerProviderStateMixin {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;
  bool _obscurePassword = true;
  String? _error;
  late AnimationController _animController;
  late Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(vsync: this, duration: const Duration(milliseconds: 800));
    _fadeAnim = CurvedAnimation(parent: _animController, curve: Curves.easeInOut);
    _animController.forward();
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _animController.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text;

    if (email.isEmpty || password.isEmpty) {
      setState(() => _error = 'Ingresa correo electrónico y contraseña');
      return;
    }

    setState(() { _isLoading = true; _error = null; });

    final success = await AuthService.login(email, password);

    if (success) {
      widget.onAuthenticated();
    } else {
      setState(() { _isLoading = false; _error = 'Credenciales incorrectas'; });
    }
  }

  void _enterDemoMode() {
    AuthService.enterDemoMode();
    widget.onAuthenticated();
  }

  void _goToRegister() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => RegisterScreen(
          onRegistered: widget.onAuthenticated,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      body: LayoutBuilder(
        builder: (context, constraints) {
          final isWide = constraints.maxWidth >= 850;

          return Center(
            child: FadeTransition(
              opacity: _fadeAnim,
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Container(
                  constraints: BoxConstraints(maxWidth: isWide ? 880 : 420),
                  decoration: BoxDecoration(
                    color: AppTheme.card,
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: AppTheme.divider),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.35),
                        blurRadius: 40,
                        offset: const Offset(0, 12),
                      ),
                    ],
                  ),
                  child: isWide
                      ? Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            // Left Column — Hero & Features (Web/Desktop)
                            Expanded(
                              flex: 5,
                              child: Container(
                                padding: const EdgeInsets.all(36),
                                decoration: BoxDecoration(
                                  color: AppTheme.surface.withAlpha(150),
                                  borderRadius: const BorderRadius.horizontal(left: Radius.circular(24)),
                                  border: Border(right: BorderSide(color: AppTheme.divider)),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Row(
                                      children: [
                                        Image.asset('assets/images/logo_icon.png', width: 44, height: 44),
                                        const SizedBox(width: 12),
                                        Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              'Smart Ranch',
                                              style: TextStyle(
                                                color: AppTheme.textPrimary,
                                                fontWeight: FontWeight.w800,
                                                fontSize: 22,
                                                letterSpacing: -0.5,
                                              ),
                                            ),
                                            Text(
                                              'Ganadería Inteligente IoT',
                                              style: TextStyle(
                                                color: AppTheme.primary,
                                                fontWeight: FontWeight.w600,
                                                fontSize: 12,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 28),
                                    Text(
                                      'Gestión Integral de Ganado en Tiempo Real',
                                      style: TextStyle(
                                        color: AppTheme.textPrimary,
                                        fontWeight: FontWeight.w700,
                                        fontSize: 18,
                                        height: 1.3,
                                      ),
                                    ),
                                    const SizedBox(height: 12),
                                    Text(
                                      'Monitorea la ubicación GPS, estrés térmico (THI), bebederos y salud de tu hato desde cualquier navegador.',
                                      style: TextStyle(
                                        color: AppTheme.textSecondary,
                                        fontSize: 13,
                                        height: 1.4,
                                      ),
                                    ),
                                    const SizedBox(height: 24),
                                    _buildFeatureItem(Icons.gps_fixed_rounded, 'Rastreo GPS y Geocercas virtuales'),
                                    const SizedBox(height: 10),
                                    _buildFeatureItem(Icons.thermostat_rounded, 'Monitoreo de Índice THI y Temperatura'),
                                    const SizedBox(height: 10),
                                    _buildFeatureItem(Icons.water_drop_rounded, 'Nivel de agua ultrasónico en bebederos'),
                                    const SizedBox(height: 10),
                                    _buildFeatureItem(Icons.favorite_rounded, 'Detección de celo y salud por acelerómetro'),
                                  ],
                                ),
                              ),
                            ),
                            // Right Column — Login Form
                            Expanded(
                              flex: 5,
                              child: Padding(
                                padding: const EdgeInsets.all(36),
                                child: _buildLoginForm(isWide: true),
                              ),
                            ),
                          ],
                        )
                      : Padding(
                          padding: const EdgeInsets.all(28),
                          child: _buildLoginForm(isWide: false),
                        ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildFeatureItem(IconData icon, String text) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: AppTheme.primary.withAlpha(30),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, size: 16, color: AppTheme.primary),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            text,
            style: TextStyle(color: AppTheme.textSecondary, fontSize: 12, fontWeight: FontWeight.w500),
          ),
        ),
      ],
    );
  }

  Widget _buildLoginForm({required bool isWide}) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (!isWide) ...[
          Image.asset('assets/images/logo_icon.png', width: 80, height: 80),
          const SizedBox(height: 10),
          Text(
            'Smart Ranch',
            style: TextStyle(
              color: AppTheme.textPrimary,
              fontWeight: FontWeight.w800,
              fontSize: 22,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            'Ganadería Inteligente',
            style: TextStyle(
              color: AppTheme.primary,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 22),
        ] else ...[
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              'Iniciar Sesión',
              style: TextStyle(
                color: AppTheme.textPrimary,
                fontWeight: FontWeight.w800,
                fontSize: 20,
              ),
            ),
          ),
          const SizedBox(height: 4),
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              'Ingresa con tus credenciales de rancho',
              style: TextStyle(
                color: AppTheme.textSecondary,
                fontSize: 12,
              ),
            ),
          ),
          const SizedBox(height: 20),
        ],

        // Email
        TextField(
          controller: _emailController,
          keyboardType: TextInputType.emailAddress,
          style: TextStyle(color: AppTheme.textPrimary, fontSize: 14),
          decoration: InputDecoration(
            labelText: 'Correo electrónico',
            hintText: 'ejemplo@correo.com',
            hintStyle: TextStyle(color: AppTheme.textSecondary.withAlpha(100), fontSize: 13),
            labelStyle: TextStyle(color: AppTheme.textSecondary, fontSize: 13),
            prefixIcon: Icon(Icons.email_outlined, color: AppTheme.textSecondary, size: 20),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(color: AppTheme.divider),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(color: AppTheme.primary, width: 1.5),
            ),
            filled: true,
            fillColor: AppTheme.surface,
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          ),
          textInputAction: TextInputAction.next,
        ),
        const SizedBox(height: 14),

        // Password
        TextField(
          controller: _passwordController,
          obscureText: _obscurePassword,
          style: TextStyle(color: AppTheme.textPrimary, fontSize: 14),
          decoration: InputDecoration(
            labelText: 'Contraseña',
            labelStyle: TextStyle(color: AppTheme.textSecondary, fontSize: 13),
            prefixIcon: Icon(Icons.lock_outline, color: AppTheme.textSecondary, size: 20),
            suffixIcon: IconButton(
              icon: Icon(
                _obscurePassword ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                color: AppTheme.textSecondary, size: 20,
              ),
              onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(color: AppTheme.divider),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(color: AppTheme.primary, width: 1.5),
            ),
            filled: true,
            fillColor: AppTheme.surface,
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          ),
          textInputAction: TextInputAction.done,
          onSubmitted: (_) => _login(),
        ),
        const SizedBox(height: 8),

        // Error
        if (_error != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(_error!, style: TextStyle(color: AppTheme.thiDanger, fontSize: 12)),
          ),

        const SizedBox(height: 8),

        // Login button
        SizedBox(
          width: double.infinity,
          height: 46,
          child: ElevatedButton(
            onPressed: _isLoading ? null : _login,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              elevation: 0,
            ),
            child: _isLoading
                ? const SizedBox(width: 20, height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Text('Iniciar Sesión', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
          ),
        ),
        const SizedBox(height: 14),

        // Divider with "o"
        Row(
          children: [
            Expanded(child: Divider(color: AppTheme.divider)),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Text('o', style: TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
            ),
            Expanded(child: Divider(color: AppTheme.divider)),
          ],
        ),
        const SizedBox(height: 14),

        // Social login buttons
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () {
                  AuthService.currentUser ??= {};
                  AuthService.currentUser!['username'] = 'google_user';
                  AuthService.currentUser!['full_name'] = 'Usuario Google';
                  AuthService.currentUser!['email'] = 'usuario@gmail.com';
                  AuthService.currentUser!['ranch_name'] = 'Rancho Smart';
                  widget.onAuthenticated();
                },
                icon: const Icon(Icons.g_mobiledata_rounded, size: 24, color: Color(0xFFEA4335)),
                label: const Text('Google', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppTheme.textPrimary,
                  side: BorderSide(color: AppTheme.divider),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  padding: const EdgeInsets.symmetric(vertical: 11),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () {
                  AuthService.currentUser ??= {};
                  AuthService.currentUser!['username'] = 'apple_user';
                  AuthService.currentUser!['full_name'] = 'Usuario Apple';
                  AuthService.currentUser!['email'] = 'usuario@icloud.com';
                  AuthService.currentUser!['ranch_name'] = 'Rancho Puerto Peñasco';
                  widget.onAuthenticated();
                },
                icon: const Icon(Icons.apple_rounded, size: 20, color: Colors.white),
                label: const Text('Apple', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppTheme.textPrimary,
                  side: BorderSide(color: AppTheme.divider),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  padding: const EdgeInsets.symmetric(vertical: 11),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),

        // Register button
        SizedBox(
          width: double.infinity,
          height: 44,
          child: OutlinedButton(
            onPressed: _goToRegister,
            style: OutlinedButton.styleFrom(
              foregroundColor: AppTheme.primary,
              side: BorderSide(color: AppTheme.primary.withAlpha(100)),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text('Crear Cuenta Nueva', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
          ),
        ),
        const SizedBox(height: 10),

        // Demo mode button
        TextButton.icon(
          onPressed: _enterDemoMode,
          icon: Icon(Icons.play_circle_outline_rounded, size: 18, color: AppTheme.textSecondary),
          label: Text(
            'Entrar como Invitado (Modo Demo)',
            style: TextStyle(color: AppTheme.textSecondary, fontSize: 12),
          ),
        ),
        const SizedBox(height: 8),
        Text('v2.0 — Sonora, México', style: TextStyle(
            color: AppTheme.textSecondary.withValues(alpha: 0.5), fontSize: 10)),
      ],
    );
  }
}
