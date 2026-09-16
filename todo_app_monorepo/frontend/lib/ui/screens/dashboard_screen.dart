import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shamsi_date/shamsi_date.dart';
import '../../providers/providers.dart';
import '../../models/models.dart';
import '../widgets/task_card.dart';
import '../widgets/task_bottom_sheet.dart';

class DashboardScreen extends ConsumerStatefulWidget {
  const DashboardScreen({super.key});

  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen> {
  String? _selectedCategoryId;
  bool _showCompletedTasks = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await ref.read(categoriesProvider.notifier).refresh();
      await ref.read(tasksProvider.notifier).refresh();
      
      // Connect WebSocket with token
      final apiService = ref.read(apiServiceProvider);
      final token = await apiService.getToken();
      if (token != null && mounted) {
        ref.read(websocketServiceProvider).connect(token);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = ref.watch(currentUserProvider);
    final categoriesAsync = ref.watch(categoriesProvider);
    final tasksAsync = ref.watch(tasksProvider);
    final selectedCategory = ref.watch(selectedCategoryFilterProvider);

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Theme.of(context).colorScheme.primaryContainer.withOpacity(0.5),
              Theme.of(context).colorScheme.surface,
            ],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              _buildAppBar(context, currentUser),
              _buildCategoryFilter(categoriesAsync),
              Expanded(
                child: tasksAsync.when(
                  data: (tasks) {
                    // Filter tasks
                    var filteredTasks = tasks.where((task) {
                      if (_selectedCategoryId != null &&
                          task.categoryId != _selectedCategoryId) {
                        return false;
                      }
                      if (!_showCompletedTasks && task.isCompleted) {
                        return false;
                      }
                      return true;
                    }).toList();

                    // Sort: pinned first, then by order
                    filteredTasks.sort((a, b) {
                      if (a.isPinned && !b.isPinned) return -1;
                      if (!a.isPinned && b.isPinned) return 1;
                      return a.orderIndex.compareTo(b.orderIndex);
                    });

                    if (filteredTasks.isEmpty) {
                      return _buildEmptyState();
                    }

                    return ReorderableListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: filteredTasks.length,
                      onReorder: (oldIndex, newIndex) {
                        if (oldIndex < newIndex) {
                          newIndex -= 1;
                        }
                        _handleReorder(filteredTasks, oldIndex, newIndex);
                      },
                      itemBuilder: (context, index) {
                        final task = filteredTasks[index];
                        return TaskCard(
                          key: ValueKey(task.id),
                          task: task,
                          onToggleComplete: () =>
                              _toggleTaskComplete(task),
                          onTogglePin: () => _toggleTaskPin(task),
                          onEdit: () => _editTask(task),
                          onDelete: () => _deleteTask(task),
                        );
                      },
                    );
                  },
                  loading: () => const Center(child: CircularProgressIndicator()),
                  error: (error, stack) => Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.error_outline,
                          size: 64,
                          color: Theme.of(context).colorScheme.error,
                        ),
                        const SizedBox(height: 16),
                        Text('خطا در بارگذاری تسک‌ها'),
                        const SizedBox(height: 8),
                        Text(error.toString(), style: TextStyle(fontSize: 12)),
                        const SizedBox(height: 16),
                        FilledButton.icon(
                          onPressed: () {
                            ref.read(tasksProvider.notifier).refresh(categoryId: _selectedCategoryId);
                          },
                          icon: const Icon(Icons.refresh),
                          label: const Text('تلاش مجدد'),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showTaskBottomSheet(null),
        icon: const Icon(Icons.add),
        label: Text('تسک جدید', style: GoogleFonts.vazirmatn()),
      ),
    );
  }

  Widget _buildAppBar(BuildContext context, User? user) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Row(
        children: [
          CircleAvatar(
            radius: 24,
            backgroundColor: Theme.of(context).colorScheme.primary,
            child: Text(
              user?.username.substring(0, 1).toUpperCase() ?? '?',
              style: TextStyle(
                color: Theme.of(context).colorScheme.onPrimary,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'سلام، ${user?.username ?? 'کاربر'}',
                  style: GoogleFonts.vazirmatn(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  Jalali.now().formatFullDate(),
                  style: GoogleFonts.vazirmatn(
                    fontSize: 12,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () => _showLogoutDialog(context),
            tooltip: 'خروج',
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryFilter(AsyncValue<List<Category>> categoriesAsync) {
    return SizedBox(
      height: 50,
      child: categoriesAsync.when(
        data: (categories) {
          return ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: categories.length + 1,
            itemBuilder: (context, index) {
              if (index == 0) {
                final isSelected = _selectedCategoryId == null;
                return Padding(
                  padding: const EdgeInsets.only(left: 8),
                  child: FilterChip(
                    label: Text('همه', style: GoogleFonts.vazirmatn()),
                    selected: isSelected,
                    onSelected: (selected) {
                      setState(() {
                        _selectedCategoryId = null;
                      });
                      ref.read(selectedCategoryFilterProvider.notifier).state = null;
                      ref.read(tasksProvider.notifier).refresh();
                    },
                  ),
                );
              }
              final category = categories[index - 1];
              final isSelected = _selectedCategoryId == category.id;
              return Padding(
                padding: const EdgeInsets.only(left: 8),
                child: FilterChip(
                  label: Text(category.name, style: GoogleFonts.vazirmatn()),
                  selected: isSelected,
                  avatar: CircleAvatar(
                    backgroundColor: Color(int.parse(category.color.replaceFirst('#', '0xFF'))),
                    radius: 8,
                  ),
                  onSelected: (selected) {
                    setState(() {
                      _selectedCategoryId = selected ? category.id : null;
                    });
                    ref.read(selectedCategoryFilterProvider.notifier).state = selected ? category.id : null;
                    ref.read(tasksProvider.notifier).refresh(categoryId: selected ? category.id : null);
                  },
                ),
              );
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, __) => const SizedBox.shrink(),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.task_alt_outlined,
            size: 96,
            color: Theme.of(context).colorScheme.outline.withOpacity(0.5),
          ),
          const SizedBox(height: 16),
          Text(
            'هیچ تسکی وجود ندارد',
            style: GoogleFonts.vazirmatn(
              fontSize: 18,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'با زدن دکمه + یک تسک جدید اضافه کنید',
            style: GoogleFonts.vazirmatn(
              fontSize: 14,
              color: Theme.of(context).colorScheme.outline,
            ),
          ),
        ],
      ),
    );
  }

  void _handleReorder(List<Task> tasks, int oldIndex, int newIndex) async {
    final updatedList = List<Task>.from(tasks);
    final movedTask = updatedList.removeAt(oldIndex);
    updatedList.insert(newIndex, movedTask);

    // Update order indices
    final taskIds = updatedList.map((t) => t.id).toList();
    await ref.read(tasksProvider.notifier).reorderTasks(taskIds);
  }

  void _toggleTaskComplete(Task task) async {
    await ref.read(tasksProvider.notifier).toggleComplete(task);
  }

  void _toggleTaskPin(Task task) async {
    await ref.read(tasksProvider.notifier).togglePin(task);
  }

  void _editTask(Task task) {
    _showTaskBottomSheet(task);
  }

  void _deleteTask(Task task) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('حذف تسک'),
        content: Text('آیا از حذف "${task.title}" مطمئن هستید؟'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('انصراف'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            child: const Text('حذف'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await ref.read(tasksProvider.notifier).deleteTask(task.id);
    }
  }

  void _showTaskBottomSheet(Task? task) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => TaskBottomSheet(task: task),
    );
  }

  void _showLogoutDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('خروج'),
        content: const Text('آیا می‌خواهید از حساب کاربری خارج شوید؟'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('انصراف'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(context);
              ref.read(authNotifierProvider.notifier).logout();
            },
            child: const Text('خروج'),
          ),
        ],
      ),
    );
  }
}
