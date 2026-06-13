import 'package:flutter/material.dart';
import '../core/colors.dart';

class RiskBadge extends StatelessWidget {
  final String riskLevel; // 'Low', 'Medium', 'High'

  const RiskBadge({super.key, required this.riskLevel});

  @override
  Widget build(BuildContext context) {
    Color bg;
    if (riskLevel.toLowerCase() == 'low') {
      bg = AppColors.success;
    } else if (riskLevel.toLowerCase() == 'medium') {
      bg = AppColors.warning;
    } else {
      bg = AppColors.danger;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: bg.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: bg),
      ),
      child: Text(
        '$riskLevel Risk',
        style: TextStyle(
          color: bg,
          fontWeight: FontWeight.bold,
          fontSize: 12,
        ),
      ),
    );
  }
}
