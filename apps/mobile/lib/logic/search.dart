import 'dart:math' as math;

import '../models/spot.dart';
import 'areas.dart';

/// Spot search, in the spirit of the web's Fuse setup (name weighs most, then
/// tags, then area, then the summary) without the dependency.
///
/// Relevance leads, like the web: exact name, then names starting with the
/// query, then everything else by how well each word matched. Every word has
/// to match somewhere; a word of four letters or more may be off by a typo or
/// two ("tiramisu" finds "tiramissu", "kazanchiz" finds Kazanchis), and an
/// area matches by any of its synonyms ("piazza" finds Piassa).

String _norm(String s) =>
    s.toLowerCase().replaceAll(RegExp(r'''[().,;:/&'"!?\-–—“”]+'''), ' ').replaceAll(RegExp(r'\s+'), ' ').trim();

/// Typo matches rank at or above this, so a caller can keep them only when
/// nothing matched exactly ("piazza" is Piassa, not every pizza place).
const fuzzyRank = 100.0;

/// Lower is better; null means no match. 0 = exact name, 1 = name prefix,
/// 2 = name contains the query, 3+ = per-word matches across fields, and
/// [fuzzyRank]+ when any word only matched with a typo.
double? searchRank(Spot s, String query) {
  final q = _norm(query);
  if (q.isEmpty) return 0;
  final name = _norm(s.name);
  if (name == q) return 0;
  if (name.startsWith(q)) return 1;
  if (name.contains(q)) return 2;

  // (text, cost): cheaper fields win ties between spots
  final fields = <(String, double)>[
    (name, 0),
    (_norm(s.tags.join(' ')), 1),
    ('${areaSearchText(s.area)} ${_norm(s.neighborhood ?? '')}', 1.5),
    (_norm('${s.summary ?? ''} ${s.address ?? ''}'), 2.5),
  ];

  var total = 0.0;
  var fuzzy = false;
  final terms = q.split(' ');
  for (final term in terms) {
    double? best;
    for (final (text, cost) in fields) {
      if (text.contains(term)) best = math.min(best ?? cost, cost);
    }
    if (best == null && term.length >= 4) {
      final allowed = term.length <= 6 ? 1 : 2;
      for (final (text, cost) in fields) {
        if (text.split(' ').any((w) => _closeEnough(term, w, allowed))) {
          best = math.min(best ?? cost, cost);
          fuzzy = true;
        }
      }
    }
    if (best == null) return null;
    total += best;
  }
  return (fuzzy ? fuzzyRank : 3) + total / terms.length;
}

/// Ranks for [spots] against [query]: exact matches if there are any,
/// otherwise the typo matches.
Map<Spot, double> searchSpots(Iterable<Spot> spots, String query) {
  final ranks = <Spot, double>{for (final s in spots) s: ?searchRank(s, query)};
  if (ranks.values.any((r) => r < fuzzyRank)) ranks.removeWhere((_, r) => r >= fuzzyRank);
  return ranks;
}

/// Edit distance ≤ [max] between [a] and [b] (or a typo'd prefix of a longer
/// word, so "cappucc" still reaches "cappuccino"), stopping early once a row
/// can't get back under the limit.
bool _closeEnough(String a, String b, int max) {
  if (b.length > a.length + max) b = b.substring(0, a.length + max);
  if ((a.length - b.length).abs() > max) return false;
  var prev = List<int>.generate(b.length + 1, (i) => i);
  for (var i = 1; i <= a.length; i++) {
    final cur = List<int>.filled(b.length + 1, 0)..[0] = i;
    var rowMin = cur[0];
    for (var j = 1; j <= b.length; j++) {
      final sub = prev[j - 1] + (a.codeUnitAt(i - 1) == b.codeUnitAt(j - 1) ? 0 : 1);
      cur[j] = math.min(sub, math.min(prev[j] + 1, cur[j - 1] + 1));
      rowMin = math.min(rowMin, cur[j]);
    }
    if (rowMin > max) return false;
    prev = cur;
  }
  // a typo'd prefix counts too: best distance anywhere along the last row
  return prev.reduce(math.min) <= max;
}
