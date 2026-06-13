import 'dart:convert';
import 'package:http/http.dart' as http;
import 'nlp_service.dart';

class DrugResult {
  final String name;       // Display name (brand or generic)
  final String genericName;
  final String dosageForm; // Tablet, Capsule, Syrup, etc.
  final String strength;   // e.g. "500 mg"

  DrugResult({
    required this.name,
    required this.genericName,
    required this.dosageForm,
    required this.strength,
  });

  String get displayName => name;

  String get suggestedUnit {
    final s = strength.toLowerCase();
    if (s.contains('mcg')) return 'mcg';
    if (s.contains('mg/ml')) return 'mg/ml';
    if (s.contains('mg')) return 'mg';
    if (s.contains('ml')) return 'ml';
    return 'mg';
  }

  String get strengthValue {
    final m = RegExp(r'[\d.]+').firstMatch(strength);
    return m?.group(0) ?? '';
  }
}

class OpenFDAService {
  static const String _fdaBase = 'https://api.fda.gov/drug/label.json';
  static const String _rxBase  = 'https://rxnav.nlm.nih.gov/REST';

  /// Search drugs by name.
  /// Tries: Local database (instant) + OpenFDA + RxNorm (parallel).
  /// This ensures Indian brands, common OTC, and global medicines always appear.
  static Future<List<DrugResult>> search(String query, {int limit = 15}) async {
    final q = query.trim();
    if (q.length < 2) return [];

    // Step 1: Instant local results (covers Indian brands, common meds)
    final localResults = _searchLocal(q, limit);

    // Step 2: Run OpenFDA and RxNorm in parallel
    List<List<DrugResult>> apiResults;
    try {
      apiResults = await Future.wait([
        _searchFDA(q, limit),
        _searchRxNorm(q, limit),
      ]).timeout(const Duration(seconds: 8), onTimeout: () => [[], []]);
    } catch (_) {
      apiResults = [[], []];
    }

    // Step 3: Merge all — local first (instant), then API results
    final seen   = <String>{};
    final merged = <DrugResult>[];

    // Local results first (always available, includes Indian brands)
    for (final d in localResults) {
      final key = d.name.toLowerCase();
      if (seen.add(key)) merged.add(d);
    }

    // Then API results
    for (final list in apiResults) {
      for (final d in list) {
        final key = d.name.toLowerCase();
        if (seen.add(key)) merged.add(d);
        if (merged.length >= limit) break;
      }
      if (merged.length >= limit) break;
    }

    return merged;
  }

  // ── Local Medicine Database Search ──────────────────────────
  /// Fuzzy search against a comprehensive local database of medicines.
  /// Covers Indian brands, common OTC drugs, and generics that
  /// US-centric APIs like OpenFDA/RxNorm often miss.
  static List<DrugResult> _searchLocal(String query, int limit) {
    final q = query.toLowerCase().trim();
    final results = <DrugResult>[];
    final seen = <String>{};

    for (final med in _localMedicineDb) {
      final name = (med['name'] as String).toLowerCase();
      final generic = (med['generic'] as String).toLowerCase();
      final aliases = (med['aliases'] as List<String>?) ?? [];

      // Check if query matches name, generic, or any alias
      bool matches = name.contains(q) || q.contains(name) ||
          generic.contains(q) || q.contains(generic);

      if (!matches) {
        for (final alias in aliases) {
          if (alias.toLowerCase().contains(q) || q.contains(alias.toLowerCase())) {
            matches = true;
            break;
          }
        }
      }

      // NLP fuzzy match as fallback (handles typos like "paracetmol")
      if (!matches && q.length >= 3) {
        final targets = [name, generic, ...aliases.map((a) => a.toLowerCase())];
        for (final t in targets) {
          if (NlpService.jaroWinklerSimilarity(q, t) >= 0.85) {
            matches = true;
            break;
          }
        }
      }

      if (matches) {
        final key = (med['name'] as String).toLowerCase();
        if (seen.add(key)) {
          results.add(DrugResult(
            name: med['name'] as String,
            genericName: med['generic'] as String,
            dosageForm: med['form'] as String? ?? 'Tablet',
            strength: med['strength'] as String? ?? '',
          ));
        }
        if (results.length >= limit) break;
      }
    }

    return results;
  }

  // ── OpenFDA search ──────────────────────────────────────────
  static Future<List<DrugResult>> _searchFDA(String q, int limit) async {
    final encoded = Uri.encodeComponent(q);
    final url = '$_fdaBase?search=openfda.brand_name:$encoded*+openfda.generic_name:$encoded*&limit=$limit';

    try {
      final resp = await http.get(Uri.parse(url)).timeout(const Duration(seconds: 6));
      if (resp.statusCode != 200) return [];
      final body = jsonDecode(resp.body);
      final raw  = body['results'] as List? ?? [];
      return _parseFDA(raw, limit);
    } catch (_) {
      return [];
    }
  }

