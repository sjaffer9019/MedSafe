import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'nlp_service.dart';

/// Drug interaction result model.
class DrugInteraction {
  final String drug1;
  final String drug2;
  final String severity; // 'High', 'Moderate', 'Low'
  final String description;
  final String source; // 'NIH RxNorm API', 'Local Knowledge Base'

  DrugInteraction({
    required this.drug1,
    required this.drug2,
    required this.severity,
    required this.description,
    this.source = 'Local Knowledge Base',
  });
}

/// Drug interaction service combining:
///  - NLP fuzzy matching (Jaro-Winkler + Levenshtein) for drug name resolution
///  - NIH RxNorm Interaction API for comprehensive interaction checking (10,000+ pairs)
///  - Local knowledge base as offline fallback
class RxNormService {
  static const String _rxBase = 'https://rxnav.nlm.nih.gov/REST';

  // ═══════════════════════════════════════════════════════════
  //  PUBLIC API
  // ═══════════════════════════════════════════════════════════

  /// Check interactions between a list of drug names.
  /// First tries the real NIH RxNorm Interaction API, then
  /// falls back to the local knowledge base if API fails.
  static Future<List<DrugInteraction>> checkInteractions(
      List<String> drugNames) async {
    if (drugNames.length < 2) return [];

    // Step 1: Normalize all drug names using NLP fuzzy matching
    final normalizedNames = drugNames.map(_normalizeName).toList();

    // Step 2: Try the real RxNorm Interaction API
    try {
      final apiResults =
          await _checkInteractionsViaAPI(drugNames, normalizedNames);
      if (apiResults.isNotEmpty) {
        // Merge API results with local DB results for completeness
        final localResults = _checkInteractionsLocal(drugNames, normalizedNames);
        return _mergeResults(apiResults, localResults);
      }
    } catch (e) {
      debugPrint('RxNorm API failed, using local fallback: $e');
    }

    // Step 3: Fallback to local knowledge base
    return _checkInteractionsLocal(drugNames, normalizedNames);
  }

  /// Get the RxCUI (RxNorm Concept Unique Identifier) for a drug name.
  /// Uses approximate matching for better results with misspellings.
  static Future<String?> getRxCui(String drugName) async {
    try {
      final normalized = _normalizeName(drugName);
      final encoded = Uri.encodeComponent(normalized);

      // Try approximate match first (handles typos)
      final url = '$_rxBase/rxcui.json?name=$encoded&search=2';
      final resp =
          await http.get(Uri.parse(url)).timeout(const Duration(seconds: 6));
      if (resp.statusCode == 200) {
        final body = jsonDecode(resp.body);
        final group = body['idGroup'];
        if (group != null) {
          final rxnormId = group['rxnormId'] as List?;
          if (rxnormId != null && rxnormId.isNotEmpty) {
            return rxnormId.first as String;
          }
        }
      }

      // Retry with exact match
      final exactUrl = '$_rxBase/rxcui.json?name=$encoded&search=0';
      final exactResp = await http
          .get(Uri.parse(exactUrl))
          .timeout(const Duration(seconds: 6));
      if (exactResp.statusCode == 200) {
        final body = jsonDecode(exactResp.body);
        final group = body['idGroup'];
        if (group != null) {
          final rxnormId = group['rxnormId'] as List?;
          if (rxnormId != null && rxnormId.isNotEmpty) {
            return rxnormId.first as String;
          }
        }
      }
    } catch (e) {
      debugPrint('Error getting RxCUI for $drugName: $e');
    }
    return null;
  }

  // ═══════════════════════════════════════════════════════════
  //  NLP-BASED NAME NORMALIZATION (Fuzzy Matching)
  // ═══════════════════════════════════════════════════════════

