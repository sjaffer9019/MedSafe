import 'package:flutter/material.dart';
import '../core/app_colors.dart';
import '../core/app_transitions.dart';
import '../models/medicine_model.dart';
import 'package:provider/provider.dart';
import '../providers/medicine_provider.dart';
import '../providers/adherence_provider.dart';
import '../providers/alerts_provider.dart';
import '../providers/user_provider.dart';
import '../providers/medicine_dose_provider.dart';
import '../services/dose_scheduler_service.dart';
import 'add_medicine_screen.dart';
import 'medicines_screen.dart';
import 'alerts_screen.dart';
import 'weekly_report_screen.dart';
import 'profile_screen.dart';
import 'safety_screen.dart';
import 'medicine_detail_screen.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> with WidgetsBindingObserver {
  int _currentIndex = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadAll();
      _startScheduler();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    DoseSchedulerService.instance.stop();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      // Force check when app comes to foreground
      DoseSchedulerService.instance.forceCheck();
    }
  }

  void _loadAll() {
    context.read<MedicineProvider>().loadMedicines();
    context.read<AdherenceProvider>().loadAdherence();
    context.read<AlertsProvider>().loadAlerts();
    context.read<UserProvider>().loadUser();
    context.read<MedicineDoseProvider>().loadAll();
  }

  void _startScheduler() {
    DoseSchedulerService.instance.start(
      onUpdate: () {
        if (mounted) {
          context.read<MedicineDoseProvider>().loadAll();
          context.read<AlertsProvider>().loadAlerts();
        }
      },
    );
  }

  late final List<Widget> _pages = [
    const _DashboardHome(),
    const MedicinesScreen(),
    const AlertsScreen(),
    const WeeklyReportScreen(),
    const SafetyScreen(),
    const ProfileScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    final alertCount = context.watch<AlertsProvider>().badgeCount;
    final c = AppColors.of(context);

    return Scaffold(
      backgroundColor: c.background,
      body: IndexedStack(index: _currentIndex, children: _pages),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: c.surface,
          boxShadow: [
            BoxShadow(
                color: c.shadow,
                blurRadius: 12,
                offset: const Offset(0, -2))
          ],
        ),
        child: SafeArea(
          top: false,
          child: BottomNavigationBar(
            currentIndex: _currentIndex,
            onTap: (i) => setState(() => _currentIndex = i),
            type: BottomNavigationBarType.fixed,
            backgroundColor: c.surface,
            selectedItemColor: c.primary,
            unselectedItemColor: c.textTertiary,
            selectedLabelStyle:
                const TextStyle(fontWeight: FontWeight.w600, fontSize: 11),
            unselectedLabelStyle: const TextStyle(fontSize: 11),
            elevation: 0,
            items: [
              const BottomNavigationBarItem(
                  icon: Icon(Icons.home_rounded), label: 'Home'),
              const BottomNavigationBarItem(
                  icon: Icon(Icons.medication_rounded), label: 'Meds'),
              BottomNavigationBarItem(
                icon: Stack(children: [
                  const Icon(Icons.notifications_rounded),
                  if (alertCount > 0)
                    Positioned(
                      right: 0,
                      top: 0,
                      child: Container(
                        padding: const EdgeInsets.all(2),
                        decoration: BoxDecoration(
                            color: c.error,
                            shape: BoxShape.circle),
                        constraints: const BoxConstraints(
                            minWidth: 16, minHeight: 16),
                        child: Text(
                          alertCount > 9 ? '9+' : '$alertCount',
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 9,
                              fontWeight: FontWeight.bold),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                ]),
                label: 'Alerts',
              ),
              const BottomNavigationBarItem(
                  icon: Icon(Icons.bar_chart_rounded), label: 'Stats'),
              const BottomNavigationBarItem(
                  icon: Icon(Icons.shield_outlined), label: 'Safety'),
              const BottomNavigationBarItem(
                  icon: Icon(Icons.person_rounded), label: 'Profile'),
            ],
          ),
        ),
      ),
    );
  }
}

// ────────────────────────────────────────────────────────────
//  DASHBOARD HOME — Dynamic stats from MedicineDoseProvider
// ────────────────────────────────────────────────────────────
class _DashboardHome extends StatelessWidget {
  const _DashboardHome();

