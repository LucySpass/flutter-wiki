// =============================================================================
// integration_test/app_test.dart
//
// Flutter Integration Test — Manual City Search Flow
//
// What is an integration test in Flutter?
//   Unlike unit tests (which test isolated functions) or widget tests (which
//   render widgets in a fake environment), integration tests run on a REAL
//   device or emulator with real networking. They drive the actual app UI —
//   tapping buttons, entering text, waiting for real HTTP responses.
//
//   Playwright/Cypress equivalent:
//     test('user can search for a city', async ({ page }) => {
//       await page.goto('/');
//       await page.fill('[data-testid="city-input"]', 'London');
//       await page.click('[data-testid="search-button"]');
//       await expect(page.locator('.article-card')).toHaveCount.greaterThan(0);
//     });
//
// Why test the manual path (not GPS)?
//   GPS on emulators is unreliable — the device may have no location fix,
//   and permission dialogs block the test runner. The city search path
//   is fully deterministic for CI and local testing.
//
// How to run:
//   flutter test integration_test/app_test.dart
//   (with a device/emulator connected, or using `flutter test --platform chrome` for web)
// =============================================================================

// `flutter_test` provides `testWidgets`, `expect`, `find`, `WidgetTester`, etc.
// This is the same library used in widget tests — integration_test extends it.
import 'package:flutter_test/flutter_test.dart';

// `integration_test` provides the binding that bridges the test runner with the
// running app on a real device. Must be initialised before any tests run.
import 'package:integration_test/integration_test.dart';

// Import Material widgets so we can reference types like `CircularProgressIndicator`
// and `ListTile` in `find.byType()` — same as importing component types for
// React Testing Library's `screen.getByRole()`.
import 'package:flutter/material.dart';

// Import the app's entry point — like `import App from '../src/App'` in RTL/Playwright.
import 'package:flutter_wiki/main.dart' as app;

