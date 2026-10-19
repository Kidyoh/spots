import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:supabase_flutter/supabase_flutter.dart' hide User;
import 'package:supabase_flutter/supabase_flutter.dart' as sb show User;
import 'package:url_launcher/url_launcher.dart' as launcher;

import '../models/happening.dart';
import '../models/spot.dart';
import '../models/visit.dart';
import 'backend.dart';

/// Must also be listed under Supabase → Auth → URL Configuration → Redirect
/// URLs, and matches the intent filter / URL scheme in the platform folders.
const authRedirect = 'spots://login-callback';

/// The OAuth *web* client configured on Supabase's Google provider. With it,
/// Android shows its own account picker and hands us an ID token for that
/// client, which Supabase accepts directly — no browser, no redirect. Needs
/// an Android OAuth client (package io.spots + the signing key's SHA-1) in
/// the same Google Cloud project; see README.
const googleWebClientId = String.fromEnvironment('GOOGLE_WEB_CLIENT_ID');

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

  bool _googleReady = false;

  @override
  Future<void> signIn() async {
    if (kIsWeb) {
      await _db.auth.signInWithOAuth(OAuthProvider.google);
      return;
    }
    if (googleWebClientId.isNotEmpty && defaultTargetPlatform == TargetPlatform.android) {
      try {
        await _signInNative();
        return;
      } on GoogleSignInException catch (e) {
        if (e.code == GoogleSignInExceptionCode.canceled) return; // they backed out
        // anything else (usually the Android client isn't registered yet):
        // fall through to the browser flow rather than leave them stuck
        debugPrint('Native Google sign-in unavailable (${e.code}): ${e.description}');
      }
    }
    await _signInInBrowserTab();
  }

  /// Android's own Google account sheet → ID token → Supabase session.
  Future<void> _signInNative() async {
    final google = GoogleSignIn.instance;
    if (!_googleReady) {
      await google.initialize(serverClientId: googleWebClientId);
      _googleReady = true;
    }
    final account = await google.authenticate();
    final idToken = account.authentication.idToken;
    if (idToken == null) {
      throw const GoogleSignInException(code: GoogleSignInExceptionCode.unknownError, description: 'no ID token');
    }
    await _db.auth.signInWithIdToken(provider: OAuthProvider.google, idToken: idToken);
  }

  /// Fallback: Google's page in an in-app browser tab (Chrome Custom Tab /
  /// SFSafariViewController) over the app. supabase_flutter's signInWithOAuth
  /// forces the external browser for Google on Android, so we build the URL
  /// (which also stores the PKCE verifier) and open it ourselves; Google
  /// refuses plain WebViews. The redirect to [authRedirect] — which must be
  /// on Supabase's Redirect URLs list, or Supabase sends people to the website
  /// instead — is finished by supabase_flutter's deep-link listener, and
  /// launchMode="singleTask" closes the tab.
  Future<void> _signInInBrowserTab() async {
    final res = await _db.auth.getOAuthSignInUrl(provider: OAuthProvider.google, redirectTo: authRedirect);
    final opened = await launcher.launchUrl(Uri.parse(res.url), mode: launcher.LaunchMode.inAppBrowserView);
    if (!opened) {
      await launcher.launchUrl(Uri.parse(res.url), mode: launcher.LaunchMode.externalApplication);
    }
  }

  @override
  Future<void> signOut() async {
    await _db.auth.signOut();
    // so the picker asks again next time instead of reusing the account
    if (_googleReady) await GoogleSignIn.instance.signOut();
  }

  @override
  Future<void> deleteAccount() async {
    await _db.rpc('delete_my_account');
    // The account is gone, so the server-side logout may fail; the local
    // session is dropped before that call either way.
    try {
      await signOut();
    } catch (e) {
      debugPrint('Sign-out after account deletion: $e');
    }
  }

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
