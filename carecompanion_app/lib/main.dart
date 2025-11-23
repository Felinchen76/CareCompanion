import 'package:flutter/material.dart';
import 'screens/dashboard.dart';
import 'screens/profile.dart';
import 'screens/medications.dart';
import 'screens/tasks.dart';
import 'screens/protocolls.dart';
import 'services/agent_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Lade Dummy-Daten & starte Agent sofort
  await agentService.loadDummyData();
  agentService.startAgent();
  
  runApp(MyApp(agent: agentService));
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
        useMaterial3: true,
      ),
      home: DashboardScreen(agent: agent),
      // routen zu seiten
      routes: {
        '/dashboard': (ctx) => DashboardScreen(agent: agent),
        '/profile': (ctx) => const ProfileScreen(),
        '/medications': (ctx) => MedicationsScreen(agent: agent),
        '/tasks': (ctx) => TasksScreen(agent: agent),
        '/protocolls': (ctx) => const ProtocollsScreen(),
        '/requests': (ctx) => const PlaceholderScreen(title: 'Anträge'),
        '/planning': (ctx) => const PlaceholderScreen(title: 'Planung'),
      },
    );
  }
}

// Placeholder für noch nicht implementierte Screens
class PlaceholderScreen extends StatelessWidget {
  final String title;
  const PlaceholderScreen({super.key, required this.title});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.construction, size: 80, color: Colors.grey.shade400),
            const SizedBox(height: 16),
            Text(
              '$title (in Entwicklung)',
              style: TextStyle(fontSize: 18, color: Colors.grey.shade600),
            ),
          ],
        ),
      ),
    );
  }
}