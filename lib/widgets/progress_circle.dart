import 'package:flutter/material.dart';
import 'package:percent_indicator/percent_indicator.dart';
import '../core/colors.dart';

class ProgressCircle extends StatelessWidget {
  final double percentage;

  const ProgressCircle({super.key, required this.percentage});

  @override
  Widget build(BuildContext context) {
    Color progressColor = AppColors.success;
    if (percentage < 70) {
      progressColor = AppColors.danger;
    } else if (percentage < 90) {
      progressColor = AppColors.warning;
    }

    return CircularPercentIndicator(
      radius: 60.0,
      lineWidth: 12.0,
      percent: (percentage / 100).clamp(0.0, 1.0),
      center: Text(
        '${percentage.toStringAsFixed(1)}%',
        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 20.0),
      ),
      progressColor: progressColor,
      backgroundColor: AppColors.background,
      circularStrokeCap: CircularStrokeCap.round,
      animation: true,
    );
  }
}
