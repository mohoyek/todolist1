/// Backend data models for the ToDoList application

/// User model representing a registered user in the system
class User {
  final String id;
  final String username;
  final String passwordHash;
  final String? fullName;
  final DateTime createdAt;

  User({
    required this.id,
    required this.username,
    required this.passwordHash,
    this.fullName,
    required this.createdAt,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'username': username,
      'full_name': fullName,
      'created_at': createdAt.toIso8601String(),
    };
  }

  factory User.fromMap(Map<String, dynamic> map) {
    return User(
      id: map['id'] as String,
      username: map['username'] as String,
      passwordHash: map['password_hash'] as String,
      fullName: map['full_name'] as String?,
      createdAt: DateTime.parse(map['created_at'] as String),
    );
  }
}

/// Category model for organizing tasks
class Category {
  final String id;
  final String name;
  final String color; // Hex color code
  final String ownerId;
  final DateTime createdAt;

  Category({
    required this.id,
    required this.name,
    required this.color,
    required this.ownerId,
    required this.createdAt,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'color': color,
      'owner_id': ownerId,
      'created_at': createdAt.toIso8601String(),
    };
  }

  factory Category.fromMap(Map<String, dynamic> map) {
    return Category(
      id: map['id'] as String,
      name: map['name'] as String,
      color: map['color'] as String,
      ownerId: map['owner_id'] as String,
      createdAt: DateTime.parse(map['created_at'] as String),
    );
  }
}

/// Task model representing a todo item
class Task {
  final String id;
  final String title;
  final String? description;
  final bool isCompleted;
  final bool isPinned;
  final int orderIndex;
  final String categoryId;
  final String ownerId;
  final String? assignedTo; // User ID of assigned user (nullable)
  final String? dueDate; // Persian date string (e.g., "1403/01/15")
  final DateTime createdAt;
  final DateTime updatedAt;

  Task({
    required this.id,
    required this.title,
    this.description,
    required this.isCompleted,
    required this.isPinned,
    required this.orderIndex,
    required this.categoryId,
    required this.ownerId,
    this.assignedTo,
    this.dueDate,
    required this.createdAt,
    required this.updatedAt,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'is_completed': isCompleted ? 1 : 0,
      'is_pinned': isPinned ? 1 : 0,
      'order_index': orderIndex,
      'category_id': categoryId,
      'owner_id': ownerId,
      'assigned_to': assignedTo,
      'due_date': dueDate,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  factory Task.fromMap(Map<String, dynamic> map) {
    return Task(
      id: map['id'] as String,
      title: map['title'] as String,
      description: map['description'] as String?,
      isCompleted: (map['is_completed'] as int) == 1,
      isPinned: (map['is_pinned'] as int) == 1,
      orderIndex: map['order_index'] as int,
      categoryId: map['category_id'] as String,
      ownerId: map['owner_id'] as String,
      assignedTo: map['assigned_to'] as String?,
      dueDate: map['due_date'] as String?,
      createdAt: DateTime.parse(map['created_at'] as String),
      updatedAt: DateTime.parse(map['updated_at'] as String),
    );
  }

  Task copyWith({
    String? id,
    String? title,
    String? description,
    bool? isCompleted,
    bool? isPinned,
    int? orderIndex,
    String? categoryId,
    String? ownerId,
    String? assignedTo,
    String? dueDate,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Task(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      isCompleted: isCompleted ?? this.isCompleted,
      isPinned: isPinned ?? this.isPinned,
      orderIndex: orderIndex ?? this.orderIndex,
      categoryId: categoryId ?? this.categoryId,
      ownerId: ownerId ?? this.ownerId,
      assignedTo: assignedTo ?? this.assignedTo,
      dueDate: dueDate ?? this.dueDate,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
