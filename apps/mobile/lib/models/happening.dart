/// A published row of the `happenings` table — a time-bound event, as opposed
/// to a [Spot], which is a permanent venue. A published row always has a
/// `starts_at` (DB check constraint); everything else is genuinely optional.
class Happening {
  const Happening({
    required this.id,
    required this.sourceUrl,
    required this.imageUrl,
    required this.title,
    required this.summary,
    required this.venueName,
    required this.startsAt,
    required this.endsAt,
    required this.priceMin,
    required this.priceMax,
    required this.priceCurrency,
    required this.ticketUrl,
    required this.tags,
    required this.confidence,
  });

  final String id;
  final String sourceUrl;
  final String? imageUrl;
  final String? title;
  final String? summary;
  final String? venueName;
  final DateTime startsAt;
  final DateTime? endsAt;
  final double? priceMin;
  final double? priceMax;
  final String priceCurrency;
  final String? ticketUrl;
  final List<String> tags;
  final double? confidence;

  bool get isFree => priceMin == 0;

  factory Happening.fromJson(Map<String, dynamic> j) => Happening(
    id: '${j['id']}',
    sourceUrl: '${j['source_url'] ?? ''}',
    imageUrl: j['image_url'] as String?,
    title: j['title'] as String?,
    summary: j['summary'] as String?,
    venueName: j['venue_name'] as String?,
    startsAt: DateTime.parse('${j['starts_at']}').toUtc(),
    endsAt: j['ends_at'] == null ? null : DateTime.parse('${j['ends_at']}').toUtc(),
    priceMin: _num(j['price_min']),
    priceMax: _num(j['price_max']),
    priceCurrency: (j['price_currency'] as String?) ?? 'ETB',
    ticketUrl: j['ticket_url'] as String?,
    tags: ((j['tags'] as List?) ?? const []).map((t) => '$t').toList(),
    confidence: _num(j['confidence']),
  );
}

double? _num(Object? v) {
  if (v == null) return null;
  if (v is num) return v.toDouble();
  return double.tryParse('$v');
}
