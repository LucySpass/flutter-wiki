// =============================================================================
// lib/main.dart — UI Layer
//
// Widget tree overview:
//   ProviderScope                        ← Riverpod root (like Redux <Provider>)
//   └─ WikipediaExplorerApp              ← ConsumerWidget; MaterialApp with light/dark themes
//      └─ HomeScreen                     ← ConsumerWidget; reads global appProvider state
//         └─ DefaultTabController        ← manages selected tab index via InheritedWidget
//            └─ Scaffold
//               ├─ appBar: AppBar
//               │  ├─ title: Row
//               │  │  ├─ Text 'Wikipedia Explorer'
//               │  │  └─ _ThemeModeButton    ← cycles system / light / dark theme
//               │  └─ bottom: PreferredSize
//               │     ├─ _StatsBar           ← API call count + history length
//               │     └─ TabBar              ← Explore / History tab switcher
//               ├─ body: LayoutBuilder → Align → SizedBox (maxWidth 1300) → TabBarView
//               │  ├─ [Explore tab] Column
//               │  │  ├─ _SearchControls     ← GPS button + location text input
//               │  │  └─ _ResultsView        ← loading / error / empty / list or grid
//               │  │     └─ _ArticleCard     ← individual list/grid item
//               │  └─ [History tab]
//               │     └─ _HistoryView        ← previously visited articles
//               │        └─ _HistoryCard     ← individual history item
//               └─ bottomNavigationBar: _Footer  ← 'made by Ivana', always visible
// =============================================================================

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:url_launcher/url_launcher.dart';

import 'api/api_service.dart';
import 'state/app_state.dart';

// =============================================================================
// RESPONSIVE BREAKPOINTS
//
// Returns the number of result columns based on available width.
// Equivalent to CSS container queries / media queries:
//   width < 600 px         → 1 column  (phone portrait)
//   600 px ≤ width < 1024  → 2 columns (phone landscape / tablet)
//   width ≥ 1024 px        → 3 columns (desktop / wide tablet)
// =============================================================================
// Maximum width for body content — equivalent to CSS max-width + margin: 0 auto.
const double _kMaxContentWidth = 1300;
// Height of the stats bar strip shown between the toolbar and the tab bar.
const double _kStatsBarHeight = 32.0;
const String _mainTitle = "Wikipedia Explorer";

int _columnCount(double width) {
  if (width >= 1024) return 3;
  if (width >= 600) return 2;
  return 1;
}

// =============================================================================
// ENTRY POINT
//
// `runApp()` is Flutter's equivalent of:
//   ReactDOM.createRoot(document.getElementById('root')).render(<App />)
//
// `ProviderScope` MUST wrap the entire widget tree — it is the Riverpod
// equivalent of Redux's `<Provider store={store}>` or React Context's
// `<MyContext.Provider value={...}>`.
//
// Without ProviderScope, any `ref.watch()` call will throw at runtime.
// =============================================================================
void main() {
  // Ensure the Flutter engine bindings are initialised before any platform
  // channel calls (e.g. permission checks). Equivalent to waiting for
  // `DOMContentLoaded` before calling browser APIs.
  WidgetsFlutterBinding.ensureInitialized();

  runApp(
    const ProviderScope(
      child: WikipediaExplorerApp(),
    ),
  );
}

// =============================================================================
// THEME MODE PROVIDER
//
// A `StateProvider` holds a single mutable value with no extra logic — the
// simplest Riverpod primitive, equivalent to a Zustand store that only does:
//   const useThemeMode = create(() => ({ mode: ThemeMode.system, set }))
//
// Starts at `ThemeMode.system` (follows the OS). The toggle button cycles:
//   system → light → dark → system → …
//
// Writing to it from anywhere:
//   ref.read(themeModeProvider.notifier).state = ThemeMode.dark;
// =============================================================================
final themeModeProvider = StateProvider<ThemeMode>((ref) => ThemeMode.system);

