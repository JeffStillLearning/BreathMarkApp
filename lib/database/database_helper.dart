// lib/database/database_helper.dart
// DatabaseHelper = petugas yang mengurus semua operasi database
// (menyimpan, membaca, menghapus data)

import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/session_model.dart';

class DatabaseHelper {
  // Singleton pattern: pastikan hanya ada SATU instance DatabaseHelper
  // di seluruh aplikasi (supaya tidak ada konflik database)
  static final DatabaseHelper instance = DatabaseHelper._internal();
  static Database? _database;

  DatabaseHelper._internal();

  // Getter: ambil database, kalau belum ada maka buat dulu
  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  // Inisialisasi database: tentukan nama file dan buat tabelnya
  Future<Database> _initDatabase() async {
    String path = join(await getDatabasesPath(), 'breathmark.db');

    return await openDatabase(
      path,
      version: 1,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE sessions (
            id            INTEGER PRIMARY KEY AUTOINCREMENT,
            date          TEXT NOT NULL,
            mood_before   REAL NOT NULL,
            mood_label    TEXT NOT NULL,
            stress_level  TEXT NOT NULL,
            mood_after    REAL,
            relax_score   REAL,
            duration_sec  INTEGER
          )
        ''');
      },
    );
  }

  // SIMPAN sesi baru ke database
  Future<int> insertSession(SessionModel session) async {
    final db = await database;
    return await db.insert('sessions', session.toMap());
  }

  // BACA semua sesi, diurutkan dari yang terbaru
  Future<List<SessionModel>> getAllSessions() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'sessions',
      orderBy: 'id DESC',
    );
    return maps.map((map) => SessionModel.fromMap(map)).toList();
  }

  // BACA sesi terakhir saja (untuk ditampilkan di Home Screen)
  Future<SessionModel?> getLastSession() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'sessions',
      orderBy: 'id DESC',
      limit: 1,
    );
    if (maps.isEmpty) return null;
    return SessionModel.fromMap(maps.first);
  }

  // BACA sesi 7 hari terakhir (untuk grafik)
  Future<List<SessionModel>> getLastWeekSessions() async {
    final db = await database;
    final sevenDaysAgo = DateTime.now()
        .subtract(const Duration(days: 7))
        .toIso8601String()
        .substring(0, 10);

    final List<Map<String, dynamic>> maps = await db.query(
      'sessions',
      where: 'date >= ?',
      whereArgs: [sevenDaysAgo],
      orderBy: 'date ASC',
    );
    return maps.map((map) => SessionModel.fromMap(map)).toList();
  }
}
