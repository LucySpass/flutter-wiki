# Improvements

Things I would change if I continued working on this app.

---

## 1. Proper folder structure

Right now `lib/main.dart` contains the entire UI layer (~1000 lines). Split it into per-widget files grouped by responsibility:

```
lib/
├── main.dart                       # entry point + WikipediaExplorerApp only
├── api/
│   └── api_service.dart            # already exists
├── state/
│   ├── app_state.dart              # AppState model + AppNotifier
│   └── theme_mode_provider.dart    # extract themeModeProvider
├── screens/
│   └── home_screen.dart            # HomeScreen widget
└── widgets/
    ├── stats_bar.dart
    ├── search_controls.dart
    ├── results_view.dart
    ├── article_card.dart
    ├── history_view.dart
    ├── history_card.dart
    ├── footer.dart
    └── theme_mode_button.dart
```

**Why**: faster file navigation, easier code review, encourages single-responsibility components, makes it obvious which widgets are reused.

---

## 2. Snackbar deduplication

Right now if the user spams the GPS button when location services are disabled, ten identical snackbars stack on top of each other.

**Fix**: clear existing snackbars before showing a new one.

```dart
void _showSnackBar(String message) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()    // ← dismiss any active snackbar first
    ..showSnackBar(SnackBar(content: Text(message)));
}
```

For per-button cooldown (e.g. ignore taps within 2 seconds of each other), wrap the handler in a debouncer using a `Timer`:

```dart
Timer? _debounce;

void _handleLocationPressed() {
  if (_debounce?.isActive ?? false) return;
  _debounce = Timer(const Duration(seconds: 2), () {});
  // ... actual handler
}
```

---

## 3. Dependency injection for ApiService

Make `ApiService` injectable via a Riverpod `Provider` so tests can swap it for a mock:

```dart
final apiServiceProvider = Provider<ApiService>((ref) => ApiService());

class AppNotifier extends Notifier<AppState> {
  Future<void> fetchByCity(String city) async {
    final api = ref.read(apiServiceProvider);
    final coords = await api.geocodeCity(city);
    // ...
  }
}
```

In tests:

```dart
ProviderContainer(
  overrides: [apiServiceProvider.overrideWithValue(MockApiService())],
);
```

---

## 4. Persist history across app restarts

Currently `state.history` is in-memory only — close the app and it's gone. Persist it with `shared_preferences` (Flutter's equivalent of `localStorage`):

```dart
// On addToHistory:
final prefs = await SharedPreferences.getInstance();
await prefs.setStringList('history', state.history);

// On AppNotifier.build():
final saved = prefs.getStringList('history') ?? [];
return AppState.initial().copyWith(history: saved);
```

---

## 5. Article detail screen instead of leaving the app

Right now tapping an article launches the system browser, which kicks the user out of the app. Add an in-app detail screen using a `WebView` (`webview_flutter` package) or by parsing the Wikipedia article API into native Flutter widgets. Navigate with `Navigator.push` or `go_router`.

---

## 6. Pagination / infinite scroll

The Wikipedia API call is currently capped at 20 results (`gslimit=20`). Add a "Load more" button or infinite scroll that fetches the next page when the user scrolls near the bottom of the list. This means tracking `currentOffset` in `AppState`.

---

## 7. Internationalization (i18n)

All user-facing strings are hardcoded in English. Move them into `lib/l10n/app_en.arb` and use Flutter's built-in `intl` package. This is a one-time refactor that makes the app instantly translatable.

---

## 8. Extract magic numbers and strings into constants

Things like `gsradius=5000`, `gslimit=20`, breakpoints (`600`, `1024`), the Wikipedia base URL, error messages — move them into a `lib/constants.dart` file. Easier to tweak, easier to test.

---
