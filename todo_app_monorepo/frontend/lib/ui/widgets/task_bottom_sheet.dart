import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:persian_datetime_picker/persian_datetime_picker.dart';
import 'package:shamsi_date/shamsi_date.dart';
import '../../providers/providers.dart';
import '../../models/models.dart';

class TaskBottomSheet extends ConsumerStatefulWidget {
  final Task? task;

  const TaskBottomSheet({super.key, this.task});

  @override
  ConsumerState<TaskBottomSheet> createState() => _TaskBottomSheetState();
}

class _TaskBottomSheetState extends ConsumerState<TaskBottomSheet> {
  late TextEditingController _titleController;
  late TextEditingController _descriptionController;
  String? _selectedCategoryId;
  String? _selectedAssignedTo;
  String? _selectedDueDate;
  bool _isPinned = false;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.task?.title ?? '');
    _descriptionController =
        TextEditingController(text: widget.task?.description ?? '');
    _selectedCategoryId = widget.task?.categoryId;
    _selectedAssignedTo = widget.task?.assignedTo;
    _selectedDueDate = widget.task?.dueDate;
    _isPinned = widget.task?.isPinned ?? false;
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _selectDueDate() async {
    final picked = await showPersianDatePicker(
      context: context,
      initialDate: Jalali.now(),
      firstDate: Jalali(1300, 1, 1),
      lastDate: Jalali(1450, 12, 29),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: Theme.of(context).colorScheme,
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        _selectedDueDate = picked.formatFullDate();
      });
    }
  }

  Future<void> _saveTask() async {
    if (_titleController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('لطفاً عنوان تسک را وارد کنید')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final task = Task(
        id: widget.task?.id ?? DateTime.now().millisecondsSinceEpoch.toString(),
        title: _titleController.text.trim(),
        description: _descriptionController.text.trim().isEmpty
            ? null
            : _descriptionController.text.trim(),
        isCompleted: widget.task?.isCompleted ?? false,
        isPinned: _isPinned,
        orderIndex: widget.task?.orderIndex ?? 0,
        dueDate: _selectedDueDate,
        categoryId: _selectedCategoryId,
        assignedTo: _selectedAssignedTo,
        createdBy: widget.task?.createdBy ?? '',
        createdAt: widget.task?.createdAt ?? DateTime.now(),
        updatedAt: DateTime.now(),
      );

      if (widget.task == null) {
        await ref.read(tasksProvider.notifier).createTask(task);
      } else {
        await ref.read(tasksProvider.notifier).updateTask(task);
      }

      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('خطا: ${e.toString()}')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final categoriesAsync = ref.watch(categoriesProvider);
    final usersAsync = ref.watch(usersProvider);

    return Container(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    widget.task == null ? 'تسک جدید' : 'ویرایش تسک',
                    style: GoogleFonts.vazirmatn(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              TextField(
                controller: _titleController,
                decoration: InputDecoration(
                  labelText: 'عنوان *',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  prefixIcon: const Icon(Icons.title),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _descriptionController,
                maxLines: 3,
                decoration: InputDecoration(
                  labelText: 'توضیحات',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  prefixIcon: const Icon(Icons.description),
                ),
              ),
              const SizedBox(height: 16),
              // Category dropdown
              categoriesAsync.when(
                data: (categories) {
                  return DropdownButtonFormField<String>(
                    value: _selectedCategoryId,
                    decoration: InputDecoration(
                      labelText: 'دسته‌بندی',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      prefixIcon: const Icon(Icons.category),
                    ),
                    items: [
                      const DropdownMenuItem(
                        value: null,
                        child: Text('بدون دسته‌بندی'),
                      ),
                      ...categories.map((category) {
                        return DropdownMenuItem(
                          value: category.id,
                          child: Row(
                            children: [
                              CircleAvatar(
                                backgroundColor: Color(
                                  int.parse(
                                    category.color.replaceFirst('#', '0xFF'),
                                  ),
                                ),
                                radius: 8,
                              ),
                              const SizedBox(width: 8),
                              Text(category.name),
                            ],
                          ),
                        );
                      }),
                    ],
                    onChanged: (value) {
                      setState(() => _selectedCategoryId = value);
                    },
                  );
                },
                loading: () => const CircularProgressIndicator(),
                error: (_, __) => const SizedBox.shrink(),
              ),
              const SizedBox(height: 16),
              // User assignment dropdown
              usersAsync.when(
                data: (users) {
                  final currentUser = ref.read(currentUserProvider);
                  final otherUsers =
                      users.where((u) => u.id != currentUser?.id).toList();

                  if (otherUsers.isEmpty) {
                    return const SizedBox.shrink();
                  }

                  return DropdownButtonFormField<String>(
                    value: _selectedAssignedTo,
                    decoration: InputDecoration(
                      labelText: 'واگذاری به',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      prefixIcon: const Icon(Icons.person_add),
                    ),
                    items: [
                      const DropdownMenuItem(
                        value: null,
                        child: Text('بدون واگذاری'),
                      ),
                      ...otherUsers.map((user) {
                        return DropdownMenuItem(
                          value: user.id,
                          child: Text(user.username),
                        );
                      }),
                    ],
                    onChanged: (value) {
                      setState(() => _selectedAssignedTo = value);
                    },
                  );
                },
                loading: () => const CircularProgressIndicator(),
                error: (_, __) => const SizedBox.shrink(),
              ),
              const SizedBox(height: 16),
              // Due date picker
              InkWell(
                onTap: _selectDueDate,
                borderRadius: BorderRadius.circular(12),
                child: InputDecorator(
                  decoration: InputDecoration(
                    labelText: 'تاریخ سررسید',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    prefixIcon: const Icon(Icons.calendar_today),
                    suffixIcon: _selectedDueDate != null
                        ? IconButton(
                            icon: const Icon(Icons.clear, size: 20),
                            onPressed: () {
                              setState(() => _selectedDueDate = null);
                            },
                          )
                        : null,
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          _selectedDueDate ?? 'انتخاب تاریخ',
                          style: GoogleFonts.vazirmatn(
                            color: _selectedDueDate != null
                                ? Theme.of(context).colorScheme.onSurface
                                : Theme.of(context).colorScheme.outline,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              // Pin toggle
              SwitchListTile(
                title: Text('پین کردن (مهم)', style: GoogleFonts.vazirmatn()),
                subtitle: Text(
                  'نمایش در بالای لیست',
                  style: GoogleFonts.vazirmatn(fontSize: 12),
                ),
                value: _isPinned,
                onChanged: (value) {
                  setState(() => _isPinned = value);
                },
                secondary: Icon(
                  _isPinned ? Icons.push_pin : Icons.push_pin_outlined,
                  color: _isPinned
                      ? Theme.of(context).colorScheme.primary
                      : Theme.of(context).colorScheme.outline,
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: FilledButton.icon(
                  onPressed: _isLoading ? null : _saveTask,
                  icon: _isLoading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.save),
                  label: Text(_isLoading ? 'در حال ذخیره...' : 'ذخیره'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
