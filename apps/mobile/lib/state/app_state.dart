import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/widgets.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../data/analytics.dart';
import '../data/backend.dart';
import '../logic/areas.dart';
import '../logic/categories.dart';
import '../logic/geo.dart';
import '../logic/happenings.dart';
import '../logic/search.dart';
import '../models/happening.dart';
import '../models/spot.dart';
import '../models/visit.dart';

enum LocStatus { idle, locating, granted, denied, unavailable }

/// The whole app's state in one notifier: the catalog, filters, the personal
/// lists, and the phone's location. Screens read it through [AppScope].
class AppState extends ChangeNotifier {
  AppState(this.backend, {Analytics? analytics}) : analytics = analytics ?? Analytics.disabled() {
    user = backend.currentUser;
    _authSub = backend.userChanges.listen((u) {
      final changed = u?.id != user?.id;
      user = u;
      notifyListeners();
      if (changed) unawaited(_loadPersonal());
    });
  }

  final Backend backend;

  /// Product events into the shared `events` table, tagged as the app.
  final Analytics analytics;
  late final StreamSubscription<AppUser?> _authSub;
  final _toasts = StreamController<String>.broadcast();
  final _rng = math.Random();

  /// One-line confirmations and errors, shown as floating snackbars.
  Stream<String> get toasts => _toasts.stream;

  // ── catalog ─────────────────────────────────────────────────────────────

  List<Spot>? spots;
  Object? spotsError;
  List<Happening>? happenings;
  Object? eventsError;

  static const _screens = ['discover', 'events', 'near', 'saved'];

  /// The screen the user is on, for an event's path (`/app/<screen>`).
  String get screen => _screens[tab];

  void track(String name, [Map<String, Object?>? props]) => analytics.track(name, screen: screen, props: props);

  bool _opened = false;

  Future<void> load() async {
    if (!_opened) {
      _opened = true;
      track('page_view'); // the web's name for "opened the app"
    }
    await Future.wait([_loadSpots(), _loadEvents(), _loadPersonal(), _loadHint()]);
  }

  Future<void> _loadSpots() async {
    spotsError = null;
    notifyListeners();
    try {
      final loaded = await backend.fetchSpots();
      assignSefers(loaded);
      spots = loaded;
      _invalidate();
    } catch (e) {
      spotsError = e;
    }
    notifyListeners();
  }

  Future<void> _loadEvents() async {
    eventsError = null;
    try {
      happenings = dedupe(await backend.fetchHappenings());
    } catch (e) {
      eventsError = e;
    }
    notifyListeners();
  }

  Future<void> retry() => load();
  Future<void> refreshEvents() => _loadEvents();

  Spot? spotById(String placeId) {
    for (final s in spots ?? const <Spot>[]) {
      if (s.placeId == placeId) return s;
    }
    return null;
  }

  // ── navigation ──────────────────────────────────────────────────────────

  int tab = 0;

  void setTab(int i) {
    if (i == tab) return;
    tab = i;
    // same names as the web where the feature is the same
    switch (i) {
      case 1:
        track('events_tab');
      case 2:
        track('near_open');
      case 3:
        track('saved_open');
    }
    notifyListeners();
  }

  // ── spot filters ────────────────────────────────────────────────────────

  String query = '';
  String? area;
  int? price;
  SortMode sort = SortMode.quality;
  final Set<String> selectedCategories = {};
  int deckIndex = 0;

  List<Spot>? _filtered;

  void _invalidate() {
    _filtered = null;
    deckIndex = 0;
  }

  int get activeFilterCount => (query.trim().isNotEmpty ? 1 : 0) + (area != null ? 1 : 0) + (price != null ? 1 : 0);

  void setQuery(String v) {
    query = v;
    _invalidate();
    notifyListeners();
  }

  void setArea(String? v) {
    area = v;
    _invalidate();
    notifyListeners();
  }

  void setPrice(int? v) {
    price = v;
    _invalidate();
    notifyListeners();
  }

  void setSort(SortMode v) {
    sort = v;
    _invalidate();
    notifyListeners();
  }

  void toggleCategory(String key) {
    if (!selectedCategories.remove(key)) selectedCategories.add(key);
    _invalidate();
    notifyListeners();
  }

  void clearFilters() {
    query = '';
    area = null;
    price = null;
    selectedCategories.clear();
    _invalidate();
    notifyListeners();
  }

  /// Neighbourhoods with spots, most-populated first.
  /// Canonical areas (sefers) with spots, most-populated first — the same
  /// ~60 the web's filter offers, not every spelling in the data.
  List<String> get areas {
    final counts = <String, int>{};
    for (final s in spots ?? const <Spot>[]) {
      if (s.sefer != null) counts.update(s.sefer!, (c) => c + 1, ifAbsent: () => 1);
    }
    return counts.keys.toList()
      ..sort((a, b) => counts[b]!.compareTo(counts[a]!) != 0 ? counts[b]!.compareTo(counts[a]!) : a.compareTo(b));
  }

