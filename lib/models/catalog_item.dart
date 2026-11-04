import 'dart:convert';

class CatalogItem {
  const CatalogItem({
    required this.id,
    required this.name,
    required this.category,
    this.value,
    this.rangeMin,
    this.rangeMax,
    this.demand,
    this.rarity,
    this.stability,
    this.origin,
    this.aliases = const [],
  });

  final String id;
  final String name;
  final String category;
  final double? value;
  final double? rangeMin;
  final double? rangeMax;
  final int? demand;
  final int? rarity;
  final String? stability;
  final String? origin;
  final List<String> aliases;

  factory CatalogItem.fromMap(Map<String, Object?> map) {
    final rawAliases = map['aliases_json'] as String? ?? '[]';
    List<String> aliases;
    try {
      aliases = (jsonDecode(rawAliases) as List<dynamic>)
          .whereType<String>()
          .toList(growable: false);
    } catch (_) {
      aliases = const [];
    }

    return CatalogItem(
      id: map['id'] as String,
      name: map['name'] as String,
      category: map['category'] as String,
      value: (map['value'] as num?)?.toDouble(),
      rangeMin: (map['range_min'] as num?)?.toDouble(),
      rangeMax: (map['range_max'] as num?)?.toDouble(),
      demand: (map['demand'] as num?)?.toInt(),
      rarity: (map['rarity'] as num?)?.toInt(),
      stability: map['stability'] as String?,
      origin: map['origin'] as String?,
      aliases: aliases,
    );
  }

  Map<String, Object?> toMap() => {
        'id': id,
        'name': name,
        'category': category,
        'value': value,
        'range_min': rangeMin,
        'range_max': rangeMax,
        'demand': demand,
        'rarity': rarity,
        'stability': stability,
        'origin': origin,
        'aliases_json': jsonEncode(aliases),
      };

  static String normalize(String input) {
    return input
        .toLowerCase()
        .replaceAll(RegExp(r"[’']"), '')
        .replaceAll(RegExp(r'[^a-z0-9]+'), ' ')
        .trim()
        .replaceAll(RegExp(r'\s+'), ' ');
  }

  static String makeId(String category, String name) {
    final slug = normalize(name).replaceAll(' ', '-');
    return '$category:$slug';
  }
}
