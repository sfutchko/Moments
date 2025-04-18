import 'dart:io'; // For File type hint
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:video_editor/video_editor.dart'; // Import video_editor
import 'package:path_provider/path_provider.dart'; // For potential export path
import 'package:path/path.dart' as path_pkg; // Use alias to avoid conflicts
import 'package:firebase_auth/firebase_auth.dart'; // Import FirebaseAuth
import 'package:ffmpeg_kit_flutter_full_gpl/ffmpeg_kit.dart';
import 'package:ffmpeg_kit_flutter_full_gpl/return_code.dart';

import '../../../models/project.dart';
import '../../../services/database_service.dart'; // For future use
import '../../../services/storage_service.dart'; // For future use
import 'package:provider/provider.dart'; // For future use

// Convert to StatefulWidget
class ReviewTrimScreen extends StatefulWidget {
  final Project project;
  final String videoPath;
  final String prompt;

  const ReviewTrimScreen({
    super.key, 
    required this.project, 
    required this.videoPath, 
    required this.prompt,
  });

  @override
  State<ReviewTrimScreen> createState() => _ReviewTrimScreenState();
}

class _ReviewTrimScreenState extends State<ReviewTrimScreen> {
  late VideoEditorController _controller;
  bool _isExporting = false;
  double _exportProgress = 0.0;
  
  @override
  void initState() {
    super.initState();
    print("ReviewTrimScreen received prompt: ${widget.prompt}");
    _controller = VideoEditorController.file(
      File(widget.videoPath), 
      maxDuration: const Duration(seconds: 60), // Ensure max duration consistency
    );
    _controller.initialize(aspectRatio: 9/16).then((_) {
      if (mounted) {
        setState(() {}); // Update UI after initialization
      }
    }).catchError((error) {
       print("Error initializing VideoEditorController: $error");
       // Handle error (e.g., show a dialog or navigate back)
       if (mounted) {
         ScaffoldMessenger.of(context).showSnackBar(
           SnackBar(content: Text('Error loading video: $error'), backgroundColor: Colors.red)
         );
         Navigator.pop(context);
       }
    });
  }

  @override
  void dispose() {
    // dispose needs to be called only if initialized
    if (_controller.initialized) {
      _controller.dispose();
    }
    super.dispose();
  }
  
