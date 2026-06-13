import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/app_colors.dart';
import '../providers/alerts_provider.dart';
import '../providers/medicine_dose_provider.dart';
import '../models/alert_model.dart';

class AlertsScreen extends StatefulWidget {
  const AlertsScreen({super.key});

  @override
  State<AlertsScreen> createState() => _AlertsScreenState();
}

class _AlertsScreenState extends State<AlertsScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<AlertsProvider>().loadAlerts();
    });
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AlertsProvider>();
    final c = AppColors.of(context);

    return Column(
      children: [
        Container(
          width: double.infinity,
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
              Row(children: [
                const Icon(Icons.notifications_rounded, color: Colors.white, size: 22),
                const SizedBox(width: 10),
                const Expanded(
                    child: Text('Notifications',
                        style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white))),
                if (provider.alerts.isNotEmpty)
                  TextButton(
                    onPressed: () => provider.clearAll(),
                    child: const Text('Clear All', style: TextStyle(color: Colors.white70, fontSize: 13)),
                  ),
              ]),
              const SizedBox(height: 4),
              Text(
                provider.pendingReminderCount > 0
                    ? '${provider.pendingReminderCount} dose${provider.pendingReminderCount > 1 ? 's' : ''} awaiting your response'
                    : "Today's updates and reminders",
                style: const TextStyle(fontSize: 13, color: Colors.white70),
              ),
            ],
          ),
        ),

        Expanded(
          child: provider.isLoading
              ? Center(child: CircularProgressIndicator(color: c.primary))
              : provider.alerts.isEmpty
                  ? Center(
                      child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                          Icon(Icons.notifications_none_rounded, size: 64, color: c.textTertiary),
                          const SizedBox(height: 12),
                          Text('No notifications', style: TextStyle(color: c.textSecondary, fontSize: 16)),
                        ]))
                  : RefreshIndicator(
                      color: c.primary,
                      onRefresh: () => provider.loadAlerts(),
                      child: ListView.separated(
                        padding: const EdgeInsets.all(16),
                        itemCount: provider.alerts.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 10),
                        itemBuilder: (_, i) => _buildCard(provider, provider.alerts[i]),
                      ),
                    ),
        ),
      ],
    );
  }

  Widget _buildCard(AlertsProvider provider, Alert alert) {
    // ── Medicine Reminder Card ──
    if (alert.isReminder) {
      return _buildReminderCard(provider, alert);
    }
    // ── Standard Alert Card ──
    return _buildStandardCard(provider, alert);
  }

  // ────────────────────────────────────────────────────────
  Widget _buildReminderCard(AlertsProvider provider, Alert alert) {
    final c = AppColors.of(context);
    final isPending = alert.doseStatus == 'pending';
    final isTaken = alert.doseStatus == 'taken';
    final isMissed = alert.doseStatus == 'missed';

    Color statusColor;
    IconData statusIcon;
    String statusLabel;
    if (isTaken) {
      statusColor = c.success;
      statusIcon = Icons.check_circle_rounded;
      statusLabel = 'Taken';
    } else if (isMissed) {
      statusColor = c.error;
      statusIcon = Icons.cancel_rounded;
      statusLabel = 'Missed';
    } else {
      statusColor = c.warning;
      statusIcon = Icons.access_time_rounded;
      statusLabel = 'Pending';
    }

    String expiryText = '';
    if (isPending && alert.expiresAt != null) {
      final remaining = alert.timeUntilExpiry;
      if (remaining != null && remaining.inMinutes > 0) {
        final hours = remaining.inHours;
        final mins = remaining.inMinutes % 60;
        expiryText = 'Expires in ${hours}h ${mins}m';
      } else {
        expiryText = 'Expiring soon';
      }
    }

    return AnimatedOpacity(
      duration: const Duration(milliseconds: 300),
      opacity: isPending ? 1.0 : 0.75,
      child: Container(
        padding: const EdgeInsets.all(13),
        decoration: BoxDecoration(
          color: c.card,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isPending ? c.warning.withOpacity(0.35) : statusColor.withOpacity(0.15),
            width: 0.8,
          ),
          boxShadow: [BoxShadow(color: c.shadow, blurRadius: 6, offset: const Offset(0, 2))],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 40, height: 40,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: isPending ? [c.primary, c.primaryDark] : [statusColor.withOpacity(0.8), statusColor],
                    ),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.medication_rounded, color: Colors.white, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(alert.medicineName ?? 'Medicine', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: c.textPrimary)),
                      const SizedBox(height: 2),
                      Row(children: [
                        Icon(Icons.access_time, size: 13, color: c.textSecondary),
                        const SizedBox(width: 4),
                        Text(alert.doseTime ?? '', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: c.textSecondary)),
                      ]),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(color: statusColor.withOpacity(0.1), borderRadius: BorderRadius.circular(16)),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    Icon(statusIcon, size: 13, color: statusColor),
                    const SizedBox(width: 3),
                    Text(statusLabel, style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: statusColor)),
                  ]),
                ),
              ],
            ),

            if (isPending && expiryText.isNotEmpty) ...[
              const SizedBox(height: 6),
              Align(
                alignment: Alignment.centerRight,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(color: c.warningBg, borderRadius: BorderRadius.circular(4)),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    Icon(Icons.timer_outlined, size: 10, color: c.warning),
                    const SizedBox(width: 3),
                    Text(expiryText, style: TextStyle(fontSize: 10, color: c.warning, fontWeight: FontWeight.w500)),
                  ]),
                ),
              ),
            ],

            if (isPending && alert.doseId != null) ...[
              const SizedBox(height: 10),
              Row(children: [
                Expanded(child: _actionButton(label: 'Taken', icon: Icons.check_rounded, color: c.success, onTap: () => _handleDoseResponse(provider, alert, 'taken'))),
                const SizedBox(width: 10),
                Expanded(child: _actionButton(label: 'Missed', icon: Icons.close_rounded, color: c.error, onTap: () => _handleDoseResponse(provider, alert, 'missed'))),
              ]),
            ],
          ],
        ),
      ),
    );
  }

  Widget _actionButton({required String label, required IconData icon, required Color color, required VoidCallback onTap}) {
    return Material(
      color: color.withOpacity(0.08),
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          alignment: Alignment.center,
          child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(width: 8),
            Text(label, style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: color)),
          ]),
        ),
      ),
    );
  }

  Future<void> _handleDoseResponse(AlertsProvider provider, Alert alert, String status) async {
    final c = AppColors.of(context);
    try {
      await provider.respondToReminder(alert.id, alert.doseId!, status);
      if (mounted) context.read<MedicineDoseProvider>().loadAll();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(
            status == 'taken' ? '✓ ${alert.medicineName} marked as taken' : '✗ ${alert.medicineName} marked as missed',
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
          backgroundColor: status == 'taken' ? c.success : c.error,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: c.error));
      }
    }
  }

  Widget _buildStandardCard(AlertsProvider provider, Alert alert) {
    final c = AppColors.of(context);
    final isHigh = alert.severity == 'High';
    final isMedium = alert.severity == 'Medium';

    Color iconColor;
    Color iconBg;
    IconData icon;

    if (isHigh) {
      iconColor = c.error;
      iconBg = c.errorBg;
      icon = Icons.warning_rounded;
    } else if (isMedium) {
      iconColor = c.warning;
      iconBg = c.warningBg;
      icon = Icons.info_rounded;
    } else {
      iconColor = c.primary;
      iconBg = c.primaryLight;
      icon = Icons.notifications_rounded;
    }

    final timeStr = '${alert.date.hour.toString().padLeft(2, '0')}:${alert.date.minute.toString().padLeft(2, '0')}';

    return Dismissible(
      key: Key(alert.id),
      direction: DismissDirection.endToStart,
      onDismissed: (_) => provider.dismissAlert(alert.id),
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        decoration: BoxDecoration(color: c.error, borderRadius: BorderRadius.circular(16)),
        child: const Icon(Icons.delete_outline, color: Colors.white, size: 28),
      ),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: c.card,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [BoxShadow(color: c.shadow, blurRadius: 4, offset: const Offset(0, 1))],
        ),
        child: Row(children: [
          Container(
            width: 44, height: 44,
            decoration: BoxDecoration(color: iconBg, shape: BoxShape.circle),
            child: Icon(icon, color: iconColor, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                Expanded(child: Text(alert.severity, style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: c.textPrimary))),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(color: iconBg, borderRadius: BorderRadius.circular(6)),
                  child: Text(alert.severity, style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: iconColor)),
                ),
              ]),
              const SizedBox(height: 4),
              Text(alert.message, style: TextStyle(fontSize: 13, color: c.textSecondary)),
              const SizedBox(height: 6),
              Row(children: [
                Icon(Icons.access_time, size: 13, color: c.textTertiary),
                const SizedBox(width: 4),
                Text(timeStr, style: TextStyle(fontSize: 12, color: c.textTertiary)),
              ]),
            ]),
          ),
        ]),
      ),
    );
  }
}
