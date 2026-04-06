// =============================================================================
// lib/state/app_state.dart
//
// Contains:
//   1. AppState      — the immutable state shape
//   2. AppNotifier   — the store class with actions
//   3. appProvider   — the global provider handle
// =============================================================================

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../api/api_service.dart';

const _noValue = Object();

// =============================================================================
// IMMUTABLE STATE CLASS
//
// TypeScript/Redux Toolkit equivalent:
//   interface AppState {
//     readonly isLoading: boolean;
//     readonly error: string | null;
//     readonly apiCallCount: number;
//     readonly articles: readonly Article[];
//     readonly history: readonly string[];
//   }
//
//   const initialState: AppState = {
//     isLoading: false, error: null, apiCallCount: 0, articles: [], history: []
//   };
// =============================================================================
class AppState {
  final bool isLoading;
  final String? error;

  final int apiCallCount;
  final List<Article> articles;

  // History is a list of article titles the user has opened this session
  final List<String> history;

  const AppState({
    required this.isLoading,
    required this.error,
    required this.apiCallCount,
    required this.articles,
    required this.history,
  });

  // ---------------------------------------------------------------------------
  // Initial state factory
  // ---------------------------------------------------------------------------
  factory AppState.initial() {
    return const AppState(
      isLoading: false,
      error: null,
      apiCallCount: 0,
      articles: [],
      history: [],
    );
  }

  // ---------------------------------------------------------------------------
  // copyWith — the Dart immutable-update pattern.
  // ---------------------------------------------------------------------------
  AppState copyWith({
    bool? isLoading,
    Object? error = _noValue, // uses sentinel default, NOT null
    int? apiCallCount,
    List<Article>? articles,
    List<String>? history,
  }) {
    return AppState(
      isLoading: isLoading ?? this.isLoading,
      error: identical(error, _noValue) ? this.error : error as String?,
      apiCallCount: apiCallCount ?? this.apiCallCount,
      articles: articles ?? this.articles,
      history: history ?? this.history,
    );
  }
}

// =============================================================================
// APP NOTIFIER — the store / slice
//
// `Notifier<AppState>` is a base class that:
//   1. Holds the current state (accessible via the `state` getter/setter)
//   2. Notifies all listening widgets automatically on `state =` assignment
//   3. Keeps business logic completely separate from the UI
// =============================================================================
class AppNotifier extends Notifier<AppState> {
  @override
  AppState build() => AppState.initial();

  // ---------------------------------------------------------------------------
  // ACTION: Fetch articles using GPS coordinates (Path A — location button)
  // ---------------------------------------------------------------------------
  Future<void> fetchByCoordinates(double lat, double lng) async {
    state = state.copyWith(isLoading: true, error: null);

    try {
      final articles = await ApiService.fetchNearbyArticles(lat, lng);

      state = state.copyWith(
        isLoading: false,
        articles: articles,
        // One API call was made (fetchNearbyArticles)
        apiCallCount: state.apiCallCount + 1,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: e.toString().replaceFirst('Exception: ', ''),
      );
    }
  }

  // ---------------------------------------------------------------------------
  // ACTION: Fetch articles by city name (Path B — manual search fallback)
  //
  // This action makes TWO sequential API calls:
  //   1. geocodeCity()         → converts "London" to { lat: 51.5, lng: -0.1 }
  //   2. fetchNearbyArticles() → uses those coords to search Wikipedia
  // ---------------------------------------------------------------------------
  Future<void> fetchByCity(String city) async {
    state = state.copyWith(isLoading: true, error: null);

    try {
      // Step 1: city name → coordinates (1 API call)
      final coords = await ApiService.geocodeCity(city);

      // Step 2: coordinates → nearby Wikipedia articles (1 more API call)
      final articles = await ApiService.fetchNearbyArticles(
        coords.lat,
        coords.lng,
      );

      state = state.copyWith(
        isLoading: false,
        articles: articles,
        // Two API calls total for this action
        apiCallCount: state.apiCallCount + 2,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: e.toString().replaceFirst('Exception: ', ''),
      );
    }
  }

  // ---------------------------------------------------------------------------
  // ACTION: Add an article title to the session history (no API call)
  // ---------------------------------------------------------------------------
  void addToHistory(String title) {
    // Guard against duplicates — `.contains()`
    if (!state.history.contains(title)) {
      state = state.copyWith(history: [...state.history, title]);
    }
  }
}

// =============================================================================
// THE PROVIDER — the globally accessible "hook" handle
// =============================================================================
final appProvider = NotifierProvider<AppNotifier, AppState>(() {
  return AppNotifier();
});
