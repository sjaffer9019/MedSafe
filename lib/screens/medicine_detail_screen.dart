import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../core/app_colors.dart';
import '../core/app_transitions.dart';
import '../models/medicine_model.dart';
import '../models/medicine_dose_model.dart';
import '../providers/alerts_provider.dart';
import '../providers/medicine_dose_provider.dart';
import '../providers/medicine_provider.dart';
import '../services/rxnorm_service.dart';
import '../services/supabase_service.dart';
import 'add_medicine_screen.dart';

class MedicineDetailScreen extends StatelessWidget {
  final Medicine medicine;

  const MedicineDetailScreen({super.key, required this.medicine});

  static const double _padding = 16.0;
  static const double _borderRadius = 12.0;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return Scaffold(
      backgroundColor: c.background,
      appBar: AppBar(
        title: Text('Medicine Details',
            style: TextStyle(fontWeight: FontWeight.bold, color: c.textPrimary)),
        backgroundColor: c.surface,
        elevation: 0,
        iconTheme: IconThemeData(color: c.textPrimary),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(_padding),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildHeaderCard(c),
              if (medicine.notes.isNotEmpty) ...[
                const SizedBox(height: 16),
                _buildNotesCard(c),
              ],
              const SizedBox(height: 24),
              _buildScheduleCard(c),
              const SizedBox(height: 24),
              _buildDoseHistoryCard(c),
              const SizedBox(height: 24),
              _buildInteractionWarningCard(),
              const SizedBox(height: 32),
              _buildActionButtons(context, c),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionTitle(AppColors c, String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0, left: 4),
      child: Text(title, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: c.textPrimary)),
    );
  }

  Widget _buildHeaderCard(AppColors c) {
    return Card(
      elevation: 2,
      shadowColor: c.shadow,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(_borderRadius)),
      color: c.card,
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(medicine.name, style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: c.textPrimary)),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: medicine.isCompleted
                        ? c.textTertiary.withOpacity(0.1)
                        : medicine.isPaused
                            ? c.warning.withOpacity(0.1)
                            : medicine.isActive
                                ? c.success.withOpacity(0.1)
                                : c.textTertiary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: medicine.isCompleted
                        ? c.textTertiary.withOpacity(0.3)
                        : medicine.isPaused
                            ? c.warning.withOpacity(0.3)
                            : medicine.isActive
                                ? c.success.withOpacity(0.3)
                                : c.textTertiary.withOpacity(0.3)),
                  ),
                  child: Text(
                      medicine.isCompleted ? 'Completed' : medicine.isPaused ? 'Paused' : medicine.isActive ? 'Active' : 'Completed',
                      style: TextStyle(
                        color: medicine.isCompleted
                            ? c.textTertiary
                            : medicine.isPaused ? c.warning : medicine.isActive ? c.success : c.textTertiary,
                        fontWeight: FontWeight.bold,
                      )),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(Icons.medication_liquid, color: c.textSecondary, size: 20),
                const SizedBox(width: 8),
                Text(medicine.dosage, style: TextStyle(fontSize: 16, color: c.textSecondary)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNotesCard(AppColors c) {
    return Builder(
      builder: (context) => Card(
        elevation: 1,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(_borderRadius)),
        color: c.card,
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(color: c.primary.withOpacity(0.1), shape: BoxShape.circle),
                child: Icon(Icons.notes_rounded, color: c.primary, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Notes', style: TextStyle(color: c.textSecondary, fontSize: 13)),
                    const SizedBox(height: 4),
                    Text(medicine.notes, style: TextStyle(fontSize: 15, color: c.textPrimary, height: 1.4)),
                  ],
                ),
              ),
              GestureDetector(
                onTap: () => Navigator.push(context, AppPageRoute(page: AddMedicineScreen(editMedicine: medicine))),
                child: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: c.primary.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(Icons.edit_outlined, color: c.primary, size: 16),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildScheduleCard(AppColors c) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle(c, 'Schedule'),
        Card(
          elevation: 1,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(_borderRadius)),
          color: c.card,
          child: Padding(
            padding: const EdgeInsets.all(_padding),
            child: Column(
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(color: c.primary.withOpacity(0.1), shape: BoxShape.circle),
                      child: Icon(Icons.schedule, color: c.primary),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Dose Times', style: TextStyle(color: c.textSecondary, fontSize: 13)),
                          const SizedBox(height: 2),
                          Text(
                            medicine.times.isNotEmpty ? medicine.times.join(', ') : 'No time set',
                            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: c.textPrimary),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 16.0),
                  child: Divider(color: c.divider),
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _buildDateInfo(c, 'Start Date', _formatDate(medicine.startDate)),
                    _buildDateInfo(c, 'End Date', _formatDate(medicine.endDate)),
                  ],
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(color: c.surfaceVariant, borderRadius: BorderRadius.circular(8)),
                  child: Row(
                    children: [
                      Icon(Icons.repeat, size: 18, color: c.textSecondary),
                      const SizedBox(width: 8),
                      Text('Frequency: ${medicine.frequency}', style: TextStyle(color: c.textPrimary, fontWeight: FontWeight.w500)),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDateInfo(AppColors c, String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(color: c.textSecondary, fontSize: 13)),
        const SizedBox(height: 4),
        Text(value, style: TextStyle(fontWeight: FontWeight.w600, color: c.textPrimary)),
      ],
    );
  }

  String _formatDate(String isoDate) {
    try {
      final date = DateTime.parse(isoDate);
      return "${date.day}/${date.month}/${date.year}";
    } catch (_) {
      return isoDate;
    }
  }

  // ────────────────────────────────────────────────────────
  //  PER-MEDICINE DOSE HISTORY (Last 7 Days)
  //  with manual Taken / Missed toggle
  // ────────────────────────────────────────────────────────
  Widget _buildDoseHistoryCard(AppColors c) {
    if (medicine.id == null) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle(c, 'Last 7 Days Status'),
        _DoseHistoryList(medicine: medicine),
      ],
    );
  }

  Widget _buildInteractionWarningCard() {
    return _InteractionWarningCard(
      medicineName: medicine.name,
      borderRadius: _borderRadius,
      padding: _padding,
    );
  }

  Widget _buildActionButtons(BuildContext context, AppColors c) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: ElevatedButton.icon(
                onPressed: () => Navigator.push(context, AppPageRoute(page: AddMedicineScreen(editMedicine: medicine))),
                icon: const Icon(Icons.edit, color: Colors.white),
                label: const Text('Edit', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: c.primary,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  elevation: 0,
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () => _showPauseConfirmation(context),
                icon: Icon(medicine.isPaused ? Icons.play_arrow : Icons.pause,
                    color: medicine.isPaused ? c.success : c.textPrimary),
                label: Text(medicine.isPaused ? 'Resume' : 'Pause',
                    style: TextStyle(color: medicine.isPaused ? c.success : c.textPrimary, fontSize: 16, fontWeight: FontWeight.bold)),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  side: BorderSide(color: c.divider),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        SizedBox(
          width: double.infinity,
          child: TextButton.icon(
            onPressed: () => _showDeleteConfirmation(context),
            icon: Icon(Icons.delete_outline, color: c.error),
            label: Text('Delete Medicine', style: TextStyle(color: c.error, fontSize: 16, fontWeight: FontWeight.bold)),
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
              backgroundColor: c.error.withOpacity(0.05),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
                side: BorderSide(color: c.error.withOpacity(0.2)),
              ),
            ),
          ),
        )
      ],
    );
  }

  void _showDeleteConfirmation(BuildContext context) {
    final c = AppColors.of(context);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Delete Medicine?'),
        content: Text('Are you sure you want to completely remove ${medicine.name} from your schedule? This will also delete all dose history.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Cancel', style: TextStyle(color: c.textSecondary)),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              if (medicine.id != null) {
                try {
                  await context.read<MedicineProvider>().removeMedicine(medicine.id!);
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                      content: Text('${medicine.name} deleted'),
                      backgroundColor: c.error,
                      behavior: SnackBarBehavior.floating,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ));
                    Navigator.pop(context);
                  }
                } catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: c.error));
                  }
                }
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: c.error),
            child: const Text('Delete', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _showPauseConfirmation(BuildContext context) {
    final c = AppColors.of(context);
    final today = DateTime.now();

    bool isPaused = false;
    try {
      final endDate = DateTime.parse(medicine.endDate);
      isPaused = endDate.isBefore(DateTime(today.year, today.month, today.day));
    } catch (_) {}

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(isPaused ? 'Resume Medicine?' : 'Pause Medicine?'),
        content: Text(isPaused
            ? 'Resume ${medicine.name}? It will be active for the next 30 days.'
            : 'Pause ${medicine.name}? The end date will be set to today, so no more reminders will be created.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Cancel', style: TextStyle(color: c.textSecondary)),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              try {
                final yesterday = today.subtract(const Duration(days: 1));
                final yesterdayStr = '${yesterday.year}-${yesterday.month.toString().padLeft(2, '0')}-${yesterday.day.toString().padLeft(2, '0')}';
                final updated = Medicine(
                  id: medicine.id,
                  name: medicine.name,
                  dosage: medicine.dosage,
                  frequency: medicine.frequency,
                  times: medicine.times,
                  startDate: medicine.startDate,
                  notes: medicine.notes,
                  endDate: isPaused
                      ? today.add(const Duration(days: 30)).toIso8601String().split('T')[0]
                      : yesterdayStr,
                );
                await context.read<MedicineProvider>().updateMedicine(updated);
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                    content: Text(isPaused ? '▶ ${medicine.name} resumed' : '⏸ ${medicine.name} paused'),
                    backgroundColor: isPaused ? c.success : c.warning,
                    behavior: SnackBarBehavior.floating,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ));
                  Navigator.pop(context);
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: c.error));
                }
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: isPaused ? c.success : c.warning),
            child: Text(isPaused ? 'Resume' : 'Pause', style: const TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }
}