  bool get hasNewSpots => (spots ?? const <Spot>[]).any((s) => s.isNew);

  List<Spot> get filteredSpots {
    final all = spots;
    if (all == null) return const [];
    return _filtered ??= () {
      final ranks = searchSpots(
        all.where(
          (s) =>
              (area == null || s.sefer == area) &&
              (price == null || s.priceLevel == price) &&
              matchesCategories(s, selectedCategories),
        ),
        query,
      );
      final list = ranks.keys.toList();
      // while searching, relevance leads and the chosen sort breaks ties
      return list..sort((a, b) {
        final byRank = ranks[a]!.compareTo(ranks[b]!);
        return byRank != 0 ? byRank : sort.compare(a, b);
      });
    }();
  }

  /// How many spots the search alone would find, ignoring area, price and
  /// category chips — so an empty result can say the chips are hiding them.
  int get searchOnlyMatches {
    if (query.trim().isEmpty) return 0;
    return searchSpots(spots ?? const <Spot>[], query).length;
  }

  /// Drop the chips, area and price but keep the search.
  void searchEverywhere() {
    area = null;
    price = null;
    selectedCategories.clear();
    _invalidate();
    notifyListeners();
  }

  Spot? get currentSpot {
    final list = filteredSpots;
    if (list.isEmpty) return null;
    return list[deckIndex % list.length];
  }

  void step(int delta) {
    final n = filteredSpots.length;
    if (n == 0) return;
    deckIndex = (deckIndex + delta) % n;
    if (deckIndex < 0) deckIndex += n;
    _markSwiped();
    notifyListeners();
  }

  /// "Surprise me": jump to a random card that isn't the one showing.
  void surprise() {
    final n = filteredSpots.length;
    if (n < 2) return;
    var next = deckIndex;
    while (next == deckIndex) {
      next = _rng.nextInt(n);
    }
    deckIndex = next;
    track('surprise');
    notifyListeners();
  }

  /// Show a particular spot on the deck (e.g. from Near me or Saved),
  /// clearing filters that would hide it.
  void focusSpot(String placeId) {
    var i = filteredSpots.indexWhere((s) => s.placeId == placeId);
    if (i < 0) {
      clearFilters();
      i = filteredSpots.indexWhere((s) => s.placeId == placeId);
    }
    if (i >= 0) deckIndex = i;
    tab = 0;
    notifyListeners();
  }

  // ── swipe hint (shown until the first swipe, like the web) ──────────────

  bool showSwipeHint = false;
  static const _swipedKey = 'spots:swiped';

  Future<void> _loadHint() async {
    try {
      final p = await SharedPreferences.getInstance();
      showSwipeHint = !(p.getBool(_swipedKey) ?? false);
    } catch (_) {}
  }

  void _markSwiped() {
    if (!showSwipeHint) return;
    showSwipeHint = false;
    unawaited(SharedPreferences.getInstance().then((p) => p.setBool(_swipedKey, true)));
  }

  // ── event filters ───────────────────────────────────────────────────────

  String eventQuery = '';
  EventWhen eventWhen = EventWhen.upcoming;
  final Set<String> eventKindsOn = {};
  bool eventFreeOnly = false;

  bool get eventFiltersOn =>
      eventQuery.trim().isNotEmpty || eventWhen != EventWhen.upcoming || eventKindsOn.isNotEmpty || eventFreeOnly;

  void setEventQuery(String v) {
    eventQuery = v;
    notifyListeners();
  }

  void setEventWhen(EventWhen v) {
    eventWhen = v;
    notifyListeners();
  }

  void toggleEventKind(String k) {
    if (!eventKindsOn.remove(k)) eventKindsOn.add(k);
    notifyListeners();
  }

  void toggleFreeOnly() {
    eventFreeOnly = !eventFreeOnly;
    notifyListeners();
  }

  void clearEventFilters() {
    eventQuery = '';
    eventWhen = EventWhen.upcoming;
    eventKindsOn.clear();
    eventFreeOnly = false;
    notifyListeners();
  }

  List<Happening> get filteredEvents {
    final all = happenings ?? const <Happening>[];
    final q = eventQuery.trim().toLowerCase();
    return all.where((h) {
      if (!matchesWhen(h, eventWhen)) return false;
      if (!matchesKinds(h, eventKindsOn)) return false;
      if (eventFreeOnly && !h.isFree) return false;
      if (q.isEmpty) return true;
      return [h.title, h.venueName, h.summary, ...h.tags].whereType<String>().join(' ').toLowerCase().contains(q);
    }).toList();
  }

  // ── auth + personal lists ───────────────────────────────────────────────

  AppUser? user;

  /// Live mode needs a Google identity for the personal lists; demo doesn't.
  bool get canPersonalize => !backend.requiresSignIn || user != null;

  List<String> savedIds = [];
  List<Visit> visits = [];

