import 'dart:math';

/// NLP Service providing fuzzy string matching algorithms
/// for intelligent drug name recognition.
///
/// Implements:
///  - Levenshtein Distance (edit distance)
///  - Jaro-Winkler Similarity (positional similarity)
///  - Combined fuzzy match with configurable threshold
class NlpService {
  // ── Levenshtein Distance ──────────────────────────────────
  /// Computes the minimum number of single-character edits
  /// (insertions, deletions, substitutions) required to
  /// transform [source] into [target].
  ///
  /// Used in spell-checkers, DNA analysis, and NLP pipelines.
  /// Time: O(m×n), Space: O(min(m,n)) via optimized single-row DP.
  static int levenshteinDistance(String source, String target) {
    final s = source.toLowerCase();
    final t = target.toLowerCase();

    if (s == t) return 0;
    if (s.isEmpty) return t.length;
    if (t.isEmpty) return s.length;

    // Optimized: use only two rows instead of full matrix
    List<int> prev = List.generate(t.length + 1, (i) => i);
    List<int> curr = List.filled(t.length + 1, 0);

    for (int i = 1; i <= s.length; i++) {
      curr[0] = i;
      for (int j = 1; j <= t.length; j++) {
        final cost = s[i - 1] == t[j - 1] ? 0 : 1;
        curr[j] = [
          prev[j] + 1,      // deletion
          curr[j - 1] + 1,  // insertion
          prev[j - 1] + cost // substitution
        ].reduce(min);
      }
      // Swap rows
      final temp = prev;
      prev = curr;
      curr = temp;
    }
    return prev[t.length];
  }

  /// Normalized Levenshtein Similarity (0.0 to 1.0).
  /// 1.0 = identical, 0.0 = completely different.
  static double levenshteinSimilarity(String source, String target) {
    if (source.isEmpty && target.isEmpty) return 1.0;
    final maxLen = max(source.length, target.length);
    if (maxLen == 0) return 1.0;
    return 1.0 - (levenshteinDistance(source, target) / maxLen);
  }

  // ── Jaro-Winkler Similarity ───────────────────────────────
  /// Computes Jaro-Winkler similarity between two strings.
  /// Returns a value between 0.0 (no match) and 1.0 (exact match).
  ///
  /// This metric gives higher scores to strings that match from
  /// the beginning — ideal for drug names where prefixes matter
  /// (e.g., "amlodipin" vs "amlodipine").
  ///
  /// Standard in medical record linkage (US Census, FDA systems).
  static double jaroWinklerSimilarity(String source, String target) {
    final s = source.toLowerCase();
    final t = target.toLowerCase();

    if (s == t) return 1.0;
    if (s.isEmpty || t.isEmpty) return 0.0;

    // Step 1: Compute Jaro similarity
    final matchWindow = (max(s.length, t.length) ~/ 2) - 1;
    if (matchWindow < 0) return 0.0;

    final sMatched = List.filled(s.length, false);
    final tMatched = List.filled(t.length, false);

    int matches = 0;
    int transpositions = 0;

    // Find matching characters
    for (int i = 0; i < s.length; i++) {
      final start = max(0, i - matchWindow);
      final end = min(i + matchWindow + 1, t.length);

      for (int j = start; j < end; j++) {
        if (tMatched[j] || s[i] != t[j]) continue;
        sMatched[i] = true;
        tMatched[j] = true;
        matches++;
        break;
      }
    }

    if (matches == 0) return 0.0;

    // Count transpositions
    int k = 0;
    for (int i = 0; i < s.length; i++) {
      if (!sMatched[i]) continue;
      while (!tMatched[k]) {
        k++;
      }
      if (s[i] != t[k]) transpositions++;
      k++;
    }

    final jaro = (matches / s.length +
            matches / t.length +
            (matches - transpositions / 2) / matches) /
        3.0;

    // Step 2: Winkler boost for common prefix (up to 4 chars)
    int prefixLen = 0;
    for (int i = 0; i < min(4, min(s.length, t.length)); i++) {
      if (s[i] == t[i]) {
        prefixLen++;
      } else {
        break;
      }
    }

    // Winkler scaling factor (standard p = 0.1)
    const p = 0.1;
    return jaro + (prefixLen * p * (1 - jaro));
  }

  // ── Combined Fuzzy Match ──────────────────────────────────
  /// Finds the best fuzzy match for [input] from a list of [candidates].
  /// Returns the best match if similarity >= [threshold], else null.
  ///
  /// Uses Jaro-Winkler as the primary metric (better for names)
  /// with Levenshtein as a secondary verification.
  static String? fuzzyMatch(
    String input,
    List<String> candidates, {
    double threshold = 0.85,
  }) {
    if (input.trim().isEmpty || candidates.isEmpty) return null;

    String? bestMatch;
    double bestScore = 0.0;

    for (final candidate in candidates) {
      final score = jaroWinklerSimilarity(input, candidate);
      if (score > bestScore) {
        bestScore = score;
        bestMatch = candidate;
      }
    }

    if (bestScore >= threshold && bestMatch != null) {
      return bestMatch;
    }

    // Fallback: try Levenshtein for short strings (≤ 5 chars)
    // where Jaro-Winkler can be less reliable
    if (input.length <= 5) {
      bestScore = 0.0;
      bestMatch = null;
      for (final candidate in candidates) {
        final score = levenshteinSimilarity(input, candidate);
        if (score > bestScore) {
          bestScore = score;
          bestMatch = candidate;
        }
      }
      if (bestScore >= threshold && bestMatch != null) {
        return bestMatch;
      }
    }

    return null;
  }

  /// Returns the similarity score and best match together.
  static ({String match, double score})? fuzzyMatchWithScore(
    String input,
    List<String> candidates, {
    double threshold = 0.85,
  }) {
    if (input.trim().isEmpty || candidates.isEmpty) return null;

    String? bestMatch;
    double bestScore = 0.0;

    for (final candidate in candidates) {
      final jwScore = jaroWinklerSimilarity(input, candidate);
      final levScore = levenshteinSimilarity(input, candidate);
      // Weighted combination: 70% Jaro-Winkler + 30% Levenshtein
      final combined = (jwScore * 0.7) + (levScore * 0.3);

      if (combined > bestScore) {
        bestScore = combined;
        bestMatch = candidate;
      }
    }

    if (bestScore >= threshold && bestMatch != null) {
      return (match: bestMatch, score: bestScore);
    }
    return null;
  }
}
