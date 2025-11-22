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
      drawer: const Menu(),
      body: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          // ---------------- TASKS ----------------
          ...agent.patient.tasks.map(
            (task) => Card(
              child: ListTile(
                title: Text(task.title),
                subtitle: task.date != null
                    ? Text(task.date.toString())
                    : const Text("Kein Datum vorhanden"),
              ),
            ),
          ),

          const SizedBox(height: 20),

          // ---------------- MEDICATIONS ----------------
          ...agent.patient.medications.map(
            (med) => Card(
              child: ListTile(
                title: Text(med.name),
                subtitle: Text("${med.dose} • Noch ${med.amountLeft} Stück"),
              ),
            ),
          ),

          const SizedBox(height: 20),

          // ---------------- APPOINTMENTS ----------------
          ...agent.patient.appointments.map(
            (app) => Card(
              child: ListTile(
                title: Text(app.type),
                subtitle: Text(app.date.toString()),
              ),
            ),
          ),

          const SizedBox(height: 20),

          // ---------------- DOCUMENTS / MEDICAL NOTES ----------------
          ...agent.patient.medicalNotes.map(
            (doc) => Card(
              child: ListTile(
                title: Text(doc.title),
                subtitle: Text("${doc.type} • ${doc.date.toLocal()}"),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

                                          