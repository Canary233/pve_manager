import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:pve_manager/data/models/pve_server_config.dart';
import 'package:sqflite/sqflite.dart' as sqflite;
import 'package:sqflite_common_ffi/sqflite_ffi.dart' as ffi;

class ServerRepository {
  ServerRepository._();

  static final ServerRepository instance = ServerRepository._();

  sqflite.Database? _database;

  Future<List<PveServerConfig>> getServers() async {
    final db = await _openDatabase();
    final rows = await db.query('servers', orderBy: 'updated_at DESC, id DESC');
    return rows.map(PveServerConfig.fromMap).toList();
  }

  Future<PveServerConfig> saveServer(PveServerConfig server) async {
    final db = await _openDatabase();
    final now = DateTime.now().millisecondsSinceEpoch;
    final values = <String, Object?>{
      ...server.toMap()..remove('id'),
      'updated_at': now,
    };

    if (server.id == null) {
      final id = await db.insert('servers', {
        ...values,
        'created_at': now,
      }, conflictAlgorithm: sqflite.ConflictAlgorithm.replace);
      return server.copyWith(id: id);
    }

    await db.update('servers', values, where: 'id = ?', whereArgs: [server.id]);
    return server;
  }

  Future<PveServerConfig> markConnected(PveServerConfig server) async {
    final db = await _openDatabase();
    final now = DateTime.now().millisecondsSinceEpoch;

    if (server.id != null) {
      await db.update(
        'servers',
        {'last_connected_at': now, 'updated_at': now},
        where: 'id = ?',
        whereArgs: [server.id],
      );
    }

    return server.copyWith(lastConnectedAt: now);
  }

  Future<void> deleteServer(int id) async {
    final db = await _openDatabase();
    await db.delete('servers', where: 'id = ?', whereArgs: [id]);
  }

  Future<sqflite.Database> _openDatabase() async {
    final existing = _database;
    if (existing != null) {
      return existing;
    }

    _configureDesktopDatabaseFactory();
    final databasePath = await sqflite.getDatabasesPath();
    final path = p.join(databasePath, 'pve_manager.db');
    _database = await sqflite.openDatabase(
      path,
      version: 3,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE servers (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            name TEXT NOT NULL,
            origin TEXT NOT NULL,
            username TEXT NOT NULL,
            password TEXT NOT NULL,
            realm TEXT NOT NULL,
            ignore_certificate_errors INTEGER NOT NULL DEFAULT 1,
            auth_type TEXT NOT NULL DEFAULT 'password',
            api_token_id TEXT NOT NULL DEFAULT '',
            api_token_secret TEXT NOT NULL DEFAULT '',
            last_connected_at INTEGER,
            created_at INTEGER NOT NULL,
            updated_at INTEGER NOT NULL
          )
        ''');
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          await db.execute(
            'ALTER TABLE servers ADD COLUMN last_connected_at INTEGER',
          );
        }
        if (oldVersion < 3) {
          await db.execute(
            "ALTER TABLE servers ADD COLUMN auth_type TEXT NOT NULL DEFAULT 'password'",
          );
          await db.execute(
            "ALTER TABLE servers ADD COLUMN api_token_id TEXT NOT NULL DEFAULT ''",
          );
          await db.execute(
            "ALTER TABLE servers ADD COLUMN api_token_secret TEXT NOT NULL DEFAULT ''",
          );
        }
      },
    );
    return _database!;
  }

  void _configureDesktopDatabaseFactory() {
    if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
      ffi.sqfliteFfiInit();
      sqflite.databaseFactory = ffi.databaseFactoryFfi;
    }
  }
}
