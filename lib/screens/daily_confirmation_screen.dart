import 'package:flutter/material.dart';
import '../core/app_colors.dart';

class DailyConfirmationScreen extends StatefulWidget {
  const DailyConfirmationScreen({super.key});

  @override
  State<DailyConfirmationScreen> createState() => _DailyConfirmationScreenState();
}

class _DailyConfirmationScreenState extends State<DailyConfirmationScreen> {
  bool _isSubmitted = false;

  void _submitConfirmation(bool allTaken) {
    if (_isSubmitted) return;
    final c = AppColors.of(context);

    setState(() => _isSubmitted = true);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          allTaken
            ? 'Great job! Your adherence has been recorded.'
            : 'Noted. Please consult the Alerts tab for recommendations.',
          style: const TextStyle(fontSize: 16),
        ),
        backgroundColor: allTaken ? c.success : c.error,
        behavior: SnackBarBehavior.floating,
      ),
    );

    Future.delayed(const Duration(milliseconds: 1500), () {
      if (mounted) Navigator.pop(context);
    });
  }

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return Scaffold(
      backgroundColor: c.background,
      appBar: AppBar(
        title: Text('Daily Check-in', style: TextStyle(fontWeight: FontWeight.bold, color: c.textPrimary)),
        backgroundColor: c.surface,
        elevation: 0,
        iconTheme: IconThemeData(color: c.textPrimary),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Spacer(),

              Icon(Icons.fact_check_outlined, size: 80, color: c.primary),
              const SizedBox(height: 32),
              Text(
                'Did you take your medicines today?',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  color: c.textPrimary,
                  height: 1.2,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Confirming helps Medsafe track your adherence and alert you of any risks.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 18, color: c.textSecondary, height: 1.4),
              ),

              const Spacer(),

              if (_isSubmitted)
                Column(
                  children: [
                    Icon(Icons.check_circle, color: c.success, size: 60),
                    const SizedBox(height: 16),
                    Text(
                      'Submission recorded for today.',
                      style: TextStyle(fontSize: 18, color: c.success, fontWeight: FontWeight.bold),
                    ),
                  ],
                )
              else ...[
                SizedBox(
                  height: 64,
                  child: ElevatedButton(
                    onPressed: () => _submitConfirmation(true),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: c.success,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      elevation: 0,
                    ),
                    child: const Text('Yes, All Taken', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white)),
                  ),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  height: 64,
                  child: OutlinedButton(
                    onPressed: () => _submitConfirmation(false),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: c.error,
                      side: BorderSide(color: c.error, width: 2),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      backgroundColor: c.error.withOpacity(0.05),
                    ),
                    child: Text('Missed Some', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: c.error)),
                  ),
                ),
              ],

              const SizedBox(height: 32),

              TextButton(
                onPressed: () {},
                style: TextButton.styleFrom(foregroundColor: c.primary),
                child: const Text('View Today\'s Schedule', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
              ),
              const Spacer(),
            ],
          ),
        ),
      ),
    );
  }
}
