// lib/screens/todo_screen.dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

class TodoScreen extends StatefulWidget {
  const TodoScreen({super.key});

  @override
  // FIX: This is a common pattern that the linter flags.
  // The state class is private, but the method is public.
  // We can safely ignore this specific warning.
  // ignore: library_private_types_in_public_api
  _TodoScreenState createState() => _TodoScreenState();
}

class _TodoScreenState extends State<TodoScreen> {
  List<Map<String, dynamic>> _tasks = [];
  final TextEditingController _taskController = TextEditingController();

  static const String _tasksKey = 'todo_tasks';

  @override
  void initState() {
    super.initState();
    _loadTasks();
  }

  @override
  void dispose() {
    _taskController.dispose();
    super.dispose();
  }

  // --- Data Persistence Methods ---

  Future<void> _loadTasks() async {
    final prefs = await SharedPreferences.getInstance();
    final String? tasksString = prefs.getString(_tasksKey);
    if (tasksString != null && tasksString.isNotEmpty) {
      try {
        final List<dynamic> decodedTasks = jsonDecode(tasksString);
        if (mounted) {
          setState(() {
            _tasks = decodedTasks.map((task) {
              final Map<String, dynamic> taskMap =
                  Map<String, dynamic>.from(task);
              if (taskMap['dateTime'] != null) {
                taskMap['dateTime'] =
                    DateTime.tryParse(taskMap['dateTime'] as String);
              }
              return taskMap;
            }).toList();
            _sortTasks();
          });
        }
      } catch (e) {
        // FIX: Replaced print with debugPrint for better practice.
        debugPrint("Error decoding tasks: $e");
        await prefs.remove(_tasksKey);
      }
    }
  }

  Future<void> _saveTasks() async {
    final prefs = await SharedPreferences.getInstance();
    final List<Map<String, dynamic>> tasksToSave = _tasks.map((task) {
      final Map<String, dynamic> taskMap = Map<String, dynamic>.from(task);
      if (taskMap['dateTime'] != null && taskMap['dateTime'] is DateTime) {
        taskMap['dateTime'] =
            (taskMap['dateTime'] as DateTime).toIso8601String();
      }
      return taskMap;
    }).toList();
    final String tasksString = jsonEncode(tasksToSave);
    await prefs.setString(_tasksKey, tasksString);
  }

  void _sortTasks() {
    _tasks.sort((a, b) {
      final aCompleted = a['completed'] as bool;
      final bCompleted = b['completed'] as bool;
      if (aCompleted != bCompleted) {
        return aCompleted ? 1 : -1;
      }
      final aDateTime = a['dateTime'] as DateTime?;
      final bDateTime = b['dateTime'] as DateTime?;
      if (aDateTime != null && bDateTime != null) {
        return aDateTime.compareTo(bDateTime);
      }
      if (aDateTime != null) return -1;
      if (bDateTime != null) return 1;
      return 0;
    });
  }

  // --- UI Methods ---

