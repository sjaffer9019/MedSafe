import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Typography scale using Inter font — premium, medical-grade readability.
class AppTypography {
  static TextTheme get textTheme => TextTheme(
    displayLarge:  GoogleFonts.inter(fontSize: 32, fontWeight: FontWeight.w800, height: 1.2),
    displayMedium: GoogleFonts.inter(fontSize: 28, fontWeight: FontWeight.w700, height: 1.25),
    headlineLarge:  GoogleFonts.inter(fontSize: 24, fontWeight: FontWeight.w700, height: 1.3),
    headlineMedium: GoogleFonts.inter(fontSize: 20, fontWeight: FontWeight.w600, height: 1.35),
    headlineSmall:  GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w600, height: 1.4),
    titleLarge:  GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w600, height: 1.4),
    titleMedium: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600, height: 1.45),
    titleSmall:  GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, height: 1.5),
    bodyLarge:  GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w400, height: 1.5),
    bodyMedium: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w400, height: 1.5),
    bodySmall:  GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w400, height: 1.5),
    labelLarge:  GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600, height: 1.4),
    labelMedium: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w500, height: 1.4),
    labelSmall:  GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w500, height: 1.4, letterSpacing: 0.5),
  );
}
