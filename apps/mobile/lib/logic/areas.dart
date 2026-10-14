import '../models/spot.dart';
import 'area_families.dart';
import 'geo.dart';

/// Area (sefer) grouping, ported from apps/web/src/lib/areas.ts.
///
/// `neighborhood` is free text from review videos, so one real area arrives
/// under many strings ("4 kilo", "Arat Kilo", "4 Kilo (Abrehot)"). Everything
/// here files those under the hand-curated canonical set in [areaFamilies].

/// Lowercase, drop Latin punctuation, collapse whitespace. Ethiopic passes
/// through, so it only matches by being listed verbatim in a family.
String _norm(String raw) =>
    raw.toLowerCase().replaceAll(RegExp(r'''[().,;/&'"-]+'''), ' ').replaceAll(RegExp(r'\s+'), ' ').trim();

/// (normalised variant, canonical), longest first so "bole bulbula" is
/// tested before "bole".
final List<(String, String)> _lookup = [
  for (final e in areaFamilies.entries)
    for (final v in e.value) (_norm(v), e.key),
]..sort((a, b) => b.$1.length.compareTo(a.$1.length));

final Map<String, String> _exact = {for (final (v, c) in _lookup) v: c};

String? _resolve(String s) {
  final exact = _exact[s];
  if (exact != null) return exact;
  for (final (variant, canonical) in _lookup) {
    if (s.startsWith('$variant ')) return canonical;
  }
  return null;
}

/// The canonical area a raw neighbourhood files under: exact variant, then
/// with the bracketed qualifier dropped, then a word-boundary stem match. An
/// unknown string comes back trimmed rather than dropped.
String? canonicalArea(String? raw) {
  if (raw == null) return null;
  final full = _norm(raw);
  if (full.isEmpty) return null;
  return _resolve(full) ?? _resolve(_norm(raw.replaceAll(RegExp(r'\(.*?\)'), ' '))) ?? raw.trim();
}

/// A canonical area named anywhere in a free-text address ("Welo Sefer Addis
/// ababa, …" → Wello Sefer). Whole words only, longest variant first.
String? areaInAddress(String? address) {
  if (address == null) return null;
  final words = ' ${_norm(address)} ';
  for (final (variant, canonical) in _lookup) {
    // two-letter stems ("22") are too likely to be a house number
    if (variant.length < 3) continue;
    if (words.contains(' $variant ')) return canonical;
  }
  return null;
}

/// Everything search should match for an area: its name plus the variants
/// that are genuine synonyms ("piazza" finds Piassa, "arat kilo" 4 Kilo).
/// Variants that name a different area are left out, so "bole" never
/// matches Summit.
final Map<String, String> _searchText = {
  for (final e in areaFamilies.entries)
    e.key: () {
      final foreign = areaFamilies.keys.where(
        (other) => other != e.key && !_norm(e.key).startsWith('${_norm(other)} '),
      );
      bool mentionsAnother(String v) {
        final words = ' ${_norm(v)} ';
        return foreign.any((other) => words.contains(' ${_norm(other)} '));
      }

      return [e.key, ...e.value.where((v) => !mentionsAnother(v))].join(' ').toLowerCase();
    }(),
};

String areaSearchText(String area) => _searchText[area] ?? area.toLowerCase();

/// Give every spot a sefer. In order:
///  1. its own neighbourhood, filed under the canonical area;
///  2. an area named in its address;
///  3. the area most of its closest labelled neighbours share (up to five
///     within 2 km) — a spot with no stated area still sits somewhere.
/// Spots with none of these keep a null sefer and read "Addis Ababa".
void assignSefers(List<Spot> spots) {
  final labelled = <Spot>[];
  for (final s in spots) {
    s.sefer = canonicalArea(s.neighborhood) ?? areaInAddress(s.address);
    if (s.sefer != null) labelled.add(s);
  }
  for (final s in spots) {
    if (s.sefer != null) continue;
    final here = (lat: s.lat, lng: s.lng);
    final near = [
      for (final o in labelled)
        if (haversineKm(here, (lat: o.lat, lng: o.lng)) case final km when km <= 2) (o.sefer!, km),
    ]..sort((a, b) => a.$2.compareTo(b.$2));
    final votes = <String, int>{};
    for (final (area, _) in near.take(5)) {
      votes.update(area, (v) => v + 1, ifAbsent: () => 1);
    }
    if (votes.isEmpty) continue;
    // most votes; ties go to whichever is closest (first seen)
    s.sefer = votes.entries.reduce((a, b) => b.value > a.value ? b : a).key;
    s.seferInferred = true;
  }
}
