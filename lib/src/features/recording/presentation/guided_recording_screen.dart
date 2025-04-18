import 'dart:async';
import 'dart:io'; // Import File
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;

import '../../../models/project.dart';
import 'review_trim_screen.dart'; // Import the next screen

// Convert to StatefulWidget
class GuidedRecordingScreen extends StatefulWidget {
  final Project project;
  final String prompt;

  const GuidedRecordingScreen({super.key, required this.project, required this.prompt});

  @override
  State<GuidedRecordingScreen> createState() => _GuidedRecordingScreenState();
}

class _GuidedRecordingScreenState extends State<GuidedRecordingScreen> {
  List<CameraDescription>? cameras;
  CameraController? _controller;
  bool _isCameraInitialized = false;
  bool _isRecording = false;
  Timer? _timer;
  int _remainingTime = 60; // Timer in seconds
  String? _videoPath;

  @override
  void initState() {
    super.initState();
    _initializeCamera();
  }

  @override
  void dispose() {
    _controller?.dispose(); // Dispose controller when screen is disposed
    _timer?.cancel(); // Cancel timer on dispose
    super.dispose();
  }

  Future<void> _initializeCamera() async {
    try {
      cameras = await availableCameras();
      if (cameras == null || cameras!.isEmpty) {
        print("Error: No cameras available");
        // Handle error: show a message to the user
        if (mounted) setState(() => _isCameraInitialized = false);
        return;
      }
      
      // Select the front camera if available, otherwise the first camera
      CameraDescription selectedCamera = cameras!.firstWhere(
        (camera) => camera.lensDirection == CameraLensDirection.front,
        orElse: () => cameras!.first, // Fallback to the first camera
      );

      _controller = CameraController(
        selectedCamera,
        ResolutionPreset.high, // Or adjust preset as needed
        enableAudio: true,
      );

      await _controller!.initialize();
      if (!mounted) return;
      setState(() {
        _isCameraInitialized = true;
      });
    } catch (e) {
      print("Error initializing camera: $e");
      // Handle initialization error
      setState(() => _isCameraInitialized = false);
    }
  }

  void _startTimer() {
    _remainingTime = 60;
    _timer?.cancel(); // Cancel any existing timer
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      setState(() {
        if (_remainingTime > 0) {
          _remainingTime--;
        } else {
          timer.cancel();
          if (_isRecording) {
            _stopRecording(); // Stop recording automatically when time runs out
          }
        }
      });
    });
  }

  Future<void> _startRecording() async {
    if (!_isCameraInitialized || _controller == null || _controller!.value.isRecordingVideo) {
      return;
    }
    try {
      // Ensure the path exists
      final Directory extDir = await getTemporaryDirectory();
      final String dirPath = '${extDir.path}/Movies/flutter_test';
      await Directory(dirPath).create(recursive: true);
      final String filePath = path.join(dirPath, '${DateTime.now().millisecondsSinceEpoch}.mp4');
      
      await _controller!.startVideoRecording();
      setState(() {
        _isRecording = true;
        _videoPath = filePath; // Store path immediately
      });
      _startTimer(); // Start the countdown timer
      print("Recording started, path: $_videoPath");
    } catch (e) {
      print("Error starting recording: $e");
      setState(() => _isRecording = false);
    }
  }

  Future<void> _stopRecording() async {
    if (!_isRecording || _controller == null || !_controller!.value.isRecordingVideo) {
      return;
    }
    _timer?.cancel(); // Stop the timer
    try {
      final XFile videoFile = await _controller!.stopVideoRecording();
      // Use the path from the XFile returned by the camera plugin
      final String finalVideoPath = videoFile.path;
      print("Recording stopped. Using XFile path: $finalVideoPath");
      
      setState(() {
        _isRecording = false;
        _videoPath = finalVideoPath; // Update _videoPath with the correct path
      });
      
      if (!mounted) return;
      
      // Navigate to review/trim screen with the XFile path and prompt
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => ReviewTrimScreen(
            project: widget.project, 
            videoPath: finalVideoPath, // Use the correct path from XFile
            prompt: widget.prompt, // Pass the prompt
          ),
        ),
      );
      
    } catch (e) {
      print("Error stopping recording: $e");
      setState(() => _isRecording = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_isCameraInitialized || _controller == null) {
      return Scaffold(
        backgroundColor: Colors.black,
        appBar: AppBar(title: const Text('Preparing Camera...'), backgroundColor: Colors.transparent, elevation: 0),
        body: const Center(child: CircularProgressIndicator(color: Colors.white)),
      );
    }
    
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Camera Preview fills the screen
          Center(
            child: AspectRatio(
              aspectRatio: _controller!.value.isInitialized ? _controller!.value.aspectRatio : 1.0,
              child: _controller!.value.isInitialized ? CameraPreview(_controller!) : Container(color: Colors.black),
            ),
          ),
          
          // Overlay with Prompt and Timer
          Positioned(
            top: MediaQuery.of(context).padding.top + 20,
            left: 20,
            right: 20,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.5),
                borderRadius: BorderRadius.circular(15),
              ),
              child: Text(
                widget.prompt,
                textAlign: TextAlign.center,
                style: GoogleFonts.nunito(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
          
          // Timer display
          if (_isRecording)
            Positioned(
              top: MediaQuery.of(context).padding.top + 80, // Position below prompt
              left: 0,
              right: 0,
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.6),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '0:${_remainingTime.toString().padLeft(2, '0')}',
                    style: GoogleFonts.nunito(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ),

          // Record Button Area
          Positioned(
            bottom: 40,
            left: 0,
            right: 0,
            child: Center(
              child: InkWell(
                onTap: _isRecording ? _stopRecording : _startRecording,
                child: Container(
                  width: 70,
                  height: 70,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: _isRecording ? Colors.white : Colors.red.shade700,
                    border: Border.all(
                      color: _isRecording ? Colors.red.shade700 : Colors.white,
                      width: 4,
                    ),
                  ),
                  child: Icon(
                    _isRecording ? Icons.stop_rounded : Icons.circle,
                    color: _isRecording ? Colors.red.shade700 : Colors.white,
                    size: _isRecording ? 40 : 0, // Show stop icon only when recording
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
} 