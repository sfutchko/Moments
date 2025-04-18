import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:lottie/lottie.dart';
import '../../../models/project.dart';
import '../../../services/database_service.dart';
import '../../../services/invitation_service.dart';
import '../../moment_detail/presentation/moment_detail_screen.dart';

class JoinProjectScreen extends StatefulWidget {
  final String projectId;
  final String? inviterId;

  const JoinProjectScreen({
    Key? key,
    required this.projectId,
    this.inviterId,
  }) : super(key: key);

  @override
  State<JoinProjectScreen> createState() => _JoinProjectScreenState();
}

class _JoinProjectScreenState extends State<JoinProjectScreen> with SingleTickerProviderStateMixin {
  late Future<Project?> _projectFuture;
  bool _isJoining = false;
  bool _hasJoined = false;
  late final AnimationController _confettiController;
  final DatabaseService _databaseService = DatabaseService();
  final InvitationService _invitationService = InvitationService();
  
  @override
  void initState() {
    super.initState();
    _projectFuture = _databaseService.getProjectDetailsSync(widget.projectId);
    _confettiController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    );
  }
  
  @override
  void dispose() {
    _confettiController.dispose();
    super.dispose();
  }
  
  Future<void> _joinProject(Project project) async {
    if (_isJoining || _hasJoined) return;
    
    setState(() => _isJoining = true);
    
    try {
      // Check if user is signed in
      User? user = FirebaseAuth.instance.currentUser;
      
      if (user == null) {
        // Navigate to sign in screen
        setState(() => _isJoining = false);
        // You would typically navigate to sign in screen here
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please sign in to join this project')),
        );
        return;
      }
      
      // Update contributors list
      await _databaseService.addContributorToProject(
        project.id,
        user.uid,
        user.displayName ?? user.email?.split('@')[0] ?? 'Anonymous',
      );
      
      // Update invitation status if available
      final String? userEmail = user.email;
      if (userEmail != null) {
        await _invitationService.acceptInvitation(project.id, userEmail);
      }
      
      // Play animation and show success
      if (mounted) {
        setState(() {
          _isJoining = false;
          _hasJoined = true;
        });
        
        _confettiController.forward();
        
        // Wait a moment to show the success animation
        Future.delayed(const Duration(milliseconds: 2500), () {
          if (mounted) {
            // Navigate to the project detail screen
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                builder: (context) => MomentDetailScreen(moment: project),
              ),
            );
          }
        });
      }
    } catch (e) {
      print('Error joining project: $e');
      if (mounted) {
        setState(() => _isJoining = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error joining project: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: FutureBuilder<Project?>(
        future: _projectFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
              ),
            );
          }
          
          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.error_outline,
                      color: Colors.red,
                      size: 64,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Error loading project',
                      style: GoogleFonts.nunito(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'We couldn\'t find the project you were invited to. The invitation may have expired.',
                      style: GoogleFonts.nunito(
                        color: Colors.white70,
                        fontSize: 16,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 24),
                    ElevatedButton(
                      onPressed: () => Navigator.pop(context),
                      style: ElevatedButton.styleFrom(
                        foregroundColor: Colors.white,
                        backgroundColor: Colors.blue,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(30),
                        ),
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                      ),
                      child: Text(
                        'Go Back',
                        style: GoogleFonts.nunito(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          }
          
          final project = snapshot.data;
          if (project == null) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.not_interested,
                      color: Colors.red,
                      size: 64,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Project Not Found',
                      style: GoogleFonts.nunito(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'The project you were invited to does not exist or has been deleted.',
                      style: GoogleFonts.nunito(
                        color: Colors.white70,
                        fontSize: 16,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 24),
                    ElevatedButton(
                      onPressed: () => Navigator.pop(context),
                      style: ElevatedButton.styleFrom(
                        foregroundColor: Colors.white,
                        backgroundColor: Colors.blue,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(30),
                        ),
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                      ),
                      child: Text(
                        'Go Home',
                        style: GoogleFonts.nunito(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          }
          
          // Project found - show invitation details
          return _buildProjectView(project);
        },
      ),
    );
  }
  
  Widget _buildProjectView(Project project) {
    final bool isCurrentUserOrganizer = FirebaseAuth.instance.currentUser?.uid == project.organizerId;
    
    return Stack(
      fit: StackFit.expand,
      children: [
        // Background
        Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Colors.indigo.shade900,
                Colors.purple.shade900,
              ],
            ),
          ),
        ),
        
        // Particles or shapes for background texture
        ...List.generate(20, (index) {
          final random = index / 20;
          return Positioned(
            left: MediaQuery.of(context).size.width * (index % 5) / 5,
            top: MediaQuery.of(context).size.height * random,
            child: Opacity(
              opacity: 0.1 + (random * 0.1),
              child: Container(
                width: 100 + (random * 100),
                height: 100 + (random * 100),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withOpacity(0.1),
                ),
              ),
            ),
          );
        }),
        
        // Content
        SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // App bar with close button
                Align(
                  alignment: Alignment.topRight,
                  child: IconButton(
                    icon: const Icon(Icons.close, color: Colors.white),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ),
                
                const Spacer(),
                
                // Invitation content
                Card(
                  elevation: 8,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(24),
                  ),
                  color: Colors.white.withOpacity(0.9),
                  child: Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Project title
                        Text(
                          project.title,
                          style: GoogleFonts.nunito(
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                            color: Colors.indigo.shade900,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 8),
                        
                        // Organizer info
                        Text(
                          'Organized by ${project.organizerName}',
                          style: GoogleFonts.nunito(
                            fontSize: 16,
                            color: Colors.grey.shade700,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 24),
                        
                        // Animated icon
                        _hasJoined 
                          ? Lottie.network(
                              'https://assets1.lottiefiles.com/packages/lf20_touohxv0.json', // Confetti animation
                              width: 200,
                              height: 200,
                              controller: _confettiController,
                            )
                          : Lottie.network(
                              'https://assets5.lottiefiles.com/packages/lf20_oyi9jbgc.json', // Video camera animation
                              width: 200,
                              height: 200,
                              repeat: true,
                            ),
                        const SizedBox(height: 24),
                        
                        // Description
                        Text(
                          _hasJoined
                            ? 'You\'ve joined the project!'
                            : isCurrentUserOrganizer
                                ? 'You\'re the organizer of this project'
                                : 'You\'ve been invited to contribute to this special video project!',
                          style: GoogleFonts.nunito(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: _hasJoined ? Colors.green : Colors.indigo.shade900,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _hasJoined
                            ? 'Taking you to the project...'
                            : isCurrentUserOrganizer
                                ? 'You already have access to this project'
                                : 'Join and add your special video message to make this moment special!',
                          style: GoogleFonts.nunito(
                            fontSize: 16,
                            color: Colors.grey.shade700,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 32),
                        
                        // Action button
                        if (!_hasJoined)
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton(
                              onPressed: isCurrentUserOrganizer 
                                ? () => Navigator.pushReplacement(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) => MomentDetailScreen(moment: project),
                                    ),
                                  )
                                : _isJoining ? null : () => _joinProject(project),
                              style: ElevatedButton.styleFrom(
                                foregroundColor: Colors.white,
                                backgroundColor: isCurrentUserOrganizer ? Colors.blue : Colors.pink,
                                disabledBackgroundColor: Colors.grey,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(30),
                                ),
                                padding: const EdgeInsets.symmetric(vertical: 16),
                              ),
                              child: _isJoining
                                ? const SizedBox(
                                    height: 24,
                                    width: 24,
                                    child: CircularProgressIndicator(
                                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                      strokeWidth: 2,
                                    ),
                                  )
                                : Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        isCurrentUserOrganizer 
                                          ? Icons.visibility 
                                          : Icons.celebration_outlined,
                                        size: 20,
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                        isCurrentUserOrganizer ? 'View Project' : 'Join Project',
                                        style: GoogleFonts.nunito(
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ],
                                  ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
                
                const Spacer(),
              ],
            ),
          ),
        ),
      ],
    );
  }
} 