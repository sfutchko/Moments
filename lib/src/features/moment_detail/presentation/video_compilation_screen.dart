import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'dart:ui';

import '../../../models/project.dart';
import '../../../services/database_service.dart';
import '../../../services/storage_service.dart';
import '../../../services/video_compilation_service.dart';
import 'video_player_screen.dart';

class VideoCompilationScreen extends StatefulWidget {
  final Project project;
  
  const VideoCompilationScreen({
    Key? key,
    required this.project,
  }) : super(key: key);
  
  @override
  State<VideoCompilationScreen> createState() => _VideoCompilationScreenState();
}

class _VideoCompilationScreenState extends State<VideoCompilationScreen> {
  bool _isCompiling = false;
  double _progress = 0.0;
  String? _errorMessage;
  String? _compiledVideoPath;
  String? _compiledVideoUrl;
  
  @override
  void initState() {
    super.initState();
    // If project already has a compiled video, use that
    if (widget.project.compiledVideoUrl != null) {
      setState(() {
        _compiledVideoUrl = widget.project.compiledVideoUrl;
      });
    } else {
      // Otherwise start the compilation process
      _startCompilation();
    }
  }
  
  Future<void> _startCompilation() async {
    if (_isCompiling) return;
    
    setState(() {
      _isCompiling = true;
      _progress = 0.0;
      _errorMessage = null;
      _compiledVideoPath = null;
      _compiledVideoUrl = null;
    });
    
    try {
      final databaseService = context.read<DatabaseService>();
      final storageService = context.read<StorageService>();
      
      // Create a VideoCompilationService
      final compilationService = VideoCompilationService(
        storageService,
        databaseService: databaseService,
      );
      
      // Get video clips for this project
      final clipsStream = databaseService.getVideoClipsForProject(widget.project.id);
      final clips = await clipsStream.first;
      
      if (clips.isEmpty) {
        setState(() {
          _isCompiling = false;
          _errorMessage = 'No video clips found for this project';
        });
        return;
      }
      
      // Start compilation
      final compiledVideoUrl = await compilationService.compileVideos(
        widget.project.id,
        clips,
        (progress) {
          if (mounted) {
            setState(() {
              _progress = progress;
            });
          }
        },
      );
      
      if (compiledVideoUrl == null) {
        setState(() {
          _isCompiling = false;
          _errorMessage = 'Failed to compile videos';
        });
        return;
      }
      
      // Refresh the project to get the updated compiledVideoUrl
      final projectStream = databaseService.getProjectDetails(widget.project.id);
      final updatedProject = await projectStream.first;
      
      setState(() {
        _isCompiling = false;
        _compiledVideoPath = null; // No longer tracking the local path
        _compiledVideoUrl = compiledVideoUrl;
      });
    } catch (e) {
      setState(() {
        _isCompiling = false;
        _errorMessage = 'Error during compilation: $e';
      });
    }
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: Text(
          '${_getRecipientName(widget.project)}\'s Special Video',
          style: GoogleFonts.nunito(),
        ),
        backgroundColor: Colors.black,
        elevation: 0,
      ),
      body: _buildBody(),
    );
  }
  
  Widget _buildBody() {
    // If there's already a compiled video
    if (_compiledVideoUrl != null) {
      return _buildVideoPreview();
    }
    
    // If an error occurred
    if (_errorMessage != null) {
      return _buildErrorState();
    }
    
    // If compilation is in progress
    if (_isCompiling) {
      return _buildCompilingState();
    }
    
    // Default state - should not reach here
    return const Center(
      child: Text('Preparing to compile videos...', style: TextStyle(color: Colors.white)),
    );
  }
  
  Widget _buildVideoPreview() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Padding(
          padding: const EdgeInsets.all(20.0),
          child: Text(
            'The special video for ${_getRecipientName(widget.project)} is ready!',
            textAlign: TextAlign.center,
            style: GoogleFonts.nunito(
              color: Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        const SizedBox(height: 20),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20.0),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          Colors.purple.withOpacity(0.3),
                          Colors.blue.withOpacity(0.3),
                        ],
                      ),
                    ),
                  ),
                  Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        Icons.video_library,
                        color: Colors.white,
                        size: 60,
                      ),
                      const SizedBox(height: 20),
                      Text(
                        'Tap to play the video',
                        style: GoogleFonts.nunito(
                          color: Colors.white,
                          fontSize: 18,
                        ),
                      ),
                    ],
                  ),
                  // Create a transparent overlay for the entire container
                  Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => VideoPlayerScreen(
                              videoUrl: _compiledVideoUrl!,
                              contributorName: '${_getRecipientName(widget.project)}\'s Video',
                            ),
                          ),
                        );
                      },
                      splashColor: Colors.white.withOpacity(0.1),
                      highlightColor: Colors.white.withOpacity(0.05),
                      child: Container(
                        width: double.infinity,
                        height: double.infinity,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 20),
        Padding(
          padding: const EdgeInsets.all(20.0),
          child: ElevatedButton.icon(
            icon: const Icon(Icons.share),
            label: Text(
              'Share This Video',
              style: GoogleFonts.nunito(fontSize: 16),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(30),
              ),
            ),
            onPressed: () {
              // TODO: Implement sharing functionality
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Sharing will be implemented soon')),
              );
            },
          ),
        ),
        const SizedBox(height: 40),
      ],
    );
  }
  
  Widget _buildCompilingState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Video collage animation or icon
            const Icon(
              Icons.video_settings,
              color: Colors.white,
              size: 60,
            ),
            const SizedBox(height: 30),
            Text(
              'Creating a special video for ${_getRecipientName(widget.project)}',
              textAlign: TextAlign.center,
              style: GoogleFonts.nunito(
                color: Colors.white,
                fontSize: 22,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 40),
            // Progress indicator
            LinearProgressIndicator(
              value: _progress,
              backgroundColor: Colors.grey.shade800,
              valueColor: AlwaysStoppedAnimation<Color>(Colors.blue),
              minHeight: 10,
              borderRadius: BorderRadius.circular(10),
            ),
            const SizedBox(height: 16),
            Text(
              '${(_progress * 100).toInt()}%',
              style: GoogleFonts.nunito(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 40),
            Text(
              'This might take a few minutes. Please wait...',
              textAlign: TextAlign.center,
              style: GoogleFonts.nunito(
                color: Colors.white.withOpacity(0.7),
                fontSize: 16,
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildErrorState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.error_outline,
              color: Colors.red,
              size: 60,
            ),
            const SizedBox(height: 30),
            Text(
              'Failed to create video',
              textAlign: TextAlign.center,
              style: GoogleFonts.nunito(
                color: Colors.white,
                fontSize: 22,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              _errorMessage ?? 'An unknown error occurred',
              textAlign: TextAlign.center,
              style: GoogleFonts.nunito(
                color: Colors.red.shade300,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 40),
            ElevatedButton.icon(
              icon: const Icon(Icons.refresh),
              label: Text(
                'Try Again',
                style: GoogleFonts.nunito(fontSize: 16),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(30),
                ),
              ),
              onPressed: _startCompilation,
            ),
          ],
        ),
      ),
    );
  }
  
  // Helper to get recipient name (Mom/Dad) based on occasion
  String _getRecipientName(Project project) {
    // Default to "Mom" if occasion is null or unknown
    if (project.occasion == null) return "Mom";
    
    final occasion = project.occasion!.toLowerCase();
    if (occasion.contains("father") || occasion == "dad" || occasion == "daddy") {
      return "Dad";
    } else {
      // Default to Mom for "mother", "mom", "mommy", or any other occasion
      return "Mom";
    }
  }
} 