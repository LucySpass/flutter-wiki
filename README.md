# Fluwiki

A cross-platform Wikipedia Explorer built with Flutter. Discover Wikipedia articles near any location — either by using your device's GPS or by searching for a city name.

## Features

- **Dual search** — use GPS coordinates or type a city name to find nearby Wikipedia articles
- **Responsive layout** — 1 column on phone, 2 on tablet, 3 on desktop
- **Theme switcher** — cycle between system, light, and dark themes
- **Session history** — tracks every article you've opened in the History tab
- **Stats dashboard** — shows total API calls and history count
- **Accessibility** — semantic labels throughout for screen reader support
- **No API keys required** — uses open public APIs

## Tech stack

| Layer | Tool |
|---|---|
| UI framework | Flutter (Material 3) |
| State management | Riverpod (`Notifier` + `StateProvider`) |
| Networking | `http` package |
| Location | `geolocator` package |
| URL handling | `url_launcher` package |

## Project structure

| File | Purpose |
|---|---|
| `lib/main.dart` | UI layer — all widgets, theme config, entry point |
| `lib/state/app_state.dart` | Immutable app state + Riverpod Notifier (business logic) |
| `lib/api/api_service.dart` | API service + Article data model |
| `integration_test/app_test.dart` | Integration tests — city search, theme switcher, history, error state |

The branch "learning" is annotated with React/TypeScript analogies throughout (JSX to `build()`, `useSelector` to `ref.watch`, Zustand store to Notifier, etc.).

## Running the app

```bash
# Check setup
flutter doctor

# Web
flutter run -d chrome

# Android (emulator or USB device)
flutter run -d android

# iOS (Mac only, requires Xcode)
flutter run -d ios
```

## Building an APK

```bash
flutter build apk --release
flutter install
```

## Running integration tests

Requires a connected device or emulator:

```bash
flutter test integration_test/app_test.dart -d <device-id>
```

## APIs used

- [Wikipedia GeoSearch API](https://www.mediawiki.org/wiki/API:Geosearch) — finds articles near a coordinate
- [Open-Meteo Geocoding API](https://open-meteo.com/en/docs/geocoding-api) — converts a city name to coordinates (no API key required)
