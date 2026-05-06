import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../../shared/models/schedule.dart';

class DatabaseHelper {
  static const _dbName = 'smart_calendar.db';
  static const _dbVersion = 1;
  static const tableSchedules = 'schedules';

  DatabaseHelper._();
  static final DatabaseHelper instance = DatabaseHelper._();

  Database? _db;

  Future<Database> get database async {
    _db ??= await _initDatabase();
    return _db!;
  }

  Future<Database> _initDatabase() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, _dbName);
    return openDatabase(path, version: _dbVersion, onCreate: _onCreate);
  }

  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE $tableSchedules (
        id                   INTEGER PRIMARY KEY AUTOINCREMENT,
        title                TEXT    NOT NULL,
        memo                 TEXT,
        solar_date           TEXT    NOT NULL,
        time                 TEXT,
        is_lunar             INTEGER NOT NULL DEFAULT 0,
        alarm_minutes_before INTEGER,
        category_color       INTEGER NOT NULL DEFAULT ${0xFF2196F3}
      )
    ''');
  }

  // ── Create ──────────────────────────────────────────────────────────────────

  Future<int> insertSchedule(Schedule schedule) async {
    final db = await database;
    return db.insert(tableSchedules, schedule.toMap());
  }

  // ── Read ────────────────────────────────────────────────────────────────────

  Future<List<Schedule>> getAllSchedules() async {
    final db = await database;
    final rows = await db.query(tableSchedules, orderBy: 'solar_date ASC, time ASC');
    return rows.map(Schedule.fromMap).toList();
  }

  /// 특정 날짜(YYYY-MM-DD)의 일정 목록 반환
  Future<List<Schedule>> getSchedulesByDate(String solarDate) async {
    final db = await database;
    final rows = await db.query(
      tableSchedules,
      where: 'solar_date = ?',
      whereArgs: [solarDate],
      orderBy: 'time ASC',
    );
    return rows.map(Schedule.fromMap).toList();
  }

  /// 특정 월(YYYY-MM)의 일정 목록 반환 — 달력 마커 표시용
  Future<List<Schedule>> getSchedulesByMonth(String yearMonth) async {
    final db = await database;
    final rows = await db.query(
      tableSchedules,
      where: "solar_date LIKE ?",
      whereArgs: ['$yearMonth-%'],
      orderBy: 'solar_date ASC, time ASC',
    );
    return rows.map(Schedule.fromMap).toList();
  }

  Future<Schedule?> getScheduleById(int id) async {
    final db = await database;
    final rows = await db.query(tableSchedules, where: 'id = ?', whereArgs: [id]);
    if (rows.isEmpty) return null;
    return Schedule.fromMap(rows.first);
  }

  // ── Update ──────────────────────────────────────────────────────────────────

  Future<int> updateSchedule(Schedule schedule) async {
    assert(schedule.id != null, 'id가 없는 Schedule은 업데이트할 수 없습니다.');
    final db = await database;
    return db.update(
      tableSchedules,
      schedule.toMap(),
      where: 'id = ?',
      whereArgs: [schedule.id],
    );
  }

  // ── Delete ──────────────────────────────────────────────────────────────────

  Future<int> deleteSchedule(int id) async {
    final db = await database;
    return db.delete(tableSchedules, where: 'id = ?', whereArgs: [id]);
  }

  Future<int> deleteAllSchedules() async {
    final db = await database;
    return db.delete(tableSchedules);
  }

  // ── Utility ─────────────────────────────────────────────────────────────────

  Future<void> close() async {
    final db = await database;
    await db.close();
    _db = null;
  }
}
