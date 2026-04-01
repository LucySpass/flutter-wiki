// =============================================================================
// lib/main.dart — UI Layer
//
// Widget tree overview:
//   ProviderScope                  ← Riverpod root (like Redux <Provider>)
//   └─ WikipediaExplorerApp        ← MaterialApp setup (theme + router)
//      └─ HomeScreen               ← ConsumerWidget (reads global state)
//         ├─ AppBar
//         │  ├─ _StatsBar          ← API call count + history length
//         │  └─ TabBar             ← Explore / History tab switcher
//         └─ TabBarView
//            ├─ [Explore tab]
//            │  ├─ _SearchControls ← GPS button + location text input
//            │  └─ _ResultsView    ← loading / error / article list or grid
//            │     └─ _ArticleCard ← individual list/grid item
//            └─ [History tab]
//               └─ _HistoryView   ← previously visited articles
//                  └─ _HistoryCard ← individual history item
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
// ROOT APP WIDGET
//
// `StatelessWidget` = a pure functional React component with no local state:
//   const WikipediaExplorerApp: React.FC = () => <MaterialApp ... />
//
// `build(BuildContext context)` is the render method / JSX return value.
// `context` provides access to the theme, navigator, locale, etc. —
// similar to React's Context API, but available implicitly everywhere.
// =============================================================================
class WikipediaExplorerApp extends StatelessWidget {
  const WikipediaExplorerApp({super.key});

  @override
  Widget build(BuildContext context) {
    // `MaterialApp` is the root scaffold for a Material Design app.
    // Equivalent to wrapping your app with a Router + ThemeProvider in React:
    //   <ThemeProvider theme={theme}>
    //     <BrowserRouter><App /></BrowserRouter>
    //   </ThemeProvider>
    return MaterialApp(
      title: 'Wikipedia Explorer',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
      ),
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
          title: const Text(
            'Wikipedia Explorer',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
          ),
          // Stack the stats bar + tab bar inside the AppBar bottom slot.
          // PreferredSize height = stats row (32) + TabBar row (46).
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(32 + 46),
            child: Column(
              children: [
                _StatsBar(appState: appState),
                const TabBar(
                  labelColor: Colors.white,
                  unselectedLabelColor: Colors.white70,
                  indicatorColor: Colors.white,
                  tabs: [
                    Tab(icon: Icon(Icons.explore), text: 'Explore'),
                    Tab(icon: Icon(Icons.history), text: 'History'),
                  ],
                ),
              ],
            ),
          ),
        ),
        // `TabBarView` renders the widget for the currently selected tab.
        // Equivalent to a React conditional render driven by state:
        //   {tab === 0 ? <ExploreView /> : <HistoryView />}
        //
        // Unlike a conditional render, TabBarView KEEPS both widgets alive
        // in the widget tree once visited — similar to CSS `display: none`
        // vs truly unmounting a component.
        body: TabBarView(
          children: [
            // Tab 0 — Explore
            Column(
              children: [
                _SearchControls(),
                const Divider(height: 1),
                // `Expanded` tells the Column to give all remaining vertical space to this child.
                // Equivalent to: `flex: 1` or `flex-grow: 1` in CSS flexbox.
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
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            ExcludeSemantics(
              child: Text(
                'History: ${appState.history.length}',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
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
      _showSnackBar('Location services are disabled. Enable GPS in device settings.');
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
                label: 'Use my current GPS location to find nearby Wikipedia articles',
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
                    foregroundColor: Colors.white,
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
                  key: const Key('city_input'), // test selector → data-testid="city-input"
                  controller: _controller,
                  enabled: !isLoading,
                  decoration: const InputDecoration(
                    labelText: 'Enter a location',
                    hintText: 'e.g. Paris, Tokyo, New York',
                    prefixIcon: Icon(Icons.location_city),
                    border: OutlineInputBorder(),
                  ),
                  // `onSubmitted` fires when the user presses Enter/Done on the keyboard.
                  // Equivalent to: `onKeyDown={e => e.key === 'Enter' && handleSearch()}`
                  onSubmitted: isLoading ? null : (_) => _handleLocationSearch(),
                  textInputAction: TextInputAction.search,
                ),
              ),

              const SizedBox(height: 12),

              // ---------------------------------------------------------------
              // PATH B BUTTON — "Search Location"
              // ---------------------------------------------------------------
              Semantics(
                button: true,
                label: 'Search for Wikipedia articles near the entered location',
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
          // `liveRegion: true` tells screen readers to announce this change
          // dynamically — like `aria-live="polite"` in HTML.
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
    // We use the available width to pick the column count.
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = _columnCount(constraints.maxWidth);

        // Single-column on narrow screens → plain ListView.
        // ListView has better scroll defaults and doesn't require a fixed
        // item height — equivalent to a simple CSS `flex-direction: column`.
        if (columns == 1) {
          return Semantics(
            label: '${appState.articles.length} Wikipedia articles found nearby.',
            child: ListView.builder(
              itemCount: appState.articles.length,
              itemBuilder: (context, index) =>
                  _ArticleCard(article: appState.articles[index]),
            ),
          );
        }

        // Multi-column on wider screens → GridView.
        // `SliverGridDelegateWithFixedCrossAxisCount` = CSS Grid:
        //   grid-template-columns: repeat(columns, 1fr);
        //   aspect-ratio: 1 / (1 / childAspectRatio);
        //
        // `compact: true` trims card margins and clips long titles so content
        // fits within the fixed grid cell height.
        return Semantics(
          label: '${appState.articles.length} Wikipedia articles found nearby.',
          child: GridView.builder(
            padding: const EdgeInsets.all(8),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: columns,
              // childAspectRatio = width ÷ height.
              // 3.5 gives ~95–115 px tall cells across common tablet/desktop widths,
              // enough to render the card title + distance without clipping.
              childAspectRatio: 3.5,
              crossAxisSpacing: 4,
              mainAxisSpacing: 4,
            ),
            itemCount: appState.articles.length,
            itemBuilder: (context, index) => _ArticleCard(
              article: appState.articles[index],
              compact: true,
            ),
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
            backgroundColor: isVisited
                ? Colors.grey
                : Theme.of(context).colorScheme.primary,
            child: const Icon(Icons.article, color: Colors.white, size: 20),
          ),
          title: Text(
            article.title,
            maxLines: compact ? 1 : 2,
            overflow: compact ? TextOverflow.ellipsis : TextOverflow.visible,
            style: TextStyle(
              fontWeight: FontWeight.w600,
              color: isVisited
                  ? Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5)
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
    // Reuses the same breakpoints as _ResultsView — keeps behaviour consistent
    // across both tabs.
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = _columnCount(constraints.maxWidth);
        // Show most-recently visited first — like a reverse-chronological feed.
        // `.reversed` returns a lazy Iterable; `.toList()` materialises it.
        // TS equivalent: [...history].reverse()
        final items = history.reversed.toList();

        if (columns == 1) {
          return Semantics(
            label: '${history.length} visited articles.',
            child: ListView.builder(
              itemCount: items.length,
              itemBuilder: (_, index) => _HistoryCard(title: items[index]),
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
            itemBuilder: (_, index) =>
                _HistoryCard(title: items[index], compact: true),
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
            child: const Icon(Icons.history, color: Colors.white, size: 20),
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
