import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:spots/data/demo_backend.dart';
import 'package:spots/main.dart';
import 'package:spots/state/app_state.dart';

/// A demo backend whose server call fails, to check nothing is cleared.
class _FailingBackend extends DemoBackend {
  @override
  Future<void> deleteAccount() async => throw Exception('offline');
}

/// Seed one saved spot and one visit through the backend, then load.
Future<AppState> _seeded(WidgetTester tester, DemoBackend backend) async {
  final state = AppState(backend);
  await tester.runAsync(() async {
    final spot = (await backend.fetchSpots()).first;
    await backend.addSaved(spot.placeId);
    await backend.createVisit(spot);
    await state.load();
  });
  expect(state.savedIds, hasLength(1));
  expect(state.visits, hasLength(1));
  return state;
}

Future<void> _openDeleteDialog(WidgetTester tester, AppState state) async {
  // a short phone, where the account sheet has to scroll
  tester.view.physicalSize = const Size(400 * 3, 640 * 3);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(SpotsApp(state: state));
  await tester.pumpAndSettle();
  await tester.tap(find.byTooltip('Account'));
  await tester.pumpAndSettle();
  await tester.tap(find.widgetWithText(TextButton, 'Delete account'));
  await tester.pumpAndSettle();
  expect(find.text('Delete your account?'), findsOneWidget);
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({'spots:swiped': true}));

  testWidgets('delete account confirms, clears the demo data and signs out', (tester) async {
    final state = await _seeded(tester, DemoBackend());
    await _openDeleteDialog(tester, state);
    expect(find.textContaining('ratings'), findsOneWidget);

    await tester.tap(find.widgetWithText(FilledButton, 'Delete account'));
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
    await tester.pumpAndSettle();

    expect(state.user, isNull);
    expect(state.savedIds, isEmpty);
    expect(state.visits, isEmpty);
    expect(find.text('Delete your account?'), findsNothing);
    expect(find.text('Your account and its data were deleted'), findsOneWidget);
    final prefs = await tester.runAsync(SharedPreferences.getInstance);
    expect(prefs!.getStringList('demo:saved'), isNull);
    expect(prefs.getString('demo:visits'), isNull);
  });

  testWidgets('cancelling keeps everything', (tester) async {
    final state = await _seeded(tester, DemoBackend());
    await _openDeleteDialog(tester, state);

    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    expect(find.text('Delete your account?'), findsNothing);
    expect(state.user, isNotNull);
    expect(state.savedIds, hasLength(1));
    expect(state.visits, hasLength(1));
  });

  testWidgets('a failed delete keeps the lists and says so', (tester) async {
    final state = await _seeded(tester, _FailingBackend());
    await _openDeleteDialog(tester, state);

    await tester.tap(find.widgetWithText(FilledButton, 'Delete account'));
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
    await tester.pumpAndSettle();

    expect(state.user, isNotNull);
    expect(state.savedIds, hasLength(1));
    expect(state.visits, hasLength(1));
    expect(find.textContaining("Couldn't delete your account"), findsOneWidget);
  });
}
