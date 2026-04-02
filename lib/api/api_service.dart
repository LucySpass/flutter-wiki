// =============================================================================
// lib/api/api_service.dart
//
// Contains:
//   1. Article       — the data model (equivalent to a TypeScript interface)
//   2. ApiService    — static async methods for each endpoint
//                      (equivalent to a React Query queryFn / Redux async thunk)
// =============================================================================

// `dart:convert` provides jsonDecode() — the exact equivalent of JSON.parse() in JS.
import 'dart:convert';

// `as http` is an import alias — identical to `import * as http from '...'` in TypeScript.
// We alias it to avoid name collisions and to clarify call-site syntax: `http.get(...)`.
import 'package:http/http.dart' as http;

// =============================================================================
// DATA MODEL: Article
//
// TypeScript equivalent:
//   interface Article {
//     readonly pageid: number;
//     readonly title: string;
//     readonly lat: number;
//     readonly lon: number;
//     readonly dist: number;   // distance in metres from the search point
//     readonly url: string;    // computed getter
//   }
//
// In Dart, `final` on each field is the equivalent of TypeScript's `readonly`.
// There are no plain interfaces in Dart — we use classes instead.
// =============================================================================
class Article {
  final int pageid;
  final String title;
  final double lat;
  final double lon;
  final double dist; // distance in metres from the queried coordinates

  // `get` declares a computed/derived property — identical to a JS getter:
  //   get url() { return `https://en.wikipedia.org/?curid=${this.pageid}`; }
  String get url => 'https://en.wikipedia.org/?curid=$pageid';

  // `const` constructor: all fields are compile-time constants.
  // The `this.field` parameter shorthand is like TypeScript's constructor shorthand:
  //   constructor(readonly pageid: number, readonly title: string, ...) {}
  // `required` = the parameter has no default value and must always be provided.
  const Article({
    required this.pageid,
    required this.title,
    required this.lat,
    required this.lon,
    required this.dist,
  });

  // ---------------------------------------------------------------------------
  // Factory constructor — the Dart equivalent of a static factory method:
  //   static fromJSON(json: Record<string, unknown>): Article {
  //     return new Article({ pageid: json.pageid, ... });
  //   }
  //
  // `factory` means this constructor may return a cached/existing instance
  // (useful for singletons or object pools), but here we use it purely as
  // a named constructor pattern for JSON deserialization.
  //
  // `Map<String, dynamic>` is Dart's equivalent of `Record<string, unknown>`.
  // `dynamic` is Dart's `any` — it bypasses static type-checking.
  // We immediately cast each value (e.g., `as int`) to restore type safety.
  // ---------------------------------------------------------------------------
  factory Article.fromJson(Map<String, dynamic> json) {
    return Article(
      pageid: json['pageid'] as int,
      title: json['title'] as String,
      // `num` covers both int and double — `.toDouble()` ensures a consistent type.
      // Same as `Number(json.lat)` in JavaScript.
      lat: (json['lat'] as num).toDouble(),
      lon: (json['lon'] as num).toDouble(),
      dist: (json['dist'] as num).toDouble(),
    );
  }

  // `@override` = same as TypeScript's `override` keyword (or just overriding toString).
  // String interpolation `$title` = template literals `${title}` in JS.
  @override
  String toString() =>
      'Article(title: $title, dist: ${dist.toStringAsFixed(0)}m)';
}

