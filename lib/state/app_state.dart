// =============================================================================
// lib/state/app_state.dart
//
// Contains:
//   1. AppState      — the immutable state shape   (like a Zustand state type)
//   2. AppNotifier   — the store class with actions (like a Zustand store)
//   3. appProvider   — the global provider handle  (like `useAppStore` hook)
//
// Riverpod mental model for React/Zustand developers:
//
//   ZUSTAND                            RIVERPOD
//   ─────────────────────────────────  ────────────────────────────────────
//   interface AppState { ... }         class AppState { ... }
//   create<AppState>(set => ({         class AppNotifier extends Notifier<AppState>
//     ...initialState,
//     fetchByCity: async (city) => {   Future<void> fetchByCity(String city)
//       set({ isLoading: true })         state = state.copyWith(isLoading: true)
//     }
//   }))
//   const useAppStore = create(...)    final appProvider = NotifierProvider(...)
//   useAppStore()                      ref.watch(appProvider)
//   useAppStore(s => s.articles)       ref.watch(appProvider.select(s => s.articles))
//   useAppStore.getState().action()    ref.read(appProvider.notifier).action()
// =============================================================================

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../api/api_service.dart';

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
//
// In Dart, immutability is enforced by making every field `final` (readonly).
// There is no built-in `Immutable<T>` helper — instead we use `copyWith`.
// =============================================================================
class AppState {
  final bool isLoading;

  // `String?` = `string | null` in TypeScript.
  // The `?` suffix makes a type nullable — null-safety is built into Dart 3.
  final String? error;

  final int apiCallCount;
  final List<Article> articles;

  // History is a list of article titles the user has opened this session
  final List<String> history;

  // `const` constructor: the entire object can be a compile-time constant
  // when all field values are also compile-time constants.
  const AppState({
    required this.isLoading,
    required this.error,
    required this.apiCallCount,
    required this.articles,
    required this.history,
  });

  // ---------------------------------------------------------------------------
  // Initial state factory
  //
  // Redux Toolkit equivalent:
  //   const initialState: AppState = { isLoading: false, ... }
  //
  // Zustand equivalent (the value inside `create`):
  //   { isLoading: false, error: null, apiCallCount: 0, articles: [], history: [] }
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
  //
  // This is IDENTICAL to how you update state in Redux reducers:
  //   return { ...state, isLoading: true }
  //
  // And Zustand's set():
  //   set(state => ({ ...state, isLoading: true }))
  //
  // Every parameter is optional (marked with `?`). Unspecified fields keep
  // their current value via the null-coalescing operator `??`:
  //   newValue ?? currentValue  →  newValue !== undefined ? newValue : currentValue
  //
  // SPECIAL CASE — nullable `error` field:
  // We need to distinguish between:
  //   a) copyWith()            → keep current error (don't change it)
  //   b) copyWith(error: null) → explicitly clear the error
  //
  // A plain `String? error` parameter can't express this difference because
  // both cases pass `null`. We use a private sentinel Object `_noValue` to
  // tell them apart — a common Dart pattern for nullable copyWith fields.
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
      // `identical()` checks object identity — like `===` in JavaScript.
      // If the caller didn't pass `error`, it equals `_noValue`, so we keep `this.error`.
      // If they did pass `error` (even null), we use the new value.
      error: identical(error, _noValue) ? this.error : error as String?,
      apiCallCount: apiCallCount ?? this.apiCallCount,
      articles: articles ?? this.articles,
      history: history ?? this.history,
    );
  }
}

// Private sentinel value — only accessible within this file (underscore = private in Dart).
// Equivalent to `const UNSET = Symbol('UNSET')` in TypeScript.
const _noValue = Object();

// =============================================================================
// APP NOTIFIER — the store / slice
//
// `Notifier<AppState>` is a base class that:
//   1. Holds the current state (accessible via the `state` getter/setter)
//   2. Notifies all listening widgets automatically on `state =` assignment
//   3. Keeps business logic completely separate from the UI
//
// Redux Toolkit equivalent:
//   const appSlice = createSlice({ name: 'app', initialState, reducers: {} })
//   + createAsyncThunk() for the async actions
//
// Zustand equivalent:
//   const useAppStore = create<AppState & Actions>((set) => ({
//     ...initialState,
//     fetchByCity: async (city) => { set({ isLoading: true }); ... },
//   }))
// =============================================================================
class AppNotifier extends Notifier<AppState> {
  // Cache fields — equivalent to memoisation refs inside a custom hook:
  //   const lastCityRef = useRef<string | null>(null);
  //   const lastCoordsRef = useRef<{ lat: number; lng: number } | null>(null);
  //
  // These are NOT part of AppState because widgets never need to read them —
  // they exist only to skip redundant API calls when nothing has changed.
  String? _lastCity;
  double? _lastLat;
  double? _lastLng;

