import 'package:flutter/material.dart';
import '../services/agent_service.dart';
import '../widgets/menu.dart';

class DashboardScreen extends StatelessWidget {
  final AgentService agent;
  const DashboardScreen({super.key, required this.agent});

  @override
  Widget build(BuildContext context) {
    // Statistiken berechnen (mit safe access)
    int openTasks = 0;
    int totalTasks = 0;
    try {
      final tasks = agent.patient.tasks as List;
      totalTasks = tasks.length;
      openTasks = tasks.where((t) {
        try {
          // Versuche done-Property (aus task.dart)
          return !(t.done ?? false);
        } catch (_) {
          // Fallback: versuche isCompleted
          try {
            return !(t.isCompleted ?? false);
          } catch (_) {
            return true; // wenn unklar, zähle als offen
          }
        }
      }).length;
    } catch (e) {
      // ignore: avoid_print
      print('Tasks access error: $e');
    }

    List<dynamic> upcomingAppointments = [];
    dynamic nextAppointment;
    try {
      final apps = agent.patient.appointments as List;
      upcomingAppointments = apps
          .where((a) {
            try {
              return a.date.isAfter(DateTime.now());
            } catch (_) {
              return false;
            }
          })
          .toList()
        ..sort((a, b) {
          try {
            return a.date.compareTo(b.date);
          } catch (_) {
            return 0;
          }
        });
      nextAppointment = upcomingAppointments.isNotEmpty ? upcomingAppointments.first : null;
    } catch (e) {
      // ignore: avoid_print
      print('Appointments access error: $e');
    }

    int medicationsCount = 0;
    List<dynamic> medications = [];
    try {
      medications = agent.patient.medications as List;
      medicationsCount = medications.length;
    } catch (e) {
      // ignore: avoid_print
      print('Medications access error: $e');
    }

    int notesCount = 0;
    List<dynamic> notes = [];
    try {
      notes = agent.patient.medicalNotes as List;
      notesCount = notes.length;
    } catch (e) {
      // ignore: avoid_print
      print('Medical notes access error: $e');
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Dashboard'),
        actions: [
          IconButton(
            icon: Icon(
              agent.isRunning ? Icons.pause_circle : Icons.play_circle,
              color: agent.isRunning ? Colors.green : Colors.grey,
            ),
            tooltip: agent.isRunning ? 'Agent läuft' : 'Agent pausiert',
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(agent.isRunning ? 'Agent läuft aktiv' : 'Agent ist pausiert'),
                ),
              );
            },
          ),
        ],
      ),
      drawer: const Menu(),
      body: RefreshIndicator(
        onRefresh: () async {
          await Future.delayed(const Duration(seconds: 1));
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Dashboard aktualisiert')),
            );
          }
        },
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Willkommens-Header
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.blue.shade400, Colors.blue.shade700],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.blue.shade200,
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.waving_hand, color: Colors.white, size: 28),
                      SizedBox(width: 8),
                      Text(
                        'Willkommen zurück!',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Heute ist ${_formatDate(DateTime.now())}',
                    style: const TextStyle(
                      fontSize: 14,
                      color: Colors.white70,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // Quick Stats
            Row(
              children: [
                Expanded(
                  child: _buildStatCard(
                    icon: Icons.task_alt,
                    label: 'Offene Aufgaben',
                    value: '$openTasks/$totalTasks',
                    color: Colors.orange,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildStatCard(
                    icon: Icons.medication,
                    label: 'Medikamente',
                    value: '$medicationsCount',
                    color: Colors.red,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 12),

            Row(
              children: [
                Expanded(
                  child: _buildStatCard(
                    icon: Icons.calendar_today,
                    label: 'Termine',
                    value: '${upcomingAppointments.length}',
                    color: Colors.green,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildStatCard(
                    icon: Icons.description,
                    label: 'Dokumente',
                    value: '$notesCount',
                    color: Colors.purple,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 24),

            // Nächster Termin (Highlight)
            if (nextAppointment != null) ...[
              _buildSectionHeader('Nächster Termin', Icons.event),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.green.shade300, Colors.green.shade600],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.green.shade200,
                      blurRadius: 8,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.3),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.event_available, color: Colors.white, size: 32),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _safeGetProperty(nextAppointment, 'type', 'Termin'),
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _formatDate(_safeGetDate(nextAppointment)),
                            style: const TextStyle(
                              fontSize: 14,
                              color: Colors.white70,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Icon(Icons.arrow_forward_ios, color: Colors.white, size: 20),
                  ],
                ),
              ),
              const SizedBox(height: 24),
            ],

            // Aufgaben
            _buildSectionHeader('Aufgaben', Icons.task),
            const SizedBox(height: 12),
            if (totalTasks == 0)
              _buildEmptyState('Keine Aufgaben vorhanden', Icons.task_alt)
            else
              ..._buildTasksList(),

            const SizedBox(height: 24),

            // Medikamente
            _buildSectionHeader('Medikamente', Icons.medication),
            const SizedBox(height: 12),
            if (medicationsCount == 0)
              _buildEmptyState('Keine Medikamente erfasst', Icons.medication)
            else
              ..._buildMedicationsList(medications),

            const SizedBox(height: 24),

            // Termine
            _buildSectionHeader('Bevorstehende Termine', Icons.calendar_today),
            const SizedBox(height: 12),
            if (upcomingAppointments.isEmpty)
              _buildEmptyState('Keine bevorstehenden Termine', Icons.event_busy)
            else
              ..._buildAppointmentsList(upcomingAppointments),

            const SizedBox(height: 24),

            // Dokumente
            _buildSectionHeader('Dokumente', Icons.description),
            const SizedBox(height: 12),
            if (notesCount == 0)
              _buildEmptyState('Keine Dokumente vorhanden', Icons.description)
            else
              ..._buildNotesList(notes),

            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildTasksList() {
    try {
      final tasks = (agent.patient.tasks as List).take(5);
      return tasks.map((task) {
        bool isDone = false;
        try {
          isDone = task.done ?? false;
        } catch (_) {
          try {
            isDone = task.isCompleted ?? false;
          } catch (_) {}
        }
        final title = _safeGetProperty(task, 'title', 'Aufgabe');
        final date = _safeGetDate(task);

        return Card(
          margin: const EdgeInsets.only(bottom: 8),
          elevation: 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          child: ListTile(
            leading: Icon(
              isDone ? Icons.check_circle : Icons.radio_button_unchecked,
              color: isDone ? Colors.green : Colors.orange,
            ),
            title: Text(
              title,
              style: TextStyle(
                decoration: isDone ? TextDecoration.lineThrough : null,
                fontWeight: FontWeight.w600,
              ),
            ),
            subtitle: Text(
              _formatDate(date),
              style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
            ),
            trailing: const Icon(Icons.arrow_forward_ios, size: 16),
          ),
        );
      }).toList();
    } catch (e) {
      return [_buildEmptyState('Fehler beim Laden der Aufgaben', Icons.error)];
    }
  }

  List<Widget> _buildMedicationsList(List<dynamic> medications) {
    try {
      return medications.take(5).map((med) {
        final name = _safeGetProperty(med, 'name', 'Medikament');
        final dose = _safeGetProperty(med, 'dose', '');
        int amountLeft = 0;
        try {
          amountLeft = med.amountLeft ?? 0;
        } catch (_) {}

        return Card(
          margin: const EdgeInsets.only(bottom: 8),
          elevation: 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: Colors.red.shade100,
              child: Icon(Icons.medication, color: Colors.red.shade700),
            ),
            title: Text(
              name,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            subtitle: Text(
              '$dose • Noch $amountLeft Stück',
              style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
            ),
            trailing: amountLeft < 10
                ? Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.red.shade100,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      'Niedrig',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: Colors.red.shade700,
                      ),
                    ),
                  )
                : null,
          ),
        );
      }).toList();
    } catch (e) {
      return [_buildEmptyState('Fehler beim Laden der Medikamente', Icons.error)];
    }
  }

  List<Widget> _buildAppointmentsList(List<dynamic> appointments) {
    try {
      return appointments.take(5).map((app) {
        final type = _safeGetProperty(app, 'type', 'Termin');
        final date = _safeGetDate(app);

        return Card(
          margin: const EdgeInsets.only(bottom: 8),
          elevation: 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: Colors.green.shade100,
              child: Icon(Icons.event, color: Colors.green.shade700),
            ),
            title: Text(
              type,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            subtitle: Text(
              _formatDate(date),
              style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
            ),
            trailing: const Icon(Icons.arrow_forward_ios, size: 16),
          ),
        );
      }).toList();
    } catch (e) {
      return [_buildEmptyState('Fehler beim Laden der Termine', Icons.error)];
    }
  }

  List<Widget> _buildNotesList(List<dynamic> notes) {
    try {
      return notes.take(5).map((doc) {
        final title = _safeGetProperty(doc, 'title', 'Dokument');
        final type = _safeGetProperty(doc, 'type', 'Notiz');
        final date = _safeGetDate(doc);

        return Card(
          margin: const EdgeInsets.only(bottom: 8),
          elevation: 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: Colors.purple.shade100,
              child: Icon(
                _getDocIcon(type),
                color: Colors.purple.shade700,
              ),
            ),
            title: Text(
              title,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            subtitle: Text(
              '$type • ${_formatDate(date)}',
              style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
            ),
            trailing: const Icon(Icons.arrow_forward_ios, size: 16),
          ),
        );
      }).toList();
    } catch (e) {
      return [_buildEmptyState('Fehler beim Laden der Dokumente', Icons.error)];
    }
  }

  String _safeGetProperty(dynamic obj, String prop, String fallback) {
    try {
      final val = obj.toJson()[prop];
      return val?.toString() ?? fallback;
    } catch (_) {
      try {
        // reflection fallback (not available in release)
        return obj.toString();
      } catch (_) {
        return fallback;
      }
    }
  }

  DateTime _safeGetDate(dynamic obj) {
    try {
      return obj.date ?? DateTime.now();
    } catch (_) {
      try {
        final json = obj.toJson();
        if (json['date'] != null) {
          return DateTime.parse(json['date'].toString());
        }
      } catch (_) {}
      return DateTime.now();
    }
  }

  Widget _buildStatCard({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.shade300,
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 32),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey.shade600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title, IconData icon) {
    return Row(
      children: [
        Icon(icon, color: Colors.blue.shade700, size: 24),
        const SizedBox(width: 8),
        Text(
          title,
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyState(String message, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(32),
      child: Center(
        child: Column(
          children: [
            Icon(icon, size: 64, color: Colors.grey.shade300),
            const SizedBox(height: 12),
            Text(
              message,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey.shade600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final dateToCheck = DateTime(date.year, date.month, date.day);
    
    if (dateToCheck == today) {
      return 'Heute, ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')} Uhr';
    } else if (dateToCheck == today.add(const Duration(days: 1))) {
      return 'Morgen, ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')} Uhr';
    } else {
      return '${date.day.toString().padLeft(2, '0')}.${date.month.toString().padLeft(2, '0')}.${date.year}';
    }
  }

  IconData _getDocIcon(String type) {
    switch (type.toLowerCase()) {
      case 'arztbrief':
      case 'befund':
        return Icons.medical_information;
      case 'rezept':
        return Icons.receipt;
      case 'labor':
        return Icons.science;
      default:
        return Icons.description;
    }
  }
}