// =============================================================================
// API SERVICE
//
// TypeScript/React equivalent:
//   // api.ts
//   export const fetchNearbyArticles = async (lat, lng): Promise<Article[]> => { ... }
//   export const geocodeCity = async (city): Promise<{lat: number, lng: number}> => { ... }
//
// We use static methods here to keep things simple and avoid constructor injection.
// In a larger app you might inject this as a Riverpod Provider for testability.
// =============================================================================
class ApiService {
  // ---------------------------------------------------------------------------
  // fetchNearbyArticles — Wikipedia GeoSearch API
  // Docs: https://www.mediawiki.org/wiki/API:Geosearch
  //
  // TypeScript equivalent:
  //   const url = new URL('https://en.wikipedia.org/w/api.php');
  //   url.searchParams.set('action', 'query');
  //   url.searchParams.set('list', 'geosearch');
  //   url.searchParams.set('gscoord', `${lat}|${lng}`);
  //   ...
  //   const res = await fetch(url.toString());
  //   const data = await res.json();
  //   return data.query.geosearch.map(item => Article.fromJSON(item));
  //
  // In Dart, `Uri.https()` builds and encodes the URL — you never manually
  // concatenate query strings, just like using URLSearchParams in JS.
  // ---------------------------------------------------------------------------
  static Future<List<Article>> fetchNearbyArticles(
    double lat,
    double lng,
  ) async {
    final uri = Uri.https(
      'en.wikipedia.org', // host — no scheme prefix needed here
      '/w/api.php', // path
      {
        // Query params as Map<String, String> — Uri.https() encodes them safely
        'action': 'query',
        'list': 'geosearch',
        'gscoord': '$lat|$lng', // Wikipedia uses pipe-separated lat|lng
        'gsradius': '5000', // search radius in metres (5 km)
        'gslimit': '20', // max number of results
        'format': 'json',
        'origin': '*', // required for CORS when running on the web platform
      },
    );

    // `http.get()` returns `Future<Response>` — same as `fetch(url)` returning Promise<Response>.
    // `await` unwraps the Future, exactly like async/await in JS/TS.
    final response = await http.get(uri);

    // `response.statusCode` = `response.status` in the browser's fetch API
    if (response.statusCode != 200) {
      throw Exception('Wikipedia API error: HTTP ${response.statusCode}');
    }

    // `jsonDecode(response.body)` = `JSON.parse(text)` or `await response.json()` in JS.
    // We cast the result to `Map<String, dynamic>` (i.e., Record<string, unknown>).
    final body = jsonDecode(response.body) as Map<String, dynamic>;

    // Navigate the nested JSON — equivalent to:
    //   const items = (data as any).query.geosearch as any[];
    final geoSearch = body['query']['geosearch'] as List<dynamic>;

    // `.map()` works exactly like JS Array.prototype.map().
    // `.toList()` materialises the lazy Iterable into a concrete List<Article>
    // — equivalent to spreading: `[...items.map(fromJSON)]`
    return geoSearch
        .map((item) => Article.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  // ---------------------------------------------------------------------------
  // geocodeCity — Open-Meteo Geocoding API (no API key required)
  // Docs: https://open-meteo.com/en/docs/geocoding-api
  //
  // TypeScript return type equivalent:
  //   Promise<{ lat: number; lng: number }>
  //
  // Dart 3+ Record type: `({double lat, double lng})`
  // A Record is an anonymous, typed tuple with named fields — like returning
  // a plain object literal `{ lat: 51.5, lng: -0.1 }` from a TS function.
  // ---------------------------------------------------------------------------
  static Future<({double lat, double lng})> geocodeCity(String city) async {
    final uri = Uri.https(
      'geocoding-api.open-meteo.com',
      '/v1/search',
      {
        'name': city,
        'count': '1', // only the top result is needed
        'language': 'en',
        'format': 'json',
      },
    );

    final response = await http.get(uri);

    if (response.statusCode != 200) {
      throw Exception('Geocoding API error: HTTP ${response.statusCode}');
    }

    final body = jsonDecode(response.body) as Map<String, dynamic>;

    // `as List<dynamic>?` — the `?` means the cast may be null.
    // Equivalent to TypeScript: `const results = (body as any).results as any[] | undefined`
    final results = body['results'] as List<dynamic>?;

    if (results == null || results.isEmpty) {
      // Throwing a typed message lets the UI surface a clear error to the user —
      // equivalent to `throw new Error(\`City not found: "${city}"\`)` in TS.
      throw Exception('City not found: "$city". Please check the spelling.');
    }

    final first = results.first as Map<String, dynamic>;

    // Dart 3 Record literal — like returning `{ lat: ..., lng: ... }` in TS.
    // The caller accesses fields via: `coords.lat`, `coords.lng`
    return (
      lat: (first['latitude'] as num).toDouble(),
      lng: (first['longitude'] as num).toDouble(),
    );
  }
}