  // `build()` is called once when the provider is first accessed by a widget.
  // It's the equivalent of the initial state in Zustand or Redux's initialState.
  // Think of it as a constructor that returns the starting state.
  @override
  AppState build() => AppState.initial();

  // ---------------------------------------------------------------------------
  // ACTION: Fetch articles using GPS coordinates (Path A — location button)
  //
  // TypeScript/Zustand equivalent:
  //   fetchByCoordinates: async (lat, lng) => {
  //     set({ isLoading: true, error: null });
  //     try {
  //       const articles = await ApiService.fetchNearbyArticles(lat, lng);
  //       set({ isLoading: false, articles, apiCallCount: state.apiCallCount + 1 });
  //     } catch (e) {
  //       set({ isLoading: false, error: String(e) });
  //     }
  //   }
  // ---------------------------------------------------------------------------
  Future<void> fetchByCoordinates(double lat, double lng) async {
    // Guard: skip the Wikipedia API call if coordinates haven't changed.
    // Equivalent to: if (lat === lastLat && lng === lastLng) return;
    //
    // Uses exact float equality — GPS micro-variance between readings (even a
    // few metres apart) still triggers a new fetch, which is intentional.
    if (lat == _lastLat && lng == _lastLng) return;

    // `state =` is the Riverpod equivalent of Zustand's `set()` or
    // dispatching a Redux action. All widgets watching this provider re-render.
    state = state.copyWith(isLoading: true, error: null);

    try {
      final articles = await ApiService.fetchNearbyArticles(lat, lng);

      _lastLat = lat;
      _lastLng = lng;
      state = state.copyWith(
        isLoading: false,
        articles: articles,
        // One API call was made (fetchNearbyArticles)
        apiCallCount: state.apiCallCount + 1,
      );
    } catch (e) {
      // `catch (e)` catches any thrown value — like `catch (e: unknown)` in TS.
      // `.toString()` converts the Dart Exception to a readable message string.
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
  //
  // This is equivalent to a Redux `createAsyncThunk` that chains two awaits,
  // or a Zustand action with multiple `await` + `set()` calls.
  // ---------------------------------------------------------------------------
  Future<void> fetchByCity(String city) async {
    // Guard: skip both API calls if this city was the last successful search.
    // Equivalent to: if (city === lastCity) return;
    if (city == _lastCity) return;

    state = state.copyWith(isLoading: true, error: null);

    try {
      // Step 1: city name → coordinates (1 API call)
      // `coords` is a Dart Record — accessed like: coords.lat, coords.lng
      // TypeScript equivalent: const coords = await geocodeCity(city) // {lat, lng}
      final coords = await ApiService.geocodeCity(city);

      // Step 2: coordinates → nearby Wikipedia articles (1 more API call)
      final articles = await ApiService.fetchNearbyArticles(
        coords.lat,
        coords.lng,
      );

      _lastCity = city;
      _lastLat = coords.lat;
      _lastLng = coords.lng;
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
  //
  // Zustand equivalent:
  //   addToHistory: (title) => set(state => ({
  //     history: state.history.includes(title)
  //       ? state.history
  //       : [...state.history, title]
  //   }))
  // ---------------------------------------------------------------------------
  void addToHistory(String title) {
    // Guard against duplicates — `.contains()` = `Array.prototype.includes()` in JS
    if (!state.history.contains(title)) {
      // List spread `[...state.history, title]` — identical to JS spread syntax
      state = state.copyWith(history: [...state.history, title]);
    }
  }
}

// =============================================================================
// THE PROVIDER — the globally accessible "hook" handle
//
// This is what widgets import and use to connect to the store.
//
// Zustand equivalent:
//   export const useAppStore = create(...)
//   // Used in components as: const articles = useAppStore(s => s.articles)
//
// Riverpod equivalent:
//   export final appProvider = NotifierProvider(...)
//   // Used in widgets as: final articles = ref.watch(appProvider.select(s => s.articles))
//
// The provider is LAZY — the Notifier is only instantiated the first time
// any widget calls `ref.watch(appProvider)`. This mirrors Zustand's store
// being created once on first import.
// =============================================================================
final appProvider = NotifierProvider<AppNotifier, AppState>(() {
  return AppNotifier();
});
