import 'package:flutter_test/flutter_test.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:spots/data/analytics.dart';

/// The web's bot filter (apps/cli/src/commands/analytics.ts). App events must
/// survive it, or the app's users would vanish from DAU/MAU.
final botUa = RegExp(
  'bot|crawl|spider|slurp|headless|facebookexternalhit|whatsapp|telegram|preview|python-requests|curl/',
  caseSensitive: false,
);

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    PackageInfo.setMockInitialValues(
      appName: 'spots',
      packageName: 'io.spots',
      version: '0.1.2',
      buildNumber: '3',
      buildSignature: '',
    );
  });

  test('rows are tagged as the app, keep one device id, and pass the bot filter', () async {
    final rows = <Map<String, Object?>>[];
    final analytics = Analytics.withSink((row) async => rows.add(row));

    analytics.track('page_view', screen: 'discover');
    analytics.track('spot_save', screen: 'discover', props: {'placeId': 'p1'});
    await pumpEventQueue();

    expect(rows, hasLength(2));
    final first = rows.first;
    expect(first['name'], 'page_view');
    expect(first['path'], '/app/discover');
    expect(first['user_agent'], startsWith('spots-app/0.1.2 ('));
    expect(botUa.hasMatch(first['user_agent']! as String), isFalse);
    expect(first['anon_id'], matches(RegExp(r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$')));
    expect(rows.last['anon_id'], first['anon_id']);
    expect(rows.last['props'], {'placeId': 'p1'});
    // never sends user_id: the database stamps it from the sign-in
    expect(first.containsKey('user_id'), isFalse);
  });

  test('a failing insert never throws', () async {
    final analytics = Analytics.withSink((row) async => throw Exception('offline'));
    analytics.track('page_view');
    await pumpEventQueue();
  });
}
