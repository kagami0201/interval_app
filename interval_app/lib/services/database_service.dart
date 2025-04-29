import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'dart:convert';
import '../models/exercise.dart';
import '../models/training_history.dart';

class DatabaseService {
  static final DatabaseService _instance = DatabaseService._internal();
  static Database? _database;

  factory DatabaseService() {
    return _instance;
  }

  DatabaseService._internal();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    String path = join(await getDatabasesPath(), 'interval_app.db');
    return await openDatabase(
      path,
      version: 2,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE exercises(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        workTime INTEGER NOT NULL,
        restTime INTEGER NOT NULL,
        sets INTEGER NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE training_history(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        date TEXT NOT NULL,
        exercises TEXT NOT NULL,
        totalTime INTEGER NOT NULL
      )
    ''');
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      // 既存のデータをバックアップ
      final List<Map<String, dynamic>> oldHistory = await db.query('training_history');
      
      // 既存のテーブルを削除
      await db.execute('DROP TABLE training_history');
      
      // 新しいスキーマでテーブルを作成
      await db.execute('''
        CREATE TABLE training_history(
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          date TEXT NOT NULL,
          exercises TEXT NOT NULL,
          totalTime INTEGER NOT NULL
        )
      ''');

      // バックアップしたデータを新しいスキーマに変換して移行
      for (final history in oldHistory) {
        final exerciseName = history['exerciseName'] as String;
        final totalSets = history['totalSets'] as int;
        final exercises = [
          {'name': exerciseName, 'sets': totalSets}
        ];
        
        await db.insert('training_history', {
          'date': history['date'],
          'exercises': jsonEncode(exercises),
          'totalTime': history['totalTime'],
        });
      }
    }
  }

  // Exercise CRUD operations
  Future<int> insertExercise(Exercise exercise) async {
    final db = await database;
    return await db.insert('exercises', exercise.toMap());
  }

  Future<List<Exercise>> getExercises() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query('exercises');
    return List.generate(maps.length, (i) => Exercise.fromMap(maps[i]));
  }

  Future<int> updateExercise(Exercise exercise) async {
    final db = await database;
    return await db.update(
      'exercises',
      exercise.toMap(),
      where: 'id = ?',
      whereArgs: [exercise.id],
    );
  }

  Future<int> deleteExercise(int id) async {
    final db = await database;
    return await db.delete(
      'exercises',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // Training History operations
  Future<int> insertTrainingHistory(TrainingHistory history) async {
    final db = await database;
    return await db.insert('training_history', {
      'date': history.date,
      'exercises': jsonEncode(history.exercises.map((e) => e.toMap()).toList()),
      'totalTime': history.totalTime,
    });
  }

  Future<List<TrainingHistory>> getTrainingHistory() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'training_history',
      orderBy: 'date DESC',
    );
    return List.generate(maps.length, (i) {
      final map = maps[i];
      return TrainingHistory(
        id: map['id'] as int?,
        date: map['date'] as String,
        exercises: (jsonDecode(map['exercises'] as String) as List)
            .map((e) => ExerciseHistory.fromMap(e as Map<String, dynamic>))
            .toList(),
        totalTime: map['totalTime'] as int,
      );
    });
  }

  Future<int> deleteTrainingHistory(int id) async {
    final db = await database;
    return await db.delete(
      'training_history',
      where: 'id = ?',
      whereArgs: [id],
    );
  }
} 