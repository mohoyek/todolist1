import 'dart:convert';
import 'dart:io';
import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';
import 'package:cors_headers/cors_headers.dart';
import '../db/database.dart';
import '../models/models.dart';
import '../routes/auth_routes.dart';
import '../routes/task_routes.dart';
import '../routes/category_routes.dart';

/// Middleware to extract and verify JWT token from Authorization header
Middleware createAuthMiddleware() {
  return (Handler innerHandler) {
    return (Request request) {
      // Skip auth for public endpoints
      final path = request.url.path;
      if (path == '/api/auth/register' || path == '/api/auth/login') {
        return innerHandler(request);
      }

      final authHeader = request.headers['Authorization'];
      if (authHeader == null || !authHeader.startsWith('Bearer ')) {
        return Response.unauthorized({'error': 'Missing or invalid authorization header'});
      }

      final token = authHeader.substring(7); // Remove 'Bearer ' prefix
      final payload = JwtConfig.verifyToken(token);

      if (payload == null) {
        return Response.unauthorized({'error': 'Invalid or expired token'});
      }

      // Add user info to request context
      final userId = payload['user_id'] as String;
      final username = payload['username'] as String;

      return innerHandler(request.change(context: {
        'userId': userId,
        'username': username,
      }));
    };
  };
}

/// Get user ID from request context
String? getUserId(Request request) {
  return request.context['userId'] as String?;
}