// =============================================================================
// ROOT APP WIDGET
//
// `ConsumerWidget` (was StatelessWidget) so it can watch `themeModeProvider`
// and pass the live value down to MaterialApp.
//
// `build(BuildContext context)` is the render method / JSX return value.
// `context` provides access to the theme, navigator, locale, etc. —
// similar to React's Context API, but available implicitly everywhere.
// =============================================================================
class WikipediaExplorerApp extends ConsumerWidget {
  const WikipediaExplorerApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Watches the provider — rebuilds MaterialApp whenever the user toggles
    // the theme. Equivalent to: const themeMode = useThemeMode(s => s.mode)
    final themeMode = ref.watch(themeModeProvider);
    // `MaterialApp` is the root scaffold for a Material Design app.
    // Equivalent to wrapping your app with a Router + ThemeProvider in React:
    //   <ThemeProvider theme={themeMode}>
    //     <BrowserRouter><App /></BrowserRouter>
    //   </ThemeProvider>
    return MaterialApp(
      title: _mainTitle,
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
      ),
      // `darkTheme` = the stylesheet applied when the OS is in dark mode.
      // `ColorScheme.fromSeed(..., brightness: Brightness.dark)` derives a
      // full dark palette from the same seed — same brand feel, dark surface.
      // Equivalent to a CSS `@media (prefers-color-scheme: dark) { ... }` block.
      darkTheme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.blue,
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
      ),
      // Live value from the provider — switches theme without a hot restart.
      themeMode: themeMode,
      home: const HomeScreen(),
    );
  }
}

// =============================================================================
// HOME SCREEN
//
// `ConsumerWidget` extends `StatelessWidget` with one extra parameter: `WidgetRef ref`.
// `ref` is your handle to the Riverpod store — equivalent to calling:
//   const appState = useAppStore()          // Zustand
//   const appState = useSelector(s => s)    // Redux
//
// Rule of thumb:
//   No state needed?              → StatelessWidget
//   Global state needed?          → ConsumerWidget       (this file)
//   Local UI state needed?        → StatefulWidget
//   Both local + global needed?   → ConsumerStatefulWidget (see _SearchControls)
// =============================================================================
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // `ref.watch(appProvider)` subscribes this widget to ALL AppState changes.
    // Every time `state =` is called inside AppNotifier, this widget re-renders.
    //
    // This is EXACTLY like:
    //   const appState = useAppStore()           (Zustand — full store)
    //   const appState = useSelector(s => s.app) (Redux)
    final appState = ref.watch(appProvider);

    // `DefaultTabController` manages the selected-tab index and propagates it
    // to all descendant `TabBar` and `TabBarView` widgets via InheritedWidget —
    // equivalent to wrapping children in a React context:
    //   <TabContext.Provider value={{ tab, setTab }}>
    //     {children}
    //   </TabContext.Provider>
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          backgroundColor: Theme.of(context).colorScheme.primary,
          title: Row(
            children: [
              Text(
                _mainTitle,
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onPrimary,
                  fontWeight: FontWeight.bold,
                  fontSize: 20,
                ),
              ),
              const Spacer(), // pushes button to the right
              const _ThemeModeButton(),
            ],
          ),
          // Stack the stats bar + tab bar inside the AppBar bottom slot.
          // Heights use named constants so the value is defined in one place.
          // `kTextTabBarHeight` (46) is Flutter's built-in TabBar height constant.
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(_kStatsBarHeight + kTextTabBarHeight),
            child: Column(
              children: [
                _StatsBar(appState: appState),
                TabBar(
                  labelColor: Theme.of(context).colorScheme.onPrimary,
                  unselectedLabelColor: Theme.of(context)
                      .colorScheme
                      .onPrimary
                      .withAlpha(153), // 60% opacity
                  indicatorColor: Theme.of(context).colorScheme.onPrimary,
                  tabs: const [
                    Tab(icon: Icon(Icons.explore), text: 'Explore'),
                    Tab(icon: Icon(Icons.history), text: 'History'),
                  ],
                ),
              ],
            ),
          ),
        ),
        // `LayoutBuilder` captures Scaffold's tight body constraints — that
        // lets us clamp the width to _kMaxContentWidth while passing the exact
        // height down to TabBarView (which needs a tight, bounded height to
        // lay out its PageView children correctly).
        // Equivalent to CSS: .body { max-width: 1300px; margin: 0 auto; height: 100%; }
        body: LayoutBuilder(
          builder: (context, constraints) => Align(
            alignment: Alignment.topCenter,
            child: SizedBox(
              width: constraints.maxWidth.clamp(0.0, _kMaxContentWidth),
              height: constraints.maxHeight,
              child: TabBarView(
                children: [
                  // Tab 0 — Explore
                  Column(
                    children: [
                      _SearchControls(),
                      const Divider(height: 1),
                      Expanded(
                        child: _ResultsView(appState: appState),
                      ),
                    ],
                  ),
                  // Tab 1 — History
                  _HistoryView(history: appState.history),
                ],
              ),
            ),
          ),
        ),
        // `bottomNavigationBar` is a Scaffold slot that sits below the body.
        // Scaffold handles safe-area insets and keyboard avoidance automatically.
        // Equivalent to a sticky `position: fixed; bottom: 0` footer in CSS.
        bottomNavigationBar: const _Footer(),
      ),
    );
  }
}