  /// Normalize a drug name using NLP fuzzy matching.
  /// 1. Clean the input (lowercase, remove dosage info)
  /// 2. Try exact brand-to-generic mapping
  /// 3. If no exact match, use Jaro-Winkler fuzzy matching
  ///    against the brand name dictionary
  static String _normalizeName(String name) {
    var n = name.trim().toLowerCase();

    // Remove dosage numbers (e.g., "500mg", "10 ml")
    n = n.replaceAll(RegExp(r'\d+\.?\d*\s*(mg|mcg|ml|g|iu|meq)'), '');

    // Remove common prefixes
    const prefixes = [
      'low dose ', 'extra strength ', 'maximum strength ',
      'regular strength ', 'junior ', 'adult ', 'senior ',
      'extended release ', 'sustained release ',
      'immediate release ', 'time release ', 'modified release ',
    ];
    for (final p in prefixes) {
      if (n.startsWith(p)) {
        n = n.substring(p.length);
        break;
      }
    }

    // Remove common suffixes
    const suffixes = [
      ' sodium', ' potassium', ' calcium', ' hydrochloride', ' hcl',
      ' sulfate', ' phosphate', ' tartrate', ' maleate', ' fumarate',
      ' acetate', ' mesylate', ' besylate', ' succinate', ' citrate',
      ' er', ' sr', ' xr', ' xl', ' cr', ' la', ' ds', ' forte',
      ' tablet', ' tablets', ' capsule', ' capsules', ' solution',
      ' syrup', ' injection', ' cream', ' ointment', ' gel',
      ' drops', ' patch',
    ];
    for (final s in suffixes) {
      if (n.endsWith(s)) {
        n = n.substring(0, n.length - s.length);
        break;
      }
    }

    n = n.trim();

    // ── Step 1: Exact brand-to-generic lookup ──
    if (_brandToGeneric.containsKey(n)) {
      return _brandToGeneric[n]!;
    }

    // ── Step 2: NLP Fuzzy Match (Jaro-Winkler + Levenshtein) ──
    // If no exact match, find the closest brand name using NLP
    final fuzzyResult = NlpService.fuzzyMatchWithScore(
      n,
      _brandToGeneric.keys.toList(),
      threshold: 0.85,
    );

    if (fuzzyResult != null) {
      debugPrint(
          '🧠 NLP fuzzy match: "$n" → "${fuzzyResult.match}" '
          '(score: ${fuzzyResult.score.toStringAsFixed(3)}) '
          '→ generic: "${_brandToGeneric[fuzzyResult.match]}"');
      return _brandToGeneric[fuzzyResult.match]!;
    }

    return n;
  }

  // ═══════════════════════════════════════════════════════════
  //  RxNorm INTERACTION API (Real NIH API — 10,000+ pairs)
  // ═══════════════════════════════════════════════════════════

  /// Query the real NIH RxNorm Interaction API.
  /// Endpoint: /interaction/list.json?rxcuis=CUI1+CUI2+...
  static Future<List<DrugInteraction>> _checkInteractionsViaAPI(
      List<String> originalNames, List<String> normalizedNames) async {
    // Step 1: Resolve each drug name to its RxCUI
    final rxCuis = <String>[];
    final cuiToName = <String, String>{};

    for (int i = 0; i < normalizedNames.length; i++) {
      final cui = await getRxCui(normalizedNames[i]);
      if (cui != null && cui.isNotEmpty) {
        rxCuis.add(cui);
        cuiToName[cui] = originalNames[i];
      }
    }

    if (rxCuis.length < 2) return [];

    // Step 2: Call the RxNorm Interaction API
    final cuiStr = rxCuis.join('+');
    final url = '$_rxBase/interaction/list.json?rxcuis=$cuiStr';

    final resp =
        await http.get(Uri.parse(url)).timeout(const Duration(seconds: 10));
    if (resp.statusCode != 200) return [];

    final body = jsonDecode(resp.body);
    final results = <DrugInteraction>[];
    final seen = <String>{};

    // Step 3: Parse interaction results
    final fullInteractionTypeGroup =
        body['fullInteractionTypeGroup'] as List? ?? [];

    for (final group in fullInteractionTypeGroup) {
      final interactionTypes =
          group['fullInteractionType'] as List? ?? [];

      for (final interaction in interactionTypes) {
        final interactionPairs =
            interaction['interactionPair'] as List? ?? [];

        for (final pair in interactionPairs) {
          final concepts =
              pair['interactionConcept'] as List? ?? [];
          if (concepts.length < 2) continue;

          final name1 = (concepts[0]['minConceptItem']?['name'] as String?) ?? '';
          final name2 = (concepts[1]['minConceptItem']?['name'] as String?) ?? '';
          final desc = (pair['description'] as String?) ?? '';
          final severity = _parseSeverity(pair['severity'] as String? ?? '');

          // Deduplicate
          final key = [name1.toLowerCase(), name2.toLowerCase()]
            ..sort();
          final keyStr = key.join('_');
          if (!seen.add(keyStr)) continue;

          // Map back to user's original names
          final cui1 = concepts[0]['minConceptItem']?['rxcui'] as String? ?? '';
          final cui2 = concepts[1]['minConceptItem']?['rxcui'] as String? ?? '';
          final displayName1 = cuiToName[cui1] ?? name1;
          final displayName2 = cuiToName[cui2] ?? name2;

          results.add(DrugInteraction(
            drug1: displayName1,
            drug2: displayName2,
            severity: severity,
            description: desc,
            source: 'NIH RxNorm API',
          ));
        }
      }
    }

    // Sort by severity
    results.sort((a, b) {
      const order = {'High': 0, 'Moderate': 1, 'Low': 2};
      return (order[a.severity] ?? 3).compareTo(order[b.severity] ?? 3);
    });

    return results;
  }

