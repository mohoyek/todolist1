import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../models/models.dart';

class ApiService {
  final String baseUrl;
  String? _token;

  ApiService({required this.baseUrl});

  Future<String?> getToken() async {
    if (_token != null) return _token;
    final prefs = await SharedPreferences.getInstance();
    _token = prefs.getString('jwt_token');
    return _token;
  }

  Future<void> setToken(String token) async {
    _token = token;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('jwt_token', token);
  }

  Future<void> clearToken() async {
    _token = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('jwt_token');
  }

  Map<String, String> get _headers {
    final headers = {'Content-Type': 'application/json'};
    if (_token != null) {
      headers['Authorization'] = 'Bearer $_token';
    }
    return headers;
  }

  // Auth
  Future<Map<String, dynamic>> login(String username, String password) async {
    final response = await http.post(
      Uri.parse('$baseUrl/auth/login'),
      headers: _headers,
      body: jsonEncode({'username': username, 'password': password}),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      await setToken(data['token'] as String);
      return data;
    } else {
      throw Exception('Login failed: ${response.body}');
    }
  }

  Future<Map<String, dynamic>> register(String username, String password, String? email) async {
    final response = await http.post(
      Uri.parse('$baseUrl/auth/register'),
      headers: _headers,
      body: jsonEncode({'username': username, 'password': password, 'email': email}),
    );

    if (response.statusCode == 201) {
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      await setToken(data['token'] as String);
      return data;
    } else {
      throw Exception('Registration failed: ${response.body}');
    }
  }

  Future<User> getCurrentUser() async {
    final response = await http.get(
      Uri.parse('$baseUrl/auth/me'),
      headers: _headers,
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      return User.fromJson(data['user'] as Map<String, dynamic>);
    } else {
      throw Exception('Failed to get current user: ${response.body}');
    }
  }

  // Tasks
  Future<List<Task>> getTasks({String? categoryId}) async {
    final uri = categoryId != null
        ? Uri.parse('$baseUrl/tasks?category_id=$categoryId')
        : Uri.parse('$baseUrl/tasks');

    final response = await http.get(uri, headers: _headers);

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body) as List<dynamic>;
      return data.map((e) => Task.fromJson(e as Map<String, dynamic>)).toList();
    } else {
      throw Exception('Failed to load tasks: ${response.body}');
    }
  }

  Future<Task> createTask(Task task) async {
    final response = await http.post(
      Uri.parse('$baseUrl/tasks'),
      headers: _headers,
      body: jsonEncode(task.toJson()),
    );

    if (response.statusCode == 201) {
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      return Task.fromJson(data);
    } else {
      throw Exception('Failed to create task: ${response.body}');
    }
  }

  Future<Task> updateTask(Task task) async {
    final response = await http.put(
      Uri.parse('$baseUrl/tasks/${task.id}'),
      headers: _headers,
      body: jsonEncode(task.toJson()),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      return Task.fromJson(data);
    } else {
      throw Exception('Failed to update task: ${response.body}');
    }
  }

  Future<void> deleteTask(String taskId) async {
    final response = await http.delete(
      Uri.parse('$baseUrl/tasks/$taskId'),
      headers: _headers,
    );

    if (response.statusCode != 204) {
      throw Exception('Failed to delete task: ${response.body}');
    }
  }

  Future<List<Task>> reorderTasks(List<String> taskIds) async {
    final response = await http.post(
      Uri.parse('$baseUrl/tasks/reorder'),
      headers: _headers,
      body: jsonEncode({'task_ids': taskIds}),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body) as List<dynamic>;
      return data.map((e) => Task.fromJson(e as Map<String, dynamic>)).toList();
    } else {
      throw Exception('Failed to reorder tasks: ${response.body}');
    }
  }

  // Categories
  Future<List<Category>> getCategories() async {
    final response = await http.get(
      Uri.parse('$baseUrl/categories'),
      headers: _headers,
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body) as List<dynamic>;
      return data.map((e) => Category.fromJson(e as Map<String, dynamic>)).toList();
    } else {
      throw Exception('Failed to load categories: ${response.body}');
    }
  }

  Future<Category> createCategory(Category category) async {
    final response = await http.post(
      Uri.parse('$baseUrl/categories'),
      headers: _headers,
      body: jsonEncode(category.toJson()),
    );

    if (response.statusCode == 201) {
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      return Category.fromJson(data);
    } else {
      throw Exception('Failed to create category: ${response.body}');
    }
  }

  Future<void> deleteCategory(String categoryId) async {
    final response = await http.delete(
      Uri.parse('$baseUrl/categories/$categoryId'),
      headers: _headers,
    );

    if (response.statusCode != 204) {
      throw Exception('Failed to delete category: ${response.body}');
    }
  }

  // Users
  Future<List<User>> getAllUsers() async {
    final response = await http.get(
      Uri.parse('$baseUrl/users'),
      headers: _headers,
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body) as List<dynamic>;
      return data.map((e) => User.fromJson(e as Map<String, dynamic>)).toList();
    } else {
      throw Exception('Failed to load users: ${response.body}');
    }
  }
}
