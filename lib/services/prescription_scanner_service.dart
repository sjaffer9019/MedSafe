import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:google_generative_ai/google_generative_ai.dart';

/// Parsed medicine from a prescription image.
class ScannedMedicine {
  String name;
  String dosage;
  String type;
  String frequency;
  List<String> times;
  int durationDays;
  bool selected; // user can deselect before saving

  ScannedMedicine({
    required this.name,
    this.dosage = '',
    this.type = 'Tablet',
    this.frequency = 'Once Daily',
    this.times = const ['08:00 AM'],
    this.durationDays = 30,
    this.selected = true,
  });
}

class PrescriptionScannerService {
  static const _apiKey = 'AIzaSyApyvHqOFi4Cqeliq_WZh4dj9kTzv0rcpo';

  /// Scan a prescription image and return extracted medicines.
  static Future<List<ScannedMedicine>> scanPrescription(String imagePath) async {
    try {
      final model = GenerativeModel(
        model: 'gemini-2.5-flash',
        apiKey: _apiKey,
      );

      final imageBytes = await File(imagePath).readAsBytes();
      final mimeType = imagePath.toLowerCase().endsWith('.png')
          ? 'image/png'
          : 'image/jpeg';

      final prompt = TextPart('''
You are a medical prescription reader. Analyze this prescription image and extract ALL medicines listed.

Return a JSON array where each element has exactly these fields:
- "name": Medicine name (string)
- "dosage": Dosage with unit, e.g. "500 mg", "10 ml" (string)
- "type": One of: "Tablet", "Capsule", "Syrup", "Injection", "Inhaler", "Drops", "Topical", "Patch" (string)
- "frequency": One of: "Once Daily", "Twice Daily", "Thrice Daily" (string)
- "times": Array of scheduled times in "hh:mm AM/PM" format based on frequency:
  - Once Daily: ["08:00 AM"]
  - Twice Daily: ["08:00 AM", "08:00 PM"]
  - Thrice Daily: ["08:00 AM", "02:00 PM", "08:00 PM"]
- "duration_days": Number of days for the course (integer, default 30 if not specified)

Rules:
1. Extract EVERY medicine visible in the prescription
2. If dosage is not clearly visible, make a reasonable guess based on the medicine name
3. If frequency says "BD" or "BID" → "Twice Daily", "OD" → "Once Daily", "TDS" or "TID" → "Thrice Daily"
4. If duration says "1 week" → 7, "2 weeks" → 14, "1 month" → 30, etc.
5. Return ONLY the JSON array, no other text. No markdown formatting.
6. If no medicines found, return an empty array: []

Example output:
[{"name":"Amoxicillin","dosage":"500 mg","type":"Capsule","frequency":"Thrice Daily","times":["08:00 AM","02:00 PM","08:00 PM"],"duration_days":7},{"name":"Paracetamol","dosage":"650 mg","type":"Tablet","frequency":"Twice Daily","times":["08:00 AM","08:00 PM"],"duration_days":5}]
''');

      final imagePart = DataPart(mimeType, imageBytes);

      final response = await model.generateContent([
        Content.multi([prompt, imagePart])
      ]);

      final text = response.text?.trim() ?? '[]';
      debugPrint('Gemini raw response: $text');

      return _parseResponse(text);
    } catch (e) {
      debugPrint('Prescription scan error: $e');
      rethrow;
    }
  }

  static List<ScannedMedicine> _parseResponse(String text) {
    // Clean up response — remove markdown fences if present
    var cleaned = text;
    if (cleaned.startsWith('```')) {
      cleaned = cleaned.replaceFirst(RegExp(r'^```\w*\n?'), '');
      cleaned = cleaned.replaceFirst(RegExp(r'\n?```$'), '');
    }
    cleaned = cleaned.trim();

    try {
      final List<dynamic> list = jsonDecode(cleaned);
      return list.map((item) {
        final map = item as Map<String, dynamic>;
        return ScannedMedicine(
          name: (map['name'] as String?) ?? 'Unknown',
          dosage: (map['dosage'] as String?) ?? '',
          type: _normalizeType((map['type'] as String?) ?? 'Tablet'),
          frequency: _normalizeFrequency((map['frequency'] as String?) ?? 'Once Daily'),
          times: _parseTimes(map['times'], (map['frequency'] as String?) ?? 'Once Daily'),
          durationDays: (map['duration_days'] as int?) ?? 30,
        );
      }).toList();
    } catch (e) {
      debugPrint('JSON parse error: $e\nRaw: $cleaned');
      return [];
    }
  }

  static String _normalizeType(String type) {
    const valid = ['Tablet', 'Capsule', 'Syrup', 'Injection', 'Inhaler', 'Drops', 'Topical', 'Patch'];
    for (final v in valid) {
      if (type.toLowerCase() == v.toLowerCase()) return v;
    }
    return 'Tablet';
  }

  static String _normalizeFrequency(String freq) {
    final f = freq.toLowerCase();
    if (f.contains('thrice') || f.contains('tid') || f.contains('tds') || f.contains('three')) return 'Thrice Daily';
    if (f.contains('twice') || f.contains('bid') || f.contains('bd') || f.contains('two')) return 'Twice Daily';
    return 'Once Daily';
  }

  static List<String> _parseTimes(dynamic times, String frequency) {
    if (times is List && times.isNotEmpty) {
      return times.map((t) => t.toString()).toList();
    }
    // Default times based on frequency
    switch (frequency) {
      case 'Thrice Daily':
        return ['08:00 AM', '02:00 PM', '08:00 PM'];
      case 'Twice Daily':
        return ['08:00 AM', '08:00 PM'];
      default:
        return ['08:00 AM'];
    }
  }
}
