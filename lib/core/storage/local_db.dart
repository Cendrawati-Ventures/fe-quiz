import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

final localDbProvider = Provider<AppLocalDb>((ref) {
  final db = AppLocalDb();
  ref.onDispose(() async {
    await db.close();
  });
  return db;
});

class AppLocalDb {
  static const String _databaseName = 'online_exam_local.db';
  static const int _databaseVersion = 1;

  static const String tableOutbox = 'outbox_items';
  static const String tableKeyValue = 'kv_store';

  Database? _database;

  Future<Database> get database async {
    if (_database != null) {
      return _database!;
    }

    final databasesPath = await getDatabasesPath();
    final path = p.join(databasesPath, _databaseName);
    _database = await openDatabase(
      path,
      version: _databaseVersion,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
    return _database!;
  }

  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE $tableKeyValue (
        key TEXT PRIMARY KEY,
        value TEXT NOT NULL,
        updated_at_epoch_ms INTEGER NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE $tableOutbox (
        id TEXT PRIMARY KEY,
        type TEXT NOT NULL,
        dedup_key TEXT NULL,
        payload_json TEXT NOT NULL,
        retry_count INTEGER NOT NULL,
        next_retry_at_epoch_ms INTEGER NOT NULL,
        created_at_epoch_ms INTEGER NOT NULL
      )
    ''');

    await db.execute('''
      CREATE UNIQUE INDEX idx_outbox_type_dedup
      ON $tableOutbox (type, dedup_key)
    ''');

    await db.execute('''
      CREATE INDEX idx_outbox_due
      ON $tableOutbox (next_retry_at_epoch_ms)
    ''');
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion == newVersion) {
      return;
    }
  }

  Future<void> putString(String key, String value) async {
    final db = await database;
    final nowMs = DateTime.now().toUtc().millisecondsSinceEpoch;
    await db.insert(
      tableKeyValue,
      <String, Object?>{
        'key': key,
        'value': value,
        'updated_at_epoch_ms': nowMs,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<String?> getString(String key) async {
    final db = await database;
    final rows = await db.query(
      tableKeyValue,
      columns: <String>['value'],
      where: 'key = ?',
      whereArgs: <Object?>[key],
      limit: 1,
    );
    if (rows.isEmpty) {
      return null;
    }
    return rows.first['value'] as String?;
  }

  Future<void> removeKey(String key) async {
    final db = await database;
    await db.delete(
      tableKeyValue,
      where: 'key = ?',
      whereArgs: <Object?>[key],
    );
  }

  Future<List<Map<String, Object?>>> listOutboxRows() async {
    final db = await database;
    return db.query(
      tableOutbox,
      orderBy: 'created_at_epoch_ms ASC',
    );
  }

  Future<Map<String, Object?>?> findOutboxRowByTypeAndDedup({
    required String type,
    required String dedupKey,
  }) async {
    final db = await database;
    final rows = await db.query(
      tableOutbox,
      where: 'type = ? AND dedup_key = ?',
      whereArgs: <Object?>[type, dedupKey],
      limit: 1,
    );
    if (rows.isEmpty) {
      return null;
    }
    return rows.first;
  }

  Future<void> insertOutboxRow({
    required String id,
    required String type,
    required String? dedupKey,
    required String payloadJson,
    required int retryCount,
    required int nextRetryAtEpochMs,
    required int createdAtEpochMs,
  }) async {
    final db = await database;
    await db.insert(
      tableOutbox,
      <String, Object?>{
        'id': id,
        'type': type,
        'dedup_key': dedupKey,
        'payload_json': payloadJson,
        'retry_count': retryCount,
        'next_retry_at_epoch_ms': nextRetryAtEpochMs,
        'created_at_epoch_ms': createdAtEpochMs,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> updateOutboxRowById({
    required String id,
    required String payloadJson,
    required int retryCount,
    required int nextRetryAtEpochMs,
  }) async {
    final db = await database;
    await db.update(
      tableOutbox,
      <String, Object?>{
        'payload_json': payloadJson,
        'retry_count': retryCount,
        'next_retry_at_epoch_ms': nextRetryAtEpochMs,
      },
      where: 'id = ?',
      whereArgs: <Object?>[id],
    );
  }

  Future<void> updateOutboxRetry({
    required String id,
    required int retryCount,
    required int nextRetryAtEpochMs,
  }) async {
    final db = await database;
    await db.update(
      tableOutbox,
      <String, Object?>{
        'retry_count': retryCount,
        'next_retry_at_epoch_ms': nextRetryAtEpochMs,
      },
      where: 'id = ?',
      whereArgs: <Object?>[id],
    );
  }

  Future<void> deleteOutboxRowById(String id) async {
    final db = await database;
    await db.delete(
      tableOutbox,
      where: 'id = ?',
      whereArgs: <Object?>[id],
    );
  }

  Future<void> clearOutbox() async {
    final db = await database;
    await db.delete(tableOutbox);
  }

  Future<void> close() async {
    if (_database == null) {
      return;
    }
    await _database!.close();
    _database = null;
  }
}
