import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../services/auth_service.dart';
import '../../../services/database_service.dart';
import '../../../models/project.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _animation;
  String? _displayName;
  String? _email;
  bool _isEmailVerified = false;
  String _accountCreated = '';
  bool _isLoading = true;
  
  // Notification preferences
  bool _pushNotificationsEnabled = true;
  bool _emailNotificationsEnabled = true;
  bool _contributionNotificationsEnabled = true;
  bool _deliveryNotificationsEnabled = true;
  
  // Stats
  int _totalProjects = 0;
  int _totalContributions = 0;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _animation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOut,
    );
    _animationController.forward();
    _loadUserData();
    _loadNotificationPreferences();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _loadNotificationPreferences() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      setState(() {
        _pushNotificationsEnabled = prefs.getBool('push_notifications_enabled') ?? true;
        _emailNotificationsEnabled = prefs.getBool('email_notifications_enabled') ?? true;
        _contributionNotificationsEnabled = prefs.getBool('contribution_notifications_enabled') ?? true;
        _deliveryNotificationsEnabled = prefs.getBool('delivery_notifications_enabled') ?? true;
      });
    } catch (e) {
      print('Error loading notification preferences: $e');
    }
  }
  
  Future<void> _saveNotificationPreference(String key, bool value) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(key, value);
      
      // Also save to Firestore for cross-device sync if user is logged in
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .set({
              'notificationPreferences': {
                key: value,
              }
            }, SetOptions(merge: true));
      }
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Notification settings updated')),
      );
    } catch (e) {
      print('Error saving notification preference: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Error updating notification settings')),
      );
    }
  }

  Future<void> _loadUserData() async {
    setState(() => _isLoading = true);
    
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      // Load basic user info
      setState(() {
        _displayName = user.displayName ?? 'Moments User';
        _email = user.email ?? 'No email';
        _isEmailVerified = user.emailVerified;
        
        // Format account creation time
        final creationTime = user.metadata.creationTime;
        if (creationTime != null) {
          _accountCreated = '${creationTime.month}/${creationTime.day}/${creationTime.year}';
        } else {
          _accountCreated = 'Unknown';
        }
      });
      
      // Load project stats
      try {
        final databaseService = context.read<DatabaseService>();
        final projects = await databaseService.getMomentsForUser(user.uid).first;
        
        int organized = 0;
        int contributed = 0;
        
        for (final project in projects) {
          if (project.organizerId == user.uid) {
            organized++;
          }
          if (project.contributorIds.contains(user.uid) && project.organizerId != user.uid) {
            contributed++;
          }
        }
        
        if (mounted) {
          setState(() {
            _totalProjects = organized;
            _totalContributions = contributed;
          });
        }
      } catch (e) {
        print('Error loading project stats: $e');
      }
    }
    
    if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _updateDisplayName() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    
    final TextEditingController controller = TextEditingController(text: _displayName);
    
    final newName = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.grey.shade900,
        title: Text(
          'Update Name',
          style: GoogleFonts.nunito(color: Colors.white),
        ),
        content: TextField(
          controller: controller,
          style: GoogleFonts.nunito(color: Colors.white),
          decoration: InputDecoration(
            hintText: 'Enter your name',
            hintStyle: TextStyle(color: Colors.white60),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: Colors.white30),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: Colors.blue.shade300),
            ),
          ),
        ),
        actions: [
          TextButton(
            child: Text('Cancel', style: GoogleFonts.nunito(color: Colors.white70)),
            onPressed: () => Navigator.pop(context),
          ),
          TextButton(
            child: Text('Save', style: GoogleFonts.nunito(color: Colors.blue.shade300)),
            onPressed: () => Navigator.pop(context, controller.text.trim()),
          ),
        ],
      ),
    );
    
    if (newName != null && newName.isNotEmpty && newName != _displayName) {
      setState(() => _isLoading = true);
      try {
        await user.updateDisplayName(newName);
        await user.reload();
        final updatedUser = FirebaseAuth.instance.currentUser;
        setState(() {
          _displayName = updatedUser?.displayName ?? newName;
          _isLoading = false;
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Name updated successfully')),
          );
        }
      } catch (e) {
        setState(() => _isLoading = false);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error updating name: $e')),
          );
        }
      }
    }
  }

  Future<void> _verifyEmail() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    
    setState(() => _isLoading = true);
    try {
      await user.sendEmailVerification();
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Verification email sent. Please check your inbox.')),
        );
      }
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error sending verification email: $e')),
        );
      }
    }
  }

  Future<void> _confirmLogout() async {
    final shouldLogout = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.grey.shade900,
        title: Text(
          'Confirm Logout',
          style: GoogleFonts.nunito(color: Colors.white),
        ),
        content: Text(
          'Are you sure you want to log out?',
          style: GoogleFonts.nunito(color: Colors.white70),
        ),
        actions: [
          TextButton(
            child: Text('Cancel', style: GoogleFonts.nunito(color: Colors.white70)),
            onPressed: () => Navigator.pop(context, false),
          ),
          TextButton(
            child: Text('Logout', style: GoogleFonts.nunito(color: Colors.red.shade300)),
            onPressed: () => Navigator.pop(context, true),
          ),
        ],
      ),
    );
    
    if (shouldLogout == true) {
      await context.read<AuthService>().signOut();
      if (mounted) {
        Navigator.of(context).pop();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = Provider.of<User?>(context);
    
    return Scaffold(
      extendBodyBehindAppBar: true,
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Container(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.black.withOpacity(0.2),
              border: Border.all(color: Colors.white.withOpacity(0.3), width: 0.5),
            ),
            padding: const EdgeInsets.all(8),
            child: const Icon(Icons.arrow_back, color: Colors.white),
          ),
          onPressed: () => Navigator.of(context).pop(),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: IconButton(
              icon: Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.black.withOpacity(0.2),
                  border: Border.all(color: Colors.white.withOpacity(0.3), width: 0.5),
                ),
                padding: const EdgeInsets.all(8),
                child: const Icon(Icons.logout, color: Colors.white),
              ),
              onPressed: _confirmLogout,
            ),
          ),
        ],
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Colors.deepPurple.shade900,
              Colors.indigo.shade800,
              Colors.blue.shade900,
            ],
          ),
        ),
        child: SafeArea(
          child: _isLoading 
            ? const Center(child: CircularProgressIndicator(color: Colors.white))
            : FadeTransition(
                opacity: _animation,
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // User profile section
                      Padding(
                        padding: const EdgeInsets.all(20),
                        child: _buildProfileSection(),
                      ),
                      
                      // Stats section
                      Padding(
                        padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                        child: _buildStatsSection(),
                      ),
                      
                      // Account section
                      Padding(
                        padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                        child: _buildAccountSection(),
                      ),
                      
                      // Settings section
                      Padding(
                        padding: const EdgeInsets.fromLTRB(20, 0, 20, 30),
                        child: _buildSettingsSection(),
                      ),
                    ],
                  ),
                ),
              ),
        ),
      ),
    );
  }

  Widget _buildProfileSection() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        color: Colors.white.withOpacity(0.1),
      ),
      child: Column(
        children: [
          // User avatar (simplified with initials only)
          Container(
            width: 100,
            height: 100,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Colors.purple.shade500,
                  Colors.blue.shade500,
                ],
              ),
              border: Border.all(
                color: Colors.white.withOpacity(0.5),
                width: 2,
              ),
            ),
            child: Center(
              child: Text(
                _getInitials(_displayName ?? ''),
                style: GoogleFonts.nunito(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 36,
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          
          // User name (with edit icon)
          GestureDetector(
            onTap: _updateDisplayName,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  _displayName ?? 'Moments User',
                  style: GoogleFonts.nunito(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 24,
                  ),
                ),
                const SizedBox(width: 8),
                Icon(
                  Icons.edit,
                  color: Colors.white.withOpacity(0.7),
                  size: 18,
                ),
              ],
            ),
          ),
          const SizedBox(height: 4),
          
          // Email with verification status
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                _email ?? 'No email',
                style: GoogleFonts.nunito(
                  color: Colors.white.withOpacity(0.8),
                  fontSize: 16,
                ),
              ),
              const SizedBox(width: 4),
              if (_isEmailVerified)
                Icon(
                  Icons.verified,
                  color: Colors.green.shade300,
                  size: 16,
                )
              else
                GestureDetector(
                  onTap: _verifyEmail,
                  child: Icon(
                    Icons.error_outline,
                    color: Colors.orange.shade300,
                    size: 16,
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatsSection() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        color: Colors.white.withOpacity(0.1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Your Activity',
            style: GoogleFonts.nunito(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 18,
            ),
          ),
          const SizedBox(height: 16),
          
          Row(
            children: [
              Expanded(
                child: _buildStatItem(
                  icon: Icons.collections_bookmark,
                  value: _totalProjects.toString(),
                  label: 'Created',
                  color: Colors.blue.shade300,
                ),
              ),
              Expanded(
                child: _buildStatItem(
                  icon: Icons.people,
                  value: _totalContributions.toString(),
                  label: 'Contributions',
                  color: Colors.amber.shade300,
                ),
              ),
              Expanded(
                child: _buildStatItem(
                  icon: Icons.favorite,
                  value: (_totalProjects + _totalContributions).toString(),
                  label: 'Total',
                  color: Colors.pink.shade300,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem({
    required IconData icon,
    required String value,
    required String label,
    required Color color,
  }) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: color.withOpacity(0.2),
          ),
          child: Icon(
            icon,
            color: color,
            size: 24,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          value,
          style: GoogleFonts.nunito(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 22,
          ),
        ),
        Text(
          label,
          style: GoogleFonts.nunito(
            color: Colors.white.withOpacity(0.7),
            fontSize: 12,
          ),
        ),
      ],
    );
  }

  Widget _buildAccountSection() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        color: Colors.white.withOpacity(0.1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Account Information',
            style: GoogleFonts.nunito(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 18,
            ),
          ),
          const SizedBox(height: 16),
          
          // Account created date
          _buildInfoRow(
            icon: Icons.calendar_today,
            label: 'Account Created',
            value: _accountCreated,
          ),
          
          // Verification prompt if needed
          if (!_isEmailVerified)
            Padding(
              padding: const EdgeInsets.only(top: 16),
              child: GestureDetector(
                onTap: _verifyEmail,
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    color: Colors.orange.withOpacity(0.2),
                    border: Border.all(
                      color: Colors.orange.withOpacity(0.5),
                      width: 1,
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.warning_amber_rounded,
                        color: Colors.orange.shade300,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Please verify your email address',
                          style: GoogleFonts.nunito(
                            color: Colors.orange.shade100,
                            fontSize: 14,
                          ),
                        ),
                      ),
                      Icon(
                        Icons.arrow_forward_ios,
                        color: Colors.orange.shade300,
                        size: 14,
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildSettingsSection() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        color: Colors.white.withOpacity(0.1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Settings',
            style: GoogleFonts.nunito(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 18,
            ),
          ),
          const SizedBox(height: 16),
          
          // Notifications section (simplified)
          _buildToggleSettingsItem(
            icon: Icons.notifications_active,
            label: 'Push Notifications',
            color: Colors.green.shade300,
            value: _pushNotificationsEnabled,
            onChanged: (value) {
              setState(() => _pushNotificationsEnabled = value);
              _saveNotificationPreference('push_notifications_enabled', value);
            },
          ),
          
          const Divider(color: Colors.white24, height: 24),
          
          // Email notifications
          _buildToggleSettingsItem(
            icon: Icons.email_outlined,
            label: 'Email Notifications',
            color: Colors.blue.shade300,
            value: _emailNotificationsEnabled,
            onChanged: (value) {
              setState(() => _emailNotificationsEnabled = value);
              _saveNotificationPreference('email_notifications_enabled', value);
            },
          ),
          
          const Divider(color: Colors.white24, height: 24),
          
          // Other settings
          _buildSettingsItem(
            icon: Icons.help_outline,
            label: 'Help & Support',
            color: Colors.amber.shade300,
            onTap: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Help & support coming soon')),
              );
            },
          ),
          
          const SizedBox(height: 12),
          
          _buildSettingsItem(
            icon: Icons.info_outline,
            label: 'About',
            color: Colors.cyan.shade300,
            onTap: () {
              showAboutDialog(
                context: context,
                applicationName: 'Moments',
                applicationVersion: '1.0.0',
                applicationLegalese: '© 2024 Moments Team',
                children: [
                  const SizedBox(height: 24),
                  Text(
                    'Moments is an app that helps you create and share special video compilations with your loved ones.',
                    style: GoogleFonts.nunito(),
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Icon(
            icon,
            color: Colors.blue.shade300,
            size: 20,
          ),
          const SizedBox(width: 12),
          Text(
            '$label:',
            style: GoogleFonts.nunito(
              color: Colors.white.withOpacity(0.7),
              fontSize: 14,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              value,
              style: GoogleFonts.nunito(
                color: Colors.white,
                fontWeight: FontWeight.w600,
                fontSize: 14,
              ),
              textAlign: TextAlign.end,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildToggleSettingsItem({
    required IconData icon,
    required String label,
    required Color color,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return SwitchListTile(
      contentPadding: EdgeInsets.zero,
      secondary: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: color.withOpacity(0.2),
        ),
        child: Icon(
          icon,
          color: color,
          size: 20,
        ),
      ),
      title: Text(
        label,
        style: GoogleFonts.nunito(
          color: Colors.white,
          fontSize: 16,
        ),
      ),
      value: value,
      onChanged: onChanged,
      activeColor: Colors.blue.shade300,
      activeTrackColor: Colors.blue.shade800,
      inactiveThumbColor: Colors.grey.shade400,
      inactiveTrackColor: Colors.grey.shade800,
    );
  }

  Widget _buildSettingsItem({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: color.withOpacity(0.2),
              ),
              child: Icon(
                icon,
                color: color,
                size: 20,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                label,
                style: GoogleFonts.nunito(
                  color: Colors.white,
                  fontSize: 16,
                ),
              ),
            ),
            Icon(
              Icons.arrow_forward_ios,
              color: Colors.white.withOpacity(0.5),
              size: 16,
            ),
          ],
        ),
      ),
    );
  }

  String _getInitials(String fullName) {
    if (fullName.isEmpty) return '?';
    final List<String> names = fullName.split(' ');
    if (names.length == 1) return names[0][0].toUpperCase();
    return '${names[0][0]}${names[1][0]}'.toUpperCase();
  }
} 