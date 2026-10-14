import 'package:flutter_test/flutter_test.dart';
import 'package:spots/logic/areas.dart';
import 'package:spots/logic/search.dart';
import 'package:spots/models/spot.dart';

Spot spot(
  String name, {
  String? area,
  String? address,
  List<String> tags = const [],
  double lat = 9,
  double lng = 38.7,
}) => Spot.fromJson({
  'id': name,
  'google_place_id': name,
  'name': name,
  'neighborhood': area,
  'address': address,
  'lat': lat,
  'lng': lng,
  'tags': tags,
  'first_seen_at': '2026-01-01T00:00:00Z',
});

void main() {
  group('areas', () {
    test('spellings file under one canonical area', () {
      expect(canonicalArea('Arat Kilo'), '4 Kilo');
      expect(canonicalArea('Piazza'), 'Piassa');
      expect(canonicalArea('Bole (Bulbula & Gazebo Square)'), 'Bole Bulbula');
      expect(canonicalArea('Somewhere New'), 'Somewhere New');
      expect(canonicalArea(null), isNull);
    });

    test('a spot with no neighbourhood takes it from the address, then from nearby spots', () {
      final fromAddress = spot('Garad', address: 'Welo Sefer Addis ababa, Addis Ababa 4040');
      final a = spot('A', area: 'Bole', lat: 8.99, lng: 38.79);
      final b = spot('B', area: 'Bole Medhanialem', lat: 8.991, lng: 38.791);
      final c = spot('C', area: 'Kazanchis', lat: 9.02, lng: 38.76);
      final nearBole = spot('Iftah', address: 'Namibia St, Addis Ababa', lat: 8.992, lng: 38.792);
      final faraway = spot('Lake lodge', lat: 8.75, lng: 38.98);
      assignSefers([fromAddress, a, b, c, nearBole, faraway]);
      expect(fromAddress.sefer, 'Wello Sefer');
      expect(fromAddress.seferInferred, isFalse);
      expect(nearBole.sefer, 'Bole');
      expect(nearBole.seferInferred, isTrue);
      expect(faraway.sefer, isNull);
      expect(faraway.area, 'Addis Ababa');
    });
  });

  group('search', () {
    final spots = [
      spot('713 American Breakfast', area: 'Bole', tags: ['cafe', 'breakfast']),
      spot('Ketema cafe', area: 'Piazza', tags: ['cafe']),
      spot('Pizza Hut', area: 'Bole', tags: ['pizza']),
      spot('Cucina Moseb', area: '22', tags: ['ethiopian']),
      spot('Adiz Pastry', area: 'Bole', tags: ['tiramisu', 'cake']),
    ];
    setUpAll(() => assignSefers(spots));

    List<String> names(String q) {
      final r = searchSpots(spots, q);
      return (r.keys.toList()..sort((a, b) => r[a]!.compareTo(r[b]!))).map((s) => s.name).toList();
    }

    test('finds names, tags and areas, name matches first', () {
      expect(names('713'), ['713 American Breakfast']);
      expect(names('cafe').first, 'Ketema cafe');
      expect(names('tiramisu'), ['Adiz Pastry']);
    });

    test('area synonyms match, and beat typo matches', () {
      // "piazza" is Piassa, not one typo away from "pizza"
      expect(names('piazza'), ['Ketema cafe']);
    });

    test('a typo still finds the spot when nothing matches exactly', () {
      expect(names('tiramissu'), ['Adiz Pastry']);
      expect(names('mosob'), ['Cucina Moseb']);
      expect(names('zzzz'), isEmpty);
    });
  });
}
