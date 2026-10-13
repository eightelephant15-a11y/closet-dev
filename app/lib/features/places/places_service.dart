import 'package:dio/dio.dart';
import 'package:stylist/core/network/api_client.dart';

/// Place autocomplete seam. Returns city names only: no coordinates are
/// requested or stored. Swap in a real provider behind this interface later.
abstract class PlacesService {
  Future<List<String>> autocomplete(String query);
}

class MockPlacesService implements PlacesService {
  static const cities = [
    'New York, NY',
    'Los Angeles, CA',
    'Chicago, IL',
    'Houston, TX',
    'Austin, TX',
    'Seattle, WA',
    'San Francisco, CA',
    'Boston, MA',
    'Denver, CO',
    'Miami, FL',
  ];

  @override
  Future<List<String>> autocomplete(String query) async {
    final q = query.trim().toLowerCase();
    if (q.length < 2) return [];
    return cities.where((c) => c.toLowerCase().contains(q)).take(5).toList();
  }
}

class HttpPlacesService implements PlacesService {
  HttpPlacesService(this._dio);
  final Dio _dio;

  @override
  Future<List<String>> autocomplete(String query) async {
    if (query.trim().length < 2) return [];
    final res = await guarded(
      () => _dio.get<List<dynamic>>(
        '/v1/places/autocomplete',
        queryParameters: {'q': query},
      ),
    );
    return res.data!.cast<String>();
  }
}