  Future<void> _loadPersonal() async {
    if (!canPersonalize) {
      savedIds = [];
      visits = [];
      notifyListeners();
      return;
    }
    try {
      final r = await Future.wait([backend.fetchSaved(), backend.fetchVisits()]);
      savedIds = r[0] as List<String>;
      visits = r[1] as List<Visit>;
    } catch (e) {
      _toasts.add("Couldn't load your lists");
    }
    notifyListeners();
  }

  Future<void> signIn() async {
    track('sign_in_click');
    try {
      await backend.signIn();
    } catch (e) {
      _toasts.add("Couldn't sign in — try again");
    }
  }

  Future<void> signOut() async {
    await backend.signOut();
    savedIds = [];
    visits = [];
    notifyListeners();
  }

  bool isSaved(String placeId) => savedIds.contains(placeId);
  bool isVisited(String placeId) => visits.any((v) => v.placeId == placeId);
  Visit? visitFor(String placeId) {
    for (final v in visits) {
      if (v.placeId == placeId) return v;
    }
    return null;
  }

  List<Spot> get savedSpots => [for (final id in savedIds) ?spotById(id)];

  /// Returns false when the user needs to sign in first.
  Future<bool> toggleSaved(Spot spot) async {
    if (!canPersonalize) return false;
    final was = isSaved(spot.placeId);
    // optimistic, rolled back on failure
    savedIds = was ? savedIds.where((id) => id != spot.placeId).toList() : [spot.placeId, ...savedIds];
    notifyListeners();
    try {
      was ? await backend.removeSaved(spot.placeId) : await backend.addSaved(spot.placeId);
      _toasts.add(was ? 'Removed from Want to go' : 'Saved to Want to go');
      if (!was) track('spot_save', {'placeId': spot.placeId});
    } catch (_) {
      savedIds = was ? [spot.placeId, ...savedIds] : savedIds.where((id) => id != spot.placeId).toList();
      notifyListeners();
      _toasts.add("Couldn't save that — check your connection");
    }
    return true;
  }

  Future<bool> toggleVisited(Spot spot) async {
    if (!canPersonalize) return false;
    if (isVisited(spot.placeId)) {
      final before = visits;
      visits = visits.where((v) => v.placeId != spot.placeId).toList();
      notifyListeners();
      try {
        await backend.deleteVisitsByPlace(spot.placeId);
      } catch (_) {
        visits = before;
        notifyListeners();
        _toasts.add("Couldn't update your log");
      }
    } else {
      try {
        final v = await backend.createVisit(spot);
        visits = [v, ...visits];
        notifyListeners();
        track('spot_been', {'placeId': spot.placeId});
        _toasts.add('Added to Places we\'ve been');
      } catch (_) {
        _toasts.add("Couldn't update your log");
      }
    }
    return true;
  }

  Future<void> updateVisit(Visit visit) async {
    final before = visits;
    visits = [for (final v in visits) v.id == visit.id ? visit : v];
    notifyListeners();
    try {
      await backend.updateVisit(visit);
    } catch (_) {
      visits = before;
      notifyListeners();
      _toasts.add("Couldn't save your rating");
    }
  }

  // ── location (one-shot; stays on the device) ────────────────────────────

  Coords? coords;
  LocStatus locStatus = LocStatus.idle;

  bool get farFromAddis => coords != null && !isNearAddis(coords!);

  Future<void> requestLocation() async {
    track('near_locate');
    locStatus = LocStatus.locating;
    notifyListeners();
    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
        locStatus = LocStatus.unavailable;
        notifyListeners();
        return;
      }
      var perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) perm = await Geolocator.requestPermission();
      if (perm == LocationPermission.denied || perm == LocationPermission.deniedForever) {
        locStatus = LocStatus.denied;
        notifyListeners();
        return;
      }
      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.high, timeLimit: Duration(seconds: 10)),
      );
      coords = (lat: pos.latitude, lng: pos.longitude);
      locStatus = LocStatus.granted;
    } catch (_) {
      locStatus = LocStatus.unavailable;
    }
    notifyListeners();
  }

  /// Where distances are measured from: the fix, or central Addis.
  Coords get origin => coords != null && !farFromAddis ? coords! : addis;

  double roadKmTo(Spot s) => estimateRoadKm(haversineKm(origin, (lat: s.lat, lng: s.lng)));

  @override
  void dispose() {
    _authSub.cancel();
    _toasts.close();
    super.dispose();
  }
}

/// Exposes [AppState] to the tree and rebuilds dependents on change.
class AppScope extends InheritedNotifier<AppState> {
  const AppScope({super.key, required AppState state, required super.child}) : super(notifier: state);

  static AppState of(BuildContext context) => context.dependOnInheritedWidgetOfExactType<AppScope>()!.notifier!;

  /// Read without subscribing (for callbacks).
  static AppState read(BuildContext context) => context.getInheritedWidgetOfExactType<AppScope>()!.notifier!;
}
