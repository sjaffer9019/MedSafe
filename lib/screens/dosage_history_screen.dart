import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../core/app_colors.dart';
import '../models/medicine_dose_model.dart';
import '../providers/medicine_dose_provider.dart';
import '../providers/medicine_provider.dart';

class DosageHistoryScreen extends StatefulWidget {
  const DosageHistoryScreen({super.key});

  @override
  State<DosageHistoryScreen> createState() => _DosageHistoryScreenState();
}

class _DosageHistoryScreenState extends State<DosageHistoryScreen> {
  String _filter = 'all'; // all, taken, missed, pending

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<MedicineDoseProvider>().loadAll();
    });
  }

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final doseProv = context.watch<MedicineDoseProvider>();
    final medProv = context.watch<MedicineProvider>();

    // Build medicine name map
    final nameMap = <int, String>{};
    for (final m in medProv.medicines) {
      if (m.id != null) nameMap[m.id!] = m.name;
    }

    // Get and filter doses
    List<MedicineDose> doses = List.from(doseProv.last7DaysDoses);
    if (_filter != 'all') {
      doses = doses.where((d) => d.status == _filter).toList();
    }

    // Sort: newest first
    doses.sort((a, b) {
      final dateCmp = b.scheduledDate.compareTo(a.scheduledDate);
      if (dateCmp != 0) return dateCmp;
      return b.scheduledTime.compareTo(a.scheduledTime);
    });

    // Group by date
    final grouped = <String, List<MedicineDose>>{};
    for (final d in doses) {
      grouped.putIfAbsent(d.scheduledDate, () => []).add(d);
    }

    final takenCount = doseProv.last7DaysDoses.where((d) => d.isTaken).length;
    final missedCount = doseProv.last7DaysDoses.where((d) => d.isMissed).length;
    final pendingCount = doseProv.last7DaysDoses.where((d) => d.isPending).length;

    return Scaffold(
      backgroundColor: c.background,
      body: Column(
        children: [
          // ── Header ──
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
                Row(
                  children: [
                    InkWell(
                      onTap: () => Navigator.pop(context),
                      child: const Icon(Icons.arrow_back, color: Colors.white),
                    ),
                    const SizedBox(width: 12),
                    const Icon(Icons.history_rounded, color: Colors.white, size: 22),
                    const SizedBox(width: 10),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Dosage History',
                              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white)),
                          Text('Last 7 days', style: TextStyle(fontSize: 12, color: Colors.white70)),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // ── Filter Chips ──
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            color: c.surface,
            child: Row(
              children: [
                _filterChip(c, 'All', 'all', doses.length, c.primary),
                const SizedBox(width: 8),
                _filterChip(c, 'Taken', 'taken', takenCount, c.success),
                const SizedBox(width: 8),
                _filterChip(c, 'Missed', 'missed', missedCount, c.error),
                const SizedBox(width: 8),
                _filterChip(c, 'Pending', 'pending', pendingCount, c.warning),
              ],
            ),
          ),

          // ── Body ──
          Expanded(
            child: doseProv.isLoading
                ? Center(child: CircularProgressIndicator(color: c.primary))
                : doses.isEmpty
                    ? _buildEmpty(c)
                    : ListView.builder(
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                        itemCount: grouped.keys.length,
                        itemBuilder: (context, index) {
                          final dateStr = grouped.keys.elementAt(index);
                          final dayDoses = grouped[dateStr]!;
                          return _buildDateGroup(c, dateStr, dayDoses, nameMap);
                        },
                      ),
          ),
        ],
      ),
    );
  }

  // ── Filter Chip ──
  Widget _filterChip(AppColors c, String label, String value, int count, Color color) {
    final isSelected = _filter == value;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _filter = value),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: isSelected ? color.withOpacity(0.15) : c.surfaceVariant,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: isSelected ? color.withOpacity(0.4) : Colors.transparent,
              width: 1.5,
            ),
          ),
          child: Column(
            children: [
              Icon(
                value == 'taken'
                    ? Icons.check_circle
                    : value == 'missed'
                        ? Icons.cancel
                        : value == 'pending'
                            ? Icons.schedule
                            : Icons.list_alt,
                color: isSelected ? color : c.textTertiary,
                size: 20,
              ),
              const SizedBox(height: 4),
              Text('$count',
                  style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: isSelected ? color : c.textSecondary)),
              Text(label,
                  style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: isSelected ? color : c.textTertiary)),
            ],
          ),
        ),
      ),
    );
  }

  // ── Date Group ──
  Widget _buildDateGroup(AppColors c, String dateStr, List<MedicineDose> doses, Map<int, String> nameMap) {
    String label;
    final now = DateTime.now();
    final todayStr = DateFormat('yyyy-MM-dd').format(now);
    final yesterdayStr = DateFormat('yyyy-MM-dd').format(now.subtract(const Duration(days: 1)));

    if (dateStr == todayStr) {
      label = 'Today';
    } else if (dateStr == yesterdayStr) {
      label = 'Yesterday';
    } else {
      try {
        label = DateFormat('EEE, MMM d').format(DateTime.parse(dateStr));
      } catch (_) {
        label = dateStr;
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 12, bottom: 8, left: 4),
          child: Text(label,
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: c.textSecondary)),
        ),
        ...doses.map((dose) => _buildDoseCard(c, dose, nameMap)),
      ],
    );
  }

  // ── Dose Card ──
  Widget _buildDoseCard(AppColors c, MedicineDose dose, Map<int, String> nameMap) {
    final medicineName = nameMap[dose.medicineId] ?? 'Medicine #${dose.medicineId}';

    Color statusColor;
    IconData statusIcon;
    String statusLabel;

    if (dose.isTaken) {
      statusColor = c.success;
      statusIcon = Icons.check_circle_rounded;
      statusLabel = 'Taken';
    } else if (dose.isMissed) {
      statusColor = c.error;
      statusIcon = Icons.cancel_rounded;
      statusLabel = 'Missed';
    } else {
      statusColor = c.warning;
      statusIcon = Icons.schedule_rounded;
      statusLabel = 'Pending';
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: c.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: c.divider.withOpacity(0.5)),
        boxShadow: [BoxShadow(color: c.shadow, blurRadius: 4, offset: const Offset(0, 1))],
      ),
      child: Row(
        children: [
          // Status icon
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: statusColor.withOpacity(0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(statusIcon, color: statusColor, size: 22),
          ),
          const SizedBox(width: 12),

          // Medicine name + time
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(medicineName,
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: c.textPrimary),
                    overflow: TextOverflow.ellipsis),
                const SizedBox(height: 3),
                Row(
                  children: [
                    Icon(Icons.schedule, size: 12, color: c.textTertiary),
                    const SizedBox(width: 4),
                    Text(dose.scheduledTime,
                        style: TextStyle(fontSize: 12, color: c.textSecondary)),
                  ],
                ),
              ],
            ),
          ),

          // Status badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: statusColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: statusColor.withOpacity(0.3)),
            ),
            child: Text(statusLabel,
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: statusColor)),
          ),
        ],
      ),
    );
  }

  Widget _buildEmpty(AppColors c) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.inbox_outlined, size: 48, color: c.textTertiary),
          const SizedBox(height: 12),
          Text('No doses found',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: c.textSecondary)),
          const SizedBox(height: 4),
          Text('Try a different filter',
              style: TextStyle(fontSize: 13, color: c.textTertiary)),
        ],
      ),
    );
  }
}
