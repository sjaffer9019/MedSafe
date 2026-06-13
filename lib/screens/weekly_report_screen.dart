import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../core/app_colors.dart';
import '../core/app_transitions.dart';
import '../providers/medicine_dose_provider.dart';
import '../models/medicine_dose_model.dart';
import 'dosage_history_screen.dart';

class WeeklyReportScreen extends StatefulWidget {
  const WeeklyReportScreen({super.key});

  @override
  State<WeeklyReportScreen> createState() => _WeeklyReportScreenState();
}

class _WeeklyReportScreenState extends State<WeeklyReportScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<MedicineDoseProvider>().loadAll();
    });
  }

  @override
  Widget build(BuildContext context) {
    final doseProv = context.watch<MedicineDoseProvider>();
    final doses7d = doseProv.last7DaysDoses;
    final c = AppColors.of(context);

    // Compute stats from real data
    final totalTaken = doses7d.where((d) => d.status == 'taken').length;
    final totalMissed = doses7d.where((d) => d.status == 'missed').length;
    final totalPending = doses7d.where((d) => d.status == 'pending').length;
    final totalResponded = totalTaken + totalMissed;
    final pct = totalResponded > 0
        ? ((totalTaken / doses7d.length) * 100).clamp(0.0, 100.0)
        : 0.0;

    // Build per-day bar data from real doses
    final weekData = _buildWeekData(doses7d);

    // Generate dynamic insights
    final insights = _generateInsights(weekData, pct, totalTaken, totalMissed, totalPending);

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
              const Row(
                children: [
                  Icon(Icons.trending_up_rounded, color: Colors.white, size: 22),
                  SizedBox(width: 10),
                  Text('Weekly Adherence',
                      style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: Colors.white)),
                ],
              ),
              const SizedBox(height: 4),
              const Text('Your medication tracking insights',
                  style: TextStyle(fontSize: 13, color: Colors.white70)),
            ],
          ),
        ),

        Expanded(
          child: doseProv.isLoading
              ? Center(child: CircularProgressIndicator(color: c.primary))
              : RefreshIndicator(
                  color: c.primary,
                  onRefresh: () => doseProv.loadAll(),
                  child: SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Dosage History button
                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton.icon(
                            onPressed: () => Navigator.push(
                              context,
                              AppPageRoute(page: const DosageHistoryScreen()),
                            ),
                            icon: Icon(Icons.history_rounded, color: c.primary),
                            label: Text('Dosage History',
                                style: TextStyle(fontWeight: FontWeight.bold, color: c.primary, fontSize: 15)),
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              side: BorderSide(color: c.primary.withOpacity(0.3)),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              backgroundColor: c.primary.withOpacity(0.05),
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),

                        Row(
                          children: [
                            Expanded(
                              child: _buildStatTile(
                                label: 'Taken',
                                count: '$totalTaken',
                                icon: Icons.check_circle_rounded,
                                iconColor: c.success,
                                bg: c.successBg,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: _buildStatTile(
                                label: 'Missed',
                                count: '$totalMissed',
                                icon: Icons.cancel_rounded,
                                iconColor: c.error,
                                bg: c.errorBg,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),

                        // Weekly Adherence card
                        _buildAdherenceCard(pct),
                        const SizedBox(height: 16),

                        // Bar Chart
                        _buildBarChart(weekData),
                        const SizedBox(height: 16),

                        // Dynamic Insights
                        _buildInsightsCard(insights),
                        const SizedBox(height: 24),
                      ],
                    ),
                  ),
                ),
        ),
      ],
    );
  }

  /// Build per-day taken/missed data for the last 7 days.
  List<Map<String, dynamic>> _buildWeekData(List<MedicineDose> doses) {
    final now = DateTime.now();
    final List<Map<String, dynamic>> result = [];

    for (int i = 6; i >= 0; i--) {
      final date = now.subtract(Duration(days: i));
      final dateStr = DateFormat('yyyy-MM-dd').format(date);
      final dayLabel = i == 0
          ? 'Today'
          : DateFormat('E').format(date); // Mon, Tue, Fri, etc.

      final dayDoses = doses.where((d) => d.scheduledDate == dateStr).toList();
      final taken = dayDoses.where((d) => d.status == 'taken').length;
      final missed = dayDoses.where((d) => d.status == 'missed').length;
      final pending = dayDoses.where((d) => d.status == 'pending').length;

      result.add({
        'day': dayLabel,
        'date': dateStr,
        'taken': taken,
        'missed': missed,
        'pending': pending,
        'total': dayDoses.length,
      });
    }

    return result;
  }

  /// Generate smart insights from the data.
  List<String> _generateInsights(
      List<Map<String, dynamic>> weekData, double pct, int taken, int missed, int pending) {
    final insights = <String>[];

    // Adherence message
    if (pct >= 80) {
      insights.add("Great job! You're maintaining a strong ${pct.round()}% adherence rate this week.");
    } else if (pct >= 60) {
      insights.add('Your adherence is ${pct.round()}% — aim for 80% or higher for best results.');
    } else if (taken + missed > 0) {
      insights.add('Your adherence is ${pct.round()}% — please try to take your medicines more regularly.');
    } else {
      insights.add('No dose data recorded yet this week. Make sure to respond to your reminders!');
    }

    // Find worst day
    final daysWithMissed = weekData.where((d) => (d['missed'] as int) > 0).toList();
    if (daysWithMissed.isNotEmpty) {
      daysWithMissed.sort((a, b) => (b['missed'] as int).compareTo(a['missed'] as int));
      final worstDay = daysWithMissed.first;
      insights.add(
          '${worstDay['day']} had the most missed doses (${worstDay['missed']}) — consider setting extra reminders.');
    }

    // Find best streak
    int currentStreak = 0;
    int bestStreak = 0;
    for (final day in weekData) {
      if ((day['total'] as int) > 0 && (day['missed'] as int) == 0 && (day['taken'] as int) > 0) {
        currentStreak++;
        if (currentStreak > bestStreak) bestStreak = currentStreak;
      } else if ((day['total'] as int) > 0) {
        currentStreak = 0;
      }
    }
    if (bestStreak >= 3) {
      insights.add('$bestStreak-day perfect streak! Keep up the great consistency.');
    } else if (bestStreak >= 2) {
      insights.add('$bestStreak consecutive days with all doses taken — build on that momentum!');
    }

    // Pending reminder
    if (pending > 0) {
      insights.add('You have $pending pending dose${pending > 1 ? 's' : ''} — check the Alerts tab to respond.');
    }

    // Fallback
    if (insights.length == 1 && taken + missed == 0) {
      insights.add('Start taking your medicines to see trends and insights here.');
    }

    return insights;
  }

  Widget _buildAdherenceCard(double pct) {
    final c = AppColors.of(context);
    final color = pct >= 80 ? c.success : pct >= 60 ? c.warning : c.error;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: c.card,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [BoxShadow(color: c.shadow, blurRadius: 8, offset: const Offset(0, 2))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Weekly Adherence', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: c.textPrimary)),
              Text('Rate  ${pct.round()}%', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: color)),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: pct / 100,
              minHeight: 8,
              backgroundColor: c.divider,
              valueColor: AlwaysStoppedAnimation<Color>(color),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Icon(Icons.calendar_today_outlined, size: 14, color: c.textTertiary),
              const SizedBox(width: 6),
              Text('Last 7 days', style: TextStyle(fontSize: 12, color: c.textTertiary)),
            ],
          ),
        ],
      ),
    );
  }

  int? _selectedBarIndex;

  Widget _buildBarChart(List<Map<String, dynamic>> weekData) {
    final c = AppColors.of(context);
    double maxVal = 1;
    for (final d in weekData) {
      final total = (d['taken'] as int) + (d['missed'] as int);
      if (total > maxVal) maxVal = total.toDouble();
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: c.card,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [BoxShadow(color: c.shadow, blurRadius: 8, offset: const Offset(0, 2))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Weekly Overview', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: c.textPrimary)),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.fromLTRB(8, 12, 8, 8),
            decoration: BoxDecoration(
              border: Border.all(color: c.divider, width: 1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: SizedBox(
            height: 180,
            child: weekData.every((d) => (d['taken'] as int) == 0 && (d['missed'] as int) == 0)
                ? Center(child: Text('No dose data this week', style: TextStyle(color: c.textTertiary, fontSize: 14)))
                : Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: weekData.asMap().entries.map((entry) {
                      final idx = entry.key;
                      final d = entry.value;
                      final taken = d['taken'] as int;
                      final missed = d['missed'] as int;
                      const maxH = 120.0;
                      final isSelected = _selectedBarIndex == idx;

                      return GestureDetector(
                        onTap: () {
                          setState(() {
                            _selectedBarIndex = isSelected ? null : idx;
                          });
                        },
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            // Tooltip above bars
                            AnimatedOpacity(
                              opacity: isSelected ? 1.0 : 0.0,
                              duration: const Duration(milliseconds: 200),
                              child: isSelected
                                  ? Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                      margin: const EdgeInsets.only(bottom: 6),
                                      decoration: BoxDecoration(
                                        color: c.textPrimary,
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Column(
                                        children: [
                                          Text('$taken taken', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: c.card)),
                                          if (missed > 0)
                                            Text('$missed missed', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: c.error)),
                                        ],
                                      ),
                                    )
                                  : const SizedBox(height: 30),
                            ),
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                AnimatedContainer(
                                  duration: const Duration(milliseconds: 300),
                                  width: isSelected ? 18 : 14,
                                  height: taken > 0 ? (taken / maxVal * maxH).clamp(4.0, maxH) : 0,
                                  decoration: BoxDecoration(
                                    color: c.success,
                                    borderRadius: BorderRadius.circular(4),
                                    boxShadow: isSelected ? [BoxShadow(color: c.success.withOpacity(0.4), blurRadius: 6)] : [],
                                  ),
                                ),
                                const SizedBox(width: 2),
                                if (missed > 0)
                                  AnimatedContainer(
                                    duration: const Duration(milliseconds: 300),
                                    width: isSelected ? 18 : 14,
                                    height: (missed / maxVal * maxH).clamp(4.0, maxH),
                                    decoration: BoxDecoration(
                                      color: c.error,
                                      borderRadius: BorderRadius.circular(4),
                                      boxShadow: isSelected ? [BoxShadow(color: c.error.withOpacity(0.4), blurRadius: 6)] : [],
                                    ),
                                  ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text(d['day'] as String,
                                style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                                    color: isSelected ? c.primary : c.textTertiary)),
                          ],
                        ),
                      );
                    }).toList(),
                  ),
          ),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _legendDot(c.success, 'Taken'),
              const SizedBox(width: 20),
              _legendDot(c.error, 'Missed'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildInsightsCard(List<String> insights) {
    final c = AppColors.of(context);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: c.primaryLight,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: c.primary.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Insights', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: c.textPrimary)),
          const SizedBox(height: 12),
          ...insights.map((text) => _insightBullet(text)),
        ],
      ),
    );
  }

  Widget _buildStatTile(
      {required String label,
      required String count,
      required IconData icon,
      required Color iconColor,
      required Color bg}) {
    final c = AppColors.of(context);
    return Container(
      decoration: BoxDecoration(
        color: c.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: iconColor.withOpacity(0.15)),
        boxShadow: [BoxShadow(color: iconColor.withOpacity(0.06), blurRadius: 10, offset: const Offset(0, 3))],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            border: Border(left: BorderSide(color: iconColor, width: 4)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(color: bg, shape: BoxShape.circle),
                child: Icon(icon, color: iconColor, size: 20),
              ),
              const SizedBox(height: 10),
              Text(label, style: TextStyle(fontSize: 12, color: c.textSecondary)),
              Text(count, style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: iconColor)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _legendDot(Color color, String label) {
    final c = AppColors.of(context);
    return Row(
      children: [
        Container(width: 12, height: 12, decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(3))),
        const SizedBox(width: 6),
        Text(label, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: c.textPrimary)),
      ],
    );
  }

  Widget _insightBullet(String text) {
    final c = AppColors.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('• ', style: TextStyle(color: c.primary, fontWeight: FontWeight.bold, fontSize: 16)),
          Expanded(child: Text(text, style: TextStyle(fontSize: 13, color: c.textPrimary, height: 1.4))),
        ],
      ),
    );
  }
}
