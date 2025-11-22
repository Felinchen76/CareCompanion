import 'package:flutter/material.dart';
import '../services/agent_service.dart';
import '../widgets/menu.dart';

class DashboardScreen extends StatelessWidget {
  final AgentService agent;
  const DashboardScreen({super.key, required this.agent});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Care Companion Dashboard')),
      drawer: const Menu(), // Drawer für das Burgermenü
      body: ListView(
        padding: const EdgeInsets.all(8),
        children: [
          const Text('Tasks', style: TextStyle(fontSize: 20)),
          ...agent.tasks.map(
            (task) => Card(
              child: ListTile(
                title: Text(task['task'] ?? 'Unbenannte Aufgabe'),
                subtitle: task['date'] != null ? Text(task['date'].toString()) : null,
              ),
            ),
          ),

          const SizedBox(height: 16),
          const Text('Medications', style: TextStyle(fontSize: 20)),
          ...agent.medications.map(
            (med) => Card(
              child: ListTile(
                title: Text(med['name'] ?? 'Unbekannte Medikation'),
                subtitle: med['dose'] != null ? Text(med['dose'].toString()) : null,
              ),
            ),
          ),

          const SizedBox(height: 16),
          const Text('Appointments', style: TextStyle(fontSize: 20)),
          ...agent.appointments.map(
            (app) => Card(
              child: ListTile(
                title: Text(app['title'] ?? app['type'] ?? 'Unbekannter Termin'),
                subtitle: app['date'] != null ? Text(app['date'].toString()) : null,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
