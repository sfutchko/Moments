import 'dart:async';
import 'dart:ui' as ui;
import 'package:flutter/foundation.dart'; // Import for compute
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:palette_generator/palette_generator.dart'; // Import palette_generator
import 'package:flutter/services.dart' show rootBundle; // Import for rootBundle

import '../../../services/auth_service.dart';
import '../../../services/database_service.dart';
import '../../../models/project.dart';
import '../../moment_detail/presentation/moment_detail_screen.dart';
import '../../create_moment/presentation/create_moment_screen.dart';
import '../../settings/presentation/settings_screen.dart';

// Replace SF Pro Rounded text style extension with Nunito text styles
extension NunitoText on TextTheme {
  TextStyle get appTitle => GoogleFonts.nunito(
    color: Colors.white,
    fontSize: 42,
    fontWeight: FontWeight.w700,
    letterSpacing: -0.5,
  );
  
  TextStyle get appHeadline => GoogleFonts.nunito(
    color: Colors.white, 
    fontWeight: FontWeight.w700,
    fontSize: 38,
  );
  
  TextStyle get appSubtitle => GoogleFonts.nunito(
    color: Colors.white70,
    fontWeight: FontWeight.w500,
    fontSize: 14,
  );
  
  TextStyle get appButton => GoogleFonts.nunito(
    fontSize: 16,
    fontWeight: FontWeight.w600,
  );
}

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final userId = context.select<User?, String?>((user) => user?.uid);
    final dbService = context.watch<DatabaseService>();
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // --- Custom Header Row ---
            const SizedBox(height: 8.0),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 8.0),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // Title with Nunito font
                  Text(
                    'Moments',
                    style: theme.textTheme.appTitle,
                  ),
                  const Spacer(),
                  // Add Button
                  IconButton(
                    icon: const Icon(Icons.add_circle_outline, color: Colors.white),
                    iconSize: 28.0,
                    tooltip: 'Create Moment',
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => const CreateMomentScreen()),
                      );
                    },
                  ),
                  const SizedBox(width: 8),
                  // Profile Button
                  IconButton(
                    icon: const Icon(Icons.account_circle, color: Colors.white),
                    iconSize: 28.0,
                    tooltip: 'Settings',
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => const SettingsScreen()),
                      );
                    },
                  ),
                ],
              ),
            ),
            // --- Main Content Area (Empty or Carousel) ---
            Expanded(
              child: userId == null
                  ? const Center(child: CircularProgressIndicator())
                  : StreamBuilder<List<Project>>(
                      stream: dbService.getMomentsForUser(userId),
                      builder: (context, snapshot) {
                        if (snapshot.connectionState == ConnectionState.waiting) {
                          return const Center(child: CircularProgressIndicator());
                        }
                        if (snapshot.hasError) {
                          return Center(child: Text('Error loading moments.', style: theme.textTheme.bodySmall));
                        }
                        if (!snapshot.hasData || snapshot.data!.isEmpty) {
                          return _buildEmptyState(context);
                        }

                        final moments = snapshot.data!;
                        
                        // Use our new stateful content widget
                        return MomentsPageView(
                          moments: moments, 
                          userId: userId,
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  // Helper widget for the updated empty state
  Widget _buildEmptyState(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 24.0),
        padding: const EdgeInsets.symmetric(vertical: 40.0),
        decoration: BoxDecoration(
          color: const Color(0xFF1A1A1A),
          borderRadius: BorderRadius.circular(35.0),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.calendar_today, size: 55, color: Colors.grey.shade400),
            const SizedBox(height: 24),
            Text(
              'No Upcoming Moments',
              style: GoogleFonts.nunito(
                color: Colors.white,
                fontWeight: FontWeight.w700,
                fontSize: 22,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 40.0),
              child: Text(
                'Moments you create or are invited to will appear here.',
                style: GoogleFonts.nunito(
                  color: Colors.grey.shade400,
                  fontWeight: FontWeight.w500,
                ),
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: 36),
            ElevatedButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const CreateMomentScreen()),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: Colors.black,
                minimumSize: const Size(200, 50),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(30),
                ),
              ),
              child: Text('Create Moment', 
                style: theme.textTheme.appButton.copyWith(color: Colors.black),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// New StatefulWidget for the PageView and background
class MomentsPageView extends StatefulWidget {
  final List<Project> moments;
  final String? userId;
  
  const MomentsPageView({
    super.key,
    required this.moments,
    required this.userId,
  });
  
  @override
  State<MomentsPageView> createState() => _MomentsPageViewState();
}

class _MomentsPageViewState extends State<MomentsPageView> {
  int _currentIndex = 0;
  final Map<int, List<Color>> _gradientCache = {};
  List<Color> _currentGradient = [ 
    Colors.black,
    const Color(0xFF231F20),
    const Color(0xFF2D2424),
  ];

  @override
  void initState() {
    super.initState();
    print('[MomentsPageView] initState - Initializing background.');
    if (widget.moments.isNotEmpty) {
      _updateBackgroundForPage(0);
    } else {
      print('[MomentsPageView] initState - No moments, using default background.');
    }
  }

  // New instance method for palette generation on main isolate
  Future<List<Color>> _generateGradientFromImagePath(String imagePath) async {
    print('[PaletteGenerator] Starting extraction for: $imagePath (on main isolate)');
    try {
      final PaletteGenerator palette = await PaletteGenerator.fromImageProvider(
        AssetImage(imagePath), // Use directly
        // size: const Size(200, 200), // No size needed here either
        maximumColorCount: 16, 
      );
      print('[PaletteGenerator] Palette generated for $imagePath. Dominant: ${palette.dominantColor?.color}, Vibrant: ${palette.vibrantColor?.color}, Muted: ${palette.mutedColor?.color}');

      // Extract colors - prioritize vibrant, then dominant, then muted
      Color color1 = Colors.black; 
      Color color2 = palette.dominantColor?.color ?? const Color(0xFF2D2424); 
      Color color3 = palette.darkMutedColor?.color ?? palette.darkVibrantColor?.color ?? const Color(0xFF1A1A1A);

      if (palette.darkVibrantColor != null) {
        color1 = palette.darkVibrantColor!.color;
        color3 = Colors.black;
      } else if (palette.darkMutedColor != null) {
        color1 = palette.darkMutedColor!.color;
        color3 = Colors.black;
      }

      if (palette.vibrantColor != null) {
        color2 = palette.vibrantColor!.color;
      } else if (palette.lightVibrantColor != null) {
        color2 = palette.lightVibrantColor!.color;
      } else if (palette.mutedColor != null) {
        color2 = palette.mutedColor!.color;
      }

      if (color1 == color2) color2 = palette.lightMutedColor?.color ?? color2;
      if (color2 == color3) color3 = palette.dominantColor?.color.withOpacity(0.7) ?? color3;

      final resultGradient = [color1, color2, color3];
      print('[PaletteGenerator] Result gradient for $imagePath: $resultGradient');
      return resultGradient;

    } catch (e) {
      print('[PaletteGenerator] ERROR generating palette for $imagePath: $e');
      return [ // Fallback gradient
        Colors.black,
        const Color(0xFF231F20),
        const Color(0xFF2D2424),
      ];
    }
  }

  Future<void> _updateBackgroundForPage(int index) async {
    if (!mounted) return; 
    print('[MomentsPageView] _updateBackgroundForPage called for index: $index');

    final imageIndex = index % 3; 
    final imagePath = 'assets/images/${imageIndex + 1}.png';
    print('[MomentsPageView] Corresponding image path: $imagePath (imageIndex: $imageIndex)');

    if (_gradientCache.containsKey(imageIndex)) {
      print('[MomentsPageView] Cache HIT for imageIndex: $imageIndex. Using cached gradient.');
      if (mounted) {
        setState(() {
          _currentGradient = _gradientCache[imageIndex]!;
           print('[MomentsPageView] setState (from cache) for index $index. New gradient: $_currentGradient');
        });
      }
      return;
    }

    print('[MomentsPageView] Cache MISS for imageIndex: $imageIndex. Starting generation on main isolate...');
    try {
      // Call the new instance method directly - NO COMPUTE
      final List<Color> newGradient = await _generateGradientFromImagePath(imagePath);
      print('[MomentsPageView] Generation finished for index $index. Received gradient: $newGradient');

      _gradientCache[imageIndex] = newGradient;
      print('[MomentsPageView] Stored gradient in cache for imageIndex: $imageIndex');

      if (mounted && index == _currentIndex) {
        print('[MomentsPageView] Index $index matches current index $_currentIndex. Updating state...');
        setState(() {
          _currentGradient = newGradient;
           print('[MomentsPageView] setState (after generation) for index $index. New gradient: $_currentGradient');
        });
      } else {
         print('[MomentsPageView] Index $index DOES NOT match current index $_currentIndex. State not updated immediately.');
      }
    } catch (e) {
        print("[MomentsPageView] ERROR during palette generation: $e");
        if (mounted && index == _currentIndex) {
          setState(() {
            _currentGradient = [ Colors.black, Colors.red.shade900, Colors.black]; // Error gradient
          });
        }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Use the _currentGradient state variable
    print('[MomentsPageView] build method. Current index: $_currentIndex, Current gradient: $_currentGradient');
    final screenSize = MediaQuery.of(context).size;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 800), // Slightly longer duration for smoother feel
      curve: Curves.easeInOut, // Add easing curve
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: _currentGradient, // Use state variable
          stops: const [0.0, 0.6, 1.0], // Keep stops for now
        ),
      ),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const SizedBox(height: 20), // Space at top
            Container(
              height: 550,
              child: PageView.builder(
                itemCount: widget.moments.length,
                controller: PageController(viewportFraction: 0.9),
                onPageChanged: (index) {
                  if (!mounted) return;
                  print('[MomentsPageView] onPageChanged - New index: $index');
                  setState(() {
                    _currentIndex = index; // Update index immediately for responsiveness
                  });
                  // Trigger background update for the new page
                  _updateBackgroundForPage(index);
                },
                itemBuilder: (context, index) {
                  // Pass the correct imageIndex based on page index
                  final imageIndexForCard = index % 3;
                  return Container(
                    margin: const EdgeInsets.symmetric(horizontal: 16.0),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(25.0),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.2),
                          blurRadius: 10,
                          spreadRadius: 2,
                        ),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(22.0),
                      child: _SimpleMomentCard(
                        moment: widget.moments[index],
                        // Pass the calculated imageIndex for the card's image path
                        imageIndex: imageIndexForCard,
                        currentUserId: widget.userId,
                      ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 20), // Space at bottom
          ],
        ),
      ),
    );
  }
}