  static List<DrugResult> _parseFDA(List raw, int limit) {
    final out  = <DrugResult>[];
    final seen = <String>{};

    for (final r in raw) {
      if (out.length >= limit) break;
      final openfda = r['openfda'] as Map? ?? {};

      final brands   = openfda['brand_name']   as List? ?? [];
      final generics = openfda['generic_name'] as List? ?? [];
      final forms    = openfda['dosage_form']  as List? ?? [];

      final brand   = _first(brands);
      final generic = _first(generics);
      final form    = _normalizeForm(_first(forms));
      if (brand.isEmpty && generic.isEmpty) continue;

      final displayName = brand.isNotEmpty ? brand : generic;
      final key = displayName.toLowerCase();
      if (!seen.add(key)) continue;

      String strength = '';
      final adm = r['dosage_and_administration'] as List?;
      if (adm != null && adm.isNotEmpty) {
        final m = RegExp(r'(\d+\.?\d*\s*(mg|ml|mcg|g))', caseSensitive: false)
            .firstMatch(adm.first as String);
        strength = m?.group(0) ?? '';
      }

      out.add(DrugResult(
        name:        displayName,
        genericName: generic,
        dosageForm:  form.isNotEmpty ? form : 'Tablet',
        strength:    strength,
      ));
    }
    return out;
  }

  // ── RxNorm search ───────────────────────────────────────────
  static Future<List<DrugResult>> _searchRxNorm(String q, int limit) async {
    final encoded = Uri.encodeComponent(q);
    final url = '$_rxBase/drugs.json?name=$encoded';

    try {
      final resp = await http.get(Uri.parse(url)).timeout(const Duration(seconds: 6));
      if (resp.statusCode != 200) return [];
      final body = jsonDecode(resp.body);

      final groups = body['drugGroup']?['conceptGroup'] as List? ?? [];
      final out  = <DrugResult>[];
      final seen = <String>{};

      for (final g in groups) {
        final concepts = g['conceptProperties'] as List? ?? [];
        for (final c in concepts) {
          if (out.length >= limit) break;
          final fullName = (c['name'] as String? ?? '').trim();
          if (fullName.isEmpty) continue;

          final parsed = _parseRxName(fullName);
          if (parsed == null) continue;

          final key = parsed.name.toLowerCase();
          if (!seen.add(key)) continue;
          out.add(parsed);
        }
      }
      return out;
    } catch (_) {
      return [];
    }
  }

  static DrugResult? _parseRxName(String fullName) {
    final strengthMatch = RegExp(
      r'(\d+\.?\d*)\s*(mg|mcg|ml|g|mg/ml|mEq|unit)',
      caseSensitive: false,
    ).firstMatch(fullName);

    String strength = '';
    if (strengthMatch != null) {
      strength = '${strengthMatch.group(1)} ${strengthMatch.group(2)!.toUpperCase()}';
    }

    String name = fullName;
    if (strengthMatch != null) {
      name = fullName.substring(0, strengthMatch.start).trim();
    }
    if (name.isEmpty) return null;

    String form = 'Tablet';
    final f = fullName.toLowerCase();
    if (f.contains('capsule')) form = 'Capsule';
    else if (f.contains('tablet')) form = 'Tablet';
    else if (f.contains('solution') || f.contains('injection')) form = 'Injection';
    else if (f.contains('syrup') || f.contains('suspension') || f.contains('liquid')) form = 'Syrup';
    else if (f.contains('cream') || f.contains('ointment') || f.contains('gel')) form = 'Topical';
    else if (f.contains('inhaler') || f.contains('aerosol')) form = 'Inhaler';
    else if (f.contains('drop')) form = 'Drops';
    else if (f.contains('patch')) form = 'Patch';

    return DrugResult(
      name:        name,
      genericName: name,
      dosageForm:  form,
      strength:    strength,
    );
  }

  // ── Helpers ────────────────────────────────────────────────
  static String _first(List list) =>
      list.isNotEmpty ? (list.first as String).trim() : '';

  static String _normalizeForm(String form) {
    final f = form.toLowerCase();
    if (f.contains('tablet'))    return 'Tablet';
    if (f.contains('capsule'))   return 'Capsule';
    if (f.contains('solution') || f.contains('injection')) return 'Injection';
    if (f.contains('syrup') || f.contains('suspension') || f.contains('liquid')) return 'Syrup';
    if (f.contains('cream') || f.contains('ointment') || f.contains('gel')) return 'Topical';
    if (f.contains('inhaler') || f.contains('aerosol')) return 'Inhaler';
    if (f.contains('drop'))      return 'Drops';
    if (f.contains('patch'))     return 'Patch';
    return '';
  }

