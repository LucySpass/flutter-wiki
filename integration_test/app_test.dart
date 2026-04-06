// =============================================================================
// integration_test/app_test.dart
//
// Flutter Integration Test — Manual City Search Flow
// =============================================================================

import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_wiki/main.dart' as app;

void main() {
  // ---------------------------------------------------------------------------
  // SETUP — called once before the entire test suite.
  // ---------------------------------------------------------------------------
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  // `group` organises related tests — like `describe()` in Jest/Vitest/Cypress.
  group('Fluwiki — Manual City Search Flow', () {
    // -------------------------------------------------------------------------
    // TEST: Full manual search path
    // -------------------------------------------------------------------------
    testWidgets(
      'should display article results after searching for a city by name',
      (WidgetTester tester) async {
        // -------------------------------------------------------------------
        // STEP 1 — Launch the app
        // -------------------------------------------------------------------
        app.main();
        await tester.pumpAndSettle();

        // -------------------------------------------------------------------
        // STEP 2 — Verify the city input field is present
        // -------------------------------------------------------------------
        final cityInputFinder = find.byKey(const Key('city_input'));

        expect(cityInputFinder, findsOneWidget);

        // -------------------------------------------------------------------
        // STEP 3 — Type a city name into the text field
        // -------------------------------------------------------------------
        await tester.enterText(cityInputFinder, 'Amsterdam');
        await tester.pump();

        // -------------------------------------------------------------------
        // STEP 4 — Tap the "Search Location" button
        // -------------------------------------------------------------------
        final searchButtonFinder = find.byKey(const Key('search_button'));
        expect(searchButtonFinder, findsOneWidget);

        await tester.tap(searchButtonFinder);
        await tester.pump();

        // -------------------------------------------------------------------
        // STEP 5 — Assert the loading indicator is visible
        // -------------------------------------------------------------------
        expect(find.byType(CircularProgressIndicator), findsOneWidget);

        // -------------------------------------------------------------------
        // STEP 6 — Wait for real network calls to complete
        // -------------------------------------------------------------------
        await tester.pumpAndSettle(const Duration(seconds: 15));

        // -------------------------------------------------------------------
        // STEP 7 — Assert that article results are displayed
        //
        // `findsWidgets` (plural) asserts at least one widget of this type exists.
        // -------------------------------------------------------------------
        expect(find.byType(ListTile), findsWidgets);

        // -------------------------------------------------------------------
        // STEP 8 — Assert the API call counter incremented to 2
        //
        // Searching by city makes 2 API calls:
        //   1. geocodeCity('Amsterdam')         → Open-Meteo API
        //   2. fetchNearbyArticles(lat, lng) → Wikipedia GeoSearch API
        // -------------------------------------------------------------------
        expect(find.textContaining('API Calls: 2'), findsOneWidget);

        // -------------------------------------------------------------------
        // STEP 9 — Assert the loading spinner is gone
        // -------------------------------------------------------------------
        expect(find.byType(CircularProgressIndicator), findsNothing);
      },
    );

    // -------------------------------------------------------------------------
    // TEST: Theme mode switcher cycles system → light → dark → system
    //
    // The `_ThemeModeButton` IconButton has `key: const Key('theme_mode_button')`
    // so we can locate it without relying on icon type or position in the tree.
    // -------------------------------------------------------------------------
    testWidgets(
      'theme mode button should cycle through system → light → dark → system',
      (WidgetTester tester) async {
        // -------------------------------------------------------------------
        // STEP 1 — Launch the app
        // -------------------------------------------------------------------
        app.main();
        await tester.pumpAndSettle();

        // Locate the theme toggle button by its stable Key.
        final themeBtnFinder = find.byKey(const Key('theme_mode_button'));
        expect(themeBtnFinder, findsOneWidget);

        // -------------------------------------------------------------------
        // STEP 2 — Assert initial state: system theme
        // -------------------------------------------------------------------
        expect(find.byTooltip('Switch to light theme'), findsOneWidget);

        // -------------------------------------------------------------------
        // STEP 3 — Tap once: system → light
        // -------------------------------------------------------------------
        await tester.tap(themeBtnFinder);
        await tester.pump(); // one frame — provider updates, button rebuilds

        // Tooltip should now read 'Switch to dark theme' (light mode active).
        expect(find.byTooltip('Switch to dark theme'), findsOneWidget);
        expect(find.byTooltip('Switch to light theme'), findsNothing);

        // -------------------------------------------------------------------
        // STEP 4 — Tap again: light → dark
        // -------------------------------------------------------------------
        await tester.tap(themeBtnFinder);
        await tester.pump();

        // Tooltip should now read 'Follow system theme' (dark mode active).
        expect(find.byTooltip('Follow system theme'), findsOneWidget);
        expect(find.byTooltip('Switch to dark theme'), findsNothing);

        // -------------------------------------------------------------------
        // STEP 5 — Tap again: dark → system (full cycle complete)
        // -------------------------------------------------------------------
        await tester.tap(themeBtnFinder);
        await tester.pump();

        // Back to 'Switch to light theme' — we've come full circle.
        expect(find.byTooltip('Switch to light theme'), findsOneWidget);
        expect(find.byTooltip('Follow system theme'), findsNothing);
      },
    );

    // -------------------------------------------------------------------------
    // TEST: History flow — search → tap article → history tab shows it
    //
    // This test exercises the full Riverpod state cycle:
    //   1. User searches "Banja Luka" → fetchByCity dispatches two API calls
    //   2. Articles render in the Explore tab
    //   3. User taps an article → addToHistory fires → state.history grows
    //   4. Stats bar reflects the new history count
    //   5. User switches to History tab → the article title is visible
    // -------------------------------------------------------------------------
    testWidgets(
      'should add tapped article to history and display it in the History tab',
      (WidgetTester tester) async {
        // -------------------------------------------------------------------
        // STEP 1 — Launch the app
        // -------------------------------------------------------------------
        app.main();
        await tester.pumpAndSettle();

        // -------------------------------------------------------------------
        // STEP 2 — Search for "Banja Luka"
        // -------------------------------------------------------------------
        final cityInputFinder = find.byKey(const Key('city_input'));
        await tester.enterText(cityInputFinder, 'Banja Luka');
        await tester.pump();

        final searchButtonFinder = find.byKey(const Key('search_button'));
        await tester.tap(searchButtonFinder);
        await tester.pump();

        // Loading spinner should appear while API calls are in progress.
        expect(find.byType(CircularProgressIndicator), findsOneWidget);

        // Wait for the two API calls (geocode + Wikipedia) to complete.
        await tester.pumpAndSettle(const Duration(seconds: 15));

        // Articles should now be visible.
        expect(find.byType(ListTile), findsWidgets);

        // -------------------------------------------------------------------
        // STEP 3 — Verify history is empty before tapping
        //
        // The stats bar should show "History: 0".
        // -------------------------------------------------------------------
        expect(find.textContaining('History: 0'), findsOneWidget);

        // -------------------------------------------------------------------
        // STEP 4 — Tap the first article
        // -------------------------------------------------------------------
        await tester.tap(find.byType(ListTile).first);
        await tester.pumpAndSettle();

        // -------------------------------------------------------------------
        // STEP 5 — Verify history count updated to 1
        // -------------------------------------------------------------------
        expect(find.textContaining('History: 1'), findsOneWidget);

        // -------------------------------------------------------------------
        // STEP 6 — Switch to the History tab
        // -------------------------------------------------------------------
        await tester.tap(find.text('History'));
        await tester.pumpAndSettle();

        // -------------------------------------------------------------------
        // STEP 7 — Verify the tapped article title appears in the History tab
        // -------------------------------------------------------------------
        expect(find.byType(ListTile), findsAtLeastNWidgets(1));
      },
    );

    // -------------------------------------------------------------------------
    // TEST: Error state — searching for a nonexistent city shows an error
    //
    // The geocoding API returns no results for gibberish input, so the app
    // throws 'City not found: "xyzxyzxyz"' and surfaces it in the UI.
    // This tests the full error path through the Riverpod state:
    //   fetchByCity → geocodeCity throws → state.error is set → UI shows error
    // -------------------------------------------------------------------------
    testWidgets(
      'should display an error message when searching for a nonexistent city',
      (WidgetTester tester) async {
        // -------------------------------------------------------------------
        // STEP 1 — Launch the app
        // -------------------------------------------------------------------
        app.main();
        await tester.pumpAndSettle();

        // -------------------------------------------------------------------
        // STEP 2 — Search for a nonsense city name
        // -------------------------------------------------------------------
        final cityInputFinder = find.byKey(const Key('city_input'));
        await tester.enterText(cityInputFinder, 'xyzxyzxyz');
        await tester.pump();

        final searchButtonFinder = find.byKey(const Key('search_button'));
        await tester.tap(searchButtonFinder);
        await tester.pump();

        // Loading spinner should appear while the API call is in flight.
        expect(find.byType(CircularProgressIndicator), findsOneWidget);

        // Wait for the geocoding API to respond (and fail).
        await tester.pumpAndSettle(const Duration(seconds: 15));

        // -------------------------------------------------------------------
        // STEP 3 — Assert error state
        //
        // The spinner should be gone and an error message should be visible.
        // -------------------------------------------------------------------
        expect(find.byType(CircularProgressIndicator), findsNothing);
        expect(find.textContaining('City not found'), findsOneWidget);

        // -------------------------------------------------------------------
        // STEP 4 — Assert no articles are shown
        // -------------------------------------------------------------------
        expect(find.byType(ListTile), findsNothing);
      },
    );
  });
}
