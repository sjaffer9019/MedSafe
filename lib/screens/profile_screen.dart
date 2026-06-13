import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../core/app_colors.dart';
import '../core/app_transitions.dart';
import '../providers/user_provider.dart';
import '../providers/settings_provider.dart';
import '../services/notification_service.dart';
import 'login_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameCtrl;
  late TextEditingController _phoneCtrl;
  bool _editing = false;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final user = context.read<UserProvider>();
    _nameCtrl = TextEditingController(text: user.name == 'User' ? '' : user.name);
    _phoneCtrl = TextEditingController(text: user.phone);
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      await context.read<UserProvider>().updateProfile(
        name: _nameCtrl.text.trim(),
        phone: _phoneCtrl.text.trim(),
      );
      if (mounted) {
        setState(() => _editing = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: const Text('Profile updated ✓'),
          backgroundColor: AppColors.of(context).success,
          behavior: SnackBarBehavior.floating,
        ));
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: const Text('Failed to save'),
          backgroundColor: AppColors.of(context).error,
        ));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _logout() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Logout'),
        content: const Text('Are you sure you want to log out?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.of(context).error),
            child: const Text('Logout', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    if (confirmed == true && mounted) {
      await Supabase.instance.client.auth.signOut();
      if (!mounted) return;
      Navigator.pushAndRemoveUntil(context, AppPageRoute(page: const LoginScreen()), (_) => false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<UserProvider>();
    final settings = context.watch<SettingsProvider>();
    final email = Supabase.instance.client.auth.currentUser?.email ?? user.email;
    final c = AppColors.of(context);

    return Column(
      children: [
        // ── Header (no edit icon) ──
        Container(
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(20, 40, 20, 14),
          decoration: BoxDecoration(
            gradient: LinearGradient(colors: [c.primaryDark, c.primary], begin: Alignment.topLeft, end: Alignment.bottomRight),
          ),
          child: Row(
            children: [
              Container(
                width: 56, height: 56,
                decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), shape: BoxShape.circle),
                child: const Icon(Icons.person, color: Colors.white, size: 30),
              ),
              const SizedBox(width: 16),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(user.name, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white)),
                Text(email, style: const TextStyle(fontSize: 13, color: Colors.white70)),
              ])),
            ],
          ),
        ),

        // ── Body ──
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(children: [
              // ── Account Info Card ──
              Container(
                decoration: BoxDecoration(
                  color: c.card,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [BoxShadow(color: c.shadow, blurRadius: 8, offset: const Offset(0, 2))],
                ),
                child: _editing ? _buildEditForm(c) : _buildAccountInfo(c, user, email),
              ),
              const SizedBox(height: 16),

              // ── Settings Card ──
              Container(
                decoration: BoxDecoration(
                  color: c.card,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [BoxShadow(color: c.shadow, blurRadius: 8, offset: const Offset(0, 2))],
                ),
                child: Column(children: [
                  // Section header
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 14, 16, 4),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Text('Preferences', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: c.textSecondary)),
                    ),
                  ),
                  // Notifications toggle
                  SwitchListTile(
                    activeColor: c.primary,
                    secondary: Icon(Icons.notifications_active_outlined, color: c.textSecondary),
                    title: Text('Push Notifications', style: TextStyle(fontWeight: FontWeight.w500, fontSize: 14, color: c.textPrimary)),
                    subtitle: Text(settings.notificationsEnabled ? 'Enabled' : 'Disabled',
                        style: TextStyle(fontSize: 11, color: c.textTertiary)),
                    value: settings.notificationsEnabled,
                    onChanged: (v) {
                      settings.setNotificationsEnabled(v);
                      NotificationService.enabled = v;
                    },
                  ),
                  Divider(height: 1, color: c.divider),
                  // Sound toggle
                  SwitchListTile(
                    activeColor: c.primary,
                    secondary: Icon(Icons.volume_up_outlined, color: c.textSecondary),
                    title: Text('Reminder Sounds', style: TextStyle(fontWeight: FontWeight.w500, fontSize: 14, color: c.textPrimary)),
                    subtitle: Text(settings.soundEnabled ? 'Sound on' : 'Silent',
                        style: TextStyle(fontSize: 11, color: c.textTertiary)),
                    value: settings.soundEnabled,
                    onChanged: (v) {
                      settings.setSoundEnabled(v);
                      NotificationService.soundOn = v;
                    },
                  ),
                  Divider(height: 1, color: c.divider),
                  // Theme toggle
                  ListTile(
                    leading: Icon(
                      settings.themeMode == ThemeMode.dark
                          ? Icons.dark_mode
                          : settings.themeMode == ThemeMode.light
                              ? Icons.light_mode
                              : Icons.brightness_auto,
                      color: c.textSecondary,
                    ),
                    title: Text('Theme', style: TextStyle(fontWeight: FontWeight.w500, fontSize: 14, color: c.textPrimary)),
                    subtitle: Text(settings.themeModeLabel,
                        style: TextStyle(fontSize: 11, color: c.textTertiary)),
                    trailing: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: c.primary.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(settings.themeModeLabel,
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: c.primary)),
                    ),
                    onTap: () => settings.cycleTheme(),
                  ),
                ]),
              ),
              const SizedBox(height: 16),

              // ── Logout Card ──
              Container(
                decoration: BoxDecoration(
                  color: c.card,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [BoxShadow(color: c.shadow, blurRadius: 8, offset: const Offset(0, 2))],
                ),
                child: ListTile(
                  leading: Icon(Icons.logout, color: c.error),
                  title: Text('Logout', style: TextStyle(fontWeight: FontWeight.bold, color: c.error)),
                  trailing: Icon(Icons.chevron_right, color: c.textTertiary),
                  onTap: _logout,
                ),
              ),
              const SizedBox(height: 24),
              Text('Medsafe v1.0.0', style: TextStyle(color: c.textTertiary, fontSize: 12)),
            ]),
          ),
        ),
      ],
    );
  }

  // ── Account Info (view mode) ──
  Widget _buildAccountInfo(AppColors c, UserProvider user, String email) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.person_outline, color: c.primary, size: 20),
              const SizedBox(width: 8),
              Text('Account Info', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: c.textPrimary)),
              const Spacer(),
              GestureDetector(
                onTap: () {
                  _nameCtrl.text = user.name == 'User' ? '' : user.name;
                  _phoneCtrl.text = user.phone;
                  setState(() => _editing = true);
                },
                child: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: c.primary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(Icons.edit_outlined, size: 18, color: c.primary),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _infoRow(c, Icons.person, 'Full Name', user.name),
          const SizedBox(height: 12),
          _infoRow(c, Icons.email_outlined, 'Email', email),
          const SizedBox(height: 12),
          _infoRow(c, Icons.phone_outlined, 'Phone', user.phone.isEmpty ? 'Not set' : user.phone),
        ],
      ),
    );
  }

  Widget _infoRow(AppColors c, IconData icon, String label, String value) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: c.surfaceVariant,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, size: 16, color: c.textSecondary),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: TextStyle(fontSize: 11, color: c.textTertiary)),
              Text(value, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: c.textPrimary)),
            ],
          ),
        ),
      ],
    );
  }

  // ── Edit Form ──
  Widget _buildEditForm(AppColors c) {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.edit, color: c.primary, size: 20),
                const SizedBox(width: 8),
                Text('Edit Profile', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: c.textPrimary)),
              ],
            ),
            const SizedBox(height: 16),
            _label(c, 'Full Name'),
            TextFormField(
              controller: _nameCtrl,
              decoration: _deco(c, 'Your name', Icons.person_outline),
              validator: (v) => (v == null || v.isEmpty) ? 'Required' : null,
            ),
            const SizedBox(height: 16),
            _label(c, 'Phone'),
            TextFormField(
              controller: _phoneCtrl,
              keyboardType: TextInputType.phone,
              decoration: _deco(c, 'Your phone', Icons.phone_outlined),
            ),
            const SizedBox(height: 20),
            Row(children: [
              Expanded(child: OutlinedButton(
                onPressed: () => setState(() => _editing = false),
                style: OutlinedButton.styleFrom(shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
                child: const Text('Cancel'),
              )),
              const SizedBox(width: 12),
              Expanded(child: ElevatedButton(
                onPressed: _saving ? null : _save,
                style: ElevatedButton.styleFrom(backgroundColor: c.primary, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
                child: _saving
                    ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : const Text('Save', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              )),
            ]),
          ],
        ),
      ),
    );
  }

  Widget _label(AppColors c, String t) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Text(t, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: c.textPrimary)),
  );

  InputDecoration _deco(AppColors c, String hint, IconData icon) => InputDecoration(
    hintText: hint, hintStyle: TextStyle(color: c.textTertiary, fontSize: 14),
    prefixIcon: Icon(icon, color: c.textTertiary, size: 20),
    filled: true, fillColor: c.surfaceVariant,
    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: c.primary, width: 1.5)),
    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
  );
}