// ────────────────────────────────────────────────────────────
//  STATEFUL DOSE HISTORY LIST — Per-Medicine Last 7 Days
//  Shows each day's doses with tappable Taken/Missed toggle
// ────────────────────────────────────────────────────────────
class _DoseHistoryList extends StatefulWidget {
  final Medicine medicine;
  const _DoseHistoryList({required this.medicine});

  @override
  State<_DoseHistoryList> createState() => _DoseHistoryListState();
}

class _DoseHistoryListState extends State<_DoseHistoryList> {
  List<MedicineDose>? _doses;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadDoses();
  }

  Future<void> _loadDoses() async {
    setState(() => _loading = true);
    try {
      final provider = context.read<MedicineDoseProvider>();
      final doses =
          await provider.getDosesForMedicine(widget.medicine.id!);
      if (mounted) {
        setState(() {
          _doses = doses;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      final c = AppColors.of(context);
      return Card(
        color: c.card,
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Center(
              child: CircularProgressIndicator(color: c.primary, strokeWidth: 2)),
        ),
      );
    }

    // Group doses by date
    final today = DateTime.now();
    final Map<String, List<MedicineDose>> grouped = {};
    if (_doses != null) {
      for (final dose in _doses!) {
        grouped.putIfAbsent(dose.scheduledDate, () => []).add(dose);
      }
    }

    // Build rows for last 7 days
    final List<_DayEntry> entries = [];
    DateTime parsedStart;
    try {
      parsedStart = DateTime.parse(widget.medicine.startDate);
    } catch (_) {
      parsedStart = today;
    }
    final startDay = DateTime(
        parsedStart.year, parsedStart.month, parsedStart.day);

    // Parse end date to skip days after medicine ended
    DateTime parsedEnd;
    try {
      parsedEnd = DateTime.parse(widget.medicine.endDate);
    } catch (_) {
      parsedEnd = today.add(const Duration(days: 365));
    }
    final endDay = DateTime(parsedEnd.year, parsedEnd.month, parsedEnd.day);

    for (int i = 0; i < 7; i++) {
      final date = today.subtract(Duration(days: i));
      final dateStr = DateFormat('yyyy-MM-dd').format(date);
      final currentDay = DateTime(date.year, date.month, date.day);

      if (currentDay.isBefore(startDay)) continue;
      // Skip days after the medicine ended (don't show "No doses" for those)
      if (currentDay.isAfter(endDay)) continue;

      String label;
      if (i == 0) {
        label = 'Today';
      } else if (i == 1) {
        label = 'Yesterday';
      } else {
        label = DateFormat('MMM d').format(date);
      }

      final doses = grouped[dateStr] ?? [];
      entries.add(_DayEntry(label: label, date: dateStr, doses: doses));
    }

    final c = AppColors.of(context);

    if (entries.isEmpty) {
      return Card(
        elevation: 1,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        color: c.card,
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Text('No dose history available yet.', style: TextStyle(color: c.textSecondary)),
        ),
      );
    }

    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      color: c.card,
      child: ListView.separated(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: entries.length,
        separatorBuilder: (_, __) => Divider(height: 1, color: c.divider),
        itemBuilder: (context, index) {
          final entry = entries[index];
          return _buildDayRow(c, entry);
        },
      ),
    );
  }

  Widget _buildDayRow(AppColors c, _DayEntry entry) {
    if (entry.doses.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 14.0),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(entry.label, style: TextStyle(fontSize: 15, color: c.textPrimary)),
            Row(children: [
              Text('No doses', style: TextStyle(fontSize: 13, color: c.textTertiary, fontWeight: FontWeight.w500)),
              const SizedBox(width: 6),
              Icon(Icons.remove_circle_outline, color: c.textTertiary, size: 18),
            ]),
          ],
        ),
      );
    }

    return Column(
      children: entry.doses.map((dose) {
        Color statusColor;
        IconData statusIcon;
        String statusLabel;

        if (dose.isTaken) {
          statusColor = c.success;
          statusIcon = Icons.check_circle;
          statusLabel = 'Taken';
        } else if (dose.isMissed) {
          statusColor = c.error;
          statusIcon = Icons.cancel;
          statusLabel = 'Missed';
        } else {
          statusColor = c.warning;
          statusIcon = Icons.schedule;
          statusLabel = 'Pending';
        }

        return InkWell(
          onTap: dose.isPending ? () => _showMarkDialog(dose) : null,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 14.0),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(entry.label, style: TextStyle(fontSize: 15, color: c.textPrimary, fontWeight: FontWeight.w500)),
                      const SizedBox(height: 2),
                      Text(dose.scheduledTime, style: TextStyle(fontSize: 12, color: c.textTertiary)),
                    ],
                  ),
                ),
                if (dose.isPending) ...[
                  _miniActionChip('Taken', Icons.check_rounded, c.success, () => _markDose(dose, 'taken')),
                  const SizedBox(width: 8),
                  _miniActionChip('Missed', Icons.close_rounded, c.error, () => _markDose(dose, 'missed')),
                ] else ...[
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(color: statusColor.withOpacity(0.1), borderRadius: BorderRadius.circular(20)),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      Icon(statusIcon, color: statusColor, size: 16),
                      const SizedBox(width: 4),
                      Text(statusLabel, style: TextStyle(fontWeight: FontWeight.bold, color: statusColor, fontSize: 13)),
                    ]),
                  ),
                ],
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _miniActionChip(
      String label, IconData icon, Color color, VoidCallback onTap) {
    return Material(
      color: color.withOpacity(0.08),
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding:
              const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 14, color: color),
              const SizedBox(width: 4),
              Text(label,
                  style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: color)),
            ],
          ),
        ),
      ),
    );
  }

  void _showMarkDialog(MedicineDose dose) {
    final c = AppColors.of(context);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Mark Dose'),
        content: Text('Mark ${dose.scheduledTime} dose as taken or missed?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Cancel', style: TextStyle(color: c.textSecondary)),
          ),
          ElevatedButton.icon(
            onPressed: () {
              Navigator.pop(ctx);
              _markDose(dose, 'taken');
            },
            icon: const Icon(Icons.check, size: 18),
            label: const Text('Taken'),
            style: ElevatedButton.styleFrom(backgroundColor: c.success, foregroundColor: Colors.white),
          ),
          ElevatedButton.icon(
            onPressed: () {
              Navigator.pop(ctx);
              _markDose(dose, 'missed');
            },
            icon: const Icon(Icons.close, size: 18),
            label: const Text('Missed'),
            style: ElevatedButton.styleFrom(backgroundColor: c.error, foregroundColor: Colors.white),
          ),
        ],
      ),
    );
  }

  Future<void> _markDose(MedicineDose dose, String status) async {
    final c = AppColors.of(context);
    if (dose.id == null) return;
    try {
      final provider = context.read<MedicineDoseProvider>();
      await provider.markDose(dose.id!, status);

      // Also update the corresponding alert so it disappears from Alerts tab
      try {
        await SupabaseService.instance.updateAlertDoseStatusByDoseId(dose.id!, status);
        if (mounted) {
          context.read<AlertsProvider>().loadAlerts();
        }
      } catch (_) {}

      await _loadDoses(); // Refresh this list

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              status == 'taken'
                  ? '✓ Dose at ${dose.scheduledTime} marked as taken'
                  : '✗ Dose at ${dose.scheduledTime} marked as missed',
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            backgroundColor: status == 'taken' ? c.success : c.error,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10)),
          ),
        );
      }
    } catch (e) {
      debugPrint('Error marking dose: $e');
    }
  }
}

