import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/app_colors.dart';
import '../providers/medicine_provider.dart';
import '../services/rxnorm_service.dart';

class SafetyScreen extends StatefulWidget {
  const SafetyScreen({super.key});

  @override
  State<SafetyScreen> createState() => _SafetyScreenState();
}

class _SafetyScreenState extends State<SafetyScreen> {
  List<DrugInteraction>? _interactions;
  bool _isChecking = false;
  String? _error;
  DateTime? _lastChecked;
  int _lastMedCount = -1; // Track medicine count to auto-trigger check

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _runCheck());
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
  }

  Future<void> _runCheck() async {
    // Only check active medicines (skip paused)
    final medicines = context.read<MedicineProvider>().medicines
        .where((m) => m.isActive).toList();
    if (medicines.length < 2) {
      setState(() {
        _interactions = [];
        _isChecking   = false;
      });
      return;
    }

    setState(() {
      _isChecking   = true;
      _error        = null;
      _interactions = null;
    });

    try {
      final names  = medicines.map((m) => m.name).toList();
      final result = await RxNormService.checkInteractions(names);
      if (!mounted) return;
      setState(() {
        _interactions = result;
        _isChecking   = false;
        _lastChecked  = DateTime.now();
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error      = 'Could not complete interaction check. Check your internet connection.';
        _isChecking = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<MedicineProvider>(
      builder: (context, medProv, _) {
        final medCount = medProv.medicines.length;

        // Auto-trigger check when medicines load and no check done yet
        if (medCount != _lastMedCount && medCount > 0 && !_isChecking && _interactions == null) {
          _lastMedCount = medCount;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) _runCheck();
          });
        }

        return Column(
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(20, 40, 20, 14),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [AppColors.of(context).primaryDark, AppColors.of(context).primary],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.shield_rounded, color: Colors.white, size: 22),
                      SizedBox(width: 10),
                      Text('Safety',
                          style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                              color: Colors.white)),
                    ],
                  ),
                  const SizedBox(height: 4),
                  const Text('Real-time drug interaction detection',
                      style: TextStyle(fontSize: 13, color: Colors.white70)),
                  if (_lastChecked != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        'Last checked: ${_formatTime(_lastChecked!)}',
                        style: const TextStyle(
                            fontSize: 11, color: Colors.white54),
                      ),
                    ),
                ],
              ),
            ),

            // ── Body ────────────────────────────────────────
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const SizedBox(height: 8),

                    // ── Status summary row ───────────────────
                    _buildStatusRow(medCount),
                    const SizedBox(height: 16),

                    // ── Check Results ────────────────────────
                    if (_isChecking)
                      _buildChecking()
                    else if (_error != null)
                      _buildError()
                    else if (medCount < 2)
                      _buildNotEnoughMeds(medCount)
                    else if (_interactions != null && _interactions!.isEmpty)
                      _buildAllClear()
                    else if (_interactions != null && _interactions!.isNotEmpty)
                      _buildInteractionList(_interactions!)
                    else
                      _buildChecking(),

                    const SizedBox(height: 24),

                    // ── Re-check button ──────────────────────
                    if (!_isChecking)
                      OutlinedButton.icon(
                        onPressed: _runCheck,
                        icon: Icon(Icons.refresh_rounded, color: AppColors.of(context).primary),
                        label: Text('Re-check Now', style: TextStyle(color: AppColors.of(context).primary)),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          side: BorderSide(color: AppColors.of(context).primary),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      ),

                    const SizedBox(height: 20),
                    Text(
                      '⚠️ This app provides informational monitoring only. '
                      'Always consult your doctor or pharmacist for medical advice.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                          color: AppColors.of(context).textTertiary,
                          fontSize: 12,
                          height: 1.5),
                    ),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  // ── Sub-widgets ────────────────────────────────────────────

  Widget _buildStatusRow(int medCount) {
    final c = AppColors.of(context);
    final hasIssues = _interactions != null && _interactions!.isNotEmpty;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: c.card,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [BoxShadow(color: c.shadow, blurRadius: 8, offset: const Offset(0, 2))],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: hasIssues ? c.errorBg : c.successBg,
              shape: BoxShape.circle,
            ),
            child: Icon(
              hasIssues ? Icons.warning_amber_rounded : Icons.verified_user_rounded,
              color: hasIssues ? c.error : c.success,
              size: 22,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  hasIssues
                      ? '${_interactions!.length} Interaction${_interactions!.length > 1 ? 's' : ''} Found'
                      : 'Interaction Monitor Active',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: c.textPrimary),
                ),
                const SizedBox(height: 3),
                Text(
                  '$medCount medicine${medCount != 1 ? 's' : ''} registered · NIH RxNorm API + NLP',
                  style: TextStyle(fontSize: 12, color: c.textSecondary, height: 1.4),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChecking() {
    final c = AppColors.of(context);
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: c.card,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          CircularProgressIndicator(color: c.primary, strokeWidth: 2.5),
          const SizedBox(height: 16),
          Text('Checking drug interactions via NIH RxNorm…',
              textAlign: TextAlign.center,
              style: TextStyle(color: c.textSecondary)),
          const SizedBox(height: 4),
          Text('This may take a few seconds',
              style: TextStyle(fontSize: 12, color: c.textTertiary)),
        ],
      ),
    );
  }

  Widget _buildAllClear() {
    final c = AppColors.of(context);
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: c.successBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: c.success.withOpacity(0.4)),
      ),
      child: Row(
        children: [
          Icon(Icons.check_circle_rounded, color: c.success, size: 32),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('No Interactions Detected',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: c.success)),
                const SizedBox(height: 4),
                Text(
                  'Your medicines appear safe to take together based on NIH drug interaction data.',
                  style: TextStyle(fontSize: 13, color: c.textSecondary, height: 1.4),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNotEnoughMeds(int count) {
    final c = AppColors.of(context);
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: c.surfaceVariant,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: c.divider),
      ),
      child: Column(
        children: [
          Icon(Icons.medication_outlined, color: c.textTertiary, size: 40),
          const SizedBox(height: 12),
          Text('Add More Medicines',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: c.textPrimary)),
          const SizedBox(height: 6),
          Text(
            count == 0
                ? 'No medicines registered yet. Add medicines to enable interaction checking.'
                : 'You have 1 medicine. Add at least one more to check for drug interactions.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13, color: c.textSecondary, height: 1.5),
          ),
        ],
      ),
    );
  }

  Widget _buildError() {
    final c = AppColors.of(context);
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: c.errorBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: c.error.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Icon(Icons.wifi_off_rounded, color: c.error, size: 28),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              _error ?? 'Unknown error.',
              style: TextStyle(fontSize: 13, color: c.error, height: 1.4),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInteractionList(List<DrugInteraction> interactions) {
    final c = AppColors.of(context);
    return Column(
      children: interactions.map((inter) {
        final isHigh = inter.severity == 'High';
        final isMod  = inter.severity == 'Moderate';

        final bg = isHigh
            ? Color.lerp(c.card, c.error, 0.15)!
            : isMod
                ? Color.lerp(c.card, c.warning, 0.15)!
                : Color.lerp(c.card, c.primary, 0.12)!;
        final iconColor = isHigh ? c.error : isMod ? c.warning : c.primary;

        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: bg,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: iconColor.withOpacity(0.15)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.warning_amber_rounded, color: iconColor, size: 28),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: iconColor.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text('${inter.severity} Risk',
                              style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: iconColor)),
                        ),
                      ]),
                      const SizedBox(height: 6),
                      Text('${inter.drug1}  +  ${inter.drug2}',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: iconColor)),
                      const SizedBox(height: 4),
                      Text(inter.description,
                          style: TextStyle(fontSize: 13, color: c.textSecondary, height: 1.45)),
                      const SizedBox(height: 6),
                      Row(children: [
                        Icon(Icons.verified_outlined, size: 12, color: c.textTertiary),
                        const SizedBox(width: 4),
                        Text('Source: ${inter.source}',
                            style: TextStyle(fontSize: 11, color: c.textTertiary, fontStyle: FontStyle.italic)),
                      ]),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  String _formatTime(DateTime t) {
    final h = t.hour.toString().padLeft(2, '0');
    final m = t.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }
}
