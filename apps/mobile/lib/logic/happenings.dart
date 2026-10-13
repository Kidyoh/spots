import 'package:flutter/material.dart' show IconData, Icons;

import '../models/happening.dart';

/// Presentation logic for events, ported from `apps/web/src/lib/happenings.ts`.
///
/// Addis Ababa is UTC+3 year-round with no DST. Every date decision is made in
/// Addis wall-clock rather than the phone's timezone: an event is "on
/// Saturday" in the city it happens in.
const _addisOffset = Duration(hours: 3);

/// The instant shifted into Addis wall-clock, for reading date parts off UTC.
DateTime _addis(DateTime t) => t.toUtc().add(_addisOffset);

/// YYYY-MM-DD in Addis — the grouping key for a day.
String addisDayKey(DateTime t) => _addis(t).toIso8601String().substring(0, 10);

const _days = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];
const _months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];

/// "Today" / "Tomorrow" / "Saturday 22 Aug" — the heading for a day group.
String dayLabel(DateTime t, [DateTime? now]) {
  now ??= DateTime.now();
  final key = addisDayKey(t);
  if (key == addisDayKey(now)) return 'Today';
  if (key == addisDayKey(now.add(const Duration(days: 1)))) return 'Tomorrow';
  final d = _addis(t);
  return '${_days[d.weekday - 1]} ${d.day} ${_months[d.month - 1]}';
}

/// "9:00 PM", or null when the post never stated a time (extraction writes
/// exactly midnight Addis for a date-only post).
String? timeLabel(DateTime t) {
  final d = _addis(t);
  if (d.hour == 0 && d.minute == 0) return null;
  final suffix = d.hour < 12 ? 'AM' : 'PM';
  final h12 = d.hour % 12 == 0 ? 12 : d.hour % 12;
  return '$h12:${d.minute.toString().padLeft(2, '0')} $suffix';
}

/// What to head the event with, and whether the venue has been used up.
({String title, bool venueUsed}) heading(Happening h) {
  if (h.title != null && h.title!.isNotEmpty) return (title: h.title!, venueUsed: false);
  if (h.venueName != null) return (title: h.venueName!, venueUsed: true);
  return (title: 'An evening out', venueUsed: false);
}

/// "Free" / "700 ETB" / "300–700 ETB", or null when no price was stated.
String? eventPriceLabel(Happening h) {
  final min = h.priceMin;
  final max = h.priceMax;
  if (min == null) return null;
  if (min == 0 && (max == null || max == 0)) return 'Free';
  String money(double n) => n.round().toString().replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (_) => ',');
  return max != null && max != min
      ? '${money(min)}–${money(max)} ${h.priceCurrency}'
      : '${money(min)} ${h.priceCurrency}';
}

/// "Today" / "Tomorrow" / "in 8 days" / "On now", counted in whole Addis days.
String countdown(DateTime t, [DateTime? now]) {
  now ??= DateTime.now();
  final a = DateTime.parse('${addisDayKey(t)}T00:00:00Z');
  final b = DateTime.parse('${addisDayKey(now)}T00:00:00Z');
  final days = a.difference(b).inDays;
  if (days < 0) return 'On now';
  if (days == 0) return 'Today';
  if (days == 1) return 'Tomorrow';
  if (days < 7) return 'in $days days';
  final weeks = (days / 7).round();
  return weeks == 1 ? 'in a week' : 'in $weeks weeks';
}

/// "22 Aug – 10 Sep" before a multi-day event starts, "Until 10 Sep" once it
/// is running; null for single-day events.
String? spanLabel(DateTime start, DateTime? end, [DateTime? now]) {
  now ??= DateTime.now();
  if (end == null) return null;
  final startKey = addisDayKey(start);
  if (addisDayKey(end).compareTo(startKey) <= 0) return null;
  String short(DateTime t) {
    final d = _addis(t);
    return '${d.day} ${_months[d.month - 1]}';
  }

  if (addisDayKey(now).compareTo(startKey) > 0) return 'Until ${short(end)}';
  return '${short(start)} – ${short(end)}';
}

/// "SAT 29 AUG" — the date as the card's headline.
({String weekday, String day, String month}) dateStamp(DateTime t) {
  final d = _addis(t);
  return (weekday: _days[d.weekday - 1].substring(0, 3), day: '${d.day}', month: _months[d.month - 1]);
}

