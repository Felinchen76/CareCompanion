import 'package:flutter/material.dart';
import '../services/agent_service.dart';
import '../models/task.dart';
import '../widgets/menu.dart';

class TasksScreen extends StatefulWidget {
  final AgentService agent;
  const TasksScreen({super.key, required this.agent});

  @override
  State<TasksScreen> createState() => _TasksScreenState();
}

class _TasksScreenState extends State<TasksScreen> {
  String _filterMode = 'all'; // 'all', 'open', 'done'

  @override
  Widget build(BuildContext context) {
    // Hole Tasks aus dem Agent
    List<Task> allTasks = [];
    try {
      allTasks = List<Task>.from(widget.agent.patient.tasks);
    } catch (e) {
      // fallback: leere Liste
    }

    // Filtern nach Modus
    final tasks = _filterMode == 'open'
        ? allTasks.where((t) => !t.done).toList()
        : _filterMode == 'done'
            ? allTasks.where((t) => t.done).toList()
            : allTasks;

    // Sortieren: offene Tasks nach Datum aufsteigend, erledigte ans Ende
    tasks.sort((a, b) {
      if (a.done != b.done) return a.done ? 1 : -1;
      return a.date.compareTo(b.date);
    });

    final openCount = allTasks.where((t) => !t.done).length;
    final doneCount = allTasks.where((t) => t.done).length;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Aufgaben'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            tooltip: 'Neue Aufgabe',
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Neue Aufgabe erstellen (Demo)')),
              );
            },
          ),
        ],
      ),
      drawer: const Menu(),
      body: Column(
        children: [
          // Header mit Statistik
          Container(
            width: double.infinity,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.purple.shade400, Colors.purple.shade700],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _buildStatCard('Offen', openCount, Icons.pending_actions, Colors.orange),
                    _buildStatCard('Erledigt', doneCount, Icons.check_circle, Colors.green),
                    _buildStatCard('Gesamt', allTasks.length, Icons.list, Colors.blue),
                  ],
                ),
              ],
            ),
          ),

          // Filter Chips
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                _buildFilterChip('Alle', 'all'),
                const SizedBox(width: 8),
                _buildFilterChip('Offen', 'open'),
                const SizedBox(width: 8),
                _buildFilterChip('Erledigt', 'done'),
              ],
            ),
          ),

          const Divider(height: 1),

          // Task Liste
          Expanded(
            child: tasks.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.task_alt, size: 80, color: Colors.grey.shade300),
                        const SizedBox(height: 16),
                        Text(
                          _filterMode == 'open'
                              ? 'Keine offenen Aufgaben'
                              : _filterMode == 'done'
                                  ? 'Keine erledigten Aufgaben'
                                  : 'Keine Aufgaben vorhanden',
                          style: TextStyle(fontSize: 18, color: Colors.grey.shade600),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    itemCount: tasks.length,
                    itemBuilder: (context, index) {
                      final task = tasks[index];
                      return _buildTaskCard(task);
                    },
                  ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Neue Aufgabe erstellen (Demo)')),
          );
        },
        icon: const Icon(Icons.add),
        label: const Text('Neue Aufgabe'),
        backgroundColor: Colors.purple.shade600,
      ),
    );
  }

  Widget _buildStatCard(String label, int value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.2),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Icon(icon, color: Colors.white, size: 32),
          const SizedBox(height: 8),
          Text(
            value.toString(),
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              color: Colors.white70,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String label, String mode) {
    final isSelected = _filterMode == mode;
    return FilterChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (selected) {
        setState(() {
          _filterMode = mode;
        });
      },
      selectedColor: Colors.purple.shade200,
      checkmarkColor: Colors.purple.shade700,
    );
  }

  Widget _buildTaskCard(Task task) {
    final isOverdue = !task.done && task.date.isBefore(DateTime.now());
    final dateStr = task.date.toLocal().toString().split(' ')[0];
    final today = DateTime.now();
    final isToday = task.date.year == today.year &&
        task.date.month == today.month &&
        task.date.day == today.day;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: task.done ? 1 : 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: Checkbox(
          value: task.done,
          onChanged: (val) {
            setState(() {
              // Toggle done status
              final idx = widget.agent.patient.tasks.indexWhere((t) => t.id == task.id);
              if (idx != -1) {
                final updated = Task(
                  id: task.id,
                  title: task.title,
                  date: task.date,
                  done: val ?? false,
                );
                (widget.agent.patient.tasks as List)[idx] = updated;
              }
            });
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(val == true ? 'Aufgabe erledigt!' : 'Aufgabe wieder geöffnet'),
                duration: const Duration(seconds: 1),
              ),
            );
          },
          activeColor: Colors.green,
        ),
        title: Text(
          task.title,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            decoration: task.done ? TextDecoration.lineThrough : null,
            color: task.done ? Colors.grey : Colors.black87,
          ),
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 6),
          child: Row(
            children: [
              Icon(
                Icons.calendar_today,
                size: 14,
                color: isOverdue ? Colors.red : Colors.grey.shade600,
              ),
              const SizedBox(width: 4),
              Text(
                isToday ? 'Heute' : dateStr,
                style: TextStyle(
                  fontSize: 13,
                  color: isOverdue ? Colors.red : Colors.grey.shade600,
                  fontWeight: isOverdue ? FontWeight.bold : FontWeight.normal,
                ),
              ),
              if (isOverdue) ...[
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.red.shade100,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    'Überfällig',
                    style: TextStyle(
                      fontSize: 10,
                      color: Colors.red.shade700,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
        trailing: PopupMenuButton(
          icon: const Icon(Icons.more_vert),
          itemBuilder: (context) => [
            const PopupMenuItem(
              value: 'details',
              child: Row(
                children: [
                  Icon(Icons.info_outline, size: 20),
                  SizedBox(width: 8),
                  Text('Details'),
                ],
              ),
            ),
            const PopupMenuItem(
              value: 'delete',
              child: Row(
                children: [
                  Icon(Icons.delete_outline, size: 20, color: Colors.red),
                  SizedBox(width: 8),
                  Text('Löschen', style: TextStyle(color: Colors.red)),
                ],
              ),
            ),
          ],
          onSelected: (value) {
            if (value == 'details') {
              _showTaskDetails(task);
            } else if (value == 'delete') {
              _deleteTask(task);
            }
          },
        ),
      ),
    );
  }

  void _showTaskDetails(Task task) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(task.title),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Datum: ${task.date.toLocal().toString().split(' ')[0]}'),
            const SizedBox(height: 8),
            Text('Status: ${task.done ? 'Erledigt' : 'Offen'}'),
            const SizedBox(height: 8),
            Text('ID: ${task.id}'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Schließen'),
          ),
        ],
      ),
    );
  }

  void _deleteTask(Task task) {
    setState(() {
      (widget.agent.patient.tasks as List).removeWhere((t) => t.id == task.id);
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Aufgabe "${task.title}" gelöscht'),
        action: SnackBarAction(
          label: 'Rückgängig',
          onPressed: () {
            setState(() {
              (widget.agent.patient.tasks as List).insert(0, task);
            });
          },
        ),
      ),
    );
  }
}