class _DayEntry {
  final String label;
  final String date;
  final List<MedicineDose> doses;
  _DayEntry(
      {required this.label, required this.date, required this.doses});
}

// ────────────────────────────────────────────────────────────
//  Cached Drug Interaction Card — prevents redundant API calls
// ────────────────────────────────────────────────────────────
class _InteractionWarningCard extends StatefulWidget {
  final String medicineName;
  final double borderRadius;
  final double padding;

  const _InteractionWarningCard({
    required this.medicineName,
    required this.borderRadius,
    required this.padding,
  });

  @override
  State<_InteractionWarningCard> createState() => _InteractionWarningCardState();
}

class _InteractionWarningCardState extends State<_InteractionWarningCard> {
  late Future<List<DrugInteraction>> _interactionFuture;

  @override
  void initState() {
    super.initState();
    _loadInteractions();
  }

  void _loadInteractions() {
    final allNames = context.read<MedicineProvider>().medicines
        .where((m) => m.isActive)
        .map((m) => m.name)
        .toList();
    _interactionFuture = RxNormService.checkInteractions(allNames);
  }

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Text('Safety Warnings', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: c.textPrimary)),
        ),
        FutureBuilder<List<DrugInteraction>>(
          future: _interactionFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return Card(
                elevation: 1,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(widget.borderRadius)),
                color: c.card,
                child: Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: Row(
                    children: [
                      SizedBox(width: 20, height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2, color: c.primary)),
                      const SizedBox(width: 12),
                      Text('Checking drug interactions…', style: TextStyle(color: c.textSecondary)),
                    ],
                  ),
                ),
              );
            }

            final interactions = snapshot.data ?? [];
            if (interactions.isEmpty) {
              return Card(
                elevation: 1,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(widget.borderRadius)),
                color: c.successBg,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(children: [
                    Icon(Icons.check_circle, color: c.success, size: 28),
                    const SizedBox(width: 12),
                    Expanded(child: Text(
                      'No known drug interactions detected with your current medicines.',
                      style: TextStyle(color: c.success, fontWeight: FontWeight.w500),
                    )),
                  ]),
                ),
              );
            }

            return Column(
              children: interactions.map((inter) {
                final isHigh = inter.severity == 'High';
                final isMod = inter.severity == 'Moderate';
                final bg = isHigh
                    ? Color.lerp(c.card, c.error, 0.15)!
                    : isMod
                        ? Color.lerp(c.card, c.warning, 0.15)!
                        : Color.lerp(c.card, c.primary, 0.12)!;
                final iconColor = isHigh ? c.error : isMod ? c.warning : c.primary;

                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Card(
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                      side: BorderSide(color: iconColor.withOpacity(0.15)),
                    ),
                    color: bg,
                    child: Padding(
                      padding: EdgeInsets.all(widget.padding),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(Icons.warning_amber_rounded, color: iconColor, size: 28),
                          const SizedBox(width: 12),
                          Expanded(child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('${inter.severity} Interaction: ${inter.drug1} + ${inter.drug2}',
                                  style: TextStyle(fontWeight: FontWeight.bold, color: iconColor, fontSize: 14)),
                              const SizedBox(height: 4),
                              Text(inter.description,
                                  style: TextStyle(color: c.textSecondary, fontSize: 13, height: 1.4)),
                            ],
                          )),
                        ],
                      ),
                    ),
                  ),
                );
              }).toList(),
            );
          },
        ),
      ],
    );
  }
}
