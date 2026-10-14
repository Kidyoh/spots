import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// First-party product analytics into the same `events` table the web writes
/// (see apps/web/src/lib/analytics.ts), with the same event names where the
/// feature is the same.
///
/// App events are told apart from web ones without a schema change:
/// `user_agent` starts with `spots-app/` (e.g. "spots-app/0.1.1 (android)")
/// and `path` with `/app/`. `spots analytics` and packages/db/analytics.sql
/// split web vs app on that prefix. `user_id` is stamped server-side from the
/// JWT when signed in; `anon_id` is a stable per-install id, so DAU/MAU count
/// signed-out app users too.
///
/// Fire-and-forget: a failed or slow insert never delays a tap or shows an
/// error.
class Analytics {
  /// [insert] writes one row to `events`; tests pass a recorder.
  Analytics.withSink(Future<void> Function(Map<String, Object?> row) insert) : _insert = insert;

  /// Writes nothing; used with demo data.
  Analytics.disabled() : _insert = null;

  factory Analytics.supabase() => Analytics.withSink((row) => Supabase.instance.client.from('events').insert(row));

  static const _aidKey = 'spots:aid';
  static const userAgentPrefix = 'spots-app/';

  final Future<void> Function(Map<String, Object?> row)? _insert;
  Future<({String anonId, String userAgent})>? _identity;

  Future<({String anonId, String userAgent})> _resolve() async {
    String anonId;
    try {
      final prefs = await SharedPreferences.getInstance();
      anonId = prefs.getString(_aidKey) ?? _uuid();
      await prefs.setString(_aidKey, anonId);
    } catch (_) {
      anonId = _uuid(); // storage unavailable: one id for this run
    }
    var version = '';
    try {
      version = (await PackageInfo.fromPlatform()).version;
    } catch (_) {}
    final platform = kIsWeb ? 'web' : defaultTargetPlatform.name.toLowerCase();
    return (anonId: anonId, userAgent: '$userAgentPrefix${version.isEmpty ? '0' : version} ($platform)');
  }

  /// Record an event. [screen] becomes the path (`/app/<screen>`).
  void track(String name, {String? screen, Map<String, Object?>? props}) {
    final insert = _insert;
    if (insert == null) return;
    () async {
      try {
        final id = await (_identity ??= _resolve());
        await insert({
          'name': name,
          'props': props,
          'anon_id': id.anonId,
          'path': '/app/${screen ?? ''}',
          'user_agent': id.userAgent,
        });
      } catch (_) {
        // analytics must never disrupt the app
      }
    }();
  }

  static String _uuid() {
    final r = math.Random.secure();
    final b = List<int>.generate(16, (_) => r.nextInt(256));
    b[6] = (b[6] & 0x0f) | 0x40; // version 4
    b[8] = (b[8] & 0x3f) | 0x80; // RFC 4122 variant
    final h = b.map((x) => x.toRadixString(16).padLeft(2, '0')).join();
    return '${h.substring(0, 8)}-${h.substring(8, 12)}-${h.substring(12, 16)}-${h.substring(16, 20)}-${h.substring(20)}';
  }
}
