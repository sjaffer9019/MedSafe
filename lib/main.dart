import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'core/app_theme.dart';
import 'providers/medicine_provider.dart';
import 'providers/adherence_provider.dart';
import 'providers/alerts_provider.dart';
import 'providers/user_provider.dart';
import 'providers/medicine_dose_provider.dart';
import 'providers/settings_provider.dart';
import 'screens/splash_screen.dart';
import 'services/notification_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Supabase.initialize(
  url: 'https://...supabase.co',
  anonKey: 'sb_publishable_...',
);

  await NotificationService().init();

  final settingsProvider = SettingsProvider();
  await settingsProvider.load();
  // Sync settings to notification service
  NotificationService.enabled = settingsProvider.notificationsEnabled;
  NotificationService.soundOn = settingsProvider.soundEnabled;

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => MedicineProvider()),
        ChangeNotifierProvider(create: (_) => AdherenceProvider()),
        ChangeNotifierProvider(create: (_) => AlertsProvider()),
        ChangeNotifierProvider(create: (_) => UserProvider()),
        ChangeNotifierProvider(create: (_) => MedicineDoseProvider()),
        ChangeNotifierProvider.value(value: settingsProvider),
      ],
      child: const MedsafeApp(),
    ),
  );
}

class MedsafeApp extends StatelessWidget {
  const MedsafeApp({super.key});

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsProvider>();
    return MaterialApp(
      title: 'medsafe',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: settings.themeMode,
      home: const SplashScreen(),
    );
  }
}