/// A Google Calendar "add event" link.
Uri calendarUri(Happening h) {
  String stamp(DateTime t) =>
      t.toUtc().toIso8601String().replaceAll(RegExp(r'[-:]'), '').replaceAll(RegExp(r'\.\d+'), '');
  final ends = h.endsAt ?? h.startsAt.add(const Duration(hours: 3));
  return Uri.https('calendar.google.com', '/calendar/render', {
    'action': 'TEMPLATE',
    'text': heading(h).title,
    'dates': '${stamp(h.startsAt)}/${stamp(ends)}',
    'details': [h.summary, h.sourceUrl].whereType<String>().where((s) => s.isNotEmpty).join('\n\n'),
    'location': h.venueName ?? 'Addis Ababa',
  });
}

const _noise = {'the', 'a', 'an', 'and', 'at', 'in', 'of', 'on'};

String _dedupeKey(Happening h) {
  final source = h.venueName ?? h.title ?? h.id;
  final words = source
      .toLowerCase()
      .replaceAll(RegExp(r'[^a-z0-9ሀ-፿\s]'), ' ')
      .split(RegExp(r'\s+'))
      .where((w) => w.isNotEmpty && !_noise.contains(w))
      .take(2)
      .join(' ');
  return '${addisDayKey(h.startsAt)}|${words.isEmpty ? h.id : words}';
}

/// Collapse repeat announcements (same venue, same day), keeping the most
/// confident version of each, soonest first.
List<Happening> dedupe(List<Happening> list) {
  final best = <String, Happening>{};
  for (final h in list) {
    final key = _dedupeKey(h);
    final held = best[key];
    if (held == null || (h.confidence ?? 0) > (held.confidence ?? 0)) best[key] = h;
  }
  return best.values.toList()..sort((a, b) => a.startsAt.compareTo(b.startsAt));
}

/// The category chips, and which extracted tags each covers.
final eventKinds = <(String key, String label, IconData icon, List<String> tags)>[
  ('music', 'Music', Icons.music_note_rounded, ['music']),
  ('art', 'Art & film', Icons.palette_rounded, ['art', 'film']),
  ('food', 'Food', Icons.restaurant_menu_rounded, ['food']),
  ('market', 'Markets', Icons.storefront_rounded, ['market']),
  ('outdoors', 'Outdoors', Icons.park_rounded, ['outdoors']),
  ('talk', 'Talks', Icons.mic_rounded, ['talk']),
];

enum EventWhen {
  upcoming('Anytime'),
  today('Today'),
  weekend('This weekend'),
  month('Within a month');

  const EventWhen(this.label);
  final String label;
}

DateTime _expiry(Happening h) {
  if (h.endsAt != null) return h.endsAt!;
  final local = _addis(h.startsAt);
  final endOfDay = DateTime.utc(local.year, local.month, local.day, 23, 59, 59, 999);
  return endOfDay.subtract(_addisOffset);
}

({DateTime from, DateTime to}) _weekend(DateTime now) {
  final local = _addis(now);
  final weekday = local.weekday % 7; // 0 Sun … 6 Sat
  final toFriday = weekday == 0 ? -2 : 5 - weekday;
  final friday = DateTime.utc(local.year, local.month, local.day + toFriday);
  final sunday = DateTime.utc(friday.year, friday.month, friday.day + 2, 23, 59, 59, 999);
  return (from: friday.subtract(_addisOffset), to: sunday.subtract(_addisOffset));
}

bool matchesWhen(Happening h, EventWhen when, [DateTime? now]) {
  now ??= DateTime.now();
  if (_expiry(h).isBefore(now)) return false;
  return switch (when) {
    EventWhen.today => addisDayKey(h.startsAt) == addisDayKey(now),
    EventWhen.weekend => () {
      final w = _weekend(now!);
      return !h.startsAt.isAfter(w.to) && !_expiry(h).isBefore(w.from);
    }(),
    EventWhen.month => !h.startsAt.isAfter(now.add(const Duration(days: 30))),
    EventWhen.upcoming => true,
  };
}

bool matchesKinds(Happening h, Set<String> kinds) {
  if (kinds.isEmpty) return true;
  return eventKinds.where((k) => kinds.contains(k.$1)).any((k) => k.$4.any(h.tags.contains));
}