// =============================================================================
// STATS BAR — pure display widget
//
// A StatelessWidget (no state, no actions) that shows the tracked metrics.
// The underscore prefix makes this class private to this file —
// equivalent to a non-exported component in a TypeScript module.
// =============================================================================
class _StatsBar extends StatelessWidget {
  final AppState appState;

  const _StatsBar({required this.appState});

  @override
  Widget build(BuildContext context) {
    // `Semantics` is Flutter's equivalent of ARIA attributes in HTML/React:
    //   <div role="region" aria-label="Statistics dashboard...">
    //
    // `container: true` creates a distinct semantic boundary — similar to
    // adding `role="region"` to a <div>, which screen readers treat as a
    // separate navigable landmark.
    return Semantics(
      label: 'Statistics dashboard. '
          'Total API calls made: ${appState.apiCallCount}. '
          'Articles opened this session: ${appState.history.length}.',
      container: true,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        color: Theme.of(context).colorScheme.primaryContainer,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            // `ExcludeSemantics` hides a subtree from accessibility tools.
            // We already described both values in the parent `Semantics` label,
            // so individual Text widgets don't need to be read out separately.
            // HTML equivalent: `aria-hidden="true"`
            ExcludeSemantics(
              child: Text(
                'API Calls: ${appState.apiCallCount}',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Theme.of(context).colorScheme.onPrimaryContainer,
                ),
              ),
            ),
            ExcludeSemantics(
              child: Text(
                'History: ${appState.history.length}',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Theme.of(context).colorScheme.onPrimaryContainer,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// =============================================================================
// SEARCH CONTROLS
//
// Uses `ConsumerStatefulWidget` + `ConsumerState` because it needs BOTH:
//   • Local UI state: TextEditingController (equivalent to useRef + useState)
//   • Global store access: ref.watch / ref.read (equivalent to useAppStore)
//
// React equivalent of this combination:
//   const SearchControls = () => {
//     const [location, setLocation] = useState('');    // local state
//     const { fetchByCity } = useAppStore();           // global store
//     const inputRef = useRef<HTMLInputElement>(null);
//     ...
//   }
// =============================================================================
class _SearchControls extends ConsumerStatefulWidget {
  @override
  ConsumerState<_SearchControls> createState() => _SearchControlsState();
}

// `AutomaticKeepAliveClientMixin` tells the parent PageView (used internally
// by TabBarView) to keep this State alive even when the tab is off-screen.
//
// Without it, switching tabs calls dispose() on _SearchControlsState —
// destroying the TextEditingController and its text — then recreates it
// from scratch when you come back. Equivalent to a React component being
// *unmounted* vs kept mounted with `display: none`.
//
// With it, the State object is preserved in memory and `build()` is never
// called with a fresh controller. The one required contract: you MUST call
// `super.build(context)` at the top of build() so the mixin can send its
// keep-alive signal up to the PageView.
class _SearchControlsState extends ConsumerState<_SearchControls>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  // `TextEditingController` manages a TextField's text value.
  // It combines `useRef<HTMLInputElement>` + controlled `value` state in React.
  // Read the current text with `_controller.text`.
  final TextEditingController _controller = TextEditingController();

  // `initState()` = React's `useEffect(() => { ... }, [])` with an empty
  // dependency array — runs once after the widget is first inserted.
  // We attach a listener so the clear button appears/disappears as the user
  // types. `setState(() {})` triggers a rebuild without changing any value —
  // the new `_controller.text` is read during the next `build()` call.
  @override
  void initState() {
    super.initState();
    _controller.addListener(() => setState(() {}));
  }

  // `dispose()` = React's useEffect cleanup function:
  //   useEffect(() => { return () => controller.dispose(); }, [])
  //
  // Always dispose controllers to avoid memory leaks when the widget is removed.
  @override
  void dispose() {
    _controller.dispose();
    super.dispose(); // always call super.dispose() last
  }

  // ---------------------------------------------------------------------------
  // PATH A: GPS location → fetch articles
  // ---------------------------------------------------------------------------
  Future<void> _handleLocationPressed() async {
    // Check if the device's location services (GPS) are enabled at the OS level.
    // This is separate from app-level permissions.
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      _showSnackBar(
          'Location services are disabled. Enable GPS in device settings.');
      return; // `return` inside a Future = `return` inside an async JS function
    }

    // Check the current permission state before requesting
    LocationPermission permission = await Geolocator.checkPermission();

    // If denied, prompt the user with the OS permission dialog
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }

    // If still denied (or permanently denied), fall back gracefully
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      _showSnackBar('Location permission denied. Use location search instead.');
      return;
    }

    // Get GPS coordinates — `LocationAccuracy.low` is city-level precision,
    // faster and less battery-intensive than high accuracy GPS fix.
    final position = await Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.low,
    );

