# Wikipedia Explorer

A learning project for transitioning from React/TypeScript to Flutter/Dart.

The app lets you discover Wikipedia articles near any location — either by using your device's GPS or by searching for a city or place name. Results are shown in a responsive grid (1 column on phone, 2 on tablet, 3 on desktop) and tapping an article opens it in the browser. A History tab tracks everything you've opened in the session.

## What's in the codebase

The source is intentionally small (3 files) and commented with React/TypeScript analogies throughout:

| File | React equivalent |
|---|---|
| `lib/main.dart` | Component tree — all UI widgets |
| `lib/state/app_state.dart` | Zustand/Redux store — state shape + actions |
| `lib/api/api_service.dart` | API layer — fetch functions + data model |

Key concepts covered: `StatelessWidget` vs `ConsumerWidget`, Riverpod (`ref.watch` / `ref.read`), `TextEditingController`, `LayoutBuilder` for responsive layouts, `TabBarView`, `AutomaticKeepAliveClientMixin`, and `Future`/`async`-`await`.

## Running the app

```bash
# Check setup
flutter doctor

# Web
flutter run -d chrome

# Android (emulator or USB device)
flutter run -d android

# iOS (Mac only, Simulator or device)
flutter run -d ios
```

## APIs used

- [Wikipedia GeoSearch API](https://www.mediawiki.org/wiki/API:Geosearch) — finds articles near a coordinate
- [Open-Meteo Geocoding API](https://open-meteo.com/en/docs/geocoding-api) — converts a place name to coordinates (no API key required)