  /// Parse API severity string into our standard categories.
  static String _parseSeverity(String raw) {
    final lower = raw.toLowerCase();
    if (lower.contains('high') || lower.contains('severe') ||
        lower.contains('critical') || lower.contains('contraindicated')) {
      return 'High';
    }
    if (lower.contains('moderate') || lower.contains('significant')) {
      return 'Moderate';
    }
    if (lower.contains('low') || lower.contains('minor') ||
        lower.contains('mild')) {
      return 'Low';
    }
    // Default to Moderate if severity unknown
    return 'Moderate';
  }

  // ═══════════════════════════════════════════════════════════
  //  LOCAL KNOWLEDGE BASE (Offline Fallback)
  // ═══════════════════════════════════════════════════════════

  /// Check interactions using the local knowledge base.
  /// Used as fallback when the API is unavailable.
  static List<DrugInteraction> _checkInteractionsLocal(
      List<String> originalNames, List<String> normalizedNames) {
    final results = <DrugInteraction>[];
    final seen = <String>{};

    for (int i = 0; i < normalizedNames.length; i++) {
      for (int j = i + 1; j < normalizedNames.length; j++) {
        final a = normalizedNames[i];
        final b = normalizedNames[j];
        if (a == b) continue;

        for (final entry in _db) {
          final ea = entry['a'] as String;
          final eb = entry['b'] as String;

          // Use NLP fuzzy matching for comparison
          final matchA1 = _fuzzyContains(a, ea);
          final matchB1 = _fuzzyContains(b, eb);
          final matchA2 = _fuzzyContains(b, ea);
          final matchB2 = _fuzzyContains(a, eb);

          if ((matchA1 && matchB1) || (matchA2 && matchB2)) {
            final key = [ea, eb]..sort();
            final keyStr = key.join('_');
            if (seen.add(keyStr)) {
              results.add(DrugInteraction(
                drug1: originalNames[i],
                drug2: originalNames[j],
                severity: entry['sev'] as String,
                description: entry['desc'] as String,
                source: 'Local Knowledge Base',
              ));
            }
          }
        }
      }
    }

    results.sort((a, b) {
      const order = {'High': 0, 'Moderate': 1, 'Low': 2};
      return (order[a.severity] ?? 3).compareTo(order[b.severity] ?? 3);
    });

    return results;
  }

  /// NLP-enhanced comparison: returns true if strings are
  /// similar enough to be considered a match.
  /// Uses Jaro-Winkler for fuzzy comparison + substring check.
  static bool _fuzzyContains(String input, String target) {
    // Exact substring match (original behavior)
    if (input.contains(target) || target.contains(input)) return true;

    // NLP fuzzy match (new — handles typos & abbreviations)
    final similarity = NlpService.jaroWinklerSimilarity(input, target);
    return similarity >= 0.88;
  }

