// Basic smoke test for Fluwiki.
// Verifies the app renders without crashing and the core UI elements are present.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_wiki/main.dart';

void main() {
  testWidgets('App renders and shows search controls',
      (WidgetTester tester) async {
    // ProviderScope is required because the app uses Riverpod.
    await tester.pumpWidget(
      const ProviderScope(
        child: WikipediaExplorerApp(),
      ),
    );

    // App bar title is visible
    expect(find.text('Fluwiki'), findsOneWidget);

    // Both search controls are present
    expect(find.byKey(const Key('location_button')), findsOneWidget);
    expect(find.byKey(const Key('city_input')), findsOneWidget);
    expect(find.byKey(const Key('search_button')), findsOneWidget);

    // Stats bar shows initial zero counts
    expect(find.textContaining('API Calls: 0'), findsOneWidget);
    expect(find.textContaining('History: 0'), findsOneWidget);
  });
}
