import 'dart:io';
import 'package:path/path.dart' as path;
import 'package:sqlite3/sqlite3.dart';

/// Database helper class for managing SQLite connections and schema
class DatabaseHelper {
  static final DatabaseHelper _instance = DatabaseHelper._internal();
  static Database? _database;

  factory DatabaseHelper() {
    return _instance;
  }

  DatabaseHelper._internal();

  /// Get or create database connection
  Database get database {
    _database ??= _initDatabase();
    return _database!;
  }

  /// Initialize database with schema
  Database _initDatabase() {
    final dbPath = path.join(Directory.current.path, 'data', 'todo_app.db');
    
    // Ensure data directory exists
    Directory(path.dirname(dbPath)).createSync(recursive: true);
    
    final db = sqlite3.open(dbPath);
    
    // Enable foreign keys
    db.execute('PRAGMA foreign_keys = ON');
    
    // Create tables
    _createUsersTable(db);
    _createCategoriesTable(db);
    _createTasksTable(db);
    
    return db;
  }

  /// Create users table
  void _createUsersTable(Database db) {
    db.execute('''
      CREATE TABLE IF NOT EXISTS users (
        id TEXT PRIMARY KEY,
        username TEXT UNIQUE NOT NULL,
        password_hash TEXT NOT NULL,
        full_name TEXT,
        created_at TEXT NOT NULL DEFAULT (datetime('now'))
      )
    ''');
  }

  /// Create categories table
  void _createCategoriesTable(Database db) {
    db.execute('''
      CREATE TABLE IF NOT EXISTS categories (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        color TEXT NOT NULL DEFAULT '#6200EE',
        owner_id TEXT NOT NULL,
        created_at TEXT NOT NULL DEFAULT (datetime('now')),
        FOREIGN KEY (owner_id) REFERENCES users(id) ON DELETE CASCADE
      )
    ''');
  }

  /// Create tasks table with all required fields
  void _createTasksTable(Database db) {
    db.execute('''
      CREATE TABLE IF NOT EXISTS tasks (
        id TEXT PRIMARY KEY,
        title TEXT NOT NULL,
        description TEXT,
        is_completed INTEGER NOT NULL DEFAULT 0,
        is_pinned INTEGER NOT NULL DEFAULT 0,
        order_index INTEGER NOT NULL DEFAULT 0,
        category_id TEXT NOT NULL,
        owner_id TEXT NOT NULL,
        assigned_to TEXT,
        due_date TEXT,
        created_at TEXT NOT NULL DEFAULT (datetime('now')),
        updated_at TEXT NOT NULL DEFAULT (datetime('now')),
        FOREIGN KEY (category_id) REFERENCES categories(id) ON DELETE CASCADE,
        FOREIGN KEY (owner_id) REFERENCES users(id) ON DELETE CASCADE,
        FOREIGN KEY (assigned_to) REFERENCES users(id) ON DELETE SET NULL
      )
    ''');
  }

  /// Close database connection
  void close() {
    _database?.dispose();
    _database = null;
  }
}
