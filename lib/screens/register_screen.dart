import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../core/app_colors.dart';
import '../core/app_transitions.dart';
import 'package:provider/provider.dart';
import '../providers/user_provider.dart';
import '../providers/medicine_provider.dart';
import '../providers/adherence_provider.dart';
import '../providers/alerts_provider.dart';
import 'dashboard_screen.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();
  bool _obscurePass = true;
  bool _obscureConfirm = true;
  bool _isLoading = false;
  String? _errorMsg;

  @override
  void dispose() {
    for (final ctrl in [_nameCtrl, _emailCtrl, _phoneCtrl, _passCtrl, _confirmCtrl]) {
      ctrl.dispose();
    }
    super.dispose();
  }

  String _friendlyError(String raw) {
    final msg = raw.toLowerCase();
    if (msg.contains('rate limit') || msg.contains('too many') || msg.contains('email rate')) {
      return 'Too many sign-up attempts. Please wait a few minutes and try again.';
    } else if (msg.contains('30 seconds') || msg.contains('security purposes')) {
      return 'Please wait 30 seconds before trying again.';
    } else if (msg.contains('already registered') || msg.contains('already exists') || msg.contains('already been registered')) {
      return 'This email is already registered. Please sign in instead.';
    } else if (msg.contains('weak password') || msg.contains('password should')) {
      return 'Password is too weak. Use at least 6 characters with letters and numbers.';
    } else if (msg.contains('invalid email')) {
      return 'Please enter a valid email address.';
    } else if (msg.contains('network') || msg.contains('socket')) {
      return 'Network error. Please check your internet connection.';
    }
    return raw;
  }

  Future<void> _createAccount() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() { _isLoading = true; _errorMsg = null; });
    try {
      final res = await Supabase.instance.client.auth.signUp(
        email: _emailCtrl.text.trim(),
        password: _passCtrl.text.trim(),
      );
      if (res.user == null) throw Exception('Registration failed.');

      if (!mounted) return;
      await context.read<UserProvider>().updateProfile(
        name: _nameCtrl.text.trim(),
        phone: _phoneCtrl.text.trim(),
      );

      if (!mounted) return;
      await Future.wait([
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
            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 32),
            child: Column(
              children: [
                const SizedBox(height: 24),
                Container(
                  width: 72, height: 72,
                  decoration: BoxDecoration(color: c.primary, shape: BoxShape.circle),
                  child: const Icon(Icons.medication_rounded, color: Colors.white, size: 36),
                ),
                const SizedBox(height: 16),
                Text('Create Account', style: Theme.of(context).textTheme.headlineMedium?.copyWith(color: c.textPrimary, fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                Text('Join Medsafe today', style: TextStyle(fontSize: 14, color: c.textSecondary)),
                const SizedBox(height: 32),
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
                        _label(c, 'Full Name'),
                        TextFormField(controller: _nameCtrl, textInputAction: TextInputAction.next, decoration: _deco(c, 'Enter your full name', Icons.person_outline), validator: (v) => (v == null || v.isEmpty) ? 'Required' : null),
                        const SizedBox(height: 16),
                        _label(c, 'Email'),
                        TextFormField(controller: _emailCtrl, keyboardType: TextInputType.emailAddress, textInputAction: TextInputAction.next, decoration: _deco(c, 'Enter your email', Icons.email_outlined), validator: (v) => (v == null || !v.contains('@')) ? 'Valid email required' : null),
                        const SizedBox(height: 16),
                        _label(c, 'Phone Number'),
                        TextFormField(controller: _phoneCtrl, keyboardType: TextInputType.phone, textInputAction: TextInputAction.next, decoration: _deco(c, 'Enter your phone', Icons.phone_outlined), validator: (v) => (v == null || v.isEmpty) ? 'Required' : null),
                        const SizedBox(height: 16),
                        _label(c, 'Password'),
                        TextFormField(
                          controller: _passCtrl, obscureText: _obscurePass, textInputAction: TextInputAction.next,
                          decoration: _deco(c, 'Create a password', Icons.lock_outline).copyWith(
                            suffixIcon: IconButton(icon: Icon(_obscurePass ? Icons.visibility_off_outlined : Icons.visibility_outlined, color: c.textTertiary, size: 20), onPressed: () => setState(() => _obscurePass = !_obscurePass)),
                          ),
                          validator: (v) => (v == null || v.length < 6) ? 'Min 6 characters' : null,
                        ),
                        const SizedBox(height: 16),
                        _label(c, 'Confirm Password'),
                        TextFormField(
                          controller: _confirmCtrl, obscureText: _obscureConfirm, onFieldSubmitted: (_) => _createAccount(),
                          decoration: _deco(c, 'Confirm password', Icons.lock_outline).copyWith(
                            suffixIcon: IconButton(icon: Icon(_obscureConfirm ? Icons.visibility_off_outlined : Icons.visibility_outlined, color: c.textTertiary, size: 20), onPressed: () => setState(() => _obscureConfirm = !_obscureConfirm)),
                          ),
                          validator: (v) => v != _passCtrl.text ? 'Passwords do not match' : null,
                        ),
                        const SizedBox(height: 24),
                        SizedBox(
                          width: double.infinity, height: 50,
                          child: ElevatedButton(
                            onPressed: _isLoading ? null : _createAccount,
                            style: ElevatedButton.styleFrom(backgroundColor: c.primary, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)), elevation: 0),
                            child: _isLoading
                                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                                : const Text('Create Account', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
                          ),
                        ),
                        const SizedBox(height: 16),
                        Center(
                          child: Row(mainAxisSize: MainAxisSize.min, children: [
                            Text('Already have an account? ', style: TextStyle(color: c.textSecondary, fontSize: 14)),
                            GestureDetector(onTap: () => Navigator.pop(context), child: Text('Sign In', style: TextStyle(color: c.primary, fontWeight: FontWeight.bold, fontSize: 14))),
                          ]),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 32),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _label(AppColors c, String t) => Padding(padding: const EdgeInsets.only(bottom: 8), child: Text(t, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: c.textPrimary)));

  InputDecoration _deco(AppColors c, String hint, IconData icon) => InputDecoration(
    hintText: hint, hintStyle: TextStyle(color: c.textTertiary, fontSize: 14),
    prefixIcon: Icon(icon, color: c.textTertiary, size: 20),
    filled: true, fillColor: c.surfaceVariant,
    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: c.primary, width: 1.5)),
    errorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: c.error)),
    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
  );
}
