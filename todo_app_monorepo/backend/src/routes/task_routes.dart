import 'dart:convert';
import '../db/database.dart';
import '../models/models.dart';

/// Task service for CRUD operations on tasks
class TaskService {
  final DatabaseHelper _dbHelper = DatabaseHelper();

  /// Get all tasks for a user (including assigned tasks)
  List<Task> getTasks(String userId) {
    final db = _dbHelper.database;

    final results = db.select('''
      SELECT * FROM tasks 
      WHERE owner_id = ? OR assigned_to = ?
      ORDER BY is_pinned DESC, order_index ASC
    ''', [userId, userId]);

    return results.map((row) => Task.fromMap({
      'id': row['id'],
      'title': row['title'],
      'description': row['description'],
      'is_completed': row['is_completed'],
      'is_pinned': row['is_pinned'],
      'order_index': row['order_index'],
      'category_id': row['category_id'],
      'owner_id': row['owner_id'],
      'assigned_to': row['assigned_to'],
      'due_date': row['due_date'],
      'created_at': row['created_at'],
      'updated_at': row['updated_at'],
    })).toList();
  }

  /// Get task by ID
  Task? getTaskById(String taskId) {
    final db = _dbHelper.database;

    final results = db.select('SELECT * FROM tasks WHERE id = ?', [taskId]);

    if (results.isEmpty) {
      return null;
    }

    final row = results.first;
    return Task.fromMap({
      'id': row['id'],
      'title': row['title'],
      'description': row['description'],
      'is_completed': row['is_completed'],
      'is_pinned': row['is_pinned'],
      'order_index': row['order_index'],
      'category_id': row['category_id'],
      'owner_id': row['owner_id'],
      'assigned_to': row['assigned_to'],
      'due_date': row['due_date'],
      'created_at': row['created_at'],
      'updated_at': row['updated_at'],
    });
  }

  /// Create a new task
  Task? createTask({
    required String title,
    String? description,
    required String categoryId,
    required String ownerId,
    String? assignedTo,
    String? dueDate,
  }) {
    final db = _dbHelper.database;
    final taskId = DateTime.now().millisecondsSinceEpoch.toString();
    final now = DateTime.now().toIso8601String();

    // Get max order_index for this category
    final maxOrderResult = db.select(
      'SELECT MAX(order_index) as max_order FROM tasks WHERE category_id = ?',
      [categoryId],
    );
    final maxOrder = (maxOrderResult.first['max_order'] as int?) ?? -1;
    final newOrderIndex = maxOrder + 1;

    try {
      db.execute('''
        INSERT INTO tasks (id, title, description, is_completed, is_pinned, order_index, category_id, owner_id, assigned_to, due_date, created_at, updated_at)
        VALUES (?, ?, ?, 0, 0, ?, ?, ?, ?, ?, ?, ?)
      ''', [taskId, title, description, newOrderIndex, categoryId, ownerId, assignedTo, dueDate, now, now]);

      return Task(
        id: taskId,
        title: title,
        description: description,
        isCompleted: false,
        isPinned: false,
        orderIndex: newOrderIndex,
        categoryId: categoryId,
        ownerId: ownerId,
        assignedTo: assignedTo,
        dueDate: dueDate,
        createdAt: DateTime.parse(now),
        updatedAt: DateTime.parse(now),
      );
    } catch (e) {
      return null;
    }
  }

  /// Update a task
  Task? updateTask(String taskId, {
    String? title,
    String? description,
    bool? isCompleted,
    bool? isPinned,
    String? categoryId,
    String? assignedTo,
    String? dueDate,
  }) {
    final db = _dbHelper.database;
    final now = DateTime.now().toIso8601String();

    final existingTask = getTaskById(taskId);
    if (existingTask == null) {
      return null;
    }

    final updates = <String>[];
    final values = <dynamic>[];

    if (title != null) {
      updates.add('title = ?');
      values.add(title);
    }
    if (description != null) {
      updates.add('description = ?');
      values.add(description);
    }
    if (isCompleted != null) {
      updates.add('is_completed = ?');
      values.add(isCompleted ? 1 : 0);
    }
    if (isPinned != null) {
      updates.add('is_pinned = ?');
      values.add(isPinned ? 1 : 0);
    }
    if (categoryId != null) {
      updates.add('category_id = ?');
      values.add(categoryId);
    }
    if (assignedTo != null || assignedTo == null) {
      updates.add('assigned_to = ?');
      values.add(assignedTo);
    }
    if (dueDate != null) {
      updates.add('due_date = ?');
      values.add(dueDate);
    }

    if (updates.isEmpty) {
      return existingTask;
    }

    updates.add('updated_at = ?');
    values.add(now);
    values.add(taskId);

    try {
      db.execute(
        'UPDATE tasks SET ${updates.join(', ')} WHERE id = ?',
        values,
      );

      return getTaskById(taskId);
    } catch (e) {
      return null;
    }
  }

  /// Delete a task
  bool deleteTask(String taskId) {
    final db = _dbHelper.database;

    try {
      db.execute('DELETE FROM tasks WHERE id = ?', [taskId]);
      return true;
    } catch (e) {
      return false;
    }
  }

  /// Toggle task completion status
  Task? toggleComplete(String taskId) {
    final task = getTaskById(taskId);
    if (task == null) {
      return null;
    }

    return updateTask(taskId, isCompleted: !task.isCompleted);
  }

  /// Toggle task pinned status
  Task? togglePin(String taskId) {
    final task = getTaskById(taskId);
    if (task == null) {
      return null;
    }

    return updateTask(taskId, isPinned: !task.isPinned);
  }

  /// Reorder tasks within a category
  bool reorderTasks(String categoryId, List<String> taskIdsInOrder) {
    final db = _dbHelper.database;

    try {
      db.execute('BEGIN TRANSACTION');

      for (int i = 0; i < taskIdsInOrder.length; i++) {
        db.execute(
          'UPDATE tasks SET order_index = ?, updated_at = ? WHERE id = ?',
          [i, DateTime.now().toIso8601String(), taskIdsInOrder[i]],
        );
      }

      db.execute('COMMIT');
      return true;
    } catch (e) {
      db.execute('ROLLBACK');
      return false;
    }
  }

  /// Get tasks by category
  List<Task> getTasksByCategory(String categoryId, String userId) {
    final db = _dbHelper.database;

    final results = db.select('''
      SELECT * FROM tasks 
      WHERE category_id = ? AND (owner_id = ? OR assigned_to = ?)
      ORDER BY is_pinned DESC, order_index ASC
    ''', [categoryId, userId, userId]);

    return results.map((row) => Task.fromMap({
      'id': row['id'],
      'title': row['title'],
      'description': row['description'],
      'is_completed': row['is_completed'],
      'is_pinned': row['is_pinned'],
      'order_index': row['order_index'],
      'category_id': row['category_id'],
      'owner_id': row['owner_id'],
      'assigned_to': row['assigned_to'],
      'due_date': row['due_date'],
      'created_at': row['created_at'],
      'updated_at': row['updated_at'],
    })).toList();
  }
}