  @override
  Widget build(BuildContext context) {
    final medProv = context.watch<MedicineProvider>();
    final doseProv = context.watch<MedicineDoseProvider>();
    final alertProv = context.watch<AlertsProvider>();
    final userProv = context.watch<UserProvider>();
    final c = AppColors.of(context);

    final taken = doseProv.takenCount;
    final missed = doseProv.missedCount;
    final pending = doseProv.pendingCount;
    final adherence = doseProv.weeklyAdherence;

    return Column(
      children: [
        // ── Blue Header ──
        Container(
          padding: const EdgeInsets.fromLTRB(20, 40, 20, 14),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [c.primaryDark, c.primary],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Welcome Back',
                            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                                color: Colors.white)),
                        const SizedBox(height: 2),
                        Text(userProv.name,
                            style: const TextStyle(
                                fontSize: 14, color: Colors.white70)),
                      ]),
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        shape: BoxShape.circle),
                    child: const Icon(Icons.person,
                        color: Colors.white, size: 22),
                  ),
                ],
              ),
              if (alertProv.pendingReminderCount > 0) ...[
                const SizedBox(height: 12),
                GestureDetector(
                  onTap: () {
                    // Navigate to alerts tab (index 2)
                    final dashState = context.findAncestorStateOfType<_DashboardScreenState>();
                    dashState?.setState(() => dashState._currentIndex = 2);
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(10)),
                    child: Row(children: [
                      const Icon(Icons.medication_rounded,
                          color: Colors.white, size: 18),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                  '${alertProv.pendingReminderCount} Dose${alertProv.pendingReminderCount > 1 ? 's' : ''} Need Your Response',
                                  style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14)),
                              const Text(
                                  'Tap to respond →',
                                  style: TextStyle(
                                      color: Colors.white70,
                                      fontSize: 12)),
                            ]),
                      ),
                    ]),
                  ),
                ),
              ] else if (alertProv.count > 0) ...[
                const SizedBox(height: 12),
                GestureDetector(
                  onTap: () {
                    final dashState = context.findAncestorStateOfType<_DashboardScreenState>();
                    dashState?.setState(() => dashState._currentIndex = 2);
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(10)),
                    child: Row(children: [
                      const Icon(Icons.warning_amber_rounded,
                          color: Colors.white, size: 18),
                      const SizedBox(width: 10),
                      Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                                '${alertProv.count} Alert${alertProv.count > 1 ? 's' : ''} Pending',
                                style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14)),
                            const Text(
                                'Tap to view details →',
                                style: TextStyle(
                                    color: Colors.white70,
                                    fontSize: 12)),
                          ]),
                    ]),
                  ),
                ),
              ],
            ],
          ),
        ),

        // ── Body ──
        Expanded(
          child: RefreshIndicator(
            color: c.primary,
            onRefresh: () async {
              await medProv.loadMedicines();
              await doseProv.loadAll();
              await alertProv.loadAlerts();
              await DoseSchedulerService.instance.forceCheck();
            },
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _header(context, "Today's Doses"),
                  const SizedBox(height: 10),
                  Row(children: [
                    Expanded(child: _tile(context, 'Taken', taken.toString(), c.success, c.successBg, Icons.check_circle_outlined)),
                    const SizedBox(width: 12),
                    Expanded(child: _tile(context, 'Missed', missed.toString(), c.error, c.errorBg, Icons.cancel_outlined)),
                    const SizedBox(width: 12),
                    Expanded(child: _tile(context, 'Pending', pending.toString(), c.warning, c.warningBg, Icons.access_time_outlined)),
                  ]),
                  const SizedBox(height: 20),
                  _header(context, 'Adherence Rate'),
                  const SizedBox(height: 10),
                  _adherenceCard(context, adherence),
                  const SizedBox(height: 20),
                  _header(context, 'Upcoming Doses'),
                  const SizedBox(height: 10),
                  if (medProv.medicines.isEmpty)
                    _emptyDoses(context)
                  else
                    ..._buildUpcomingDoses(context, medProv, doseProv),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  List<Widget> _buildUpcomingDoses(
      BuildContext context, MedicineProvider medProv, MedicineDoseProvider doseProv) {
    // Show pending doses first, then upcoming medicines
    final pendingDoses = doseProv.todayDoses
        .where((d) => d.status == 'pending')
        .toList();

    if (pendingDoses.isEmpty) {
      // Show next active medicines only (skip paused)
      final activeMeds = medProv.medicines.where((m) => m.isActive).toList();
      return activeMeds
          .map((m) => _doseCard(
              m.name,
              m.dosage,
              m.times.isNotEmpty ? m.times.first : '-',
              'Scheduled',
              medicine: m))
          .toList();
    }

    // Map medicine IDs to names
    final medMap = {
      for (final m in medProv.medicines)
        if (m.id != null) m.id!: m
    };

    return pendingDoses.map((dose) {
      final med = medMap[dose.medicineId];
      return _doseCard(
        med?.name ?? 'Medicine #${dose.medicineId}',
        med?.dosage ?? '',
        dose.scheduledTime,
        'Pending',
        medicine: med,
      );
    }).toList();
  }

  Widget _header(BuildContext context, String t) {
    final c = AppColors.of(context);
    return Text(t, style: Theme.of(context).textTheme.titleLarge?.copyWith(color: c.textPrimary));
  }

  Widget _tile(BuildContext context, String label, String count, Color color, Color bg, IconData icon) {
    final c = AppColors.of(context);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
          color: c.card,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [BoxShadow(color: c.shadow, blurRadius: 8, offset: const Offset(0, 2))]),
      child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(color: bg, shape: BoxShape.circle),
                child: Icon(icon, color: color, size: 18)),
            const SizedBox(height: 10),
            Text(label, style: TextStyle(fontSize: 12, color: c.textSecondary)),
            Text(count, style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: color)),
          ]),
    );
  }

  Widget _adherenceCard(BuildContext context, double adherence) {
    final c = AppColors.of(context);
    final pct = adherence.clamp(0.0, 100.0);
    final color = pct >= 80 ? c.success : pct >= 60 ? c.warning : c.error;
    final msg = pct >= 80
        ? "Great job! You're above your target of 80%"
        : pct >= 60
            ? 'Keep going — try to reach 80% this week'
            : pct > 0
                ? 'Adherence is low — please take your medicines'
                : 'No dose data yet. Take your medicines on time!';
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
          color: c.card,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [BoxShadow(color: c.shadow, blurRadius: 8, offset: const Offset(0, 2))]),
      child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Weekly Progress', style: TextStyle(fontSize: 14, color: c.textSecondary, fontWeight: FontWeight.w500)),
                  Text('${pct.round()}%', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: color)),
                ]),
            const SizedBox(height: 10),
            ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: LinearProgressIndicator(
                    value: pct / 100,
                    minHeight: 8,
                    backgroundColor: c.divider,
                    valueColor: AlwaysStoppedAnimation<Color>(color))),
            const SizedBox(height: 10),
            Text(msg, style: TextStyle(fontSize: 13, color: c.textSecondary)),
          ]),
    );
  }

  Widget _doseCard(String name, String dosage, String time, String badge, {Medicine? medicine}) {
    return Builder(builder: (context) {
      final c = AppColors.of(context);
      return GestureDetector(
        onTap: medicine != null
            ? () => Navigator.push(context, AppPageRoute(page: MedicineDetailScreen(medicine: medicine)))
            : null,
        child: Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
              color: c.card,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [BoxShadow(color: c.shadow, blurRadius: 8, offset: const Offset(0, 2))]),
          child: Row(children: [
            Container(
                width: 42, height: 42,
                decoration: BoxDecoration(color: c.primary, shape: BoxShape.circle),
                child: const Icon(Icons.medication_rounded, color: Colors.white, size: 22)),
            const SizedBox(width: 14),
            Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                  Text(name, style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: c.textPrimary)),
                  if (dosage.isNotEmpty)
                    Text(dosage, style: TextStyle(fontSize: 13, color: c.textSecondary)),
                ])),
            Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
              Row(children: [
                Icon(Icons.access_time, size: 14, color: c.textSecondary),
                const SizedBox(width: 4),
                Text(time, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: c.textPrimary)),
              ]),
              const SizedBox(height: 4),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                    color: badge == 'Pending' ? c.warningBg : c.primaryLight,
                    borderRadius: BorderRadius.circular(6)),
                child: Text(badge,
                    style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: badge == 'Pending' ? c.warning : c.primary)),
              ),
            ]),
          ]),
        ),
      );
    });
  }

  Widget _emptyDoses(BuildContext context) {
    final c = AppColors.of(context);
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: c.card, borderRadius: BorderRadius.circular(12)),
      child: Center(
          child: Column(children: [
        Icon(Icons.medication_outlined, size: 40, color: c.textTertiary),
        const SizedBox(height: 8),
        Text('No medicines added', style: TextStyle(color: c.textSecondary)),
        const SizedBox(height: 8),
        TextButton(
          onPressed: () => Navigator.push(context, AppPageRoute(page: const AddMedicineScreen())),
          child: Text('+ Add Medicine', style: TextStyle(color: c.primary, fontWeight: FontWeight.bold)),
        ),
      ])),
    );
  }
}