void main() {
  // ---------------------------------------------------------------------------
  // SETUP — called once before the entire test suite.
  //
  // `IntegrationTestWidgetsFlutterBinding.ensureInitialized()` connects the
  // Dart test runner to the Flutter engine on the device.
  // Playwright equivalent: nothing explicit needed (browser is the binding).
  // Cypress equivalent: `before(() => { cy.visit('/') })` (roughly).
  // ---------------------------------------------------------------------------
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  // `group` organises related tests — like `describe()` in Jest/Vitest/Cypress.
  group('Wikipedia Explorer — Manual City Search Flow', () {
    // -------------------------------------------------------------------------
    // TEST: Full manual search path
    //
    // `testWidgets` is the Flutter equivalent of `test()` / `it()`.
    // It receives a `WidgetTester tester` — the tool used to drive the UI.
    // WidgetTester ≈ Playwright's `page` object / Cypress's `cy` object.
    // -------------------------------------------------------------------------
    testWidgets(
      'should display article results after searching for a city by name',
      (WidgetTester tester) async {
        // -------------------------------------------------------------------
        // STEP 1 — Launch the app
        //
        // Playwright: await page.goto('http://localhost:3000')
        // Cypress:    cy.visit('/')
        //
        // `app.main()` calls `runApp(ProviderScope(child: WikipediaExplorerApp()))`.
        // `pumpAndSettle()` drives the Flutter engine until the frame queue
        // is empty — equivalent to `waitForLoadState('networkidle')` in Playwright.
        // -------------------------------------------------------------------
        app.main();
        await tester.pumpAndSettle();

        // -------------------------------------------------------------------
        // STEP 2 — Verify the city input field is present
        //
        // `find.byKey(const Key('city_input'))` locates a widget by its `Key`.
        // This is IDENTICAL to:
        //   page.getByTestId('city-input')       (Playwright)
        //   cy.get('[data-testid="city-input"]')  (Cypress)
        //   screen.getByTestId('city-input')      (React Testing Library)
        //
        // We assigned `key: const Key('city_input')` in the TextField widget.
        // -------------------------------------------------------------------
        final cityInputFinder = find.byKey(const Key('city_input'));

        // `expect(finder, findsOneWidget)` = `expect(element).toBeInTheDocument()`
        // Asserts that exactly one matching widget exists in the tree.
        expect(cityInputFinder, findsOneWidget);

        // -------------------------------------------------------------------
        // STEP 3 — Type a city name into the text field
        //
        // Playwright: await page.fill('[data-testid="city-input"]', 'London')
        // Cypress:    cy.get('[data-testid="city-input"]').type('London')
        // RTL:        await userEvent.type(input, 'London')
        // -------------------------------------------------------------------
        await tester.enterText(cityInputFinder, 'London');

        // `pump()` triggers one frame — processes the text input event.
        // Like a single `requestAnimationFrame` tick in the browser.
        await tester.pump();

        // -------------------------------------------------------------------
        // STEP 4 — Tap the "Search Location" button
        //
        // Playwright: await page.click('[data-testid="search-button"]')
        // Cypress:    cy.get('[data-testid="search-button"]').click()
        // RTL:        await userEvent.click(screen.getByTestId('search-button'))
        // -------------------------------------------------------------------
        final searchButtonFinder = find.byKey(const Key('search_button'));
        expect(searchButtonFinder, findsOneWidget);

        await tester.tap(searchButtonFinder);

        // `pump()` processes the tap event and triggers the first re-render.
        // After this single frame, `isLoading` should be `true` in the state.
        await tester.pump();

        // -------------------------------------------------------------------
        // STEP 5 — Assert the loading indicator is visible
        //
        // Playwright: await expect(page.getByRole('progressbar')).toBeVisible()
        // Cypress:    cy.get('[role="progressbar"]').should('be.visible')
        //
        // `find.byType(CircularProgressIndicator)` finds any widget of that
        // Flutter type — like `page.locator('[data-component="Spinner"]')`.
        // `findsOneWidget` = `.toHaveCount(1)` / `.should('exist')`
        // -------------------------------------------------------------------
        expect(find.byType(CircularProgressIndicator), findsOneWidget);

        // -------------------------------------------------------------------
        // STEP 6 — Wait for real network calls to complete
        //
        // `pumpAndSettle` keeps driving frames until the tree is stable again.
        // The duration is the TIMEOUT, not a sleep — it will resolve early
        // the moment the loading state clears.
        //
        // Playwright: await page.waitForSelector('.article-list')
        // Cypress:    cy.get('.article-card', { timeout: 15000 }).should('exist')
        //
        // We set 15 seconds because real API calls on CI can be slow.
        // -------------------------------------------------------------------
        await tester.pumpAndSettle(const Duration(seconds: 15));

        // -------------------------------------------------------------------
        // STEP 7 — Assert that article results are displayed
        //
        // `findsWidgets` (plural) asserts at least one widget of this type exists.
        // We check for `ListTile` because each `_ArticleCard` renders a ListTile.
        //
        // Playwright: expect(await page.locator('.article-card').count()).toBeGreaterThan(0)
        // Cypress:    cy.get('[data-testid="article-card"]').should('have.length.gt', 0)
        // -------------------------------------------------------------------
        expect(find.byType(ListTile), findsWidgets);

        // -------------------------------------------------------------------
        // STEP 8 — Assert the API call counter incremented to 2
        //
        // Searching by city makes 2 API calls:
        //   1. geocodeCity('London')         → Open-Meteo API
        //   2. fetchNearbyArticles(lat, lng) → Wikipedia GeoSearch API
        //
        // `find.textContaining('API Calls: 2')` finds any Text widget whose
        // string contains this substring — like `expect(screen.getByText(/API Calls: 2/))`.
        // -------------------------------------------------------------------
        expect(find.textContaining('API Calls: 2'), findsOneWidget);

        // -------------------------------------------------------------------
        // STEP 9 — Assert the loading spinner is gone
        //
        // `findsNothing` = `.not.toBeInTheDocument()` / `.should('not.exist')`
        // -------------------------------------------------------------------
        expect(find.byType(CircularProgressIndicator), findsNothing);
      },
    );

    // -------------------------------------------------------------------------
    // TEST: Theme mode switcher cycles system → light → dark → system
    //
    // The `_ThemeModeButton` IconButton has `key: const Key('theme_mode_button')`
    // so we can locate it without relying on icon type or position in the tree.
    //
    // Each tap mutates `themeModeProvider` (a Riverpod StateProvider) and the
    // button rebuilds with a new tooltip — equivalent to checking
    //   expect(button).toHaveAccessibleName('Switch to dark theme')
    // in React Testing Library after a state update.
    //
    // We use `find.byTooltip()` to assert the new tooltip text rather than
    // inspecting the provider value directly — tests should exercise the UI,
    // not the internals (same philosophy as RTL's "test what the user sees").
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
        // Playwright: page.getByTestId('theme-mode-button')
        // RTL:        screen.getByTestId('theme-mode-button')
        final themeBtnFinder = find.byKey(const Key('theme_mode_button'));
        expect(themeBtnFinder, findsOneWidget);

        // -------------------------------------------------------------------
        // STEP 2 — Assert initial state: system theme
        //
        // `ThemeMode.system` → tooltip is 'Switch to light theme'.
        // `find.byTooltip()` locates any widget whose tooltip matches exactly.
        // RTL equivalent: expect(btn).toHaveAttribute('title', 'Switch to light theme')
        // -------------------------------------------------------------------
        expect(find.byTooltip('Switch to light theme'), findsOneWidget);

        // -------------------------------------------------------------------
        // STEP 3 — Tap once: system → light
        //
        // `ref.read(themeModeProvider.notifier).state = ThemeMode.light` fires
        // inside `onPressed`. `pump()` processes one frame so the provider
        // notifies its listeners and the button rebuilds.
        // Playwright: await page.click('[data-testid="theme-mode-button"]')
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
    //
    // React analogy: testing that dispatching an action in one component
    // (ArticleCard → addToHistory) updates the Zustand store and a completely
    // different component (HistoryView) re-renders with the new data.
    //
    // NOTE: Tapping an article also calls launchUrl, which opens the device
    // browser. We can't prevent that in an integration test, but the history
    // state updates synchronously before the async launchUrl call, so our
    // assertions still work.
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
        //
        // Playwright: await page.fill('[data-testid="city-input"]', 'Banja Luka')
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
        // RTL: expect(screen.getByText(/History: 0/)).toBeInTheDocument()
        // -------------------------------------------------------------------
        expect(find.textContaining('History: 0'), findsOneWidget);

        // -------------------------------------------------------------------
        // STEP 4 — Tap the first article
        //
        // `find.byType(ListTile).first` grabs the first article card.
        // This fires addToHistory (sync) and then launchUrl (async).
        //
        // Playwright: await page.locator('.article-card').first().click()
        // -------------------------------------------------------------------
        await tester.tap(find.byType(ListTile).first);
        await tester.pumpAndSettle();

        // -------------------------------------------------------------------
        // STEP 5 — Verify history count updated to 1
        // -------------------------------------------------------------------
        expect(find.textContaining('History: 1'), findsOneWidget);

        // -------------------------------------------------------------------
        // STEP 6 — Switch to the History tab
        //
        // `find.text('History')` matches the Tab label. Tapping it switches
        // the TabBarView to show _HistoryView.
        //
        // Playwright: await page.click('[role="tab"]:has-text("History")')
        // -------------------------------------------------------------------
        await tester.tap(find.text('History'));
        await tester.pumpAndSettle();

        // -------------------------------------------------------------------
        // STEP 7 — Verify the tapped article title appears in the History tab
        //
        // We don't know the exact article title, but we know at least one
        // ListTile should render in the History tab (the article we tapped).
        // -------------------------------------------------------------------
        expect(find.byType(ListTile), findsOneWidget);
      },
    );

    // -------------------------------------------------------------------------
    // TEST: Error state — searching for a nonexistent city shows an error
    //
    // The geocoding API returns no results for gibberish input, so the app
    // throws 'City not found: "xyzxyzxyz"' and surfaces it in the UI.
    // This tests the full error path through the Riverpod state:
    //   fetchByCity → geocodeCity throws → state.error is set → UI shows error
    //
    // React analogy: dispatching an async thunk that rejects, and asserting
    // the error boundary / error state renders.
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
        //
        // Playwright: await page.fill('[data-testid="city-input"]', 'xyzxyzxyz')
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
        // The error text comes from ApiService.geocodeCity:
        //   'City not found: "xyzxyzxyz". Please check the spelling.'
        //
        // RTL: expect(screen.getByText(/City not found/)).toBeInTheDocument()
        // -------------------------------------------------------------------
        expect(find.byType(CircularProgressIndicator), findsNothing);
        expect(find.textContaining('City not found'), findsOneWidget);

        // -------------------------------------------------------------------
        // STEP 4 — Assert no articles are shown
        //
        // The results list should remain empty — no ListTile widgets.
        // -------------------------------------------------------------------
        expect(find.byType(ListTile), findsNothing);
      },
    );
  });
}
