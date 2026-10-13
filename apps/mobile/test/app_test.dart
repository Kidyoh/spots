import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:spots_mobile/data/demo_backend.dart';
import 'package:spots_mobile/main.dart';
import 'package:spots_mobile/state/app_state.dart';

void main() {
  // 'spots:swiped' hides the looping swipe hint so pumpAndSettle can settle
  setUp(() => SharedPreferences.setMockInitialValues({'spots:swiped': true}));

  testWidgets('boots on demo data, swipes the deck and saves a spot', (tester) async {
    tester.view.physicalSize = const Size(400 * 3, 860 * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    final state = AppState(DemoBackend());
    await tester.runAsync(state.load);
    await tester.pumpWidget(SpotsApp(state: state));
    await tester.pumpAndSettle();

    expect(find.text('Where to next'), findsOneWidget);
    expect(state.filteredSpots, isNotEmpty);
    final first = state.currentSpot!;
    expect(find.text(first.name), findsWidgets);

    // swipe the top card away → the next spot is on top
    await tester.fling(find.text(first.name).last, const Offset(-300, 0), 1500);
    await tester.pumpAndSettle();
    expect(state.deckIndex, 1);

    // save it from the deck controls
    await tester.tap(find.byTooltip('Save to Want to go'));
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
    await tester.pumpAndSettle();
    expect(state.savedIds, [state.currentSpot!.placeId]);

    // the Saved tab lists it
    await tester.tap(find.byIcon(Icons.favorite_border_rounded));
    await tester.pumpAndSettle();
    expect(find.text('Our places'), findsOneWidget);
    expect(find.text(state.currentSpot!.name), findsWidgets);
  });

  testWidgets('events tab groups by day', (tester) async {
    final state = AppState(DemoBackend());
    await tester.runAsync(state.load);
    await tester.pumpWidget(SpotsApp(state: state));
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.event_outlined));
    await tester.pumpAndSettle();
    expect(find.text("What's on"), findsOneWidget);
    expect(find.text('Today'), findsWidgets);
  });
}
