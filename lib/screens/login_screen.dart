import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:provider/provider.dart';
import '../core/app_colors.dart';
import '../core/app_transitions.dart';
import '../providers/user_provider.dart';
import '../providers/medicine_provider.dart';
import '../providers/adherence_provider.dart';
import '../providers/alerts_provider.dart';
import 'dashboard_screen.dart';
import 'register_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  bool _obscure = true;
  bool _isLoading = false;
  String? _errorMsg;

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
  }

  String _friendlyError(String raw) {
    final msg = raw.toLowerCase();
    if (msg.contains('rate limit') || msg.contains('too many')) {
      return 'Too many attempts. Please wait a few minutes and try again.';
    } else if (msg.contains('30 seconds') || msg.contains('security purposes')) {
      return 'Please wait 30 seconds before trying again.';
    } else if (msg.contains('invalid login') || msg.contains('invalid credentials') || msg.contains('wrong password')) {
      return 'Incorrect email or password. Please try again.';
    } else if (msg.contains('user not found') || msg.contains('no user')) {
      return 'No account found with this email. Please register first.';
    } else if (msg.contains('email not confirmed')) {
      return 'Please confirm your email before signing in, or disable email confirmation in settings.';
    } else if (msg.contains('network') || msg.contains('socket')) {
      return 'Network error. Please check your internet connection.';
    }
    return raw;
  }

  Future<void> _signIn() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() { _isLoading = true; _errorMsg = null; });
    try {
      await Supabase.instance.client.auth.signInWithPassword(
        email: _emailCtrl.text.trim(),
        password: _passCtrl.text.trim(),
      );
      if (!mounted) return;
      await Future.wait([
        context.read<UserProvider>().loadUser(),
        context.read<MedicineProvider>().loadMedicines(),
        context.read<AdherenceProvider>().loadAdherence(),
        context.read<AlertsProvider>().loadAlerts(),
      ]);
      if (!mounted) return;
      Navigator.pushReplacement(context, AppPageRoute(page: const DashboardScreen()));
    } on AuthException catch (e) {
      setState(() => _errorMsg = _friendlyError(e.message));
    } catch (e) {
      setState(() => _errorMsg = _friendlyError(e.toString()));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [c.primaryLight, c.background, c.surfaceVariant],
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 48),
            child: Column(
              children: [
                const SizedBox(height: 40),
                Container(
                  width: 72, height: 72,
                  decoration: BoxDecoration(color: c.primary, shape: BoxShape.circle),
                  child: const Icon(Icons.medication_rounded, color: Colors.white, size: 36),
                ),
                const SizedBox(height: 16),
                Text('Medsafe', style: Theme.of(context).textTheme.headlineMedium?.copyWith(color: c.textPrimary, fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                Text('Medication Safety System', style: TextStyle(fontSize: 14, color: c.textSecondary)),
                const SizedBox(height: 40),
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: c.card,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [BoxShadow(color: c.shadow, blurRadius: 20, offset: const Offset(0, 4))],
                  ),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Welcome Back', style: Theme.of(context).textTheme.headlineSmall?.copyWith(color: c.textPrimary, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 24),
                        if (_errorMsg != null) ...[
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(color: c.errorBg, borderRadius: BorderRadius.circular(8)),
                            child: Row(children: [
                              Icon(Icons.error_outline, color: c.error, size: 18),
                              const SizedBox(width: 8),
                              Expanded(child: Text(_errorMsg!, style: TextStyle(color: c.error, fontSize: 13))),
                            ]),
                          ),
                          const SizedBox(height: 16),
                        ],
                        Text('Email Address', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: c.textPrimary)),
                        const SizedBox(height: 8),
                        TextFormField(
                          controller: _emailCtrl,
                          keyboardType: TextInputType.emailAddress,
                          textInputAction: TextInputAction.next,
                          decoration: _inputDeco(c, 'Enter your email', Icons.person_outline),
                          validator: (v) => (v == null || v.isEmpty) ? 'Required' : null,
                        ),
                        const SizedBox(height: 16),
                        Text('Password', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: c.textPrimary)),
                        const SizedBox(height: 8),
                        TextFormField(
                          controller: _passCtrl,
                          obscureText: _obscure,
                          onFieldSubmitted: (_) => _signIn(),
                          decoration: _inputDeco(c, 'Enter your password', Icons.lock_outline).copyWith(
                            suffixIcon: IconButton(
                              icon: Icon(_obscure ? Icons.visibility_off_outlined : Icons.visibility_outlined, color: c.textTertiary, size: 20),
                              onPressed: () => setState(() => _obscure = !_obscure),
                            ),
                          ),
                          validator: (v) => (v == null || v.isEmpty) ? 'Required' : null,
                        ),
                        const SizedBox(height: 24),
                        SizedBox(
                          width: double.infinity, height: 50,
                          child: ElevatedButton(
                            onPressed: _isLoading ? null : _signIn,
                            style: ElevatedButton.styleFrom(backgroundColor: c.primary, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)), elevation: 0),
                            child: _isLoading
                                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                                : const Text('Sign In', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
                          ),
                        ),
                        const SizedBox(height: 16),
                        Center(
                          child: Row(mainAxisSize: MainAxisSize.min, children: [
                            Text("Don't have an account? ", style: TextStyle(color: c.textSecondary, fontSize: 14)),
                            GestureDetector(
                              onTap: () => Navigator.push(context, AppPageRoute(page: const RegisterScreen())),
                              child: Text('Register', style: TextStyle(color: c.primary, fontWeight: FontWeight.bold, fontSize: 14)),
                            ),
                          ]),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  InputDecoration _inputDeco(AppColors c, String hint, IconData icon) => InputDecoration(
    hintText: hint,
    hintStyle: TextStyle(color: c.textTertiary, fontSize: 14),
    prefixIcon: Icon(icon, color: c.textTertiary, size: 20),
    filled: true,
    fillColor: c.surfaceVariant,
    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: c.primary, width: 1.5)),
    errorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: c.error)),
    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
  );
}
