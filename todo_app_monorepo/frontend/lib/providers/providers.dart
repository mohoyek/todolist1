import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/models.dart';
import '../services/api_service.dart';
import '../services/websocket_service.dart';

// API Service Provider
final apiServiceProvider = Provider<ApiService>((ref) {
  return ApiService(baseUrl: 'http://localhost:8080/api');
});

// WebSocket Service Provider
final websocketServiceProvider = Provider<WebSocketService>((ref) {
  return WebSocketService(wsUrl: 'ws://localhost:8080/ws');
});

// Auth State
class AuthState {
  final User? user;
  final String? token;
  final bool isLoading;
  final String? error;

  AuthState({this.user, this.token, this.isLoading = false, this.error});

  bool get isAuthenticated => user != null && token != null;

  AuthState copyWith({
    User? user,
    String? token,
    bool? isLoading,
    String? error,
  }) {
    return AuthState(
      user: user ?? this.user,
      token: token ?? this.token,
      isLoading: isLoading ?? this.isLoading,
      error: error ?? this.error,
    );
  }
}

final authNotifierProvider = StateNotifierProvider<AuthNotifier, AsyncValue<AuthState>>((ref) {
  return AuthNotifier(ref.watch(apiServiceProvider));
});

class AuthNotifier extends StateNotifier<AsyncValue<AuthState>> {
  final ApiService _apiService;

  AuthNotifier(this._apiService) : super(const AsyncValue.data(AuthState()));

  Future<bool> login(String username, String password) async {
    state = const AsyncValue.loading();
    try {
      final result = await _apiService.login(username, password);
      final user = User.fromJson(result['user'] as Map<String, dynamic>);
      state = AsyncValue.data(AuthState(user: user, token: result['token'] as String));
      return true;
    } catch (e) {
      state = AsyncValue.data(AuthState(error: e.toString()));
      return false;
    }
  }

  Future<bool> register(String username, String password, String? email) async {
    state = const AsyncValue.loading();
    try {
      final result = await _apiService.register(username, password, email);
      final user = User.fromJson(result['user'] as Map<String, dynamic>);
      state = AsyncValue.data(AuthState(user: user, token: result['token'] as String));
      return true;
    } catch (e) {
      state = AsyncValue.data(AuthState(error: e.toString()));
      return false;
    }
  }

  Future<void> loadCurrentUser() async {
    state = const AsyncValue.loading();
    try {
      final user = await _apiService.getCurrentUser();
      final token = await _apiService.getToken();
      state = AsyncValue.data(AuthState(user: user, token: token));
    } catch (e) {
      state = AsyncValue.data(AuthState(error: e.toString()));
    }
  }

  Future<void> logout() async {
    await _apiService.clearToken();
    state = const AsyncValue.data(AuthState());
  }
}

// Tasks Provider
final tasksProvider = StateNotifierProvider<TasksNotifier, AsyncValue<List<Task>>>((ref) {
  return TasksNotifier(
    ref.watch(apiServiceProvider),
    ref.watch(websocketServiceProvider),
  );
});

class TasksNotifier extends StateNotifier<AsyncValue<List<Task>>> {
  final ApiService _apiService;
  final WebSocketService _webSocketService;
  StreamSubscription? _wsSubscription;

  TasksNotifier(this._apiService, this._webSocketService)
      : super(const AsyncValue.data([])) {
    _initWebSocket();
  }

  void _initWebSocket() {
    _wsSubscription = _webSocketService.messageStream.listen((message) {
      final type = message['type'] as String?;
      if (type == 'task_updated' || type == 'task_created' || type == 'task_deleted') {
        refresh();
      }
    });
  }

  @override
  void dispose() {
    _wsSubscription?.cancel();
    super.dispose();
  }

  Future<void> refresh({String? categoryId}) async {
    state = const AsyncValue.loading();
    try {
      final tasks = await _apiService.getTasks(categoryId: categoryId);
      state = AsyncValue.data(tasks);
    } catch (e) {
      state = AsyncValue.error(e, StackTrace.current);
    }
  }

  Future<void> createTask(Task task) async {
    try {
      await _apiService.createTask(task);
      await refresh();
    } catch (e) {
      rethrow;
    }
  }

  Future<void> updateTask(Task task) async {
    try {
      await _apiService.updateTask(task);
      await refresh();
    } catch (e) {
      rethrow;
    }
  }

  Future<void> deleteTask(String taskId) async {
    try {
      await _apiService.deleteTask(taskId);
      await refresh();
    } catch (e) {
      rethrow;
    }
  }

  Future<void> reorderTasks(List<String> taskIds) async {
    try {
      await _apiService.reorderTasks(taskIds);
      await refresh();
    } catch (e) {
      rethrow;
    }
  }

  Future<void> togglePin(Task task) async {
    final updatedTask = task.copyWith(isPinned: !task.isPinned);
    await updateTask(updatedTask);
  }

  Future<void> toggleComplete(Task task) async {
    final updatedTask = task.copyWith(isCompleted: !task.isCompleted);
    await updateTask(updatedTask);
  }
}

// Categories Provider
final categoriesProvider = StateNotifierProvider<CategoriesNotifier, AsyncValue<List<Category>>>((ref) {
  return CategoriesNotifier(ref.watch(apiServiceProvider));
});

class CategoriesNotifier extends StateNotifier<AsyncValue<List<Category>>> {
  final ApiService _apiService;

  CategoriesNotifier(this._apiService) : super(const AsyncValue.data([]));

  Future<void> refresh() async {
    state = const AsyncValue.loading();
    try {
      final categories = await _apiService.getCategories();
      state = AsyncValue.data(categories);
    } catch (e) {
      state = AsyncValue.error(e, StackTrace.current);
    }
  }

  Future<void> createCategory(Category category) async {
    try {
      await _apiService.createCategory(category);
      await refresh();
    } catch (e) {
      rethrow;
    }
  }

  Future<void> deleteCategory(String categoryId) async {
    try {
      await _apiService.deleteCategory(categoryId);
      await refresh();
    } catch (e) {
      rethrow;
    }
  }
}

// Users Provider
final usersProvider = FutureProvider<List<User>>((ref) async {
  final apiService = ref.watch(apiServiceProvider);
  return await apiService.getAllUsers();
});

// Selected Category Filter
final selectedCategoryFilterProvider = StateProvider<String?>((ref) => null);

// Current User Provider
final currentUserProvider = Provider<User?>((ref) {
  final authState = ref.watch(authNotifierProvider);
  return authState.value?.user;
});
