import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:ui'; // For ImageFilter

import '../../../models/project.dart'; // Assuming Project model path
import 'guided_recording_screen.dart'; // Import the next screen

class PromptDisplayScreen extends StatelessWidget {
  final Project project;

  const PromptDisplayScreen({super.key, required this.project});

  // Simulated prompt generation (replace with actual AI call later)
  String _getSimulatedPrompt(String occasion) {
    final occasionLower = occasion.toLowerCase();
    List<String> prompts;

    if (occasionLower.contains("father") || occasionLower == "dad" || occasionLower == "daddy") {
      prompts = [
        "Share your favorite funny story involving Dad.",
        "What's one piece of advice Dad gave you that you'll never forget?",
        "Describe a time Dad made you feel incredibly proud.",
        "What's Dad's most unique quality that you love?",
        "If you could thank Dad for one specific thing, what would it be and why?"
      ];
    } else { // Default to Mother's Day prompts
      prompts = [
        "Share a cherished memory with Mom from your childhood.",
        "What's something Mom taught you that shaped who you are today?",
        "Describe a moment Mom's strength inspired you.",
        "What makes Mom laugh the hardest?",
        "Tell Mom one thing you deeply appreciate about her."
      ];
    }
    // Simple random selection for now
    return (prompts..shuffle()).first;
  }

  @override
  Widget build(BuildContext context) {
    final String prompt = _getSimulatedPrompt(project.occasion ?? "Mother's Day");
    final theme = Theme.of(context);
    final screenSize = MediaQuery.of(context).size;

    return Scaffold(
      backgroundColor: Colors.black, // Base background
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Subtle background gradient matching detail screen's logic (optional)
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Theme.of(context).colorScheme.primaryContainer.withOpacity(0.5), // Use theme colors if available
                  Theme.of(context).colorScheme.primary.withOpacity(0.3),
                  Colors.black.withOpacity(0.8),
                ],
                stops: const [0.0, 0.4, 1.0],
              ),
            ),
          ),
          // Frosted glass effect overlay - Using a Container with Gradient
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Colors.white.withOpacity(0.15),
                  Colors.white.withOpacity(0.05),
                ],
                stops: const [0.1, 0.9],
              ),
            ),
          ),
          // Blurred overlay to enhance the frosted effect (Optional, use if performance allows)
          // BackdropFilter(
          //   filter: ImageFilter.blur(sigmaX: 5.0, sigmaY: 5.0),
          //   child: Container(color: Colors.black.withOpacity(0.05)),
          // ),

          // Centered content
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(32.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // "Prompt" title
                  Text(
                    'Your Prompt:',
                    style: GoogleFonts.nunito(
                      color: Colors.white.withOpacity(0.7),
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 24),

                  // The Prompt Text - styled for impact
                  Container(
                    padding: const EdgeInsets.all(24.0),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.05),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: Colors.white.withOpacity(0.1), width: 0.5),
                    ),
                    child: Text(
                      prompt,
                      textAlign: TextAlign.center,
                      style: GoogleFonts.nunito(
                        color: Colors.white,
                        fontSize: 28,
                        fontWeight: FontWeight.w700,
                        height: 1.4, // Line height for readability
                         shadows: [ Shadow(blurRadius: 5.0, color: Colors.black.withOpacity(0.3), offset: const Offset(1, 1)) ]
                      ),
                    ),
                  ),
                  const Spacer(), // Pushes button to the bottom

                  // Record Button
                  ElevatedButton.icon(
                    icon: const Icon(Icons.videocam_rounded, size: 24),
                    label: Text(
                      'Start Recording',
                      style: GoogleFonts.nunito(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    onPressed: () {
                       print('Start Recording Tapped');
                       Navigator.pushReplacement( // Replace this screen
                         context,
                         MaterialPageRoute(
                           builder: (context) => GuidedRecordingScreen(project: project, prompt: prompt),
                         ),
                       );
                    },
                    style: ElevatedButton.styleFrom(
                      foregroundColor: Colors.black, backgroundColor: Colors.white, // Button text color
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(30),
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                      elevation: 5,
                    ),
                  ),
                  const SizedBox(height: 20), // Space at bottom
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
} 