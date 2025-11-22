import 'package:flutter/material.dart';

class Menu extends StatelessWidget {
  const Menu({super.key});

  @override
  Widget build(BuildContext context) {
    return Drawer(
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          const DrawerHeader(
            decoration: BoxDecoration(color: Colors.deepPurple),
            child: Text(
              'Care Companion',
              style: TextStyle(color: Colors.white, fontSize: 24),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.person),
            title: const Text('Profil'),
            onTap: () {
              Navigator.of(context).pop();
              Navigator.of(context).pushNamed('/profile');
            },
          ),
          ListTile(
            leading: const Icon(Icons.medication),
            title: const Text('Medication'),
            onTap: () {
              Navigator.of(context).pop();
              Navigator.of(context).pushNamed('/medications');
            },
          ),
          ListTile(
            leading: const Icon(Icons.checklist),
            title: const Text('Tasks'),
            onTap: () {
              Navigator.of(context).pop();
              Navigator.of(context).pushNamed('/tasks');
            },
          ),
          ListTile(
            leading: const Icon(Icons.folder),
            title: const Text('Documents / Protocolls'),
            onTap: () {
                  Navigator.of(context).pop(); // Drawer schließen
                  Navigator.of(context).pushNamed('/protocolls'); 
            },
          ),
          ListTile(
            leading: const Icon(Icons.description),
            title: const Text('Requests'),
            onTap: () {
              Navigator.of(context).pop();
              Navigator.of(context).pushNamed('/requests');
            },
          ),
          ListTile(
            leading: const Icon(Icons.calendar_today),
            title: const Text('Planning'),
            onTap: () {
              Navigator.of(context).pop();
              Navigator.of(context).pushNamed('/planning');
            },
          ),
        ],
      ),
    );
  }
}
