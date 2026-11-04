import 'package:path/path.dart' as path;
import 'package:sqflite/sqflite.dart';

import '../models/catalog_item.dart';

class CatalogDatabase {
  CatalogDatabase._();

  static final CatalogDatabase instance = CatalogDatabase._();
  Database? _database;

  Future<Database> get database async {
    final cached = _database;
    if (cached != null) return cached;

    final databasesPath = await getDatabasesPath();
    final dbPath = path.join(databasesPath, 'supreme_trade_checker.db');
    final opened = await openDatabase(
      dbPath,
      version: 1,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE catalog_items (
            id TEXT PRIMARY KEY,
            name TEXT NOT NULL,
            category TEXT NOT NULL,
            value REAL,
            range_min REAL,
            range_max REAL,
            demand INTEGER,
            rarity INTEGER,
            stability TEXT,
            origin TEXT,
            aliases_json TEXT NOT NULL DEFAULT '[]'
          )
        ''');
        await db.execute(
          'CREATE INDEX idx_catalog_name ON catalog_items(name COLLATE NOCASE)',
        );
        await db.execute(
          'CREATE INDEX idx_catalog_category ON catalog_items(category)',
        );
        await db.execute('''
          CREATE TABLE metadata (
            key TEXT PRIMARY KEY,
            value TEXT NOT NULL
          )
        ''');
      },
    );
    _database = opened;
    return opened;
  }

  Future<List<CatalogItem>> getAllItems() async {
    final db = await database;
    final rows = await db.query(
      'catalog_items',
      orderBy: 'name COLLATE NOCASE ASC',
    );
    return rows
        .map((row) => CatalogItem.fromMap(Map<String, Object?>.from(row)))
        .toList(growable: false);
  }

  Future<int> countItems() async {
    final db = await database;
    final result = await db.rawQuery(
      'SELECT COUNT(*) AS total FROM catalog_items',
    );
    return Sqflite.firstIntValue(result) ?? 0;
  }

  Future<String?> readMetadata(String key) async {
    final db = await database;
    final rows = await db.query(
      'metadata',
      columns: ['value'],
      where: 'key = ?',
      whereArgs: [key],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return rows.first['value'] as String?;
  }

  Future<void> replaceAll({
    required List<CatalogItem> items,
    required String fetchedAt,
    required String sourceUpdatedLabel,
  }) async {
    final db = await database;
    await db.transaction((txn) async {
      await txn.delete('catalog_items');
      final batch = txn.batch();
      for (final item in items) {
        batch.insert(
          'catalog_items',
          item.toMap(),
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
      await batch.commit(noResult: true);

      await txn.insert(
        'metadata',
        {'key': 'last_fetched_at', 'value': fetchedAt},
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
      await txn.insert(
        'metadata',
        {'key': 'source_updated_label', 'value': sourceUpdatedLabel},
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
      await txn.insert(
        'metadata',
        {'key': 'item_count', 'value': items.length.toString()},
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    });
  }
}