  Future<void> _exportAndUploadVideo() async {
    setState(() {
       _isExporting = true;
       _exportProgress = 0.0;
    });
    final storageService = context.read<StorageService>();
    final dbService = context.read<DatabaseService>();
    final user = context.read<User?>();
    
    if (user == null) {
       print("Error: User not logged in during upload attempt.");
       if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
             const SnackBar(content: Text('Error: You must be logged in to upload.'), backgroundColor: Colors.red)
          );
          setState(() => _isExporting = false);
       }
       return;
    }
    
    final String contributorId = user.uid;
    final String contributorName = user.displayName ?? user.email ?? 'Anonymous User'; 
    
    // 1. Generate Export Path
    final String fileName = 'trimmed_${DateTime.now().millisecondsSinceEpoch}.mp4';
    final Directory extDir = await getTemporaryDirectory();
    final String exportPath = path_pkg.join(extDir.path, fileName);
    
    // 2. Manually Construct FFmpeg Command using controller values
    final String inputPath = _controller.file.path; // Get input path from controller
    final Duration start = _controller.startTrim; // Get start trim duration
    final Duration end = _controller.endTrim;     // Get end trim duration
    final Duration duration = end - start;        // Calculate trimmed duration

    // Basic FFmpeg command for trimming
    // -ss: start time, -t: duration, -i: input
    // Removed -c copy for more reliable trimming (forces re-encoding)
    final String commandToExecute = '-ss ${start.inSeconds}.${start.inMilliseconds.remainder(1000)} -t ${duration.inSeconds}.${duration.inMilliseconds.remainder(1000)} -i "$inputPath" "$exportPath"';
    
    // TODO: Add rotation/crop filters to the command if needed, e.g.:
    // final rotation = _controller.rotation;
    // final crop = _controller.crop;
    // String filters = ""; 
    // if (rotation != 0) filters += "transpose=$rotation"; // Needs mapping rotation to transpose values
    // if (crop != Rect.zero) filters += "${filters.isNotEmpty ? "," : ""}crop=..." // Needs crop calculation
    // final String commandWithFilters = '-i "$inputPath" -vf "$filters" -ss ... -t ... "$exportPath"'

    print("Executing FFmpeg command: $commandToExecute");

    try {
      // Execute the FFmpeg command using FFmpegKit
      final session = await FFmpegKit.execute(commandToExecute);
      final returnCode = await session.getReturnCode();
      
      if (ReturnCode.isSuccess(returnCode)) { // Success
        print("FFmpeg export successful. Output path: $exportPath");
        final exportedFile = File(exportPath);
        
        if (!exportedFile.existsSync()) {
          print("Export successful but file not found at path!");
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Error finding exported video file.'), backgroundColor: Colors.red)
            );
            setState(() => _isExporting = false);
          }
          return;
        }

        // --- Upload Logic --- 
        if (!mounted) return;
        try {
          final String? downloadUrl = await storageService.uploadVideoClip(widget.project.id, exportedFile);
          if (downloadUrl != null) {
            final bool success = await dbService.addVideoClipToProject(
              projectId: widget.project.id,
              videoUrl: downloadUrl,
              contributorId: contributorId,
              contributorName: contributorName,
              prompt: widget.prompt, 
            );
            if (success && mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Video uploaded successfully!'), backgroundColor: Colors.green)
              );
              Navigator.popUntil(context, (route) => route.isFirst); // Go home
            } else if (mounted) {
              throw Exception("Failed to save video metadata to database.");
            }
          } else {
            throw Exception("Failed to upload video file.");
          }
        } catch (e, s) {
          print("Error during upload/database update: $e\n$s");
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Error uploading video: $e'), backgroundColor: Colors.red)
            );
          }
        } finally {
          if (mounted) setState(() => _isExporting = false);
        }
        // --- End Upload Logic ---
      } else {
        final failStackTrace = await session.getFailStackTrace();
        print("FFmpeg export failed: ${returnCode?.getValue() ?? 'Unknown'}\n$failStackTrace");
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error trimming video: ${returnCode?.getValue() ?? 'Unknown error'}'), backgroundColor: Colors.red)
          );
          setState(() => _isExporting = false);
        }
      }
    } catch (e) {
      print("Error executing FFmpeg command: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error executing FFmpeg: $e'), backgroundColor: Colors.red)
        );
        setState(() => _isExporting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text('Review & Trim'),
        backgroundColor: Colors.black,
        elevation: 0,
        actions: [
          IconButton(
            // Use controller.isPlaying directly
            icon: Icon(_controller.isPlaying ? Icons.pause : Icons.play_arrow),
            // Check controller.initialized directly
            onPressed: _controller.initialized ? () async {
              // Use controller.video.pause() and controller.video.play()
              if (_controller.isPlaying) {
                await _controller.video.pause();
              } else {
                await _controller.video.play();
              }
              setState(() {});
            } : null,
          ),
        ],
      ),
      body: !_controller.initialized 
          ? const Center(child: CircularProgressIndicator()) 
          : SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    // Video Preview Area
                    Expanded(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            // Use CropGridViewer.preview for the preview area
                            CropGridViewer.preview(controller: _controller),
                            AnimatedBuilder(
                              animation: _controller.video,
                              builder: (_, __) => Opacity(
                                opacity: _controller.isPlaying ? 0 : 1,
                                child: GestureDetector(
                                  onTap: _controller.video.play, 
                                  child: Container(
                                    width: 40,
                                    height: 40,
                                    decoration: const BoxDecoration(
                                      color: Colors.white,
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Icon(Icons.play_arrow, color: Colors.black),
                                  ),
                                ),
                              ),
                            ),
                            // Progress indicator during export
                            if (_isExporting)
                              Container(
                                color: Colors.black.withOpacity(0.7),
                                child: Center(
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      CircularProgressIndicator(value: _exportProgress, color: Colors.white),
                                      const SizedBox(height: 16),
                                      Text(
                                        "Processing... ${(_exportProgress * 100).toStringAsFixed(0)}%",
                                        style: GoogleFonts.nunito(color: Colors.white),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    
                    // Trimming Slider Area
                    Container(
                      margin: const EdgeInsets.symmetric(horizontal: 10),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: _trimSlider(),
                      ),
                    ),
                    const SizedBox(height: 20),
                    
                    // Action Buttons
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(backgroundColor: Colors.grey.shade800),
                          onPressed: _isExporting ? null : () => Navigator.pop(context), // Go back
                          child: Text('Record Again', style: GoogleFonts.nunito(color: Colors.white)),
                        ),
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                          onPressed: _isExporting ? null : _exportAndUploadVideo,
                          child: _isExporting
                            ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                            : Text('Export & Upload', style: GoogleFonts.nunito(color: Colors.white)),
                        ),
                      ],
                    )
                  ],
                ),
              ),
            ),
    );
  }
  
  // Helper to build Trim Slider UI
  List<Widget> _trimSlider() {
    return [
      AnimatedBuilder(
        animation: Listenable.merge([
          _controller,
        ]),
        builder: (_, __) {
          final duration = _controller.videoDuration.inSeconds;
          final pos = _controller.videoPosition.inSeconds; 
          final start = _controller.startTrim.inSeconds;
          final end = _controller.endTrim.inSeconds;

          return Padding(
            padding: EdgeInsets.symmetric(horizontal: MediaQuery.of(context).size.width / 4),
            child: Row(children: [
              Text('${_formatDuration(_controller.videoPosition)}', style: const TextStyle(color: Colors.white)),
              const Expanded(child: SizedBox()),
              Text('${_formatDuration(_controller.videoDuration)}', style: const TextStyle(color: Colors.white)),
            ]),
          );
        },
      ),
      Container(
        width: MediaQuery.of(context).size.width,
        margin: const EdgeInsets.symmetric(vertical: 10),
        child: TrimSlider(
          controller: _controller,
          height: 45,
          horizontalMargin: 10.0,
          // Removed custom styling parameters
        ),
      )
    ];
  }

  // Helper to format duration (e.g., 0:15)
  String _formatDuration(Duration duration) {
    final minutes = duration.inMinutes.remainder(60);
    final seconds = duration.inSeconds.remainder(60);
    return '$minutes:${seconds.toString().padLeft(2, '0')}';
  }
} 