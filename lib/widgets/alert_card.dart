import 'package:flutter/material.dart';
import '../models/alert_model.dart';
import '../core/colors.dart';
import 'package:intl/intl.dart';

class AlertCard extends StatelessWidget {
  final Alert alert;

  const AlertCard({super.key, required this.alert});

  @override
  Widget build(BuildContext context) {
    Color severityColor;
    IconData iconData;
    if (alert.severity.toLowerCase() == 'high') {
      severityColor = AppColors.danger;
      iconData = Icons.error_outline;
    } else if (alert.severity.toLowerCase() == 'medium') {
      severityColor = AppColors.warning;
      iconData = Icons.warning_amber_rounded;
    } else {
      severityColor = AppColors.primary;
      iconData = Icons.info_outline;
    }

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: severityColor.withOpacity(0.5), width: 1),
      ),
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: severityColor.withOpacity(0.1),
          child: Icon(iconData, color: severityColor),
        ),
        title: Text(
          alert.message,
          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4.0),
          child: Text(
            DateFormat('MMM dd, hh:mm a').format(alert.date),
            style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
          ),
        ),
      ),
    );
  }
}
