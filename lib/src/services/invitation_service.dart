import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:share_plus/share_plus.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/project.dart';

class InvitationService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  
  /// Generate a link for inviting others to a project
  Future<Uri> generateInvitationLink(Project project) async {
    final String currentUserId = _auth.currentUser?.uid ?? 'unknown';
    
    // Create a direct web URL that will work with App Links and Universal Links
    // This URL should match the domain and paths configured in your
    // assetlinks.json and apple-app-site-association files
    final Uri inviteUri = Uri(
      scheme: 'https',
      host: 'moments-for-mom.web.app', // Your Firebase Hosting domain
      path: '/join',
      queryParameters: {
        'projectId': project.id,
        'inviterId': currentUserId,
      },
    );
    
    print('Generated invitation link: $inviteUri');
    return inviteUri;
  }
  
  /// Track an invitation in Firestore
  Future<void> recordInvitation({
    required String projectId, 
    required String inviteeEmail, 
    required String inviteeName,
    String? inviteePhone,
    required String inviterId,
    required String inviterName,
  }) async {
    final String invitationId = '${inviteeEmail.hashCode}';
    
    await _db
        .collection('projects')
        .doc(projectId)
        .collection('invitations')
        .doc(invitationId)
        .set({
          'email': inviteeEmail,
          'name': inviteeName,
          'phone': inviteePhone,
          'status': 'pending',
          'invitedAt': FieldValue.serverTimestamp(),
          'inviterId': inviterId,
          'inviterName': inviterName,
          'lastReminded': null,
          'timesReminded': 0,
          'acceptedAt': null,
        }, SetOptions(merge: true));
    
    print('Recorded invitation for $inviteeName ($inviteeEmail) to project $projectId');
  }
  
  /// Show an elegant invitation dialog
  Future<void> showInviteDialog(BuildContext context, Project project) async {
    final TextEditingController nameController = TextEditingController();
    final TextEditingController emailController = TextEditingController();
    
    // Current user info
    final String currentUserId = _auth.currentUser?.uid ?? 'unknown';
    final String currentUserName = _auth.currentUser?.displayName ?? 'Someone special';
    
    // Generate invitation link
    final linkGenerationFuture = generateInvitationLink(project);
    
    // Custom colors
    final Color primaryColor = Color(0xFF6A3DE8);
    final Color accentColor = Color(0xFFFF7D54);
    
    await showDialog(
      context: context,
      builder: (context) => FutureBuilder<Uri>(
        future: linkGenerationFuture,
        builder: (context, snapshot) {
          final bool isLoading = !snapshot.hasData;
          final String? inviteLink = snapshot.data?.toString();
          
          return Dialog(
            backgroundColor: Colors.transparent,
            elevation: 0,
            child: Container(
              width: double.infinity,
              margin: const EdgeInsets.all(16),
              constraints: BoxConstraints(
                maxWidth: 400, // Limit maximum width
              ),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 20,
                    spreadRadius: 5,
                    offset: Offset(0, 10),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Header with gradient
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [primaryColor, accentColor],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                        ),
                        child: Column(
                          children: [
                            CircleAvatar(
                              backgroundColor: Colors.white,
                              radius: 30,
                              child: Icon(
                                Icons.mail_outline_rounded,
                                color: primaryColor,
                                size: 32,
                              ),
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'Invite to "${project.title}"',
                              style: GoogleFonts.nunito(
                                fontSize: 22,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Help make this video special by inviting friends and family to contribute',
                              style: GoogleFonts.nunito(
                                fontSize: 14,
                                color: Colors.white.withOpacity(0.9),
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      ),
                      
                      // Content
                      Padding(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              'Invite by Email',
                              style: GoogleFonts.nunito(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Colors.black87,
                              ),
                            ),
                            const SizedBox(height: 16),
                            // Input fields
                            TextField(
                              controller: nameController,
                              decoration: InputDecoration(
                                labelText: "Friend's Name",
                                hintText: "Enter their name",
                                prefixIcon: Icon(Icons.person_outline),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                floatingLabelBehavior: FloatingLabelBehavior.always,
                                alignLabelWithHint: true,
                                isDense: true,
                                filled: true,
                                fillColor: Colors.grey.shade50,
                                contentPadding: EdgeInsets.symmetric(vertical: 16, horizontal: 12),
                              ),
                            ),
                            const SizedBox(height: 12),
                            TextField(
                              controller: emailController,
                              keyboardType: TextInputType.emailAddress,
                              decoration: InputDecoration(
                                labelText: "Friend's Email",
                                hintText: "Enter their email",
                                prefixIcon: Icon(Icons.email_outlined),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                floatingLabelBehavior: FloatingLabelBehavior.always,
                                alignLabelWithHint: true,
                                isDense: true,
                                filled: true,
                                fillColor: Colors.grey.shade50,
                                contentPadding: EdgeInsets.symmetric(vertical: 16, horizontal: 12),
                              ),
                            ),
                            const SizedBox(height: 24),
                            
                            // Sharing options
                            Text(
                              'Or Share Directly',
                              style: GoogleFonts.nunito(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Colors.black87,
                              ),
                            ),
                            const SizedBox(height: 16),
                            if (isLoading)
                              const CircularProgressIndicator()
                            else
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                decoration: BoxDecoration(
                                  color: Colors.grey.shade100,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Expanded(
                                      child: Text(
                                        inviteLink ?? 'Link not available',
                                        style: TextStyle(
                                          color: Colors.grey.shade700,
                                          fontSize: 14,
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                        maxLines: 1,
                                      ),
                                    ),
                                    IconButton(
                                      icon: Icon(Icons.copy, color: primaryColor),
                                      onPressed: () {
                                        if (inviteLink != null) {
                                          ScaffoldMessenger.of(context).showSnackBar(
                                            SnackBar(content: Text('Link copied to clipboard!'))
                                          );
                                        }
                                      },
                                      tooltip: 'Copy link',
                                    ),
                                  ],
                                ),
                              ),
                            const SizedBox(height: 16),
                            
                            // Share options as icons
                            Container(
                              width: double.infinity,
                              child: Wrap(
                                alignment: WrapAlignment.center,
                                spacing: 8,
                                runSpacing: 12,
                                children: [
                                  _buildShareOption(
                                    context, 
                                    Icons.message, 
                                    Colors.green.shade600,
                                    'WhatsApp',
                                    () => _shareViaApp(context, project, inviteLink, 'whatsapp'),
                                  ),
                                  _buildShareOption(
                                    context, 
                                    Icons.sms_outlined, 
                                    Colors.blue.shade600,
                                    'SMS',
                                    () => _shareViaApp(context, project, inviteLink, 'sms'),
                                  ),
                                  _buildShareOption(
                                    context, 
                                    Icons.messenger_outline_rounded, 
                                    Colors.purple.shade600,
                                    'Messenger',
                                    () => _shareViaApp(context, project, inviteLink, 'messenger'),
                                  ),
                                  _buildShareOption(
                                    context, 
                                    Icons.more_horiz, 
                                    Colors.grey.shade700,
                                    'More',
                                    () => _shareViaApp(context, project, inviteLink, 'more'),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      
                      // Buttons
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                        child: Row(
                          children: [
                            Expanded(
                              child: TextButton(
                                onPressed: () => Navigator.pop(context),
                                style: TextButton.styleFrom(
                                  foregroundColor: Colors.grey.shade700,
                                  padding: const EdgeInsets.symmetric(vertical: 12),
                                ),
                                child: Text(
                                  'Cancel',
                                  style: GoogleFonts.nunito(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: ElevatedButton(
                                onPressed: isLoading || inviteLink == null
                                  ? null
                                  : () => _sendInviteEmail(
                                      context, 
                                      project, 
                                      inviteLink, 
                                      nameController.text, 
                                      emailController.text,
                                      currentUserId,
                                      currentUserName,
                                    ),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: primaryColor,
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(vertical: 12),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(30),
                                  ),
                                ),
                                child: Text(
                                  'Share Invite',
                                  style: GoogleFonts.nunito(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
  
  // Helper to build share option icon
  Widget _buildShareOption(
    BuildContext context, 
    IconData icon, 
    Color color, 
    String label, 
    VoidCallback onTap
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 24),
            ),
            const SizedBox(height: 6),
            Text(
              label,
              style: GoogleFonts.nunito(
                fontSize: 12,
                color: Colors.grey.shade700,
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  // Method to handle sharing via different apps
  Future<void> _shareViaApp(BuildContext context, Project project, String? inviteLink, String app) async {
    if (inviteLink == null) return;
    
    final String message = 'Join me in creating a special video for "${project.title}"! '
                          'Tap this link to add your video: $inviteLink';
    
    try {
      await Share.share(
        message,
        subject: 'Invitation to join "${project.title}"',
      );
    } catch (e) {
      print('Error sharing via $app: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not share: $e')),
      );
    }
  }
  
  // Method to send an email invitation and record it
  Future<void> _sendInviteEmail(
    BuildContext context, 
    Project project, 
    String inviteLink, 
    String inviteeName, 
    String inviteeEmail,
    String inviterId,
    String inviterName,
  ) async {
    if (inviteeEmail.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Please enter an email address')),
      );
      return;
    }
    
    try {
      // Record the invitation in Firestore
      await recordInvitation(
        projectId: project.id,
        inviteeEmail: inviteeEmail,
        inviteeName: inviteeName.isNotEmpty ? inviteeName : 'Friend',
        inviterId: inviterId,
        inviterName: inviterName,
      );
      
      // Create email message with all details
      final String message = 'Hi ${inviteeName.isNotEmpty ? inviteeName : "there"}! '
                            'I\'d like you to contribute to a special video for "${project.title}". '
                            'Tap this link to add your video: $inviteLink';
      
      // Use standard Share.share for a cleaner experience
      await Share.share(
        message,
        subject: 'Invitation to join "${project.title}"',
      );
      
      Navigator.of(context).pop(); // Close dialog
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Invitation sent to $inviteeEmail'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      print('Error sending invitation: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error sending invitation: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
  
  /// Initialize app/universal links to handle app opens from invitations
  void initDynamicLinks(BuildContext context, Function(String) onProjectJoin) {
    // This is left as a stub for compatibility
    // Deep link handling is now managed by the operating system and Flutter's built-in
    // deep linking support via flutter_deeplinking_enabled
    print('Deep link handling now relies on platform-native mechanisms');
  }
  
  /// Mark an invitation as accepted
  Future<void> acceptInvitation(String projectId, String inviteeEmail) async {
    final String invitationId = '${inviteeEmail.hashCode}';
    
    await _db
        .collection('projects')
        .doc(projectId)
        .collection('invitations')
        .doc(invitationId)
        .update({
          'status': 'accepted',
          'acceptedAt': FieldValue.serverTimestamp(),
        });
  }
  
  /// Get a stream of invitations for a project
  Stream<QuerySnapshot> getInvitationsForProject(String projectId) {
    return _db
        .collection('projects')
        .doc(projectId)
        .collection('invitations')
        .orderBy('invitedAt', descending: true)
        .snapshots();
  }
} 