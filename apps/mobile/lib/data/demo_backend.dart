import 'dart:async';
import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/happening.dart';
import '../models/spot.dart';
import '../models/visit.dart';
import 'backend.dart';

/// Runs the app with no Supabase keys: the spots are the design mock
/// (`design/data/spots-data.js`, exported to JSON), events are generated
/// relative to today, and the personal lists live in SharedPreferences.
class DemoBackend extends Backend {
  static const _savedKey = 'demo:saved';
  static const _visitsKey = 'demo:visits';

  final _users = StreamController<AppUser?>.broadcast();
  AppUser? _user = const AppUser(id: 'demo', name: 'Guest');

  @override
  bool get isLive => false;

  @override
  Future<List<Spot>> fetchSpots() async {
    final raw = await rootBundle.loadString('assets/data/demo_spots.json');
    final list = (jsonDecode(raw) as List).cast<Map<String, dynamic>>();
    final now = DateTime.now();
    return [
      for (var i = 0; i < list.length; i++)
        Spot.fromJson({
          ...list[i],
          // Stagger "first seen" so the New chip and "Recently added" sort
          // have something to show.
          'first_seen_at': now.subtract(Duration(days: (list.length - i) * 3 - 2)).toIso8601String(),
        }),
    ];
  }

  @override
  Future<List<Happening>> fetchHappenings() async {
    // Anchor on Addis midnight today so the times read as stated.
    final utc = DateTime.now().toUtc().add(const Duration(hours: 3));
    DateTime at(int dayOffset, int hour, [int minute = 0]) =>
        DateTime.utc(utc.year, utc.month, utc.day + dayOffset, hour, minute).subtract(const Duration(hours: 3));

    Happening h(
      String id,
      String title,
      String venue,
      DateTime start,
      List<String> tags, {
      String? summary,
      double? price,
      double? priceMax,
      DateTime? end,
      String? ticket,
    }) => Happening(
      id: id,
      sourceUrl: 'https://t.me/s/addisevents',
      imageUrl: null,
      title: title,
      summary: summary,
      venueName: venue,
      startsAt: start,
      endsAt: end,
      priceMin: price,
      priceMax: priceMax,
      priceCurrency: 'ETB',
      ticketUrl: ticket,
      tags: tags,
      confidence: 0.9,
    );

    return [
      h(
        'e1',
        'Jazz at the Fendika',
        'Fendika Cultural Center',
        at(0, 20, 30),
        ['music'],
        summary: 'Ethio-jazz quartet, azmari interludes, and a full house by ten.',
        price: 500,
      ),
      h(
        'e2',
        'Sunset Vinyl Session',
        'Kuriftu Rooftop',
        at(1, 18),
        ['music'],
        summary: 'Soul and Ethiopiques on wax while the sun drops behind Entoto.',
        price: 0,
      ),
      h(
        'e3',
        'Makers Market',
        'Lafto Mall Courtyard',
        at(2, 10),
        ['market', 'food'],
        summary: 'Local designers, leather, coffee roasters and a lot of injera wraps.',
        end: at(3, 18),
        price: 0,
      ),
      h(
        'e4',
        'Open-air Cinema: Teza',
        'Alliance Éthio-Française',
        at(3, 19),
        ['art', 'film'],
        summary: 'Haile Gerima\'s classic under the stars. Bring a scarf.',
        price: 200,
      ),
      h(
        'e5',
        'Entoto Sunrise Hike',
        'Entoto Park Gate',
        at(4, 6),
        ['outdoors'],
        summary: 'Guided 8 km loop through the eucalyptus, coffee ceremony at the top.',
        price: 350,
        ticket: 'https://example.com/tickets',
      ),
      h(
        'e6',
        'Gallery Night: New Voices',
        'Zoma Museum',
        at(6, 17),
        ['art'],
        summary: 'Six young painters, one long evening, plenty of tej.',
        price: 0,
      ),
      h(
        'e7',
        'Tasting Menu Pop-up',
        'The Mosaic Hotel',
        at(9, 19, 30),
        ['food'],
        summary: 'Seven courses reimagining Habesha classics.',
        price: 2500,
        priceMax: 3200,
      ),
      h(
        'e8',
        'Design & Cities Talk',
        'Addis Ababa University',
        at(12, 0),
        ['talk'],
        summary: 'How Addis grew up — and where it goes next.',
        price: 0,
      ),
    ];
  }

  // ── auth: a local guest; "signing in" just flips it back on ──────────────

  @override
  bool get requiresSignIn => false;

  @override
  AppUser? get currentUser => _user;

  @override
  Stream<AppUser?> get userChanges => _users.stream;

  @override
  Future<void> signIn() async {
    _user = const AppUser(id: 'demo', name: 'Guest');
    _users.add(_user);
  }

  @override
  Future<void> signOut() async {
    _user = null;
    _users.add(null);
  }

  // ── personal lists, on the device ───────────────────────────────────────

  Future<SharedPreferences> get _prefs => SharedPreferences.getInstance();

  @override
  Future<List<String>> fetchSaved() async => (await _prefs).getStringList(_savedKey) ?? [];

  @override
  Future<void> addSaved(String placeId) async {
    final p = await _prefs;
    final list = p.getStringList(_savedKey) ?? [];
    if (!list.contains(placeId)) await p.setStringList(_savedKey, [placeId, ...list]);
  }

  @override
  Future<void> removeSaved(String placeId) async {
    final p = await _prefs;
    final list = p.getStringList(_savedKey) ?? [];
    await p.setStringList(_savedKey, list.where((id) => id != placeId).toList());
  }

  Future<List<Visit>> _readVisits() async {
    final raw = (await _prefs).getString(_visitsKey);
    if (raw == null) return [];
    return (jsonDecode(raw) as List).cast<Map<String, dynamic>>().map(Visit.fromJson).toList();
  }

  Future<void> _writeVisits(List<Visit> visits) async =>
      (await _prefs).setString(_visitsKey, jsonEncode(visits.map((v) => v.toJson()).toList()));

  @override
  Future<List<Visit>> fetchVisits() async => (await _readVisits())..sort((a, b) => b.visitedAt.compareTo(a.visitedAt));

  @override
  Future<Visit> createVisit(Spot spot) async {
    final visit = Visit(
      id: 'v${DateTime.now().microsecondsSinceEpoch}',
      placeId: spot.placeId,
      name: spot.name,
      visitedAt: DateTime.now(),
    );
    await _writeVisits([visit, ...await _readVisits()]);
    return visit;
  }

  @override
  Future<void> updateVisit(Visit visit) async {
    final list = await _readVisits();
    await _writeVisits([for (final v in list) v.id == visit.id ? visit : v]);
  }

  @override
  Future<void> deleteVisitsByPlace(String placeId) async {
    final list = await _readVisits();
    await _writeVisits(list.where((v) => v.placeId != placeId).toList());
  }
}