    // Dispatch the action — equivalent to:
    //   dispatch(fetchByCoordinates(lat, lng))   (Redux)
    //   useAppStore.getState().fetchByCoordinates(lat, lng)  (Zustand)
    //
    // Use `ref.read` (not `ref.watch`) inside event handlers.
    // `ref.watch` is for the build() method only — like calling hooks in JSX.
    // `ref.read` is for outside build() — like calling store methods in onClick.
    await ref.read(appProvider.notifier).fetchByCoordinates(
          position.latitude,
          position.longitude,
        );
  }

  // ---------------------------------------------------------------------------
  // PATH B: Location name → geocode → fetch articles
  // ---------------------------------------------------------------------------
  Future<void> _handleLocationSearch() async {
    final location = _controller.text.trim();
    if (location.isEmpty) {
      _showSnackBar('Please enter a location first.');
      return;
    }
    await ref.read(appProvider.notifier).fetchByCity(location);
  }

  void _showSnackBar(String message) {
    // `ScaffoldMessenger` is the Flutter way to show floating toasts/snackbars.
    // Equivalent to calling a toast library like `react-hot-toast` or `sonner`.
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 4),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Required by AutomaticKeepAliveClientMixin — sends the keep-alive signal
    // up to the PageView. Must be called before returning any widget.
    super.build(context);

    // Memoized selector — only re-renders this widget when `isLoading` changes.
    // Equivalent to Zustand's: `const isLoading = useAppStore(s => s.isLoading)`
    // or Redux's: `const isLoading = useSelector(s => s.app.isLoading)`
    //
    // Without `.select()`, the widget would rebuild on every state change.
    final isLoading = ref.watch(appProvider.select((s) => s.isLoading));

    // `Center` + `ConstrainedBox` limits the form to a readable max width on
    // tablet and desktop — equivalent to a CSS rule:
    //   .search-form { max-width: 480px; margin: 0 auto; }
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // ---------------------------------------------------------------
              // PATH A BUTTON — "Use My Location"
              // ---------------------------------------------------------------
              // `Semantics` with `button: true` = `role="button"` + `aria-label` in HTML.
              // Screen readers will announce: "Use my current GPS location..., button"
              Semantics(
                button: true,
                label:
                    'Use my current GPS location to find nearby Wikipedia articles',
                child: ElevatedButton.icon(
                  // `key` is a test selector — like `data-testid="location-button"` in React Testing Library.
                  // The integration test uses `find.byKey(const Key('location_button'))` to find this widget.
                  key: const Key('location_button'),
                  // Setting `onPressed: null` disables the button — equivalent to the HTML `disabled` attribute.
                  onPressed: isLoading ? null : _handleLocationPressed,
                  icon: const Icon(Icons.location_on),
                  label: const Text('Use My Location'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Theme.of(context).colorScheme.primary,
                    foregroundColor: Theme.of(context).colorScheme.onPrimary,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                ),
              ),

              const SizedBox(height: 12),

              // Divider with "or" label — a common UI pattern for dual-path forms
              const Row(
                children: [
                  Expanded(child: Divider()),
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: 8),
                    child: Text('or', style: TextStyle(color: Colors.grey)),
                  ),
                  Expanded(child: Divider()),
                ],
              ),

              const SizedBox(height: 12),

              // ---------------------------------------------------------------
              // PATH B INPUT — Location text field
              //
              // `TextField` = <input type="text" /> in HTML.
              // `TextEditingController` provides the controlled-component pattern —
              // equivalent to `value={location} onChange={e => setLocation(e.target.value)}`
              // ---------------------------------------------------------------
              Semantics(
                // `textField: true` = `role="textbox"` for screen readers
                textField: true,
                label: 'Location text input',
                child: TextField(
                  key: const Key(
                      'city_input'), // test selector → data-testid="city-input"
                  controller: _controller,
                  enabled: !isLoading,
                  decoration: InputDecoration(
                    labelText: 'Enter a location',
                    hintText: 'e.g. Paris, Tokyo, New York',
                    prefixIcon: const Icon(Icons.location_city),
                    border: const OutlineInputBorder(),
                    // Show a clear (×) button only when there is text.
                    // Equivalent to a controlled <input> with a conditional
                    // clear icon: {value && <button onClick={() => setValue('')} />}
                    suffixIcon: _controller.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear),
                            tooltip: 'Clear',
                            onPressed: _controller.clear,
                          )
                        : null,
                  ),
                  // `onSubmitted` fires when the user presses Enter/Done on the keyboard.
                  // Equivalent to: `onKeyDown={e => e.key === 'Enter' && handleSearch()}`
                  onSubmitted:
                      isLoading ? null : (_) => _handleLocationSearch(),
                  textInputAction: TextInputAction.search,
                ),
              ),

              const SizedBox(height: 12),

              // ---------------------------------------------------------------
              // PATH B BUTTON — "Search Location"
              // ---------------------------------------------------------------
              Semantics(
                button: true,
                label:
                    'Search for Wikipedia articles near the entered location',
                child: ElevatedButton(
                  key: const Key('search_button'), // test selector
                  onPressed: isLoading ? null : _handleLocationSearch,
                  child: const Text('Search Location'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// =============================================================================
// RESULTS VIEW — pure display widget
//
// Renders one of four states (a state machine pattern):
//   1. isLoading → spinner
//   2. error     → error message
//   3. empty     → prompt to search
//   4. articles  → responsive list (1 col) or grid (2–3 cols)
// =============================================================================
class _ResultsView extends StatelessWidget {
  final AppState appState;

  const _ResultsView({required this.appState});

  @override
  Widget build(BuildContext context) {
    // ---- STATE 1: Loading ------------------------------------------------
    // Equivalent to: if (isLoading) return <CircularProgress />
    if (appState.isLoading) {
      return Center(
        child: Semantics(
          liveRegion: true,
          label: 'Loading Wikipedia articles, please wait',
          child: const CircularProgressIndicator(),
        ),
      );
    }

    // ---- STATE 2: Error --------------------------------------------------
    if (appState.error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Semantics(
            liveRegion: true,
            label: 'Error: ${appState.error}',
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.error_outline, color: Colors.red, size: 48),
                const SizedBox(height: 12),
                // `appState.error!` — the `!` is Dart's non-null assertion.
                // We already confirmed `error != null` above, so this is safe.
                // Equivalent to TypeScript's `appState.error!` (non-null assertion).
                Text(
                  appState.error!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.red, fontSize: 15),
                ),
              ],
            ),
          ),
        ),
      );
    }

    // ---- STATE 3: Empty (no search yet) ----------------------------------
    if (appState.articles.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Semantics(
            label:
                'No articles yet. Use the location button or enter a location to search.',
            child: const Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.travel_explore, size: 72, color: Colors.grey),
                SizedBox(height: 16),
                Text(
                  'Search a location to discover\nnearby Wikipedia articles.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey, fontSize: 16),
                ),
              ],
            ),
          ),
        ),
      );
    }

    // ---- STATE 4: Articles list / grid -----------------------------------
    // `LayoutBuilder` provides the parent's constraints at build time —
    // equivalent to a CSS container query or a ResizeObserver callback.
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = _columnCount(constraints.maxWidth);
        final articles = appState.articles;

        if (columns == 1) {
          return Semantics(
            label: '${articles.length} Wikipedia articles found nearby.',
            child: ListView.builder(
              itemCount: articles.length,
              itemBuilder: (_, i) => _ArticleCard(article: articles[i]),
            ),
          );
        }

        return Semantics(
          label: '${articles.length} Wikipedia articles found nearby.',
          child: GridView.builder(
            padding: const EdgeInsets.all(8),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: columns,
              childAspectRatio: 3.5,
              crossAxisSpacing: 4,
              mainAxisSpacing: 4,
            ),
            itemCount: articles.length,
            itemBuilder: (_, i) =>
                _ArticleCard(article: articles[i], compact: true),
          ),
        );
      },
    );
  }
}

