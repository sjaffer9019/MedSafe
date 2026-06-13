import 'package:flutter/material.dart';
import 'app_colors.dart';

/// Convenience extensions for cleaner widget code.
extension ContextX on BuildContext {
  AppColors get colors => AppColors.of(this);
  TextTheme get textTheme => Theme.of(this).textTheme;
  Size get screenSize => MediaQuery.sizeOf(this);
  bool get isDark => Theme.of(this).brightness == Brightness.dark;

  void showSuccess(String msg) => ScaffoldMessenger.of(this).showSnackBar(
    SnackBar(
      content: Text(msg),
      backgroundColor: colors.success,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ),
  );

  void showError(String msg) => ScaffoldMessenger.of(this).showSnackBar(
    SnackBar(
      content: Text(msg),
      backgroundColor: colors.error,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ),
  );

  void showWarning(String msg) => ScaffoldMessenger.of(this).showSnackBar(
    SnackBar(
      content: Text(msg),
      backgroundColor: colors.warning,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ),
  );
}
