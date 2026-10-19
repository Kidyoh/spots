import '../models/happening.dart';
import '../models/spot.dart';
import '../models/visit.dart';

/// Who is signed in, as much as the UI needs.
class AppUser {
  const AppUser({required this.id, this.name, this.email, this.avatarUrl});

  final String id;
  final String? name;
  final String? email;
  final String? avatarUrl;

  String get displayName => name ?? email?.split('@').first ?? 'You';
  String get initial => displayName.isEmpty ? '?' : displayName[0].toUpperCase();
}

/// Everything the app reads and writes. [SupabaseBackend] talks to the same
/// tables (and RLS) as the web app; [DemoBackend] serves bundled sample data
/// and keeps the personal lists on the device, so the app runs without keys.
abstract class Backend {
  /// True when wired to the real Supabase project.
  bool get isLive;

  /// Live mode gates the personal lists behind Google sign-in (RLS scopes them
  /// to `auth.uid()`); demo mode keeps them on the device for anyone.
  bool get requiresSignIn => isLive;

  Future<List<Spot>> fetchSpots();
  Future<List<Happening>> fetchHappenings();

  AppUser? get currentUser;
  Stream<AppUser?> get userChanges;
  Future<void> signIn();
  Future<void> signOut();

  /// Permanently delete the signed-in account and everything tied to it, then
  /// sign out. Live: the `delete_my_account()` RPC (profile, Want to go,
  /// visits with their public ratings and notes, matching, feedback; analytics
  /// rows are kept without the user id). Demo: clears the on-device lists.
  Future<void> deleteAccount();

  /// Place ids on the "Want to go" list, newest first.
  Future<List<String>> fetchSaved();
  Future<void> addSaved(String placeId);
  Future<void> removeSaved(String placeId);

  /// "Places we've been", newest first.
  Future<List<Visit>> fetchVisits();
  Future<Visit> createVisit(Spot spot);
  Future<void> updateVisit(Visit visit);
  Future<void> deleteVisitsByPlace(String placeId);
}
