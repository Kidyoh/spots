import 'package:flutter_test/flutter_test.dart';
import 'package:spots/logic/format.dart';
import 'package:spots/logic/geo.dart';
import 'package:spots/logic/happenings.dart';
import 'package:spots/models/happening.dart';

Happening event({
  String id = 'e',
  String? title = 'Night',
  String? venue = 'Fendika',
  required String starts,
  String? ends,
  double? min,
  double? max,
  double confidence = 0.5,
}) => Happening(
  id: id,
  sourceUrl: '',
  imageUrl: null,
  title: title,
  summary: null,
  venueName: venue,
  startsAt: DateTime.parse(starts),
  endsAt: ends == null ? null : DateTime.parse(ends),
  priceMin: min,
  priceMax: max,
  priceCurrency: 'ETB',
  ticketUrl: null,
  tags: const [],
  confidence: confidence,
);

void main() {
  group('happenings (Addis wall-clock)', () {
    // Saturday 22 Aug 2026, 10:00 in Addis
    final now = DateTime.parse('2026-08-22T07:00:00Z');

    test('dayLabel is relative for today/tomorrow, dated otherwise', () {
      expect(dayLabel(DateTime.parse('2026-08-22T18:00:00Z'), now), 'Today');
      // 23:30 UTC on the 22nd is already the 23rd in Addis
      expect(dayLabel(DateTime.parse('2026-08-22T23:30:00Z'), now), 'Tomorrow');
      expect(dayLabel(DateTime.parse('2026-08-29T12:00:00Z'), now), 'Saturday 29 Aug');
    });

    test('timeLabel hides the midnight placeholder of a date-only post', () {
      expect(timeLabel(DateTime.parse('2026-08-21T21:00:00Z')), isNull);
      expect(timeLabel(DateTime.parse('2026-08-22T18:00:00Z')), '9:00 PM');
    });

    test('countdown counts whole Addis days', () {
      expect(countdown(DateTime.parse('2026-08-22T18:00:00Z'), now), 'Today');
      expect(countdown(DateTime.parse('2026-08-23T06:00:00Z'), now), 'Tomorrow');
      expect(countdown(DateTime.parse('2026-08-26T06:00:00Z'), now), 'in 4 days');
      expect(countdown(DateTime.parse('2026-09-05T06:00:00Z'), now), 'in 2 weeks');
      expect(countdown(DateTime.parse('2026-08-20T06:00:00Z'), now), 'On now');
    });

    test('spanLabel only for multi-day events', () {
      expect(spanLabel(DateTime.parse('2026-08-25T07:00:00Z'), null, now), isNull);
      expect(
        spanLabel(DateTime.parse('2026-08-25T07:00:00Z'), DateTime.parse('2026-09-10T15:00:00Z'), now),
        '25 Aug – 10 Sep',
      );
      expect(
        spanLabel(DateTime.parse('2026-08-20T07:00:00Z'), DateTime.parse('2026-09-10T15:00:00Z'), now),
        'Until 10 Sep',
      );
    });

    test('price labels', () {
      expect(eventPriceLabel(event(starts: '2026-08-25T07:00:00Z')), isNull);
      expect(eventPriceLabel(event(starts: '2026-08-25T07:00:00Z', min: 0)), 'Free');
      expect(eventPriceLabel(event(starts: '2026-08-25T07:00:00Z', min: 1500)), '1,500 ETB');
      expect(eventPriceLabel(event(starts: '2026-08-25T07:00:00Z', min: 300, max: 700)), '300–700 ETB');
    });

    test('dedupe keeps the most confident post per venue per day', () {
      final out = dedupe([
        event(id: 'a', venue: 'The Golden Tulip Hotel', starts: '2026-08-25T17:00:00Z', confidence: 0.4),
        event(id: 'b', venue: 'Golden Tulip', starts: '2026-08-25T18:00:00Z', confidence: 0.9),
        event(id: 'c', venue: 'Golden Tulip', starts: '2026-08-26T18:00:00Z'),
      ]);
      expect(out.map((e) => e.id), ['b', 'c']);
    });

    test('weekend window covers Fri–Sun around a Saturday', () {
      final fri = event(starts: '2026-08-21T12:00:00Z', ends: '2026-08-21T20:00:00Z');
      final sun = event(starts: '2026-08-23T12:00:00Z');
      final mon = event(starts: '2026-08-24T12:00:00Z');
      expect(matchesWhen(fri, EventWhen.weekend, now), isFalse); // already over
      expect(matchesWhen(sun, EventWhen.weekend, now), isTrue);
      expect(matchesWhen(mon, EventWhen.weekend, now), isFalse);
    });
  });

  group('geo + format', () {
    test('road estimate rounds to half kilometres, floored at 0.5', () {
      expect(formatRoadEstimate(0.1), '0.5 km');
      expect(formatRoadEstimate(3.2), '3 km');
      expect(formatRoadEstimate(3.3), '3.5 km');
    });

    test('haversine is roughly right across Addis', () {
      final km = haversineKm((lat: 9.0108, lng: 38.7613), (lat: 9.0930, lng: 38.7560));
      expect(km, closeTo(9.2, 0.3));
    });

    test('etb groups thousands', () {
      expect(etb(300), '300');
      expect(etb(1500), '1,500');
      expect(etb(1234567), '1,234,567');
    });
  });
}
