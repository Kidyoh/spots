import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:spots/data/demo_backend.dart';
import 'package:spots/main.dart';
import 'package:spots/state/app_state.dart';

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

    expect(find.text('spots'), findsOneWidget);
    expect(state.filteredSpots, isNotEmpty);
    final first = state.currentSpot!;
    expect(find.text(first.name), findsWidgets);

    // swipe the top card away → the next spot is on top
    await tester.fling(find.text(first.name).last, const Offset(-300, 0), 1500);
    await tester.pumpAndSettle();
    expect(state.deckIndex, 1);
    // the counter shows the whole total, not a truncated one
    expect(find.text('2 of ${state.filteredSpots.length}'), findsOneWidget);

    // a short drag springs back without moving on
    await tester.drag(find.text(state.currentSpot!.name).last, const Offset(-40, 0));
    await tester.pumpAndSettle();
    expect(state.deckIndex, 1);

    // back brings the previous card in again
    await tester.tap(find.byTooltip('Previous'));
    await tester.pumpAndSettle();
    expect(state.deckIndex, 0);
    // like the web: swipe right → previous (wrapping round), swipe left → next
    final n = state.filteredSpots.length;
    await tester.fling(find.text(first.name).last, const Offset(300, 0), 1500);
    await tester.pumpAndSettle();
    expect(state.deckIndex, n - 1);
    await tester.fling(find.text(state.currentSpot!.name).last, const Offset(-300, 0), 1500);
    await tester.pumpAndSettle();
    expect(state.deckIndex, 0);
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

  testWidgets('a search hidden by a chip says so and can show all', (tester) async {
    tester.view.physicalSize = const Size(400 * 3, 860 * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    final state = AppState(DemoBackend());
    await tester.runAsync(state.load);
    await tester.pumpWidget(SpotsApp(state: state));
    await tester.pumpAndSettle();

    state.toggleCategory('burgers'); // like having Habesha on and searching a cafe
    state.setQuery('tomoca');
    await tester.pumpAndSettle();
    expect(state.filteredSpots, isEmpty);
    expect(find.textContaining('outside these filters'), findsOneWidget);

    await tester.tap(find.text('Show it'));
    await tester.pumpAndSettle();
    expect(state.selectedCategories, isEmpty);
    expect(state.query, 'tomoca');
    expect(state.currentSpot!.name, contains('Tomoca'));
  });
}
