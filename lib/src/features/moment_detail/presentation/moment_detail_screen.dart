import 'package:flutter/material.dart';
import 'package:provider/provider.dart'; // If needed for actions later
import 'package:share_plus/share_plus.dart'; // Import share_plus

import '../../../models/project.dart'; // Import the Project model
// TODO: Import other services if needed (e.g., DatabaseService for updates)

class MomentDetailScreen extends StatelessWidget {
  final Project moment;

  const MomentDetailScreen({super.key, required this.moment});

  // Method to handle sharing the invitation
  void _shareInvitation(BuildContext context, Project moment) {
     // TODO: Generate a proper unique deep link URL instead of just the ID
     final String invitationText = 
        'Join my "${moment.title}" Moment for Mom! \n'
        'Use this code/link in the app: ${moment.id}'; // Placeholder link/code
     
     // Use share_plus to show the platform share sheet
     Share.share(invitationText, subject: 'Invitation to join ${moment.title}');
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      // Use a transparent AppBar to keep the back button consistent
      appBar: AppBar(
        title: Text(moment.title, style: theme.appBarTheme.titleTextStyle),
        backgroundColor: Colors.transparent,
        elevation: 0,
        // Theme handles icon color
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
             // TODO: Replace with a cover image/video preview area later
             Container(
                height: 200,
                width: double.infinity,
                decoration: BoxDecoration(
                   color: theme.colorScheme.surface, // Placeholder color
                   borderRadius: BorderRadius.circular(12.0),
                ),
                child: Center(child: Text('Cover Image/Video Placeholder', style: theme.textTheme.bodySmall)),
             ),
             const SizedBox(height: 24),
             
             Text('Details', style: theme.textTheme.titleLarge), // Section header
             const SizedBox(height: 8),
             Card(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                     crossAxisAlignment: CrossAxisAlignment.start,
                     children: [
                        Text('Moment Title: ${moment.title}', style: theme.textTheme.bodyLarge),
                        const SizedBox(height: 8),
                        Text('Organized by: ${moment.organizerName}', style: theme.textTheme.bodyMedium),
                        const SizedBox(height: 8),
                        Text('Created: ${moment.createdAt.toDate()}', style: theme.textTheme.bodyMedium), // Basic date display
                        const SizedBox(height: 8),
                        Text('Moment ID: ${moment.id}', style: theme.textTheme.bodySmall), // For debugging
                     ],
                  ),
                )
             ),
             const SizedBox(height: 24),

             Text('Contributors (${moment.contributorIds.length})', style: theme.textTheme.titleLarge), // Section header
             const SizedBox(height: 8),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                     crossAxisAlignment: CrossAxisAlignment.start,
                     children: [
                        // TODO: Display contributor list nicely (avatars, names)
                        Text(moment.contributorIds.join('\n'), style: theme.textTheme.bodySmall),
                     ],
                  ),
                )
             ),
             const SizedBox(height: 24),

             // --- Invitation Section --- 
             Center(
                 child: ElevatedButton.icon(
                    icon: const Icon(Icons.person_add_alt_1), 
                    label: const Text('Invite Contributors'), 
                    onPressed: () => _shareInvitation(context, moment), // Call the share method
                 ),
              ),

             // TODO: Add sections for viewing clips, recording, etc.
          ],
        ),
      ),
    );
  }
} 