import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart' hide User;
import 'package:supabase_flutter/supabase_flutter.dart' as sb show User;

import '../models/happening.dart';
import '../models/spot.dart';
import '../models/visit.dart';
import 'backend.dart';

/// Must also be listed under Supabase → Auth → URL Configuration → Redirect
/// URLs, and matches the intent filter / URL scheme in the platform folders.
const authRedirect = 'spots://login-callback';

/// The same queries `apps/web/src/lib/*.ts` makes, against the same RLS.
class SupabaseBackend extends Backend {
  SupabaseClient get _db => Supabase.instance.client;

  @override
  bool get isLive => true;

  @override
  Future<List<Spot>> fetchSpots() async {
    final rows = await _db.from('spots').select();
    return rows.map(Spot.fromJson).toList();
  }

  /// Published events that haven't finished yet, soonest first. Expiry is a
  /// query predicate, so an event can never be shown after it's over.
  @override
  Future<List<Happening>> fetchHappenings() async {
    final now = DateTime.now().toUtc();
    final addisNow = now.add(const Duration(hours: 3));
    final startOfAddisToday = DateTime.utc(
      addisNow.year,
      addisNow.month,
      addisNow.day,
    ).subtract(const Duration(hours: 3));
    final rows = await _db
        .from('happenings')
        .select(
          'id, source_url, image_url, title, summary, venue_name, starts_at, ends_at, '
          'price_min, price_max, price_currency, ticket_url, tags, confidence',
        )
        .eq('status', 'published')
        .not('starts_at', 'is', null)
        .or(
          'ends_at.gte.${now.toIso8601String()},'
          'and(ends_at.is.null,starts_at.gte.${startOfAddisToday.toIso8601String()})',
        )
        .order('starts_at', ascending: true);
    return rows.map(Happening.fromJson).toList();
  }

  // ── auth ────────────────────────────────────────────────────────────────

  AppUser? _map(sb.User? u) {
    if (u == null) return null;
    final meta = u.userMetadata ?? const {};
    return AppUser(
      id: u.id,
      name: (meta['full_name'] ?? meta['name']) as String?,
      email: u.email,
      avatarUrl: (meta['avatar_url'] ?? meta['picture']) as String?,
    );
  }

  @override
  AppUser? get currentUser => _map(_db.auth.currentUser);

  @override
  Stream<AppUser?> get userChanges => _db.auth.onAuthStateChange.map((e) => _map(e.session?.user));

  @override
  Future<void> signIn() async {
    await _db.auth.signInWithOAuth(OAuthProvider.google, redirectTo: kIsWeb ? null : authRedirect);
  }

  @override
  Future<void> signOut() => _db.auth.signOut();

  String get _uid => _db.auth.currentUser!.id;

  // ── want to go ──────────────────────────────────────────────────────────

  @override
  Future<List<String>> fetchSaved() async {
    final rows = await _db
        .from('saved_spots')
        .select('google_place_id')
        .eq('user_id', _uid)
        .order('created_at', ascending: false);
    return rows.map((r) => '${r['google_place_id']}').toList();
  }

  @override
  Future<void> addSaved(String placeId) async {
    try {
      await _db.from('saved_spots').insert({'google_place_id': placeId});
    } on PostgrestException catch (e) {
      // 23505 = unique violation → already saved, treat as success.
      if (e.code != '23505') rethrow;
    }
  }

  @override
  Future<void> removeSaved(String placeId) => _db.from('saved_spots').delete().eq('google_place_id', placeId);

  // ── places we've been ───────────────────────────────────────────────────

  @override
  Future<List<Visit>> fetchVisits() async {
    final rows = await _db.from('visits').select().eq('user_id', _uid).order('visited_at', ascending: false);
    return rows.map(Visit.fromJson).toList();
  }

  @override
  Future<Visit> createVisit(Spot spot) async {
    final row = await _db
        .from('visits')
        .insert({
          'google_place_id': spot.placeId,
          'name': spot.name,
          'visited_at': DateTime.now().toIso8601String().substring(0, 10),
        })
        .select()
        .single();
    return Visit.fromJson(row);
  }

  @override
  Future<void> updateVisit(Visit visit) => _db
      .from('visits')
      .update({...visit.patchJson(), 'updated_at': DateTime.now().toUtc().toIso8601String()})
      .eq('id', visit.id);

  @override
  Future<void> deleteVisitsByPlace(String placeId) => _db.from('visits').delete().eq('google_place_id', placeId);
}