// =============================================================================
// ARTICLE CARD — individual list/grid item
//
// `ConsumerWidget` because it needs to dispatch `addToHistory` to the store
// AND read `history` to show a "visited" indicator.
// =============================================================================
class _ArticleCard extends ConsumerWidget {
  final Article article;
  // `compact` = true when rendered inside a GridView cell.
  // Reduces margins and clips the title to one line so the card fits the
  // fixed grid cell height — equivalent to a CSS variant class:
  //   .card--compact { margin: 2px 4px; }
  //   .card--compact .title { white-space: nowrap; overflow: hidden; text-overflow: ellipsis; }
  final bool compact;

  const _ArticleCard({required this.article, this.compact = false});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Memoized selector: only re-renders this card when THIS article's visited
    // status changes — not on every state update.
    //
    // Zustand equivalent:
    //   const isVisited = useAppStore(s => s.history.includes(article.title))
    //
    // `.select()` is Riverpod's equivalent of a memoized selector in Reselect /
    // Zustand's `useStore(selector)`. It prevents unnecessary re-renders.
    final isVisited = ref.watch(
      appProvider.select((s) => s.history.contains(article.title)),
    );

    return Semantics(
      // Compose a rich accessible label for each card — equivalent to:
      //   aria-label={`${title}. ${dist}m away. ${visited ? 'Visited.' : 'Tap to open.'}`}
      label: '${article.title}. '
          '${article.dist.toStringAsFixed(0)} metres away. '
          '${isVisited ? 'Already visited.' : 'Tap to open in browser.'}',
      button: true,
      child: Card(
        margin: EdgeInsets.symmetric(
          horizontal: compact ? 4 : 12,
          vertical: compact ? 2 : 5,
        ),
        elevation: isVisited ? 0 : 2,
        // Tint visited cards to give visual feedback — like a `:visited` CSS pseudo-class
        color: isVisited
            ? Theme.of(context).colorScheme.surfaceContainerHighest
            : null,
        child: ListTile(
          leading: CircleAvatar(
            backgroundColor:
                isVisited ? Colors.grey : Theme.of(context).colorScheme.primary,
            child: Icon(Icons.article,
                color: Theme.of(context).colorScheme.onPrimary, size: 20),
          ),
          title: Text(
            article.title,
            maxLines: compact ? 1 : 2,
            overflow: compact ? TextOverflow.ellipsis : TextOverflow.visible,
            style: TextStyle(
              fontWeight: FontWeight.w600,
              color: isVisited
                  ? Theme.of(context)
                      .colorScheme
                      .onSurface
                      .withValues(alpha: 0.5)
                  : null,
            ),
          ),
          subtitle: Text(
            '${article.dist.toStringAsFixed(0)} m away',
            style: const TextStyle(fontSize: 12),
          ),
          trailing: isVisited
              ? const Icon(Icons.check_circle, color: Colors.green, size: 20)
              : const Icon(Icons.open_in_browser, size: 20),
          onTap: () async {
            // 1. Add to session history — fire-and-forget dispatch
            ref.read(appProvider.notifier).addToHistory(article.title);

            // 2. Launch the Wikipedia article in the default browser
            final uri = Uri.parse(article.url);

            if (await canLaunchUrl(uri)) {
              await launchUrl(uri, mode: LaunchMode.externalApplication);
            } else {
              // IMPORTANT: After any `await`, the widget may have been unmounted.
              // `context.mounted` guards against calling `ScaffoldMessenger.of(context)`
              // on a disposed widget — equivalent to checking `isMounted` in older
              // React class components, or the AbortController pattern in hooks.
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Could not open the article.')),
                );
              }
            }
          },
        ),
      ),
    );
  }
}

