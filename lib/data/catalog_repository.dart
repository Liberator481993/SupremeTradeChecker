import 'dart:async';

import 'package:http/http.dart' as http;

import '../models/catalog_item.dart';
import 'catalog_database.dart';
import 'supreme_values_parser.dart';

class CatalogRefreshReport {
  const CatalogRefreshReport({
    required this.itemCount,
    required this.categoryCount,
    required this.fetchedAt,
    required this.sourceUpdatedLabel,
  });

  final int itemCount;
  final int categoryCount;
  final DateTime fetchedAt;
  final String sourceUpdatedLabel;
}

class CatalogRepository {
  CatalogRepository({
    CatalogDatabase? database,
    http.Client? client,
  })  : _database = database ?? CatalogDatabase.instance,
        _client = client ?? http.Client();

  static const categories = [
    'sets',
    'uniques',
    'evos',
    'ancients',
    'vintages',
    'chromas',
    'godlies',
    'legendaries',
    'rares',
    'uncommons',
    'commons',
    'pets',
    'misc',
    'untradables',
  ];

  static const _baseUrl = 'https://www.supremevalues.com/mm2';
  final CatalogDatabase _database;
  final http.Client _client;

  Future<List<CatalogItem>> loadItems() => _database.getAllItems();

  Future<int> itemCount() => _database.countItems();

  Future<String?> lastFetchedAt() =>
      _database.readMetadata('last_fetched_at');

  Future<String?> sourceUpdatedLabel() =>
      _database.readMetadata('source_updated_label');

  List<CatalogItem> search(
    List<CatalogItem> source,
    String query, {
    int limit = 8,
  }) {
    final normalized = CatalogItem.normalize(query);
    if (normalized.length < 2) return const [];

    final matches = source.where((item) {
      final name = CatalogItem.normalize(item.name);
      if (name.contains(normalized)) return true;
      return item.aliases.any(
        (alias) => CatalogItem.normalize(alias).contains(normalized),
      );
    }).take(limit);
    return matches.toList(growable: false);
  }

  List<CatalogItem> exactMatches(
    List<CatalogItem> source,
    String input,
  ) {
    final normalized = CatalogItem.normalize(input);
    if (normalized.isEmpty) return const [];

    return source.where((item) {
      if (CatalogItem.normalize(item.name) == normalized) return true;
      return item.aliases.any(
        (alias) => CatalogItem.normalize(alias) == normalized,
      );
    }).toList(growable: false);
  }

  Future<CatalogRefreshReport> refresh() async {
    final oldCount = await _database.countItems();
    final freshById = <String, CatalogItem>{};
    var successfulCategories = 0;
    var firstSourceLabel = '';

    for (var offset = 0; offset < categories.length; offset += 3) {
      final batch = categories.skip(offset).take(3).toList(growable: false);
      final pages = await Future.wait(batch.map(_downloadCategory));

      for (final page in pages) {
        successfulCategories++;
        if (firstSourceLabel.isEmpty &&
            (page.sourceUpdatedLabel?.isNotEmpty ?? false)) {
          firstSourceLabel = page.sourceUpdatedLabel!;
        }
        for (final item in page.items) {
          freshById[item.id] = item;
        }
      }
    }

    final freshItems = freshById.values.toList(growable: false);
    if (successfulCategories != categories.length) {
      throw StateError('Not all catalogue categories were downloaded.');
    }
    if (freshItems.length < 50) {
      throw StateError(
        'The downloaded catalogue looks incomplete (${freshItems.length} items). '
        'The existing local database was not changed.',
      );
    }
    if (oldCount > 0 && freshItems.length < oldCount * 0.70) {
      throw StateError(
        'The new catalogue is much smaller than the saved catalogue. '
        'The existing local database was not changed.',
      );
    }

    final fetchedAt = DateTime.now().toUtc();
    final sourceLabel =
        firstSourceLabel.isEmpty ? 'Not provided by source' : firstSourceLabel;
    await _database.replaceAll(
      items: freshItems,
      fetchedAt: fetchedAt.toIso8601String(),
      sourceUpdatedLabel: sourceLabel,
    );

    return CatalogRefreshReport(
      itemCount: freshItems.length,
      categoryCount: successfulCategories,
      fetchedAt: fetchedAt,
      sourceUpdatedLabel: sourceLabel,
    );
  }

  Future<ParsedCatalogPage> _downloadCategory(String category) async {
    final uri = Uri.parse('$_baseUrl/$category');
    Object? lastError;

    for (var attempt = 0; attempt < 2; attempt++) {
      try {
        final response = await _client
            .get(
              uri,
              headers: const {
                'User-Agent': 'SupremeTradeChecker/1.0 (manual value catalogue)',
                'Accept': 'text/html,application/xhtml+xml',
              },
            )
            .timeout(const Duration(seconds: 25));

        if (response.statusCode != 200) {
          throw HttpExceptionForCatalogue(
            'HTTP ${response.statusCode} while loading $category.',
          );
        }
        if (response.bodyBytes.length < 500) {
          throw HttpExceptionForCatalogue(
            'The $category page was unexpectedly short.',
          );
        }

        final parsed = SupremeValuesParser.parse(response.body, category);
        if (parsed.items.isEmpty) {
          throw HttpExceptionForCatalogue(
            'No catalogue rows were recognised on the $category page.',
          );
        }
        return parsed;
      } catch (error) {
        lastError = error;
        if (attempt == 0) {
          await Future<void>.delayed(const Duration(milliseconds: 500));
        }
      }
    }

    throw StateError(
      'Could not safely refresh "$category": $lastError. '
      'The last saved catalogue has been kept.',
    );
  }

  void dispose() {
    _client.close();
  }
}

class HttpExceptionForCatalogue implements Exception {
  const HttpExceptionForCatalogue(this.message);

  final String message;

  @override
  String toString() => message;
}
