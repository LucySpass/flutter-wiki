// =============================================================================
// lib/api/api_service.dart
//
// Contains:
//   1. Article       — the data model
//   2. ApiService    — static async methods for each endpoint
// =============================================================================

import 'dart:convert';
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
// =============================================================================
class Article {
  final int pageid;
  final String title;
  final double lat;
  final double lon;
  final double dist; // distance in metres from the queried coordinates

  String get url => 'https://en.wikipedia.org/?curid=$pageid';

  const Article({
    required this.pageid,
    required this.title,
    required this.lat,
    required this.lon,
    required this.dist,
  });

  factory Article.fromJson(Map<String, dynamic> json) {
    return Article(
      pageid: json['pageid'] as int,
      title: json['title'] as String,
      lat: (json['lat'] as num).toDouble(),
      lon: (json['lon'] as num).toDouble(),
      dist: (json['dist'] as num).toDouble(),
    );
  }

  @override
  String toString() =>
      'Article(title: $title, dist: ${dist.toStringAsFixed(0)}m)';
}

// =============================================================================
// API SERVICE
//
// We use static methods here to keep things simple and avoid constructor injection.
// =============================================================================
class ApiService {
  // ---------------------------------------------------------------------------
  // fetchNearbyArticles — Wikipedia GeoSearch API
  // Docs: https://www.mediawiki.org/wiki/API:Geosearch
  // ---------------------------------------------------------------------------
  static Future<List<Article>> fetchNearbyArticles(
    double lat,
    double lng,
  ) async {
    final uri = Uri.https(
      'en.wikipedia.org', // host — no scheme prefix needed here
      '/w/api.php', // path
      {
        'action': 'query',
        'list': 'geosearch',
        'gscoord': '$lat|$lng', // Wikipedia uses pipe-separated lat|lng
        'gsradius': '5000', // search radius in metres (5 km)
        'gslimit': '20', // max number of results
        'format': 'json',
        'origin': '*', // required for CORS when running on the web platform
      },
    );

    final response = await http.get(uri);

    if (response.statusCode != 200) {
      throw Exception('Wikipedia API error: HTTP ${response.statusCode}');
    }

    final body = jsonDecode(response.body) as Map<String, dynamic>;
    final geoSearch = body['query']['geosearch'] as List<dynamic>;

    return geoSearch
        .map((item) => Article.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  // ---------------------------------------------------------------------------
  // geocodeCity — Open-Meteo Geocoding API (no API key required)
  // Docs: https://open-meteo.com/en/docs/geocoding-api
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

    final results = body['results'] as List<dynamic>?;

    if (results == null || results.isEmpty) {
      throw Exception('City not found: "$city". Please check the spelling.');
    }

    final first = results.first as Map<String, dynamic>;

    return (
      lat: (first['latitude'] as num).toDouble(),
      lng: (first['longitude'] as num).toDouble(),
    );
  }
}
