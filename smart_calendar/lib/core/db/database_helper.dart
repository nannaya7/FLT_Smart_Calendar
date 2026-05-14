import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../../shared/models/schedule.dart';
import '../../shared/models/holiday.dart';

class DatabaseHelper {
  static const _dbName = 'smart_calendar.db';
  static const _dbVersion = 5;
  static const tableSchedules = 'schedules';
  static const tableHolidays = 'holidays';

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
    return openDatabase(
      path,
      version: _dbVersion,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE $tableSchedules (
        id                   INTEGER PRIMARY KEY AUTOINCREMENT,
        title                TEXT    NOT NULL,
        memo                 TEXT,
        solar_date           TEXT    NOT NULL,
        time                 TEXT,
        end_time             TEXT,
        location             TEXT,
        is_lunar             INTEGER NOT NULL DEFAULT 0,
        alarm_minutes_before INTEGER,
        category_color       INTEGER NOT NULL DEFAULT ${0xFF2196F3},
        repeat_type          TEXT,
        lunar_month          INTEGER,
        lunar_day            INTEGER
      )
    ''');
    await _createHolidaysTable(db);
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) await _createHolidaysTable(db);
    if (oldVersion < 3) {
      await db.execute(
        'ALTER TABLE $tableSchedules ADD COLUMN repeat_type TEXT',
      );
    }
    if (oldVersion < 4) {
      await db.execute(
        'ALTER TABLE $tableSchedules ADD COLUMN lunar_month INTEGER',
      );
      await db.execute(
        'ALTER TABLE $tableSchedules ADD COLUMN lunar_day INTEGER',
      );
    }
    if (oldVersion < 5) {
      await db.execute('ALTER TABLE $tableSchedules ADD COLUMN end_time TEXT');
      await db.execute('ALTER TABLE $tableSchedules ADD COLUMN location TEXT');
    }
  }

  Future<void> _createHolidaysTable(Database db) async {
    await db.execute('''
      CREATE TABLE $tableHolidays (
        id    INTEGER PRIMARY KEY AUTOINCREMENT,
        date  TEXT    NOT NULL,
        name  TEXT    NOT NULL,
        type  TEXT    NOT NULL
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
    final rows = await db.query(
      tableSchedules,
      orderBy: 'solar_date ASC, time ASC',
    );
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

  /// 음력 매년 반복 일정 전체 반환 (달력 표시 계산용)
  Future<List<Schedule>> getLunarYearlySchedules() async {
    final db = await database;
    final rows = await db.query(
      tableSchedules,
      where: 'is_lunar = 1 AND repeat_type = ?',
      whereArgs: ['yearly'],
    );
    return rows.map(Schedule.fromMap).toList();
  }

  /// 반복 타입이 있는 일정 전체 반환
  Future<List<Schedule>> getAllRepeatSchedules() async {
    final db = await database;
    final rows = await db.query(
      tableSchedules,
      where: 'repeat_type IS NOT NULL',
      orderBy: 'solar_date ASC',
    );
    return rows.map(Schedule.fromMap).toList();
  }

  Future<Schedule?> getScheduleById(int id) async {
    final db = await database;
    final rows = await db.query(
      tableSchedules,
      where: 'id = ?',
      whereArgs: [id],
    );
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

  // ── Holiday / SolarTerm ─────────────────────────────────────────────────────

  Future<void> insertHolidays(List<Holiday> holidays) async {
    final db = await database;
    final batch = db.batch();
    for (final h in holidays) {
      batch.insert(
        tableHolidays,
        h.toMap(),
        conflictAlgorithm: ConflictAlgorithm.ignore,
      );
    }
    await batch.commit(noResult: true);
  }

  Future<List<Holiday>> getHolidaysByYear(int year) async {
    final db = await database;
    final rows = await db.query(
      tableHolidays,
      where: "date LIKE ?",
      whereArgs: ['$year-%'],
    );
    return rows.map(Holiday.fromMap).toList();
  }

  Future<void> clearHolidaysByYear(int year) async {
    final db = await database;
    await db.delete(
      tableHolidays,
      where: "date LIKE ?",
      whereArgs: ['$year-%'],
    );
  }

  Future<bool> hasHolidaysForYear(int year) async {
    final db = await database;
    final count = Sqflite.firstIntValue(
      await db.rawQuery(
        'SELECT COUNT(*) FROM $tableHolidays WHERE date LIKE ?',
        ['$year-%'],
      ),
    );
    return (count ?? 0) > 0;
  }

  // ── Utility ─────────────────────────────────────────────────────────────────

  Future<void> close() async {
    final db = await database;
    await db.close();
    _db = null;
  }
}