  /// Merge API and local results, preferring API results.
  static List<DrugInteraction> _mergeResults(
      List<DrugInteraction> apiResults, List<DrugInteraction> localResults) {
    final seen = <String>{};
    final merged = <DrugInteraction>[];

    // API results take priority
    for (final r in apiResults) {
      final key = [r.drug1.toLowerCase(), r.drug2.toLowerCase()]..sort();
      seen.add(key.join('_'));
      merged.add(r);
    }

    // Add any local results not already covered by API
    for (final r in localResults) {
      final key = [r.drug1.toLowerCase(), r.drug2.toLowerCase()]..sort();
      if (seen.add(key.join('_'))) {
        merged.add(r);
      }
    }

    merged.sort((a, b) {
      const order = {'High': 0, 'Moderate': 1, 'Low': 2};
      return (order[a.severity] ?? 3).compareTo(order[b.severity] ?? 3);
    });

    return merged;
  }

  // ═══════════════════════════════════════════════════════════
  //  BRAND-TO-GENERIC MAPPING (used by NLP fuzzy matcher)
  // ═══════════════════════════════════════════════════════════

  static const Map<String, String> _brandToGeneric = {
    // ── US / Global Brands ──
    'tylenol': 'acetaminophen', 'panadol': 'acetaminophen',
    'calpol': 'acetaminophen', 'paracetamol': 'acetaminophen',
    'advil': 'ibuprofen', 'nurofen': 'ibuprofen', 'motrin': 'ibuprofen',
    'aspro': 'aspirin', 'ecotrin': 'aspirin', 'bayer': 'aspirin',
    'bufferin': 'aspirin',
    'aleve': 'naproxen', 'naprosyn': 'naproxen',
    'coumadin': 'warfarin', 'jantoven': 'warfarin',
    'plavix': 'clopidogrel',
    'lipitor': 'atorvastatin', 'zocor': 'simvastatin',
    'crestor': 'rosuvastatin', 'pravachol': 'pravastatin',
    'glucophage': 'metformin',
    'zithromax': 'azithromycin', 'biaxin': 'clarithromycin',
    'cipro': 'ciprofloxacin',
    'flagyl': 'metronidazole',
    'diflucan': 'fluconazole',
    'prozac': 'fluoxetine', 'zoloft': 'sertraline', 'celexa': 'citalopram',
    'paxil': 'paroxetine', 'lexapro': 'escitalopram',
    'cordarone': 'amiodarone',
    'lanoxin': 'digoxin',
    'lasix': 'furosemide',
    'aldactone': 'spironolactone',
    'prinivil': 'lisinopril', 'zestril': 'lisinopril',
    'altace': 'ramipril', 'vasotec': 'enalapril',
    'norvasc': 'amlodipine',
    'cardizem': 'diltiazem', 'calan': 'verapamil',
    'dilantin': 'phenytoin',
    'tegretol': 'carbamazepine',
    'viagra': 'sildenafil', 'revatio': 'sildenafil',
    'cialis': 'tadalafil', 'levitra': 'vardenafil',
    'prilosec': 'omeprazole', 'nexium': 'esomeprazole',
    'prevacid': 'lansoprazole',
    'ultram': 'tramadol',
    'medrol': 'methylprednisolone', 'deltasone': 'prednisone',
    'claritin': 'loratadine', 'zyrtec': 'cetirizine',
    'allegra': 'fexofenadine', 'xyzal': 'levocetirizine',
    'singulair': 'montelukast',
    'januvia': 'sitagliptin',
    'lyrica': 'pregabalin', 'keppra': 'levetiracetam',
    'depakote': 'valproate',

    // ── Indian Brands — Analgesics ──
    'crocin': 'acetaminophen', 'dolo': 'acetaminophen',
    'dolo 650': 'acetaminophen', 'crocin 650': 'acetaminophen',
    'combiflam': 'ibuprofen', 'brufen': 'ibuprofen',
    'disprin': 'aspirin', 'ecosprin': 'aspirin', 'ecosprin 150': 'aspirin',
    'voveran': 'diclofenac', 'voveran sr': 'diclofenac',
    'meftal': 'mefenamic acid', 'meftal spas': 'mefenamic acid',
    'ultracet': 'tramadol',
    'zerodol': 'aceclofenac',
    'nucoxia': 'etoricoxib',

    // ── Indian Brands — Antibiotics ──
    'azee': 'azithromycin', 'azithral': 'azithromycin',
    'ciplox': 'ciprofloxacin',
    'mox': 'amoxicillin', 'augmentin': 'amoxicillin',
    'zifi': 'cefixime', 'taxim-o': 'cefixime',
    'levoflox': 'levofloxacin',
    'o2': 'ofloxacin',

    // ── Indian Brands — Antacids / GI ──
    'pan': 'pantoprazole', 'pantop': 'pantoprazole', 'pan 40': 'pantoprazole',
    'pan d': 'pantoprazole',
    'razo': 'rabeprazole',
    'domstal': 'domperidone',
    'emeset': 'ondansetron',
    'gelusil': 'antacid', 'digene': 'antacid',

    // ── Indian Brands — Antidiabetics ──
    'metformin': 'metformin', 'glycomet': 'metformin',
    'amaryl': 'glimepiride',

    // ── Indian Brands — Antihypertensives ──
    'amlokind': 'amlodipine', 'amlong': 'amlodipine', 'stamlo': 'amlodipine',
    'telma': 'telmisartan', 'telmikind': 'telmisartan', 'telsar': 'telmisartan',
    'telma h': 'telmisartan',
    'losacar': 'losartan',
    'atenolol': 'atenolol', 'tenormin': 'atenolol',
    'met xl': 'metoprolol', 'betaloc': 'metoprolol',
    'inderal': 'propranolol',
    'arkamin': 'clonidine',
    'cilacar': 'cilnidipine',

    // ── Indian Brands — Cholesterol ──
    'atorva': 'atorvastatin',
    'rozavel': 'rosuvastatin',

    // ── Indian Brands — Cardiac ──
    'clopilet': 'clopidogrel',
    'sorbitrate': 'isosorbide',

    // ── Indian Brands — Thyroid ──
    'thyronorm': 'levothyroxine', 'eltroxin': 'levothyroxine',
    'thyrox': 'levothyroxine',

    // ── Indian Brands — Allergy ──
    'cetzine': 'cetirizine',
    'montair': 'montelukast',

    // ── Indian Brands — Steroids ──
    'wysolone': 'prednisolone',
    'defcort': 'deflazacort',

    // ── Indian Brands — Neuro / Psych ──
    'nexito': 'escitalopram',
    'rivotril': 'clonazepam',
    'alprax': 'alprazolam',
    'eptoin': 'phenytoin',
    'zen retard': 'carbamazepine',
    'valparin': 'valproate',
    'levipil': 'levetiracetam',
    'gabapin': 'gabapentin',
    'pregalin': 'pregabalin',

    // ── Indian Brands — Pain / Muscle ──
    'myoril': 'thiocolchicoside',

    // ── Indian Brands — Respiratory ──
    'asthalin': 'salbutamol',
    'deriphyllin': 'theophylline',
    'budecort': 'budesonide',
    'foracort': 'budesonide',
    'seroflo': 'fluticasone',

    // ── Indian Brands — Supplements ──
    'shelcal': 'calcium', 'calcimax': 'calcium', 'ccm': 'calcium',
    'limcee': 'ascorbic acid',
    'becosules': 'vitamin b complex',

    // ── Indian Brands — Urology ──
    'urimax': 'tamsulosin',

    // ── Indian Brands — Dermatology ──
    'candid': 'clotrimazole',
    'betnovate': 'betamethasone',
    'tenovate': 'clobetasol',
    't-bact': 'mupirocin',
  };

