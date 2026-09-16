import 'dart:convert';
import '../db/database.dart';
import '../models/models.dart';

/// Category service for CRUD operations on categories
class CategoryService {
  final DatabaseHelper _dbHelper = DatabaseHelper();

  /// Get all categories for a user
  List<Category> getCategories(String userId) {
    final db = _dbHelper.database;

    final results = db.select(
      'SELECT * FROM categories WHERE owner_id = ? ORDER BY created_at ASC',
      [userId],
    );

    return results.map((row) => Category.fromMap({
      'id': row['id'],
      'name': row['name'],
      'color': row['color'],
      'owner_id': row['owner_id'],
      'created_at': row['created_at'],
    })).toList();
  }

  /// Get category by ID
  Category? getCategoryById(String categoryId) {
    final db = _dbHelper.database;

    final results = db.select(
      'SELECT * FROM categories WHERE id = ?',
      [categoryId],
    );

    if (results.isEmpty) {
      return null;
    }

    final row = results.first;
    return Category.fromMap({
      'id': row['id'],
      'name': row['name'],
      'color': row['color'],
      'owner_id': row['owner_id'],
      'created_at': row['created_at'],
    });
  }

  /// Create a new category
  Category? createCategory({
    required String name,
    required String color,
    required String ownerId,
  }) {
    final db = _dbHelper.database;
    final categoryId = DateTime.now().millisecondsSinceEpoch.toString();
    final createdAt = DateTime.now().toIso8601String();

    try {
      db.execute(
        'INSERT INTO categories (id, name, color, owner_id, created_at) VALUES (?, ?, ?, ?, ?)',
        [categoryId, name, color, ownerId, createdAt],
      );

      return Category(
        id: categoryId,
        name: name,
        color: color,
        ownerId: ownerId,
        createdAt: DateTime.parse(createdAt),
      );
    } catch (e) {
      return null;
    }
  }

  /// Update a category
  Category? updateCategory(String categoryId, {
    String? name,
    String? color,
  }) {
    final db = _dbHelper.database;

    final existingCategory = getCategoryById(categoryId);
    if (existingCategory == null) {
      return null;
    }

    final updates = <String>[];
    final values = <dynamic>[];

    if (name != null) {
      updates.add('name = ?');
      values.add(name);
    }
    if (color != null) {
      updates.add('color = ?');
      values.add(color);
    }

    if (updates.isEmpty) {
      return existingCategory;
    }

    values.add(categoryId);

    try {
      db.execute(
        'UPDATE categories SET ${updates.join(', ')} WHERE id = ?',
        values,
      );

      return getCategoryById(categoryId);
    } catch (e) {
      return null;
    }
  }

  /// Delete a category
  bool deleteCategory(String categoryId) {
    final db = _dbHelper.database;

    try {
      db.execute('DELETE FROM categories WHERE id = ?', [categoryId]);
      return true;
    } catch (e) {
      return false;
    }
  }

  /// Get default categories for a new user
  List<Category> getDefaultCategories(String ownerId) {
    final defaults = [
      {'name': 'شخصی', 'color': '#FF6B6B'}, // Personal - Red
      {'name': 'کاری', 'color': '#4ECDC4'}, // Work - Teal
      {'name': 'خرید', 'color': '#95E1D3'}, // Shopping - Mint
      {'name': 'سلامتی', 'color': '#F38181'}, // Health - Coral
      {'name': 'دیگر', 'color': '#AA96DA'}, // Other - Purple
    ];

    final categories = <Category>[];
    for (final def in defaults) {
      final category = createCategory(
        name: def['name'] as String,
        color: def['color'] as String,
        ownerId: ownerId,
      );
      if (category != null) {
        categories.add(category);
      }
    }

    return categories;
  }
}
