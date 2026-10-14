import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spots/models/spot.dart';
import 'package:spots/widgets/spot_card.dart';

Spot spot({String? neighborhood}) => Spot.fromJson({
  'id': '1',
  'google_place_id': 'p1',
  'name': 'Cucina Moseb',
  'neighborhood': neighborhood,
  'lat': 9.0,
  'lng': 38.7,
  'quality_score': 68,
  'tags': ['ethiopian'],
  'video_count': 1,
  'first_seen_at': DateTime.now().toIso8601String(),
});

void main() {
  test('areaShort drops a trailing note in brackets', () {
    expect(spot(neighborhood: '22 (from Adey Ababa stadium to Addis Hiwot hospital)').areaShort, '22');
    expect(spot(neighborhood: 'Bole').areaShort, 'Bole');
    expect(spot().areaShort, 'Addis Ababa');
  });

  testWidgets('a long area, NEW, been and saved all fit on a narrow card', (tester) async {
    tester.view.physicalSize = const Size(320 * 3, 560 * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SpotCard(
            spot: spot(neighborhood: 'Somewhere With A Very Long Name Indeed Near The Old Market Road'),
            onOpen: () {},
            saved: true,
            visited: true,
          ),
        ),
      ),
    );
    // any RenderFlex overflow would have thrown during layout
    expect(tester.takeException(), isNull);
    expect(find.byIcon(Icons.check_rounded), findsOneWidget);
    expect(find.byIcon(Icons.bookmark_rounded), findsOneWidget);
    // the badges hug the card's top-right corner, not the middle
    final cardRight = tester.getTopRight(find.byType(SpotCard)).dx;
    expect(cardRight - tester.getTopRight(find.byIcon(Icons.bookmark_rounded)).dx, lessThan(40));
  });

  testWidgets('with a short area the badges still sit in the top-right corner', (tester) async {
    tester.view.physicalSize = const Size(400 * 3, 640 * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SpotCard(
            spot: spot(neighborhood: 'Bole'),
            onOpen: () {},
            visited: true,
          ),
        ),
      ),
    );
    final cardRight = tester.getTopRight(find.byType(SpotCard)).dx;
    expect(cardRight - tester.getTopRight(find.byIcon(Icons.check_rounded)).dx, lessThan(40));
  });
}
