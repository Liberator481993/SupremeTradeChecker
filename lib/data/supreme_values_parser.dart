import 'package:html/parser.dart' as html_parser;

import '../models/catalog_item.dart';

class ParsedCatalogPage {
  const ParsedCatalogPage({
    required this.items,
    required this.sourceUpdatedLabel,
  });

  final List<CatalogItem> items;
  final String? sourceUpdatedLabel;
}

class SupremeValuesParser {
  static final RegExp _rowPattern = RegExp(
    r'([^|]{1,100}?)\s+Value\s*-\s*(.*?)\s+Range\s*-\s*(\[[^\]]*\]|N/?A)\s+Stability\s*-\s*(.*?)\s+Demand\s*-\s*(\d+)\s*Rarity\s*-\s*(\d+)',
    caseSensitive: false,
    dotAll: true,
  );

  static final RegExp _untradablePattern = RegExp(
    r'([^|]{1,100}?)\s+Rarity\s*-\s*(\d+|Coming Soon!)(?:\s+Description\s*-\s*(.*?))?(?:\s+Death Effect\s*-\s*(.*?))?\s+Origin\s*-\s*([^|]+)',
    caseSensitive: false,
    dotAll: true,
  );

  static ParsedCatalogPage parse(String source, String category) {
    final document = html_parser.parse(source);
    for (final node in document.querySelectorAll('script, style, noscript')) {
      node.remove();
    }

    final rawText = document.body?.text ?? '';
    final text = rawText
        .replaceAll('\u00a0', ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();

    final updatedMatch = RegExp(
      r'Values Last Updated\s*-\s*(.+?)(?:\s*\/\/|$)',
      caseSensitive: false,
    ).firstMatch(text);
    final sourceUpdatedLabel = updatedMatch?.group(1)?.trim();

    if (category == 'untradables') {
      return ParsedCatalogPage(
        items: _parseUntradables(text),
        sourceUpdatedLabel: sourceUpdatedLabel,
      );
    }

    final byId = <String, CatalogItem>{};
    for (final match in _rowPattern.allMatches(text)) {
      var name = (match.group(1) ?? '').trim();
      name = name.replaceFirst(RegExp(r'^Image:\s*', caseSensitive: false), '');
      name = name.split(RegExp(r'\s+Contains\s*-\s*')).first.trim();
      name = name.replaceAll(RegExp(r'^[-|\s]+|[-|\s]+$'), '').trim();

      if (name.isEmpty || name.length > 80) continue;
      if (name.toLowerCase().contains('stability')) continue;

      final valueText = (match.group(2) ?? '').trim();
      final value = _parseNumber(valueText);
      final range = _parseRange(match.group(3) ?? '');
      final stability = (match.group(4) ?? '').trim();
      final demand = int.tryParse(match.group(5) ?? '');
      final rarity = int.tryParse(match.group(6) ?? '');

      if (demand != null && (demand < 1 || demand > 10)) continue;
      if (rarity != null && (rarity < 1 || rarity > 10)) continue;

      final tailStart = match.end;
      final tailEnd = text.length < tailStart + 220
          ? text.length
          : tailStart + 220;
      final tail = text.substring(tailStart, tailEnd);
      final originMatch = RegExp(
        r'Origin\s*-\s*(.+?)(?:\s+Change in Value|\s+Inv\. Controls|$)',
        caseSensitive: false,
      ).firstMatch(tail);
      final origin = originMatch?.group(1)?.trim();

      final id = CatalogItem.makeId(category, name);
      byId[id] = CatalogItem(
        id: id,
        name: name,
        category: category,
        value: value,
        rangeMin: range.$1,
        rangeMax: range.$2,
        demand: demand,
        rarity: rarity,
        stability: stability.isEmpty ? null : stability,
        origin: origin?.isEmpty == true ? null : origin,
      );
    }

    return ParsedCatalogPage(
      items: byId.values.toList(growable: false),
      sourceUpdatedLabel: sourceUpdatedLabel,
    );
  }

  static List<CatalogItem> _parseUntradables(String text) {
    final byId = <String, CatalogItem>{};
    for (final match in _untradablePattern.allMatches(text)) {
      var name = (match.group(1) ?? '').trim();
      name = name.replaceFirst(RegExp(r'^Image:\s*', caseSensitive: false), '');
      name = name.replaceAll(RegExp(r'^[-|\s]+|[-|\s]+$'), '').trim();
      if (name.isEmpty || name.length > 80) continue;

      final rarityText = match.group(2) ?? '';
      final rarity = int.tryParse(rarityText);
      if (rarity != null && (rarity < 1 || rarity > 10)) continue;
      final origin = match.group(5)?.trim();
      final id = CatalogItem.makeId('untradables', name);

      byId[id] = CatalogItem(
        id: id,
        name: name,
        category: 'untradables',
        value: null,
        rarity: rarity,
        origin: origin?.isEmpty == true ? null : origin,
      );
    }
    return byId.values.toList(growable: false);
  }

  static double? _parseNumber(String input) {
    final match = RegExp(r'^\s*([\d,]+(?:\.\d+)?)').firstMatch(input);
    if (match == null) return null;
    final cleaned = match.group(1)!.replaceAll(',', '');
    final value = double.tryParse(cleaned);
    if (value == null || !value.isFinite || value < 0 || value > 1000000000) {
      return null;
    }
    return value;
  }

  static (double?, double?) _parseRange(String input) {
    final matches = RegExp(r'\d[\d,]*(?:\.\d+)?')
        .allMatches(input)
        .map((m) => double.tryParse(m.group(0)!.replaceAll(',', '')))
        .whereType<double>()
        .toList(growable: false);

    if (matches.length < 2) return (null, null);
    final low = matches[0];
    final high = matches[1];
    if (low > high || low < 0 || high > 1000000000) return (null, null);
    return (low, high);
  }
}