// =============================================================================
// HISTORY VIEW — tab showing all previously visited articles
//
// `StatelessWidget` is sufficient here because all the data it needs
// (`history`) is passed in as a constructor parameter — no store access needed.
// The parent (HomeScreen) already watches the store and passes the slice down,
// which is the same prop-drilling pattern common in React.
// =============================================================================
class _HistoryView extends StatelessWidget {
  final List<String> history;

  const _HistoryView({required this.history});

  @override
  Widget build(BuildContext context) {
    // ---- Empty state -------------------------------------------------------
    if (history.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Semantics(
            label: 'No articles visited yet. Open one from the Explore tab.',
            child: const Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.history, size: 72, color: Colors.grey),
                SizedBox(height: 16),
                Text(
                  'No articles visited yet.\nOpen one from the Explore tab.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey, fontSize: 16),
                ),
              ],
            ),
          ),
        ),
      );
    }

    // ---- Non-empty: responsive list / grid --------------------------------
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = _columnCount(constraints.maxWidth);
        final items = history.reversed.toList();

        if (columns == 1) {
          return Semantics(
            label: '${history.length} visited articles.',
            child: ListView.builder(
              itemCount: items.length,
              itemBuilder: (_, i) => _HistoryCard(title: items[i]),
            ),
          );
        }

        return Semantics(
          label: '${history.length} visited articles.',
          child: GridView.builder(
            padding: const EdgeInsets.all(8),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: columns,
              childAspectRatio: 3.5,
              crossAxisSpacing: 4,
              mainAxisSpacing: 4,
            ),
            itemCount: items.length,
            itemBuilder: (_, i) => _HistoryCard(title: items[i], compact: true),
          ),
        );
      },
    );
  }
}

