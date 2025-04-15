import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../services/auth_service.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
        // Automatically includes a back button due to navigation
      ),
      body: ListView( // Use ListView for potential future settings
        padding: const EdgeInsets.all(16.0),
        children: [
           // TODO: Add other settings like profile editing, etc.
          ListTile(
             leading: const Icon(Icons.logout),
             title: const Text('Logout'),
             onTap: () {
                // Close the settings screen first before logging out
                Navigator.of(context).pop();
                // Call sign out from the provider
                context.read<AuthService>().signOut();
             },
          ),
        ],
      ),
    );
  }
} 