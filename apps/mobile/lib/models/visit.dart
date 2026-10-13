/// A row of the `visits` table — our "Places we've been" log. `rating` is
/// 0..5 (0 = unrated); the dimension sliders are null until rated.
class Visit {
  const Visit({
    required this.id,
    required this.placeId,
    required this.name,
    required this.visitedAt,
    this.rating = 0,
    this.notes = '',
    this.aesthetic,
    this.vibe,
    this.food,
    this.portions,
    this.service,
  });

  final String id;
  final String placeId;
  final String name;
  final DateTime visitedAt;
  final int rating;
  final String notes;
  final double? aesthetic;
  final double? vibe;
  final double? food;
  final double? portions;
  final double? service;

  /// Our subjective slider dimensions ("portions" replaces "value").
  static const dims = ['aesthetic', 'vibe', 'food', 'portions', 'service'];

  double? dim(String key) => switch (key) {
    'aesthetic' => aesthetic,
    'vibe' => vibe,
    'food' => food,
    'portions' => portions,
    'service' => service,
    _ => null,
  };

  Visit copyWith({int? rating, String? notes, Map<String, double?>? dims}) => Visit(
    id: id,
    placeId: placeId,
    name: name,
    visitedAt: visitedAt,
    rating: rating ?? this.rating,
    notes: notes ?? this.notes,
    aesthetic: dims != null && dims.containsKey('aesthetic') ? dims['aesthetic'] : aesthetic,
    vibe: dims != null && dims.containsKey('vibe') ? dims['vibe'] : vibe,
    food: dims != null && dims.containsKey('food') ? dims['food'] : food,
    portions: dims != null && dims.containsKey('portions') ? dims['portions'] : portions,
    service: dims != null && dims.containsKey('service') ? dims['service'] : service,
  );

  /// The editable columns, keyed exactly as the table names them.
  Map<String, dynamic> patchJson() => {
    'rating': rating == 0 ? null : rating,
    'notes': notes.isEmpty ? null : notes,
    'aesthetic': aesthetic,
    'vibe': vibe,
    'food': food,
    'portions': portions,
    'service': service,
  };

  Map<String, dynamic> toJson() => {
    'id': id,
    'google_place_id': placeId,
    'name': name,
    'visited_at': visitedAt.toIso8601String().substring(0, 10),
    ...patchJson(),
  };

  factory Visit.fromJson(Map<String, dynamic> j) => Visit(
    id: '${j['id']}',
    placeId: '${j['google_place_id']}',
    name: '${j['name']}',
    visitedAt: DateTime.tryParse('${j['visited_at']}') ?? DateTime.now(),
    rating: _num(j['rating'])?.round() ?? 0,
    notes: (j['notes'] as String?) ?? '',
    aesthetic: _num(j['aesthetic']),
    vibe: _num(j['vibe']),
    food: _num(j['food']),
    portions: _num(j['portions']),
    service: _num(j['service']),
  );
}

double? _num(Object? v) {
  if (v == null) return null;
  if (v is num) return v.toDouble();
  return double.tryParse('$v');
}
