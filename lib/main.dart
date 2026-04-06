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
//               └─ bottomNavigationBar: _Footer  ← 'by Ivana', always visible
// =============================================================================

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:url_launcher/url_launcher.dart';

import 'api/api_service.dart';
import 'state/app_state.dart';

const double _kMaxContentWidth = 1300;
// Height of the stats bar strip shown between the toolbar and the tab bar.
const double _kStatsBarHeight = 32.0;
const String _kMainTitle = "Wikipedia Explorer";
// Brand color for theme seed — compile-time constant like #008080 in CSS
const Color _kBrandColor = Colors.teal;

int _columnCount(double width) {
  if (width >= 1024) return 3;
  if (width >= 600) return 2;
  return 1;
}

// =============================================================================
// ENTRY POINT
// =============================================================================
void main() {
  WidgetsFlutterBinding.ensureInitialized();

  runApp(
    const ProviderScope(
      child: WikipediaExplorerApp(),
    ),
  );
}

// =============================================================================
// THEME MODE PROVIDER
// =============================================================================
final themeModeProvider = StateProvider<ThemeMode>((ref) => ThemeMode.system);

// =============================================================================
// ROOT APP WIDGET
// =============================================================================
class WikipediaExplorerApp extends ConsumerWidget {
  const WikipediaExplorerApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeModeProvider);
    return MaterialApp(
      title: _kMainTitle,
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: _kBrandColor),
        useMaterial3: true,
      ),
      darkTheme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: _kBrandColor,
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
      ),
      themeMode: themeMode,
      home: const HomeScreen(),
    );
  }
}

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final appState = ref.watch(appProvider);

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          backgroundColor: Theme.of(context).colorScheme.primary,
          title: Row(
            children: [
              Text(
                _kMainTitle,
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
          bottom: PreferredSize(
            preferredSize:
                const Size.fromHeight(_kStatsBarHeight + kTextTabBarHeight),
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
        bottomNavigationBar: const _Footer(),
      ),
    );
  }
}

// =============================================================================
// STATS BAR — pure display widget
// =============================================================================
class _StatsBar extends StatelessWidget {
  final AppState appState;

  const _StatsBar({required this.appState});

  @override
  Widget build(BuildContext context) {
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
// Uses `ConsumerStatefulWidget` + `ConsumerState` because it needs BOTH
// =============================================================================
class _SearchControls extends ConsumerStatefulWidget {
  @override
  ConsumerState<_SearchControls> createState() => _SearchControlsState();
}

class _SearchControlsState extends ConsumerState<_SearchControls>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  final TextEditingController _controller = TextEditingController();

  @override
  void initState() {
    super.initState();
    _controller.addListener(() => setState(() {}));
  }

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

    final isLoading = ref.watch(appProvider.select((s) => s.isLoading));

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
              Semantics(
                button: true,
                label:
                    'Use my current GPS location to find nearby Wikipedia articles',
                child: ElevatedButton.icon(
                  key: const Key('location_button'),
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
              // ---------------------------------------------------------------
              Semantics(
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
                    suffixIcon: _controller.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear),
                            tooltip: 'Clear',
                            onPressed: _controller.clear,
                          )
                        : null,
                  ),
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
//   4. articles  → responsive list
// =============================================================================
class _ResultsView extends StatelessWidget {
  final AppState appState;

  const _ResultsView({required this.appState});

  @override
  Widget build(BuildContext context) {
    // ---- STATE 1: Loading ------------------------------------------------
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
  final bool compact;

  const _ArticleCard({required this.article, this.compact = false});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isVisited = ref.watch(
      appProvider.select((s) => s.history.contains(article.title)),
    );

    return Semantics(
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
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            'by ',
            style: TextStyle(
              color: Theme.of(context)
                  .colorScheme
                  .onSurface
                  .withValues(alpha: 0.4),
              fontSize: 14,
            ),
          ),
          TextButton(
            onPressed: () => launchUrl(
              Uri.parse('https://github.com/LucySpass'),
              mode: LaunchMode.externalApplication,
            ),
            style: TextButton.styleFrom(
              padding: EdgeInsets.zero,
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: Text(
              'Ivana',
              style: TextStyle(
                fontSize: 14,
                decoration: TextDecoration.underline,
                decorationColor: Theme.of(context).colorScheme.primary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// =============================================================================
// THEME MODE BUTTON — AppBar toggle (system → light → dark → system → …)
//
// `ConsumerWidget` because it needs to both READ the current mode (to pick the
// right icon) and WRITE a new mode (on tap).
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
      key: const Key(
          'theme_mode_button'), // test selector → find.byKey(const Key('theme_mode_button'))
      icon: Icon(icon, color: Theme.of(context).colorScheme.onPrimary),
      tooltip: tooltip,
      onPressed: () => ref.read(themeModeProvider.notifier).state = next,
    );
  }
}
