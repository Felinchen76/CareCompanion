import 'package:flutter/material.dart';
import 'screens/dashboard.dart';
import 'services/agent_service.dart';
import 'screens/placeholder_menu.dart';
import 'screens/protocolls.dart';

void main() async {
  // Flutter vorbereiten
  WidgetsFlutterBinding.ensureInitialized();

  // Agent initialisieren und Dummy-Daten laden
  final agent = AgentService();
  await agent.loadDummyData();

  // Agenten starten (z.B. für Terminerinnerungen)
  agent.startAgent();

  // App starten
  runApp(MyApp(agent: agent));
}

class MyApp extends StatelessWidget {
  final AgentService agent;
  const MyApp({super.key, required this.agent});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Care Companion',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
      ),
      home: DashboardScreen(agent: agent),
      routes: {
        '/profile': (ctx) => const PlaceholderScreen(title: 'Profil'),
        '/medications': (ctx) => const PlaceholderScreen(title: 'Medikamente'),
        '/tasks': (ctx) => const PlaceholderScreen(title: 'Tasks'),
        '/protocolls': (ctx) => const ProtocollsScreen(), // <-- echte Seite registriert
        '/requests': (ctx) => const PlaceholderScreen(title: 'Anträge'),
        '/planning': (ctx) => const PlaceholderScreen(title: 'Planung'),
      },
    );
  }
}
