import 'package:flutter/material.dart' show IconData, Icons;

import '../models/spot.dart';

/// Curated category → tags map, ported from `apps/web/src/lib/categories.ts`.
/// A category matches a spot if any of its tags appears in the spot's tags.
class Category {
  const Category(this.key, this.label, this.icon, this.tags, {this.match});

  final String key;
  final String label;
  final IconData icon;
  final List<String> tags;

  /// Predicate categories (e.g. "New") match on spot state instead of tags.
  final bool Function(Spot)? match;

  bool matches(Spot s) {
    if (match != null) return match!(s);
    final spotTags = s.tags.map((t) => t.toLowerCase()).toSet();
    return tags.any(spotTags.contains);
  }
}

bool _isNew(Spot s) => s.isNew;

final categories = <Category>[
  const Category('new', 'New', Icons.auto_awesome_rounded, [], match: _isNew),
  const Category('habesha', 'Habesha', Icons.rice_bowl_rounded, [
    'ethiopian', 'traditional', 'kitfo', 'tibs', 'injera', 'shiro', 'fasting', //
    'fir-fir', 'doro', 'beyaynetu', 'habesha', 'local',
  ]),
  const Category('cafe', 'Cafe', Icons.local_cafe_rounded, ['cafe', 'coffee', 'espresso', 'tea']),
  const Category('burgers', 'Burgers', Icons.lunch_dining_rounded, ['burger']),
  const Category('fastfood', 'Fast food', Icons.fastfood_rounded, [
    'fast-food', 'takeaway', 'sandwich', 'wrap', 'chicken', 'fries', 'combo', //
    'hotdog', 'street-food',
  ]),
  const Category('pizza', 'Pizza & Italian', Icons.local_pizza_rounded, ['pizza', 'italian', 'pasta']),
  const Category('dessert', 'Dessert & Pastry', Icons.cake_rounded, [
    'dessert', 'bakery', 'cake', 'pastry', 'cheesecake', 'chocolate', //
    'ice-cream', 'donut', 'cookie',
  ]),
  const Category('grill', 'Grill & Steak', Icons.outdoor_grill_rounded, ['steak', 'bbq', 'grill', 'meat', 'roast']),
  const Category('me_says', 'me_says', Icons.videocam_rounded, ['me_says']),
  const Category('activity', 'Activity', Icons.sports_esports_rounded, ['activity']),
  const Category('outlets', 'Outlets', Icons.power_rounded, [
    'sockets',
    'outlet',
    'outlets',
    'power',
    'outlet_available',
    'outlets_available',
  ]),
];

/// True if the spot belongs to any of the selected categories (empty = all pass).
bool matchesCategories(Spot s, Set<String> selected) {
  if (selected.isEmpty) return true;
  return categories.any((c) => selected.contains(c.key) && c.matches(s));
}

enum SortMode {
  quality('Highest rated'),
  priceAsc('Price · low to high'),
  priceDesc('Price · high to low'),
  name('Name · A–Z'),
  recent('Recently added');

  const SortMode(this.label);
  final String label;

  int compare(Spot a, Spot b) => switch (this) {
    quality => b.qualityScore.compareTo(a.qualityScore),
    priceAsc => (a.priceMin ?? 0).compareTo(b.priceMin ?? 0),
    priceDesc => (b.priceMin ?? 0).compareTo(a.priceMin ?? 0),
    name => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
    recent => b.firstSeenAt.compareTo(a.firstSeenAt),
  };
}
