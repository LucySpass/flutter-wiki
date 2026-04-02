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
  });
}
