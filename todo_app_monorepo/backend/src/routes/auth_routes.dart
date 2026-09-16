import 'dart:convert';
import 'dart:io';
import 'package:crypto/crypto.dart';
import 'package:dart_jsonwebtoken/dart_jsonwebtoken.dart';
import 'package:bcrypt/bcrypt.dart';
import '../db/database.dart';
import '../models/models.dart';

/// JWT configuration
class JwtConfig {
  static final String _secretKey = Platform.environment['JWT_SECRET'] ?? 'your-super-secret-key-change-in-production';
  static final Duration _expiryDuration = const Duration(days: 7);

  static String generateToken(User user) {
    final jwt = JWT(
      {'user_id': user.id, 'username': user.username},
      expiresAt: DateTime.now().add(_expiryDuration),
    );
    return jwt.sign(SecretKey(_secretKey));
  }

  static Map<String, dynamic>? verifyToken(String token) {
    try {
      final jwt = JWT.verify(token, SecretKey(_secretKey));
      return jwt.payload as Map<String, dynamic>;
    } catch (e) {
      return null;
    }
  }
}

/// Authentication service for user registration and login
class AuthService {
  final DatabaseHelper _dbHelper = DatabaseHelper();

  /// Hash password using bcrypt
  String _hashPassword(String password) {
    return BCrypt.hashpw(password);
  }

  /// Verify password against hash
  bool _verifyPassword(String password, String hash) {
    return BCrypt.checkpw(password, hash);
  }

  /// Register a new user
  User? register(String username, String password, {String? fullName}) {
    final db = _dbHelper.database;
    final userId = DateTime.now().millisecondsSinceEpoch.toString();
    final passwordHash = _hashPassword(password);
    final createdAt = DateTime.now().toIso8601String();

    try {
      db.execute(
        'INSERT INTO users (id, username, password_hash, full_name, created_at) VALUES (?, ?, ?, ?, ?)',
        [userId, username, passwordHash, fullName, createdAt],
      );

      return User(
        id: userId,
        username: username,
        passwordHash: passwordHash,
        fullName: fullName,
        createdAt: DateTime.parse(createdAt),
      );
    } catch (e) {
      // Username already exists or other error
      return null;
    }
  }

  /// Login user and return JWT token
  String? login(String username, String password) {
    final db = _dbHelper.database;

    final result = db.select(
      'SELECT * FROM users WHERE username = ?',
      [username],
    );

    if (result.isEmpty) {
      return null;
    }

    final userMap = result.first;
    final user = User.fromMap({
      'id': userMap['id'],
      'username': userMap['username'],
      'password_hash': userMap['password_hash'],
      'full_name': userMap['full_name'],
      'created_at': userMap['created_at'],
    });

    if (!_verifyPassword(password, user.passwordHash)) {
      return null;
    }

    return JwtConfig.generateToken(user);
  }

  /// Get user by ID
  User? getUserById(String userId) {
    final db = _dbHelper.database;

    final result = db.select(
      'SELECT * FROM users WHERE id = ?',
      [userId],
    );

    if (result.isEmpty) {
      return null;
    }

    final userMap = result.first;
    return User.fromMap({
      'id': userMap['id'],
      'username': userMap['username'],
      'password_hash': userMap['password_hash'],
      'full_name': userMap['full_name'],
      'created_at': userMap['created_at'],
    });
  }

  /// Get user by username
  User? getUserByUsername(String username) {
    final db = _dbHelper.database;

    final result = db.select(
      'SELECT * FROM users WHERE username = ?',
      [username],
    );

    if (result.isEmpty) {
      return null;
    }

    final userMap = result.first;
    return User.fromMap({
      'id': userMap['id'],
      'username': userMap['username'],
      'password_hash': userMap['password_hash'],
      'full_name': userMap['full_name'],
      'created_at': userMap['created_at'],
    });
  }

  /// Get all users (for assignment dropdown)
  List<User> getAllUsers() {
    final db = _dbHelper.database;

    final results = db.select('SELECT id, username, full_name, created_at FROM users');

    return results.map((row) => User.fromMap({
      'id': row['id'],
      'username': row['username'],
      'password_hash': '', // Don't return password hash
      'full_name': row['full_name'],
      'created_at': row['created_at'],
    })).toList();
  }
}