  // ═══════════════════════════════════════════════════════════
  //  LOCAL MEDICINE DATABASE
  //  Covers Indian brands, common OTC, and generics worldwide
  // ═══════════════════════════════════════════════════════════
  static const List<Map<String, dynamic>> _localMedicineDb = [
    // ── Analgesics / Antipyretics ──
    {'name': 'Paracetamol',      'generic': 'Acetaminophen',    'form': 'Tablet',  'strength': '500 mg', 'aliases': ['Acetaminophen']},
    {'name': 'Crocin',           'generic': 'Paracetamol',      'form': 'Tablet',  'strength': '500 mg', 'aliases': ['Crocin Advance']},
    {'name': 'Crocin 650',      'generic': 'Paracetamol',      'form': 'Tablet',  'strength': '650 mg'},
    {'name': 'Dolo 650',        'generic': 'Paracetamol',      'form': 'Tablet',  'strength': '650 mg', 'aliases': ['Dolo']},
    {'name': 'Calpol',          'generic': 'Paracetamol',      'form': 'Syrup',   'strength': '250 mg/5ml'},
    {'name': 'Tylenol',         'generic': 'Acetaminophen',    'form': 'Tablet',  'strength': '500 mg'},
    {'name': 'Panadol',         'generic': 'Paracetamol',      'form': 'Tablet',  'strength': '500 mg'},

    // ── NSAIDs ──
    {'name': 'Ibuprofen',       'generic': 'Ibuprofen',        'form': 'Tablet',  'strength': '400 mg'},
    {'name': 'Brufen',          'generic': 'Ibuprofen',        'form': 'Tablet',  'strength': '400 mg'},
    {'name': 'Combiflam',       'generic': 'Ibuprofen + Paracetamol', 'form': 'Tablet', 'strength': '400+325 mg'},
    {'name': 'Advil',           'generic': 'Ibuprofen',        'form': 'Tablet',  'strength': '200 mg'},
    {'name': 'Diclofenac',      'generic': 'Diclofenac Sodium', 'form': 'Tablet', 'strength': '50 mg'},
    {'name': 'Voveran',         'generic': 'Diclofenac Sodium', 'form': 'Tablet', 'strength': '50 mg'},
    {'name': 'Voveran SR',      'generic': 'Diclofenac Sodium', 'form': 'Tablet', 'strength': '100 mg'},
    {'name': 'Naproxen',        'generic': 'Naproxen',         'form': 'Tablet',  'strength': '250 mg'},
    {'name': 'Aleve',           'generic': 'Naproxen Sodium',  'form': 'Tablet',  'strength': '220 mg'},
    {'name': 'Aspirin',         'generic': 'Acetylsalicylic Acid', 'form': 'Tablet', 'strength': '325 mg'},
    {'name': 'Disprin',         'generic': 'Aspirin',          'form': 'Tablet',  'strength': '350 mg'},
    {'name': 'Ecosprin',        'generic': 'Aspirin',          'form': 'Tablet',  'strength': '75 mg'},
    {'name': 'Ecosprin 150',    'generic': 'Aspirin',          'form': 'Tablet',  'strength': '150 mg'},
    {'name': 'Meftal Spas',     'generic': 'Mefenamic Acid + Dicyclomine', 'form': 'Tablet', 'strength': '250+10 mg'},
    {'name': 'Meftal',          'generic': 'Mefenamic Acid',   'form': 'Tablet',  'strength': '250 mg'},

    // ── Antibiotics ──
    {'name': 'Amoxicillin',     'generic': 'Amoxicillin',      'form': 'Capsule', 'strength': '500 mg'},
    {'name': 'Mox',             'generic': 'Amoxicillin',      'form': 'Capsule', 'strength': '500 mg'},
    {'name': 'Augmentin',       'generic': 'Amoxicillin + Clavulanate', 'form': 'Tablet', 'strength': '625 mg'},
    {'name': 'Azithromycin',    'generic': 'Azithromycin',     'form': 'Tablet',  'strength': '500 mg'},
    {'name': 'Azee',            'generic': 'Azithromycin',     'form': 'Tablet',  'strength': '500 mg'},
    {'name': 'Azithral',        'generic': 'Azithromycin',     'form': 'Tablet',  'strength': '500 mg'},
    {'name': 'Zithromax',       'generic': 'Azithromycin',     'form': 'Tablet',  'strength': '250 mg'},
    {'name': 'Ciprofloxacin',   'generic': 'Ciprofloxacin',    'form': 'Tablet',  'strength': '500 mg'},
    {'name': 'Ciplox',          'generic': 'Ciprofloxacin',    'form': 'Tablet',  'strength': '500 mg'},
    {'name': 'Cipro',           'generic': 'Ciprofloxacin',    'form': 'Tablet',  'strength': '500 mg'},
    {'name': 'Ofloxacin',       'generic': 'Ofloxacin',        'form': 'Tablet',  'strength': '200 mg'},
    {'name': 'O2',              'generic': 'Ofloxacin + Ornidazole', 'form': 'Tablet', 'strength': '200+500 mg'},
    {'name': 'Metronidazole',   'generic': 'Metronidazole',    'form': 'Tablet',  'strength': '400 mg'},
    {'name': 'Flagyl',          'generic': 'Metronidazole',    'form': 'Tablet',  'strength': '400 mg'},
    {'name': 'Cefixime',        'generic': 'Cefixime',         'form': 'Tablet',  'strength': '200 mg'},
    {'name': 'Zifi',            'generic': 'Cefixime',         'form': 'Tablet',  'strength': '200 mg'},
    {'name': 'Taxim-O',         'generic': 'Cefixime',         'form': 'Tablet',  'strength': '200 mg'},
    {'name': 'Levofloxacin',    'generic': 'Levofloxacin',     'form': 'Tablet',  'strength': '500 mg'},
    {'name': 'Levoflox',        'generic': 'Levofloxacin',     'form': 'Tablet',  'strength': '500 mg'},
    {'name': 'Doxycycline',     'generic': 'Doxycycline',      'form': 'Capsule', 'strength': '100 mg'},
    {'name': 'Clarithromycin',  'generic': 'Clarithromycin',   'form': 'Tablet',  'strength': '500 mg'},
    {'name': 'Biaxin',          'generic': 'Clarithromycin',   'form': 'Tablet',  'strength': '500 mg'},
    {'name': 'Erythromycin',    'generic': 'Erythromycin',     'form': 'Tablet',  'strength': '250 mg'},

    // ── Antacids / GI ──
    {'name': 'Pantoprazole',    'generic': 'Pantoprazole',     'form': 'Tablet',  'strength': '40 mg'},
    {'name': 'Pan 40',          'generic': 'Pantoprazole',     'form': 'Tablet',  'strength': '40 mg', 'aliases': ['Pan-40', 'Pan D']},
    {'name': 'Pantop',          'generic': 'Pantoprazole',     'form': 'Tablet',  'strength': '40 mg'},
    {'name': 'Omeprazole',      'generic': 'Omeprazole',       'form': 'Capsule', 'strength': '20 mg'},
    {'name': 'Prilosec',        'generic': 'Omeprazole',       'form': 'Capsule', 'strength': '20 mg'},
    {'name': 'Rabeprazole',     'generic': 'Rabeprazole',      'form': 'Tablet',  'strength': '20 mg'},
    {'name': 'Razo',            'generic': 'Rabeprazole',      'form': 'Tablet',  'strength': '20 mg'},
    {'name': 'Esomeprazole',    'generic': 'Esomeprazole',     'form': 'Tablet',  'strength': '40 mg'},
    {'name': 'Nexium',          'generic': 'Esomeprazole',     'form': 'Tablet',  'strength': '40 mg'},
    {'name': 'Lansoprazole',    'generic': 'Lansoprazole',     'form': 'Capsule', 'strength': '30 mg'},
    {'name': 'Domperidone',     'generic': 'Domperidone',      'form': 'Tablet',  'strength': '10 mg'},
    {'name': 'Domstal',         'generic': 'Domperidone',      'form': 'Tablet',  'strength': '10 mg'},
    {'name': 'Ondansetron',     'generic': 'Ondansetron',      'form': 'Tablet',  'strength': '4 mg'},
    {'name': 'Emeset',          'generic': 'Ondansetron',      'form': 'Tablet',  'strength': '4 mg'},
    {'name': 'Sucralfate',      'generic': 'Sucralfate',       'form': 'Syrup',   'strength': '1 g'},
    {'name': 'Gelusil',         'generic': 'Aluminium Hydroxide + Magnesium Hydroxide', 'form': 'Syrup', 'strength': ''},
    {'name': 'Digene',          'generic': 'Aluminium Hydroxide + Magnesium Hydroxide', 'form': 'Tablet', 'strength': ''},

    // ── Antidiabetics ──
    {'name': 'Metformin',       'generic': 'Metformin',        'form': 'Tablet',  'strength': '500 mg'},
    {'name': 'Glycomet',        'generic': 'Metformin',        'form': 'Tablet',  'strength': '500 mg'},
    {'name': 'Glucophage',      'generic': 'Metformin',        'form': 'Tablet',  'strength': '500 mg'},
    {'name': 'Metformin 1000',  'generic': 'Metformin',        'form': 'Tablet',  'strength': '1000 mg'},
    {'name': 'Glimepiride',     'generic': 'Glimepiride',      'form': 'Tablet',  'strength': '2 mg'},
    {'name': 'Amaryl',          'generic': 'Glimepiride',      'form': 'Tablet',  'strength': '2 mg'},
    {'name': 'Glipizide',       'generic': 'Glipizide',        'form': 'Tablet',  'strength': '5 mg'},
    {'name': 'Gliclazide',      'generic': 'Gliclazide',       'form': 'Tablet',  'strength': '80 mg'},
    {'name': 'Sitagliptin',     'generic': 'Sitagliptin',      'form': 'Tablet',  'strength': '100 mg'},
    {'name': 'Januvia',         'generic': 'Sitagliptin',      'form': 'Tablet',  'strength': '100 mg'},
    {'name': 'Voglibose',       'generic': 'Voglibose',        'form': 'Tablet',  'strength': '0.3 mg'},
    {'name': 'Insulin Glargine','generic': 'Insulin Glargine', 'form': 'Injection','strength': '100 IU/ml', 'aliases': ['Lantus', 'Basaglar']},
    {'name': 'Insulin Regular', 'generic': 'Insulin Regular',  'form': 'Injection','strength': '100 IU/ml', 'aliases': ['Actrapid', 'Humulin R']},

    // ── Antihypertensives ──
    {'name': 'Amlodipine',      'generic': 'Amlodipine',       'form': 'Tablet',  'strength': '5 mg'},
    {'name': 'Amlong',          'generic': 'Amlodipine',       'form': 'Tablet',  'strength': '5 mg', 'aliases': ['Amlokind', 'Stamlo']},
    {'name': 'Norvasc',         'generic': 'Amlodipine',       'form': 'Tablet',  'strength': '5 mg'},
    {'name': 'Telmisartan',     'generic': 'Telmisartan',      'form': 'Tablet',  'strength': '40 mg'},
    {'name': 'Telma',           'generic': 'Telmisartan',      'form': 'Tablet',  'strength': '40 mg', 'aliases': ['Telmikind', 'Telsar']},
    {'name': 'Telma H',         'generic': 'Telmisartan + Hydrochlorothiazide', 'form': 'Tablet', 'strength': '40+12.5 mg'},
    {'name': 'Losartan',        'generic': 'Losartan',         'form': 'Tablet',  'strength': '50 mg'},
    {'name': 'Losacar',         'generic': 'Losartan',         'form': 'Tablet',  'strength': '50 mg'},
    {'name': 'Enalapril',       'generic': 'Enalapril',        'form': 'Tablet',  'strength': '5 mg'},
    {'name': 'Lisinopril',      'generic': 'Lisinopril',       'form': 'Tablet',  'strength': '5 mg'},
    {'name': 'Ramipril',        'generic': 'Ramipril',         'form': 'Capsule', 'strength': '5 mg'},
    {'name': 'Atenolol',        'generic': 'Atenolol',         'form': 'Tablet',  'strength': '50 mg'},
    {'name': 'Tenormin',        'generic': 'Atenolol',         'form': 'Tablet',  'strength': '50 mg'},
    {'name': 'Metoprolol',      'generic': 'Metoprolol',       'form': 'Tablet',  'strength': '50 mg'},
    {'name': 'Met XL',          'generic': 'Metoprolol Succinate', 'form': 'Tablet', 'strength': '50 mg', 'aliases': ['Betaloc']},
    {'name': 'Propranolol',     'generic': 'Propranolol',      'form': 'Tablet',  'strength': '40 mg'},
    {'name': 'Inderal',         'generic': 'Propranolol',      'form': 'Tablet',  'strength': '40 mg'},
    {'name': 'Hydrochlorothiazide', 'generic': 'Hydrochlorothiazide', 'form': 'Tablet', 'strength': '12.5 mg', 'aliases': ['HCTZ']},
    {'name': 'Furosemide',      'generic': 'Furosemide',       'form': 'Tablet',  'strength': '40 mg'},
    {'name': 'Lasix',           'generic': 'Furosemide',       'form': 'Tablet',  'strength': '40 mg'},
    {'name': 'Spironolactone',  'generic': 'Spironolactone',   'form': 'Tablet',  'strength': '25 mg'},
    {'name': 'Aldactone',       'generic': 'Spironolactone',   'form': 'Tablet',  'strength': '25 mg'},
    {'name': 'Prazosin',        'generic': 'Prazosin',         'form': 'Tablet',  'strength': '1 mg'},
    {'name': 'Clonidine',       'generic': 'Clonidine',        'form': 'Tablet',  'strength': '0.1 mg', 'aliases': ['Arkamin']},
    {'name': 'Cilnidipine',     'generic': 'Cilnidipine',      'form': 'Tablet',  'strength': '10 mg', 'aliases': ['Cilacar']},

    // ── Cholesterol / Statins ──
    {'name': 'Atorvastatin',    'generic': 'Atorvastatin',     'form': 'Tablet',  'strength': '10 mg'},
    {'name': 'Lipitor',         'generic': 'Atorvastatin',     'form': 'Tablet',  'strength': '10 mg'},
    {'name': 'Atorva',          'generic': 'Atorvastatin',     'form': 'Tablet',  'strength': '10 mg'},
    {'name': 'Rosuvastatin',    'generic': 'Rosuvastatin',     'form': 'Tablet',  'strength': '10 mg'},
    {'name': 'Crestor',         'generic': 'Rosuvastatin',     'form': 'Tablet',  'strength': '10 mg'},
    {'name': 'Rozavel',         'generic': 'Rosuvastatin',     'form': 'Tablet',  'strength': '10 mg'},
    {'name': 'Simvastatin',     'generic': 'Simvastatin',      'form': 'Tablet',  'strength': '20 mg'},
    {'name': 'Zocor',           'generic': 'Simvastatin',      'form': 'Tablet',  'strength': '20 mg'},
    {'name': 'Fenofibrate',     'generic': 'Fenofibrate',      'form': 'Tablet',  'strength': '160 mg'},

    // ── Thyroid ──
    {'name': 'Levothyroxine',   'generic': 'Levothyroxine',    'form': 'Tablet',  'strength': '50 mcg'},
    {'name': 'Thyronorm',       'generic': 'Levothyroxine',    'form': 'Tablet',  'strength': '50 mcg', 'aliases': ['Eltroxin', 'Thyrox']},

    // ── Antihistamines / Allergy ──
    {'name': 'Cetirizine',      'generic': 'Cetirizine',       'form': 'Tablet',  'strength': '10 mg'},
    {'name': 'Zyrtec',          'generic': 'Cetirizine',       'form': 'Tablet',  'strength': '10 mg'},
    {'name': 'Cetzine',         'generic': 'Cetirizine',       'form': 'Tablet',  'strength': '10 mg'},
    {'name': 'Levocetirizine',  'generic': 'Levocetirizine',   'form': 'Tablet',  'strength': '5 mg'},
    {'name': 'Xyzal',           'generic': 'Levocetirizine',   'form': 'Tablet',  'strength': '5 mg'},
    {'name': 'Fexofenadine',    'generic': 'Fexofenadine',     'form': 'Tablet',  'strength': '120 mg'},
    {'name': 'Allegra',         'generic': 'Fexofenadine',     'form': 'Tablet',  'strength': '120 mg'},
    {'name': 'Loratadine',      'generic': 'Loratadine',       'form': 'Tablet',  'strength': '10 mg'},
    {'name': 'Claritin',        'generic': 'Loratadine',       'form': 'Tablet',  'strength': '10 mg'},
    {'name': 'Montelukast',     'generic': 'Montelukast',      'form': 'Tablet',  'strength': '10 mg'},
    {'name': 'Montair',         'generic': 'Montelukast',      'form': 'Tablet',  'strength': '10 mg', 'aliases': ['Singulair']},

    // ── Cough & Cold ──
    {'name': 'Dextromethorphan', 'generic': 'Dextromethorphan', 'form': 'Syrup',  'strength': '15 mg/5ml'},
    {'name': 'Benadryl',        'generic': 'Diphenhydramine',  'form': 'Syrup',   'strength': ''},
    {'name': 'Alex',            'generic': 'Chlorpheniramine + Dextromethorphan', 'form': 'Syrup', 'strength': ''},
    {'name': 'Corex',           'generic': 'Chlorpheniramine + Codeine', 'form': 'Syrup', 'strength': ''},
    {'name': 'Sinarest',        'generic': 'Paracetamol + Phenylephrine + Chlorpheniramine', 'form': 'Tablet', 'strength': ''},
    {'name': 'Otrivin',         'generic': 'Xylometazoline',   'form': 'Drops',   'strength': '0.1%', 'aliases': ['Nasivion']},

    // ── Antidepressants / Anxiolytics ──
    {'name': 'Fluoxetine',      'generic': 'Fluoxetine',       'form': 'Capsule', 'strength': '20 mg'},
    {'name': 'Prozac',          'generic': 'Fluoxetine',       'form': 'Capsule', 'strength': '20 mg'},
    {'name': 'Sertraline',      'generic': 'Sertraline',       'form': 'Tablet',  'strength': '50 mg'},
    {'name': 'Zoloft',          'generic': 'Sertraline',       'form': 'Tablet',  'strength': '50 mg'},
    {'name': 'Escitalopram',    'generic': 'Escitalopram',     'form': 'Tablet',  'strength': '10 mg'},
    {'name': 'Nexito',          'generic': 'Escitalopram',     'form': 'Tablet',  'strength': '10 mg', 'aliases': ['Lexapro']},
    {'name': 'Amitriptyline',   'generic': 'Amitriptyline',    'form': 'Tablet',  'strength': '25 mg'},
    {'name': 'Clonazepam',      'generic': 'Clonazepam',       'form': 'Tablet',  'strength': '0.5 mg'},
    {'name': 'Rivotril',        'generic': 'Clonazepam',       'form': 'Tablet',  'strength': '0.5 mg'},
    {'name': 'Alprazolam',      'generic': 'Alprazolam',       'form': 'Tablet',  'strength': '0.25 mg'},
    {'name': 'Alprax',          'generic': 'Alprazolam',       'form': 'Tablet',  'strength': '0.25 mg'},

    // ── Vitamins / Supplements ──
    {'name': 'Calcium',         'generic': 'Calcium Carbonate + Vitamin D3', 'form': 'Tablet', 'strength': '500 mg'},
    {'name': 'Shelcal',         'generic': 'Calcium Carbonate + Vitamin D3', 'form': 'Tablet', 'strength': '500 mg'},
    {'name': 'Calcimax',        'generic': 'Calcium + Vitamin D3', 'form': 'Tablet', 'strength': '500 mg'},
    {'name': 'Vitamin D3',      'generic': 'Cholecalciferol',  'form': 'Tablet',  'strength': '60000 IU', 'aliases': ['D Rise', 'Arachitol']},
    {'name': 'Vitamin B12',     'generic': 'Methylcobalamin',  'form': 'Tablet',  'strength': '1500 mcg'},
    {'name': 'Methylcobalamin', 'generic': 'Methylcobalamin',  'form': 'Tablet',  'strength': '1500 mcg', 'aliases': ['Mecobalamin', 'Mecobion']},
    {'name': 'Vitamin C',       'generic': 'Ascorbic Acid',    'form': 'Tablet',  'strength': '500 mg'},
    {'name': 'Limcee',          'generic': 'Ascorbic Acid',    'form': 'Tablet',  'strength': '500 mg'},
    {'name': 'Iron',            'generic': 'Ferrous Sulfate',  'form': 'Tablet',  'strength': '200 mg'},
    {'name': 'Autrin',          'generic': 'Iron + Folic Acid', 'form': 'Capsule', 'strength': ''},
    {'name': 'Folic Acid',      'generic': 'Folic Acid',       'form': 'Tablet',  'strength': '5 mg'},
    {'name': 'Zinc',            'generic': 'Zinc Sulfate',     'form': 'Tablet',  'strength': '20 mg'},
    {'name': 'Multivitamin',    'generic': 'Multivitamin',     'form': 'Tablet',  'strength': '', 'aliases': ['Becosules', 'Supradyn', 'Zincovit']},
    {'name': 'Becosules',       'generic': 'B-Complex + Vitamin C', 'form': 'Capsule', 'strength': ''},
    {'name': 'Omega 3',         'generic': 'Fish Oil (EPA + DHA)', 'form': 'Capsule', 'strength': '1000 mg'},

    // ── Antifungals ──
    {'name': 'Fluconazole',     'generic': 'Fluconazole',      'form': 'Tablet',  'strength': '150 mg'},
    {'name': 'Diflucan',        'generic': 'Fluconazole',      'form': 'Tablet',  'strength': '150 mg'},
    {'name': 'Itraconazole',    'generic': 'Itraconazole',     'form': 'Capsule', 'strength': '100 mg'},
    {'name': 'Clotrimazole',    'generic': 'Clotrimazole',     'form': 'Topical', 'strength': '1%'},
    {'name': 'Candid',          'generic': 'Clotrimazole',     'form': 'Topical', 'strength': '1%'},

    // ── Respiratory / Asthma ──
    {'name': 'Salbutamol',      'generic': 'Salbutamol',       'form': 'Inhaler', 'strength': '100 mcg', 'aliases': ['Albuterol', 'Asthalin']},
    {'name': 'Asthalin',        'generic': 'Salbutamol',       'form': 'Inhaler', 'strength': '100 mcg'},
    {'name': 'Deriphyllin',     'generic': 'Theophylline + Etophylline', 'form': 'Tablet', 'strength': ''},
    {'name': 'Budecort',        'generic': 'Budesonide',       'form': 'Inhaler', 'strength': '200 mcg'},
    {'name': 'Foracort',        'generic': 'Budesonide + Formoterol', 'form': 'Inhaler', 'strength': '200+6 mcg'},
    {'name': 'Seroflo',         'generic': 'Salmeterol + Fluticasone', 'form': 'Inhaler', 'strength': '250 mcg'},

    // ── Cardiac ──
    {'name': 'Clopidogrel',     'generic': 'Clopidogrel',      'form': 'Tablet',  'strength': '75 mg'},
    {'name': 'Plavix',          'generic': 'Clopidogrel',      'form': 'Tablet',  'strength': '75 mg'},
    {'name': 'Clopilet',        'generic': 'Clopidogrel',      'form': 'Tablet',  'strength': '75 mg'},
    {'name': 'Warfarin',        'generic': 'Warfarin',         'form': 'Tablet',  'strength': '5 mg'},
    {'name': 'Digoxin',         'generic': 'Digoxin',          'form': 'Tablet',  'strength': '0.25 mg'},
    {'name': 'Lanoxin',         'generic': 'Digoxin',          'form': 'Tablet',  'strength': '0.25 mg'},
    {'name': 'Nitroglycerin',   'generic': 'Nitroglycerin',    'form': 'Tablet',  'strength': '2.6 mg', 'aliases': ['Sorbitrate', 'Isosorbide']},
    {'name': 'Amiodarone',      'generic': 'Amiodarone',       'form': 'Tablet',  'strength': '200 mg'},
    {'name': 'Diltiazem',       'generic': 'Diltiazem',        'form': 'Tablet',  'strength': '30 mg'},
    {'name': 'Verapamil',       'generic': 'Verapamil',        'form': 'Tablet',  'strength': '40 mg'},

    // ── Steroids ──
    {'name': 'Prednisolone',    'generic': 'Prednisolone',     'form': 'Tablet',  'strength': '10 mg'},
    {'name': 'Wysolone',        'generic': 'Prednisolone',     'form': 'Tablet',  'strength': '10 mg'},
    {'name': 'Prednisone',      'generic': 'Prednisone',       'form': 'Tablet',  'strength': '5 mg'},
    {'name': 'Dexamethasone',   'generic': 'Dexamethasone',    'form': 'Tablet',  'strength': '0.5 mg'},
    {'name': 'Deflazacort',     'generic': 'Deflazacort',      'form': 'Tablet',  'strength': '6 mg', 'aliases': ['Defcort']},
    {'name': 'Hydrocortisone',  'generic': 'Hydrocortisone',   'form': 'Topical', 'strength': '1%'},

    // ── Pain / Muscle Relaxants ──
    {'name': 'Tramadol',        'generic': 'Tramadol',         'form': 'Tablet',  'strength': '50 mg'},
    {'name': 'Ultracet',        'generic': 'Tramadol + Paracetamol', 'form': 'Tablet', 'strength': '37.5+325 mg'},
    {'name': 'Gabapentin',      'generic': 'Gabapentin',       'form': 'Capsule', 'strength': '300 mg', 'aliases': ['Gabapin']},
    {'name': 'Pregabalin',      'generic': 'Pregabalin',       'form': 'Capsule', 'strength': '75 mg', 'aliases': ['Pregalin', 'Lyrica']},
    {'name': 'Thiocolchicoside', 'generic': 'Thiocolchicoside', 'form': 'Capsule', 'strength': '4 mg', 'aliases': ['Myoril']},
    {'name': 'Etoricoxib',      'generic': 'Etoricoxib',       'form': 'Tablet',  'strength': '90 mg', 'aliases': ['Nucoxia']},
    {'name': 'Aceclofenac',     'generic': 'Aceclofenac',      'form': 'Tablet',  'strength': '100 mg', 'aliases': ['Zerodol']},

    // ── Dermatology ──
    {'name': 'Betamethasone',   'generic': 'Betamethasone',    'form': 'Topical', 'strength': '0.1%', 'aliases': ['Betnovate']},
    {'name': 'Clobetasol',      'generic': 'Clobetasol',       'form': 'Topical', 'strength': '0.05%', 'aliases': ['Tenovate']},
    {'name': 'Mupirocin',       'generic': 'Mupirocin',        'form': 'Topical', 'strength': '2%', 'aliases': ['T-Bact']},
    {'name': 'Permethrin',      'generic': 'Permethrin',       'form': 'Topical', 'strength': '5%'},
    {'name': 'Calamine',        'generic': 'Calamine Lotion',  'form': 'Topical', 'strength': '', 'aliases': ['Lacto Calamine']},

    // ── Eye drops ──
    {'name': 'Ciprofloxacin Eye Drops', 'generic': 'Ciprofloxacin',  'form': 'Drops', 'strength': '0.3%'},
    {'name': 'Moxifloxacin Eye Drops',  'generic': 'Moxifloxacin',   'form': 'Drops', 'strength': '0.5%', 'aliases': ['Vigamox']},
    {'name': 'Tobramycin Eye Drops',    'generic': 'Tobramycin',      'form': 'Drops', 'strength': '0.3%'},
    {'name': 'Artificial Tears', 'generic': 'Carboxymethylcellulose', 'form': 'Drops', 'strength': '0.5%', 'aliases': ['Refresh Tears', 'Systane']},

    // ── Miscellaneous ──
    {'name': 'Sildenafil',      'generic': 'Sildenafil',       'form': 'Tablet',  'strength': '50 mg', 'aliases': ['Viagra']},
    {'name': 'Tadalafil',       'generic': 'Tadalafil',        'form': 'Tablet',  'strength': '10 mg', 'aliases': ['Cialis']},
    {'name': 'Tamsulosin',      'generic': 'Tamsulosin',       'form': 'Capsule', 'strength': '0.4 mg', 'aliases': ['Urimax']},
    {'name': 'Finasteride',     'generic': 'Finasteride',      'form': 'Tablet',  'strength': '1 mg'},
    {'name': 'Phenytoin',       'generic': 'Phenytoin',        'form': 'Tablet',  'strength': '100 mg', 'aliases': ['Eptoin', 'Dilantin']},
    {'name': 'Carbamazepine',   'generic': 'Carbamazepine',    'form': 'Tablet',  'strength': '200 mg', 'aliases': ['Tegretol', 'Zen Retard']},
    {'name': 'Valproate',       'generic': 'Sodium Valproate', 'form': 'Tablet',  'strength': '200 mg', 'aliases': ['Valparin', 'Depakote']},
    {'name': 'Levetiracetam',   'generic': 'Levetiracetam',    'form': 'Tablet',  'strength': '500 mg', 'aliases': ['Levipil', 'Keppra']},
    {'name': 'ORS',             'generic': 'Oral Rehydration Salts', 'form': 'Syrup', 'strength': '', 'aliases': ['Electral']},
  ];
}