  void _showAddTaskDialog(ThemeData theme) {
    _taskController.clear();
    DateTime? dialogSelectedDateTime;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (modalContext) {
        return StatefulBuilder(
            builder: (BuildContext context, StateSetter setModalState) {
          return Padding(
            padding: EdgeInsets.only(
              left: 20,
              right: 20,
              top: 24,
              bottom: MediaQuery.of(modalContext).viewInsets.bottom + 24,
            ),
            child: Container(
              decoration: BoxDecoration(
                  color: theme.cardColor,
                  borderRadius:
                      const BorderRadius.vertical(top: Radius.circular(20))),
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text("Add New Task",
                      style: theme.textTheme.headlineSmall
                          ?.copyWith(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 20),
                  TextField(
                    controller: _taskController,
                    decoration: InputDecoration(
                      hintText: "What do you need to do?",
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12)),
                      filled: true,
                      // FIX: `surfaceVariant` is deprecated, use `surfaceContainerHighest`.
                      // FIX: `withOpacity` is deprecated, use `withAlpha`. (255 * 0.3).round() = 77
                      fillColor: theme.colorScheme.surfaceContainerHighest
                          .withAlpha(77),
                      prefixIcon: Icon(Icons.edit_note_outlined,
                          color: theme.hintColor),
                    ),
                    autofocus: true,
                  ),
                  const SizedBox(height: 16),
                  Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: () async {
                        // FIX: Added a mounted check before using the context across an async gap.
                        if (!mounted) return;
                        DateTime? picked = await _pickDateTime(
                            modalContext, dialogSelectedDateTime);
                        if (picked != null) {
                          setModalState(() {
                            dialogSelectedDateTime = picked;
                          });
                        }
                      },
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            vertical: 12, horizontal: 12),
                        decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: theme.dividerColor)),
                        child: Row(
                          children: [
                            Icon(Icons.calendar_today_outlined,
                                color: theme.colorScheme.primary, size: 20),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                dialogSelectedDateTime != null
                                    ? DateFormat('EEE, MMM d, yyyy - hh:mm a')
                                        .format(dialogSelectedDateTime!)
                                    : "Set Reminder (Optional)",
                                style: TextStyle(
                                  color: dialogSelectedDateTime != null
                                      ? theme.textTheme.bodyLarge?.color
                                      : theme.hintColor,
                                  fontSize: 15,
                                ),
                              ),
                            ),
                            if (dialogSelectedDateTime != null)
                              IconButton(
                                icon: Icon(Icons.clear,
                                    size: 18, color: theme.hintColor),
                                onPressed: () {
                                  setModalState(() {
                                    dialogSelectedDateTime = null;
                                  });
                                },
                                tooltip: "Clear Reminder",
                              )
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () {
                        _addTask(dialogSelectedDateTime);
                        Navigator.pop(modalContext);
                      },
                      icon: const Icon(Icons.add_task_rounded),
                      label: const Text("Create Task"),
                      style: ElevatedButton.styleFrom(
                          backgroundColor: theme.colorScheme.primary,
                          foregroundColor: theme.colorScheme.onPrimary,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                          textStyle: const TextStyle(
                              fontSize: 16, fontWeight: FontWeight.w500)),
                    ),
                  ),
                ],
              ),
            ),
          );
        });
      },
    );
  }

  Future<DateTime?> _pickDateTime(
      BuildContext pickerContext, DateTime? initialDateTime) async {
    DateTime now = DateTime.now();
    DateTime initialDate = initialDateTime ?? now;
    if (initialDate.isBefore(now) && initialDateTime == null) initialDate = now;

    DateTime? pickedDate = await showDatePicker(
        context: pickerContext,
        initialDate: initialDate,
        firstDate: now,
        lastDate: DateTime(now.year + 5),
        builder: (context, child) {
          return Theme(
            data: Theme.of(context).copyWith(
              colorScheme: Theme.of(context).colorScheme.copyWith(
                    primary: Theme.of(context).colorScheme.primary,
                    onPrimary: Theme.of(context).colorScheme.onPrimary,
                    onSurface: Theme.of(context).textTheme.bodyLarge?.color,
                  ),
              textButtonTheme: TextButtonThemeData(
                style: TextButton.styleFrom(
                  foregroundColor: Theme.of(context).colorScheme.primary,
                ),
              ),
            ),
            child: child!,
          );
        });

    if (pickedDate == null || !mounted) return null;

    TimeOfDay initialTime = TimeOfDay.fromDateTime(initialDateTime ??
        DateTime(now.year, now.month, now.day, now.hour + 1));

    TimeOfDay? pickedTime = await showTimePicker(
        context: pickerContext,
        initialTime: initialTime,
        builder: (context, child) {
          return Theme(
            data: Theme.of(context).copyWith(
              colorScheme: Theme.of(context).colorScheme.copyWith(
                    primary: Theme.of(context).colorScheme.primary,
                    onPrimary: Theme.of(context).colorScheme.onPrimary,
                    surface: Theme.of(context).cardColor,
                    onSurface: Theme.of(context).textTheme.bodyLarge?.color,
                  ),
            ),
            child: child!,
          );
        });

    if (pickedTime != null) {
      return DateTime(
        pickedDate.year,
        pickedDate.month,
        pickedDate.day,
        pickedTime.hour,
        pickedTime.minute,
      );
    }
    return pickedDate;
  }

  void _addTask(DateTime? taskDateTime) {
    if (_taskController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text("Task title cannot be empty."),
            backgroundColor: Colors.orange),
      );
      return;
    }
    if (mounted) {
      setState(() {
        _tasks.add({
          'id': DateTime.now().millisecondsSinceEpoch.toString(),
          'title': _taskController.text.trim(),
          'dateTime': taskDateTime,
          'completed': false,
        });
        _sortTasks();
      });
      _saveTasks();
    }
  }

  void _toggleTask(int index) {
    if (mounted) {
      setState(() {
        _tasks[index]['completed'] = !_tasks[index]['completed'];
        _sortTasks();
      });
      _saveTasks();
    }
  }

  void _removeTask(int index) {
    if (mounted) {
      final removedTaskTitle = _tasks[index]['title'];
      setState(() => _tasks.removeAt(index));
      _saveTasks();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text("Task '$removedTaskTitle' removed."),
            backgroundColor: Colors.grey.shade700),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text("My To-Do List"),
        elevation: 0.5,
      ),
      body: _tasks.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.check_circle_outline_rounded,
                      size: 80, color: Colors.grey[300]),
                  const SizedBox(height: 20),
                  Text("No tasks yet!",
                      style: theme.textTheme.headlineSmall
                          ?.copyWith(color: Colors.grey[500])),
                  const SizedBox(height: 8),
                  Text("Tap the '+' button to add your first task.",
                      style: theme.textTheme.bodyMedium
                          ?.copyWith(color: Colors.grey[400])),
                ],
              ),
            )
          : ListView.separated(
              padding:
                  const EdgeInsets.symmetric(horizontal: 12.0, vertical: 16.0),
              itemCount: _tasks.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (context, index) {
                final task = _tasks[index];
                final bool isCompleted = task['completed'] as bool;
                final DateTime? taskDateTime = task['dateTime'] as DateTime?;
                final bool isOverdue = taskDateTime != null &&
                    !isCompleted &&
                    taskDateTime.isBefore(DateTime.now());

                return Card(
                  elevation: 1.5,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: isOverdue
                        ? BorderSide(color: theme.colorScheme.error, width: 1.5)
                        : BorderSide.none,
                  ),
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(
                        vertical: 8.0, horizontal: 12.0),
                    leading: Checkbox.adaptive(
                      value: isCompleted,
                      onChanged: (bool? value) {
                        if (value != null) _toggleTask(index);
                      },
                      activeColor: theme.colorScheme.primary,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(4)),
                    ),
                    title: Text(
                      task['title'] as String,
                      style: theme.textTheme.titleMedium?.copyWith(
                          decoration:
                              isCompleted ? TextDecoration.lineThrough : null,
                          color: isCompleted
                              ? theme.hintColor
                              : theme.textTheme.bodyLarge?.color,
                          fontWeight: isCompleted
                              ? FontWeight.normal
                              : FontWeight.w500),
                    ),
                    subtitle: taskDateTime != null
                        ? Text(
                            DateFormat('EEE, MMM d, yyyy hh:mm a')
                                .format(taskDateTime),
                            style: TextStyle(
                              fontSize: 13,
                              // FIX: `withOpacity` is deprecated, use `withAlpha`. (255 * 0.7).round() = 179
                              color: isCompleted
                                  ? theme.hintColor.withAlpha(179)
                                  : (isOverdue
                                      ? theme.colorScheme.error
                                      : theme.hintColor),
                              decoration: isCompleted
                                  ? TextDecoration.lineThrough
                                  : null,
                            ),
                          )
                        : null,
                    trailing: IconButton(
                      // FIX: `withOpacity` is deprecated, use `withAlpha`. (255 * 0.7).round() = 179
                      icon: Icon(Icons.delete_sweep_outlined,
                          color: theme.colorScheme.error.withAlpha(179)),
                      onPressed: () => _removeTask(index),
                      tooltip: "Remove Task",
                    ),
                    onTap: () => _toggleTask(index),
                  ),
                );
              },
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddTaskDialog(theme),
        backgroundColor: theme.colorScheme.primaryContainer,
        foregroundColor: theme.colorScheme.onPrimaryContainer,
        icon: const Icon(Icons.add_rounded),
        label: const Text("New Task"),
        elevation: 4.0,
      ),
    );
  }
}
