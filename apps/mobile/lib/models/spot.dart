/// A row of the `spots` table — the curated output of the ingestion pipeline.
/// Mirrors `apps/web/src/lib/types.ts` (`Spot`). PostgREST may serialize
/// `numeric` as strings, so every number is coerced on the way in.
class Spot {
  Spot({
    required this.id,
    required this.placeId,
    required this.name,
    required this.neighborhood,
    required this.address,
    required this.lat,
    required this.lng,
    required this.priceMin,
    required this.priceMax,
    required this.priceCurrency,
    required this.priceBasis,
    required this.priceLevel,
    required this.qualityScore,
    required this.dimensions,
    required this.tags,
    required this.summary,
    required this.videoCount,
    required this.coverImageUrl,
    required this.sourceVideoUrl,
    required this.firstSeenAt,
    required this.hideMap,
    required this.mapUrl,
  });

  final String id;

  /// `google_place_id` — the stable key everything else (saves, visits,
  /// share links) hangs off.
  final String placeId;
  final String name;
  final String? neighborhood;
  final String? address;
  final double lat;
  final double lng;
  final double? priceMin;
  final double? priceMax;
  final String priceCurrency;

  /// `per_person` | `total` | `unknown`
  final String priceBasis;
  final int? priceLevel;

  /// 0..100; the UI shows it as a 0..5 star score.
  final double qualityScore;
  final Dimensions dimensions;
  final List<String> tags;
  final String? summary;
  final int videoCount;
  final String? coverImageUrl;
  final String? sourceVideoUrl;
  final DateTime firstSeenAt;
  final bool hideMap;
  final String? mapUrl;

  double get stars => qualityScore / 20;

  /// The canonical area (sefer) this spot files under, set once the catalog
  /// loads (see logic/areas.dart: own neighbourhood → address → nearby
  /// spots). Null when nothing places it.
  String? sefer;

  /// True when [sefer] was worked out from nearby spots rather than stated.
  bool seferInferred = false;

  String get area => sefer ?? neighborhood ?? 'Addis Ababa';

  /// [area] without a trailing note in brackets, for tags and one-line
  /// labels: "22 (from Adey Ababa stadium to Addis Hiwot hospital)" → "22".
  String get areaShort {
    final short = area.replaceFirst(RegExp(r'\s*\(.*\)\s*$'), '').trim();
    return short.isEmpty ? area : short;
  }

  /// A smaller WebP of a cover we re-host, by the ingestion naming rule
  /// `<placeId>-<width>.webp` (widths 480 and 960, see the CLI's
  /// lib/storage.ts). Null for external covers, which have no variants.
  String? coverVariant(int width) {
    const marker = '/storage/v1/object/public/spot-covers/';
    final url = coverImageUrl;
    final i = url?.indexOf(marker) ?? -1;
    if (i < 0) return null;
    return '${url!.substring(0, i + marker.length)}${Uri.encodeComponent(placeId)}-$width.webp';
  }

  bool get hasPrice => priceLevel != null && priceMin != null;

  /// First seen within the last 7 days. `first_seen_at` is set once on insert,
  /// so the badge decays on its own.
  bool get isNew => DateTime.now().difference(firstSeenAt).inDays < 7;

  factory Spot.fromJson(Map<String, dynamic> j) {
    final signals = j['quality_signals'] as Map<String, dynamic>?;
    return Spot(
      id: '${j['id']}',
      placeId: '${j['google_place_id']}',
      name: '${j['name']}',
      neighborhood: j['neighborhood'] as String?,
      address: j['address'] as String?,
      lat: _num(j['lat']) ?? 0,
      lng: _num(j['lng']) ?? 0,
      priceMin: _num(j['price_min']),
      priceMax: _num(j['price_max']),
      priceCurrency: (j['price_currency'] as String?) ?? 'ETB',
      priceBasis: (j['price_basis'] as String?) ?? 'unknown',
      priceLevel: _num(j['price_level'])?.round(),
      qualityScore: _num(j['quality_score']) ?? 0,
      dimensions: Dimensions.fromJson(signals?['dimensions'] as Map<String, dynamic>?),
      tags: ((j['tags'] as List?) ?? const []).map((t) => '$t').toList(),
      summary: j['summary'] as String?,
      videoCount: _num(j['video_count'])?.round() ?? 0,
      coverImageUrl: j['cover_image_url'] as String?,
      sourceVideoUrl: j['source_video_url'] as String?,
      firstSeenAt: DateTime.tryParse('${j['first_seen_at']}') ?? DateTime.now().subtract(const Duration(days: 30)),
      hideMap: j['hide_map'] == true,
      mapUrl: j['map_url'] as String?,
    );
  }
}

/// The five 0..5 quality dimensions the normalizer scores from reviews.
class Dimensions {
  const Dimensions({
    required this.aesthetic,
    required this.vibe,
    required this.food,
    required this.value,
    required this.service,
  });

  final double aesthetic;
  final double vibe;
  final double food;
  final double value;
  final double service;

  List<(String, double)> get labelled => [
    ('Aesthetic', aesthetic),
    ('Vibe', vibe),
    ('Food', food),
    ('Value', value),
    ('Service', service),
  ];

  factory Dimensions.fromJson(Map<String, dynamic>? j) => Dimensions(
    aesthetic: _num(j?['aesthetic']) ?? 0,
    vibe: _num(j?['vibe']) ?? 0,
    food: _num(j?['food']) ?? 0,
    value: _num(j?['value']) ?? 0,
    service: _num(j?['service']) ?? 0,
  );
}

double? _num(Object? v) {
  if (v == null) return null;
  if (v is num) return v.toDouble();
  return double.tryParse('$v');
}
