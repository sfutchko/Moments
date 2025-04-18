import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../services/database_service.dart';
import '../../../models/project.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../moment_detail/presentation/moment_detail_screen.dart';

class JoinProjectScreen extends StatefulWidget {
  final String projectId;

  const JoinProjectScreen({
    Key? key,
    required this.projectId,
  }) : super(key: key);

  @override
  State<JoinProjectScreen> createState() => _JoinProjectScreenState();
}

class _JoinProjectScreenState extends State<JoinProjectScreen> with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;
  bool _isLoading = true;
  Project? _project;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _scaleAnimation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOutBack,
    );
    _loadProjectDetails();
    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _loadProjectDetails() async {
    final databaseService = Provider.of<DatabaseService>(context, listen: false);
    try {
      final project = await databaseService.getProjectById(widget.projectId);
      setState(() {
        _project = project;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Unable to load the invitation. The project may no longer exist.';
        _isLoading = false;
      });
    }
  }

  void _joinProject() {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (context) => MomentDetailScreen(
          moment: _project!,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Colors.blue.shade300,
              Colors.purple.shade300,
            ],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: _isLoading
                ? const CircularProgressIndicator(color: Colors.white)
                : _errorMessage != null
                    ? _buildErrorView()
                    : _buildInvitationView(),
          ),
        ),
      ),
    );
  }

  Widget _buildErrorView() {
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.error_outline,
            size: 80,
            color: Colors.white,
          ),
          const SizedBox(height: 24),
          Text(
            'Invitation Error',
            style: GoogleFonts.poppins(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            _errorMessage!,
            textAlign: TextAlign.center,
            style: GoogleFonts.poppins(
              fontSize: 16,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 32),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: Colors.purple.shade700,
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(30),
              ),
            ),
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Return to Home'),
          ),
        ],
      ),
    );
  }

  Widget _buildInvitationView() {
    return ScaleTransition(
      scale: _scaleAnimation,
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.9),
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 20,
                    spreadRadius: 5,
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.celebration,
                    size: 64,
                    color: Colors.purple,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'You\'re Invited!',
                    style: GoogleFonts.poppins(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.purple.shade700,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    _project?.title ?? 'Moments Project',
                    style: GoogleFonts.poppins(
                      fontSize: 20,
                      fontWeight: FontWeight.w600,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Organized by ${_project?.organizerName ?? 'Someone special'}',
                    style: GoogleFonts.poppins(
                      fontSize: 16,
                      color: Colors.black54,
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    _project?.occasion != null && _project!.occasion!.isNotEmpty
                        ? 'Celebrating: ${_project!.occasion}'
                        : 'Join this special moment',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.poppins(
                      fontSize: 16,
                      fontStyle: FontStyle.italic,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 32),
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.purple.shade600,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(30),
                            ),
                          ),
                          onPressed: _joinProject,
                          child: const Text('Accept & Join'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: Text(
                      'Return to Home',
                      style: GoogleFonts.poppins(
                        color: Colors.purple.shade700,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
} 