// =============================================================================
// HISTORY CARD — individual visited-article item
//
// History stores only article titles (strings), not full Article objects.
// We reconstruct a valid Wikipedia URL using `Uri(pathSegments: ...)` so Dart
// percent-encodes the title automatically:
//   "New York" → https://en.wikipedia.org/wiki/New%20York
//
// TypeScript equivalent:
//   const url = `https://en.wikipedia.org/wiki/${encodeURIComponent(title)}`;
// =============================================================================
class _HistoryCard extends StatelessWidget {
  final String title;
  final bool compact;

  const _HistoryCard({required this.title, this.compact = false});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: '$title. Tap to open in browser.',
      button: true,
      child: Card(
        margin: EdgeInsets.symmetric(
          horizontal: compact ? 4 : 12,
          vertical: compact ? 2 : 5,
        ),
        child: ListTile(
          leading: CircleAvatar(
            backgroundColor: Theme.of(context).colorScheme.secondary,
            child: Icon(Icons.history,
                color: Theme.of(context).colorScheme.onSecondary, size: 20),
          ),
          title: Text(
            title,
            maxLines: compact ? 1 : 2,
            overflow: compact ? TextOverflow.ellipsis : TextOverflow.visible,
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
          trailing: const Icon(Icons.open_in_browser, size: 20),
          onTap: () async {
            // `Uri(pathSegments: ['wiki', title])` percent-encodes each segment.
            // Equivalent to: `new URL('/wiki/' + encodeURIComponent(title), base)` in JS.
            final uri = Uri(
              scheme: 'https',
              host: 'en.wikipedia.org',
              pathSegments: ['wiki', title],
            );

            if (await canLaunchUrl(uri)) {
              await launchUrl(uri, mode: LaunchMode.externalApplication);
            } else {
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Could not open the article.')),
                );
              }
            }
          },
        ),
      ),
    );
  }
}