  // ═══════════════════════════════════════════════════════════
  //  LOCAL INTERACTION DATABASE (Offline Fallback)
  // ═══════════════════════════════════════════════════════════

  static const List<Map<String, dynamic>> _db = [
    // Warfarin
    {'a': 'warfarin', 'b': 'aspirin',        'sev': 'High',     'desc': 'Concurrent use significantly increases bleeding risk. Warfarin anticoagulation is potentiated by aspirin antiplatelet effect.'},
    {'a': 'warfarin', 'b': 'ibuprofen',      'sev': 'High',     'desc': 'Ibuprofen (NSAID) increases warfarin anticoagulant effect and causes GI bleeding risk.'},
    {'a': 'warfarin', 'b': 'naproxen',       'sev': 'High',     'desc': 'Naproxen can increase warfarin plasma levels and significantly raise bleeding risk.'},
    {'a': 'warfarin', 'b': 'fluconazole',    'sev': 'High',     'desc': 'Fluconazole inhibits warfarin metabolism (CYP2C9), greatly increasing INR and bleeding risk.'},
    {'a': 'warfarin', 'b': 'amiodarone',     'sev': 'High',     'desc': 'Amiodarone inhibits warfarin metabolism. INR can double or triple. Monitor closely.'},
    {'a': 'warfarin', 'b': 'metronidazole',  'sev': 'High',     'desc': 'Metronidazole inhibits warfarin metabolism, markedly increasing anticoagulation.'},
    {'a': 'warfarin', 'b': 'rifampin',       'sev': 'High',     'desc': 'Rifampin induces warfarin metabolism, significantly reducing anticoagulant effect.'},
    {'a': 'warfarin', 'b': 'clarithromycin', 'sev': 'Moderate', 'desc': 'Clarithromycin can increase warfarin levels. Monitor INR when co-administered.'},
    {'a': 'warfarin', 'b': 'phenytoin',      'sev': 'Moderate', 'desc': 'Phenytoin and warfarin mutually affect each other metabolism. Both levels may fluctuate.'},
    {'a': 'warfarin', 'b': 'carbamazepine',  'sev': 'Moderate', 'desc': 'Carbamazepine induces warfarin metabolism, reducing anticoagulant effect.'},
    {'a': 'warfarin', 'b': 'ciprofloxacin',  'sev': 'Moderate', 'desc': 'Ciprofloxacin may enhance warfarin anticoagulant effect. Monitor INR.'},
    // Aspirin
    {'a': 'aspirin',        'b': 'ibuprofen',      'sev': 'Moderate', 'desc': 'Ibuprofen may block aspirin antiplatelet effect. Both increase GI bleeding risk.'},
    {'a': 'aspirin',        'b': 'naproxen',       'sev': 'Moderate', 'desc': 'Increased risk of GI bleeding and peptic ulcer when combined.'},
    {'a': 'aspirin',        'b': 'clopidogrel',    'sev': 'Moderate', 'desc': 'Dual antiplatelet therapy increases bleeding risk.'},
    {'a': 'aspirin',        'b': 'methotrexate',   'sev': 'High',     'desc': 'Aspirin reduces methotrexate renal excretion, leading to methotrexate toxicity.'},
    // NSAIDs
    {'a': 'ibuprofen',      'b': 'lisinopril',     'sev': 'Moderate', 'desc': 'NSAIDs blunt the antihypertensive effect of ACE inhibitors and can impair kidney function.'},
    {'a': 'ibuprofen',      'b': 'methotrexate',   'sev': 'High',     'desc': 'NSAIDs reduce methotrexate excretion, causing toxicity. Avoid concurrent use.'},
    {'a': 'ibuprofen',      'b': 'lithium',        'sev': 'Moderate', 'desc': 'NSAIDs reduce lithium excretion, increasing risk of lithium toxicity.'},
    {'a': 'ibuprofen',      'b': 'spironolactone', 'sev': 'Moderate', 'desc': 'NSAIDs reduce antihypertensive and diuretic effects of spironolactone.'},
    {'a': 'naproxen',       'b': 'lisinopril',     'sev': 'Moderate', 'desc': 'NSAIDs reduce antihypertensive effect of ACE inhibitors and may cause renal impairment.'},
    {'a': 'naproxen',       'b': 'methotrexate',   'sev': 'High',     'desc': 'NSAIDs reduce methotrexate excretion, causing toxicity.'},
    // Statins
    {'a': 'simvastatin',    'b': 'clarithromycin', 'sev': 'High',     'desc': 'Clarithromycin markedly increases simvastatin levels (CYP3A4 inhibition). High risk of rhabdomyolysis.'},
    {'a': 'simvastatin',    'b': 'erythromycin',   'sev': 'High',     'desc': 'Erythromycin inhibits simvastatin metabolism, greatly increasing myopathy risk.'},
    {'a': 'simvastatin',    'b': 'amiodarone',     'sev': 'High',     'desc': 'Amiodarone increases simvastatin plasma levels. Risk of myopathy.'},
    {'a': 'simvastatin',    'b': 'amlodipine',     'sev': 'Moderate', 'desc': 'Amlodipine may increase simvastatin exposure. Limit simvastatin to 20mg/day.'},
    {'a': 'simvastatin',    'b': 'diltiazem',      'sev': 'Moderate', 'desc': 'Diltiazem inhibits simvastatin metabolism, increasing myopathy risk.'},
    {'a': 'simvastatin',    'b': 'fluconazole',    'sev': 'High',     'desc': 'Azole antifungals markedly raise statin levels. Risk of severe myopathy.'},
    {'a': 'atorvastatin',   'b': 'clarithromycin', 'sev': 'Moderate', 'desc': 'Clarithromycin increases atorvastatin plasma levels, raising myopathy risk.'},
    {'a': 'atorvastatin',   'b': 'diltiazem',      'sev': 'Moderate', 'desc': 'Diltiazem inhibits atorvastatin metabolism via CYP3A4.'},
    // PDE5 inhibitors
    {'a': 'sildenafil',     'b': 'nitroglycerin',  'sev': 'High',     'desc': 'Combination causes severe, potentially fatal hypotension. Absolutely contraindicated.'},
    {'a': 'sildenafil',     'b': 'isosorbide',     'sev': 'High',     'desc': 'Any nitrate + sildenafil causes severe hypotension. Contraindicated.'},
    {'a': 'sildenafil',     'b': 'amlodipine',     'sev': 'Moderate', 'desc': 'Additive blood pressure lowering effect. Monitor for symptomatic hypotension.'},
    {'a': 'tadalafil',      'b': 'nitroglycerin',  'sev': 'High',     'desc': 'Combination causes severe hypotension. Contraindicated with any nitrate.'},
    // ACE inhibitors
    {'a': 'lisinopril',     'b': 'spironolactone', 'sev': 'High',     'desc': 'Combination can cause dangerous hyperkalemia. Monitor potassium levels.'},
    {'a': 'lisinopril',     'b': 'potassium',      'sev': 'Moderate', 'desc': 'ACE inhibitors increase potassium retention. Potassium supplements increase hyperkalemia risk.'},
    {'a': 'ramipril',       'b': 'spironolactone', 'sev': 'High',     'desc': 'Combination can cause dangerous hyperkalemia. Monitor potassium levels.'},
    {'a': 'enalapril',      'b': 'spironolactone', 'sev': 'High',     'desc': 'Combination can cause dangerous hyperkalemia. Monitor potassium levels.'},
    // Amiodarone
    {'a': 'amiodarone',     'b': 'digoxin',        'sev': 'High',     'desc': 'Amiodarone increases digoxin plasma levels by up to 70%, increasing toxicity risk.'},
    {'a': 'amiodarone',     'b': 'phenytoin',      'sev': 'Moderate', 'desc': 'Amiodarone inhibits phenytoin metabolism, increasing risk of phenytoin toxicity.'},
    // Digoxin
    {'a': 'digoxin',        'b': 'clarithromycin', 'sev': 'High',     'desc': 'Clarithromycin can increase digoxin concentrations significantly, causing toxicity.'},
    {'a': 'digoxin',        'b': 'erythromycin',   'sev': 'Moderate', 'desc': 'Erythromycin may increase digoxin concentrations in some patients.'},
    {'a': 'digoxin',        'b': 'spironolactone', 'sev': 'Moderate', 'desc': 'Spironolactone may increase digoxin levels and reduce renal clearance.'},
    // Metformin
    {'a': 'metformin',      'b': 'alcohol',        'sev': 'Moderate', 'desc': 'Alcohol with metformin increases risk of lactic acidosis. Avoid heavy drinking.'},
    // Antifungals
    {'a': 'fluconazole',    'b': 'phenytoin',      'sev': 'Moderate', 'desc': 'Fluconazole inhibits phenytoin metabolism, increasing risk of phenytoin toxicity.'},
    {'a': 'fluconazole',    'b': 'clopidogrel',    'sev': 'Moderate', 'desc': 'Fluconazole may reduce conversion of clopidogrel to its active form.'},
    // Antibiotics
    {'a': 'ciprofloxacin',  'b': 'theophylline',   'sev': 'High',     'desc': 'Ciprofloxacin inhibits theophylline metabolism, raising risk of toxicity.'},
    {'a': 'ciprofloxacin',  'b': 'antacid',        'sev': 'Moderate', 'desc': 'Antacids reduce ciprofloxacin absorption. Separate doses by 2 hours.'},
    // Clopidogrel
    {'a': 'clopidogrel',    'b': 'omeprazole',     'sev': 'Moderate', 'desc': 'Omeprazole inhibits CYP2C19, potentially reducing clopidogrel efficacy.'},
    {'a': 'clopidogrel',    'b': 'esomeprazole',   'sev': 'Moderate', 'desc': 'Esomeprazole may reduce clopidogrel antiplatelet efficacy.'},
    // SSRIs
    {'a': 'fluoxetine',     'b': 'tramadol',       'sev': 'High',     'desc': 'SSRIs + tramadol significantly increase risk of serotonin syndrome.'},
    {'a': 'sertraline',     'b': 'tramadol',       'sev': 'High',     'desc': 'SSRIs + tramadol significantly increase risk of serotonin syndrome.'},
    {'a': 'fluoxetine',     'b': 'warfarin',       'sev': 'Moderate', 'desc': 'Fluoxetine can enhance warfarin anticoagulant effect. Monitor INR.'},
    {'a': 'sertraline',     'b': 'warfarin',       'sev': 'Moderate', 'desc': 'SSRIs can enhance warfarin anticoagulant effect. Monitor INR.'},
    // Methotrexate
    {'a': 'methotrexate',   'b': 'probenecid',     'sev': 'High',     'desc': 'Probenecid reduces methotrexate excretion, causing toxicity.'},
    // Lithium
    {'a': 'lithium',        'b': 'ibuprofen',      'sev': 'Moderate', 'desc': 'NSAIDs reduce lithium excretion. Lithium toxicity risk increases.'},
    {'a': 'lithium',        'b': 'naproxen',       'sev': 'Moderate', 'desc': 'NSAIDs reduce lithium excretion. Lithium toxicity risk increases.'},
    // Phenytoin
    {'a': 'phenytoin',      'b': 'carbamazepine',  'sev': 'Moderate', 'desc': 'Complex interaction - levels of both drugs can be unpredictably altered.'},
    // Theophylline
    {'a': 'theophylline',   'b': 'ciprofloxacin',  'sev': 'High',     'desc': 'Ciprofloxacin inhibits theophylline metabolism, raising toxicity risk.'},
    {'a': 'theophylline',   'b': 'clarithromycin', 'sev': 'Moderate', 'desc': 'Clarithromycin may increase theophylline levels, increasing toxicity risk.'},
    // Spironolactone
    {'a': 'spironolactone', 'b': 'potassium',      'sev': 'Moderate', 'desc': 'Spironolactone is potassium-sparing. Adding potassium increases hyperkalemia risk.'},
    // Corticosteroids
    {'a': 'prednisolone',   'b': 'ibuprofen',      'sev': 'Moderate', 'desc': 'Combination greatly increases risk of GI ulceration and bleeding.'},
    {'a': 'prednisone',     'b': 'ibuprofen',      'sev': 'Moderate', 'desc': 'Combination greatly increases risk of GI ulceration and bleeding.'},
    {'a': 'prednisone',     'b': 'warfarin',       'sev': 'Moderate', 'desc': 'Corticosteroids can alter warfarin anticoagulation. Monitor INR.'},
    // Antihypertensives
    {'a': 'verapamil',      'b': 'simvastatin',    'sev': 'Moderate', 'desc': 'Verapamil inhibits simvastatin metabolism, increasing myopathy risk.'},
    {'a': 'verapamil',      'b': 'digoxin',        'sev': 'Moderate', 'desc': 'Verapamil increases digoxin plasma concentrations.'},
    {'a': 'diltiazem',      'b': 'simvastatin',    'sev': 'Moderate', 'desc': 'Diltiazem inhibits simvastatin metabolism, increasing myopathy risk.'},
    {'a': 'diltiazem',      'b': 'digoxin',        'sev': 'Moderate', 'desc': 'Diltiazem can increase digoxin levels and heart block risk.'},
    // Opioids
    {'a': 'tramadol',       'b': 'fluoxetine',     'sev': 'High',     'desc': 'High risk of serotonin syndrome.'},
    {'a': 'tramadol',       'b': 'sertraline',     'sev': 'High',     'desc': 'High risk of serotonin syndrome.'},
    {'a': 'tramadol',       'b': 'citalopram',     'sev': 'High',     'desc': 'High risk of serotonin syndrome and QT prolongation.'},
  ];
}