/// Create the main API router with all endpoints
Router createApiRouter() {
  final router = Router();
  final authService = AuthService();
  final taskService = TaskService();
  final categoryService = CategoryService();
  final dbHelper = DatabaseHelper();

  // ============ AUTH ENDPOINTS ============
  
  // POST /api/auth/register - Register new user
  router.post('/auth/register', (Request request) async {
    final body = await request.readAsString();
    final data = jsonDecode(body) as Map<String, dynamic>;

    final username = data['username'] as String?;
    final password = data['password'] as String?;
    final fullName = data['full_name'] as String?;

    if (username == null || password == null || username.isEmpty || password.isEmpty) {
      return Response.badRequest(body: jsonEncode({'error': 'Username and password are required'}));
    }

    final user = authService.register(username, password, fullName: fullName);
    
    if (user == null) {
      return Response.badRequest(body: jsonEncode({'error': 'Username already exists'}));
    }

    // Create default categories for new user
    categoryService.getDefaultCategories(user.id);

    final token = JwtConfig.generateToken(user);

    return Response.ok(jsonEncode({
      'user': user.toJson(),
      'token': token,
    }));
  });

  // POST /api/auth/login - Login user
  router.post('/auth/login', (Request request) async {
    final body = await request.readAsString();
    final data = jsonDecode(body) as Map<String, dynamic>;

    final username = data['username'] as String?;
    final password = data['password'] as String?;

    if (username == null || password == null) {
      return Response.badRequest(body: jsonEncode({'error': 'Username and password are required'}));
    }

    final token = authService.login(username, password);

    if (token == null) {
      return Response.unauthorized({'error': 'Invalid credentials'});
    }

    final user = authService.getUserByUsername(username);

    return Response.ok(jsonEncode({
      'user': user?.toJson(),
      'token': token,
    }));
  });

  // GET /api/auth/me - Get current user
  router.get('/auth/me', (Request request) {
    final userId = getUserId(request);
    if (userId == null) {
      return Response.unauthorized({'error': 'Unauthorized'});
    }

    final user = authService.getUserById(userId);
    if (user == null) {
      return Response.notFound('User not found');
    }

    return Response.ok(jsonEncode({'user': user.toJson()}));
  });

  // GET /api/users - Get all users (for assignment)
  router.get('/users', (Request request) {
    final users = authService.getAllUsers();
    return Response.ok(jsonEncode({
      'users': users.map((u) => u.toJson()).toList(),
    }));
  });

  // ============ CATEGORY ENDPOINTS ============
  
  // GET /api/categories - Get all categories for current user
  router.get('/categories', (Request request) {
    final userId = getUserId(request);
    if (userId == null) {
      return Response.unauthorized({'error': 'Unauthorized'});
    }

    final categories = categoryService.getCategories(userId);
    return Response.ok(jsonEncode({
      'categories': categories.map((c) => c.toJson()).toList(),
    }));
  });

  // POST /api/categories - Create new category
  router.post('/categories', (Request request) async {
    final userId = getUserId(request);
    if (userId == null) {
      return Response.unauthorized({'error': 'Unauthorized'});
    }

    final body = await request.readAsString();
    final data = jsonDecode(body) as Map<String, dynamic>;

    final name = data['name'] as String?;
    final color = data['color'] as String?;

    if (name == null || color == null) {
      return Response.badRequest(body: jsonEncode({'error': 'Name and color are required'}));
    }

    final category = categoryService.createCategory(
      name: name,
      color: color,
      ownerId: userId,
    );

    if (category == null) {
      return Response.internalServerError(body: jsonEncode({'error': 'Failed to create category'}));
    }

    return Response.ok(jsonEncode({'category': category.toJson()}));
  });

  // PUT /api/categories/:id - Update category
  router.put('/categories/<id>', (Request request, String id) async {
    final userId = getUserId(request);
    if (userId == null) {
      return Response.unauthorized({'error': 'Unauthorized'});
    }

    final category = categoryService.getCategoryById(id);
    if (category == null || category.ownerId != userId) {
      return Response.notFound('Category not found');
    }

    final body = await request.readAsString();
    final data = jsonDecode(body) as Map<String, dynamic>;

    final updatedCategory = categoryService.updateCategory(
      id,
      name: data['name'] as String?,
      color: data['color'] as String?,
    );

    if (updatedCategory == null) {
      return Response.internalServerError(body: jsonEncode({'error': 'Failed to update category'}));
    }

    return Response.ok(jsonEncode({'category': updatedCategory.toJson()}));
  });

  // DELETE /api/categories/:id - Delete category
  router.delete('/categories/<id>', (Request request, String id) {
    final userId = getUserId(request);
    if (userId == null) {
      return Response.unauthorized({'error': 'Unauthorized'});
    }

    final category = categoryService.getCategoryById(id);
    if (category == null || category.ownerId != userId) {
      return Response.notFound('Category not found');
    }

    final success = categoryService.deleteCategory(id);
    if (!success) {
      return Response.internalServerError(body: jsonEncode({'error': 'Failed to delete category'}));
    }

    return Response.ok(jsonEncode({'success': true}));
  });

  // ============ TASK ENDPOINTS ============
  
  // GET /api/tasks - Get all tasks for current user
  router.get('/tasks', (Request request) {
    final userId = getUserId(request);
    if (userId == null) {
      return Response.unauthorized({'error': 'Unauthorized'});
    }

    final categoryId = request.url.queryParameters['category_id'];
    List<Task> tasks;

    if (categoryId != null) {
      tasks = taskService.getTasksByCategory(categoryId, userId);
    } else {
      tasks = taskService.getTasks(userId);
    }

    return Response.ok(jsonEncode({
      'tasks': tasks.map((t) => t.toJson()).toList(),
    }));
  });

  // POST /api/tasks - Create new task
  router.post('/tasks', (Request request) async {
    final userId = getUserId(request);
    if (userId == null) {
      return Response.unauthorized({'error': 'Unauthorized'});
    }

    final body = await request.readAsString();
    final data = jsonDecode(body) as Map<String, dynamic>;

    final title = data['title'] as String?;
    final description = data['description'] as String?;
    final categoryId = data['category_id'] as String?;
    final assignedTo = data['assigned_to'] as String?;
    final dueDate = data['due_date'] as String?;

    if (title == null || categoryId == null) {
      return Response.badRequest(body: jsonEncode({'error': 'Title and category_id are required'}));
    }

    final task = taskService.createTask(
      title: title,
      description: description,
      categoryId: categoryId,
      ownerId: userId,
      assignedTo: assignedTo,
      dueDate: dueDate,
    );

    if (task == null) {
      return Response.internalServerError(body: jsonEncode({'error': 'Failed to create task'}));
    }

    return Response.ok(jsonEncode({'task': task.toJson()}));
  });

  // PUT /api/tasks/:id - Update task
  router.put('/tasks/<id>', (Request request, String id) async {
    final userId = getUserId(request);
    if (userId == null) {
      return Response.unauthorized({'error': 'Unauthorized'});
    }

    final task = taskService.getTaskById(id);
    if (task == null || (task.ownerId != userId && task.assignedTo != userId)) {
      return Response.notFound('Task not found');
    }

    final body = await request.readAsString();
    final data = jsonDecode(body) as Map<String, dynamic>;

    final updatedTask = taskService.updateTask(
      id,
      title: data['title'] as String?,
      description: data['description'] as String?,
      isCompleted: data['is_completed'] as bool?,
      isPinned: data['is_pinned'] as bool?,
      categoryId: data['category_id'] as String?,
      assignedTo: data['assigned_to'] as String?,
      dueDate: data['due_date'] as String?,
    );

    if (updatedTask == null) {
      return Response.internalServerError(body: jsonEncode({'error': 'Failed to update task'}));
    }

    return Response.ok(jsonEncode({'task': updatedTask.toJson()}));
  });

  // PATCH /api/tasks/:id/toggle-complete - Toggle task completion
  router.patch('/tasks/<id>/toggle-complete', (Request request, String id) {
    final userId = getUserId(request);
    if (userId == null) {
      return Response.unauthorized({'error': 'Unauthorized'});
    }

    final task = taskService.toggleComplete(id);
    if (task == null) {
      return Response.notFound('Task not found');
    }

    return Response.ok(jsonEncode({'task': task.toJson()}));
  });

  // PATCH /api/tasks/:id/toggle-pin - Toggle task pinned status
  router.patch('/tasks/<id>/toggle-pin', (Request request, String id) {
    final userId = getUserId(request);
    if (userId == null) {
      return Response.unauthorized({'error': 'Unauthorized'});
    }

    final task = taskService.togglePin(id);
    if (task == null) {
      return Response.notFound('Task not found');
    }

    return Response.ok(jsonEncode({'task': task.toJson()}));
  });

  // POST /api/tasks/reorder - Reorder tasks
  router.post('/tasks/reorder', (Request request) async {
    final userId = getUserId(request);
    if (userId == null) {
      return Response.unauthorized({'error': 'Unauthorized'});
    }

    final body = await request.readAsString();
    final data = jsonDecode(body) as Map<String, dynamic>;

    final categoryId = data['category_id'] as String?;
    final taskIds = (data['task_ids'] as List?)?.cast<String>();

    if (categoryId == null || taskIds == null) {
      return Response.badRequest(body: jsonEncode({'error': 'category_id and task_ids are required'}));
    }

    final success = taskService.reorderTasks(categoryId, taskIds);
    if (!success) {
      return Response.internalServerError(body: jsonEncode({'error': 'Failed to reorder tasks'}));
    }

    return Response.ok(jsonEncode({'success': true}));
  });

  // DELETE /api/tasks/:id - Delete task
  router.delete('/tasks/<id>', (Request request, String id) {
    final userId = getUserId(request);
    if (userId == null) {
      return Response.unauthorized({'error': 'Unauthorized'});
    }

    final task = taskService.getTaskById(id);
    if (task == null || task.ownerId != userId) {
      return Response.notFound('Task not found');
    }

    final success = taskService.deleteTask(id);
    if (!success) {
      return Response.internalServerError(body: jsonEncode({'error': 'Failed to delete task'}));
    }

    return Response.ok(jsonEncode({'success': true}));
  });

  return router;
}

/// Create the complete Shelf handler with middleware and routes
Handler createHandler() {
  final pipeline = const Pipeline()
      .addMiddleware(corsHeaders())
      .addMiddleware(logRequests())
      .addMiddleware(createAuthMiddleware());

  final apiRouter = createApiRouter();

  return pipeline.addHandler((Request request) async {
    final path = request.url.path;
    
    // Route API requests
    if (path.startsWith('/api/')) {
      return apiRouter.call(request.change(url: request.url.replace(path: path.substring(4))));
    }
    
    return Response.notFound('Not found');
  });
}