// --- Simplified Moment Card with no blur effects ---
class _SimpleMomentCard extends StatelessWidget {
  final Project moment;
  final int imageIndex;
  final String? currentUserId;

  const _SimpleMomentCard({
    required this.moment,
    required this.imageIndex,
    required this.currentUserId,
  });

  @override
  Widget build(BuildContext context) {
    final String imagePath = 'assets/images/${(imageIndex % 3) + 1}.png';
    final bool isHosting = currentUserId != null && currentUserId == moment.organizerId;
    final dbService = Provider.of<DatabaseService>(context, listen: false);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => MomentDetailScreen(moment: moment)),
          );
        },
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Layer 1: Background Image
            Image.asset(
              imagePath,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) =>
                Container(color: Colors.grey.shade800, child: const Center(child: Icon(Icons.broken_image))),
            ),
            
            // New implementation for the bottom gradient blur effect
            Positioned(
              bottom: 0,
              left: 0, // Extend to screen edges
              right: 0, // Extend to screen edges
              height: 190.0, // Keep fixed height
              child: ClipRRect(
                // Round only the top corners
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(25.0), 
                  topRight: Radius.circular(25.0),
                ),
                // Use a Container with a gradient simulating the faded blur
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      // Colors chosen to simulate the frosted look with fade - Increased opacity
                      colors: [
                        Colors.transparent,             // Start transparent
                        const Color(0x4DFFFFFF),        // White @ 30% opacity
                        const Color(0x7F9E9ABF),        // Light purplish grey @ 50% opacity
                        const Color(0x998C89A6),        // Slightly darker purplish grey @ 60% opacity
                      ],
                      // Stops to control the fade and color transition
                      stops: const [0.0, 0.15, 0.5, 1.0],
                    ),
                  ),
                  child: Center( // Keep text centered
                    child: Text(
                      moment.title,
                      style: GoogleFonts.openSans(
                        color: Colors.white,
                        fontSize: 42,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                  ),
                ), 
              ),
            ),
            
            // Layer 5: Hosting Badge (pill-shaped)
            if (isHosting)
              Positioned(
                top: 12.0,
                left: 12.0,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14.0, vertical: 6.0),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.4),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    'Hosting',
                    style: GoogleFonts.nunito(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
              
            // Layer 6: Delete button (only visible for organizer)
            if (isHosting)
              Positioned(
                top: 12.0,
                right: 12.0,
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(50),
                    onTap: () => _confirmDelete(context, dbService, moment),
                    child: Container(
                      padding: const EdgeInsets.all(8.0),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.4),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.delete_outline,
                        color: Colors.white,
                        size: 20,
                      ),
                    ),
                  ),
                ),
              )
          ],
        ),
      ),
    );
  }
  
  // Show confirmation dialog before deleting
  Future<void> _confirmDelete(BuildContext context, DatabaseService dbService, Project moment) async {
    return showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          backgroundColor: const Color(0xFF1A1A1A),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: Text(
            'Delete Moment', 
            style: GoogleFonts.nunito(
              color: Colors.white, 
              fontWeight: FontWeight.w700,
            ),
          ),
          content: Text(
            'Are you sure you want to delete "${moment.title}"? This action cannot be undone.',
            style: GoogleFonts.nunito(
              color: Colors.white70,
              fontWeight: FontWeight.w500,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: Text(
                'Cancel', 
                style: GoogleFonts.nunito(
                  color: Colors.grey,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            TextButton(
              onPressed: () async {
                // Close the dialog first
                Navigator.of(dialogContext).pop();
                
                // Show loading indicator
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Deleting moment...'),
                    duration: Duration(seconds: 1),
                  ),
                );
                
                // Delete the project
                final success = await dbService.deleteProject(moment.id);
                
                // Show result
                if (success && context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Moment deleted successfully'),
                      backgroundColor: Colors.green,
                    ),
                  );
                } else if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Failed to delete moment'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              },
              child: Text(
                'Delete',
                style: GoogleFonts.nunito(
                  color: Colors.red, 
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}