// =============================================================================
// FOOTER — shown at the bottom of the results scroll
// =============================================================================
class _Footer extends StatelessWidget {
  const _Footer();

  @override
  Widget build(BuildContext context) {
    // NOTE: Do NOT wrap in Center here — bottomNavigationBar gives loose height
    // constraints, and Center expands to fill all of them, leaving the body 0px tall.
    // textAlign: TextAlign.center achieves the same visual result safely.
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Text(
        'made by Ivana',
        textAlign: TextAlign.center,
        style: TextStyle(
          color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.4),
          fontSize: 14,
        ),
      ),
    );
  }
}

// =============================================================================
// THEME MODE BUTTON — AppBar toggle (system → light → dark → system → …)
//
// `ConsumerWidget` because it needs to both READ the current mode (to pick the
// right icon) and WRITE a new mode (on tap).
//
// The three-state cycle mirrors a common web pattern:
//   const [theme, setTheme] = useState<'system'|'light'|'dark'>('system')
//   const nextTheme = { system: 'light', light: 'dark', dark: 'system' }[theme]
// =============================================================================
class _ThemeModeButton extends ConsumerWidget {
  const _ThemeModeButton();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mode = ref.watch(themeModeProvider);

    // Map each mode to the icon that represents it and the tooltip explaining
    // what tapping will do next.
    final (IconData icon, String tooltip) = switch (mode) {
      ThemeMode.system => (Icons.brightness_auto, 'Switch to light theme'),
      ThemeMode.light => (Icons.light_mode, 'Switch to dark theme'),
      ThemeMode.dark => (Icons.dark_mode, 'Follow system theme'),
    };

    // Cycle: system → light → dark → system
    final ThemeMode next = switch (mode) {
      ThemeMode.system => ThemeMode.light,
      ThemeMode.light => ThemeMode.dark,
      ThemeMode.dark => ThemeMode.system,
    };

    return IconButton(
      icon: Icon(icon, color: Theme.of(context).colorScheme.onPrimary),
      tooltip: tooltip,
      // `ref.read` (not `ref.watch`) inside event handlers — same rule as always.
      // Writing `.state =` on a StateProvider notifier is like calling Zustand's
      // `set()`: all watchers of `themeModeProvider` re-render immediately.
      onPressed: () => ref.read(themeModeProvider.notifier).state = next,
    );
  }
}
