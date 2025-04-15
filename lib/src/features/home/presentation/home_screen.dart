import 'dart:async'; // Add this import
import 'dart:ui' as ui; // Import dart:ui for ImageFilter
import 'package:flutter/foundation.dart'; // Import for compute
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart'; // Import User
import 'package:cloud_firestore/cloud_firestore.dart'; // Import Timestamp if needed for formatting
import 'package:google_fonts/google_fonts.dart';
import 'package:palette_generator/palette_generator.dart';

import '../../../services/auth_service.dart';
import '../../../services/database_service.dart'; // Import DatabaseService
import '../../../models/project.dart'; // Import Project model
import '../../moment_detail/presentation/moment_detail_screen.dart'; // Import MomentDetailScreen
import '../../create_moment/presentation/create_moment_screen.dart'; // Import CreateMomentScreen
import '../../settings/presentation/settings_screen.dart';

// Helper function to run color extraction in an isolate
Future<List<Color>> _extractColorsIsolate(String imagePath) async {
  try {
    final palette = await PaletteGenerator.fromImageProvider(
      AssetImage(imagePath),
      size: const Size(100, 100), 
      maximumColorCount: 5,
    );
    final dominant = palette.dominantColor?.color;
    if (dominant != null) {
      return [
        Colors.black,
        dominant.withOpacity(0.7),
        dominant.withOpacity(0.4),
      ];
    }
  } catch (e) {
    print('Isolate color extraction error: $e');
  }
  // Return default on error or no dominant color
  return [Colors.black, const Color(0xFF1E1E1E), const Color(0xFF242424)];
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  // Define PageController
  late PageController _pageController;
  int _currentIndex = 0;
  bool _areColorsPrecomputed = false;
  
  // Background colors
  final List<Color> _defaultGradient = [
    Colors.black,
    const Color(0xFF1E1E1E),
    const Color(0xFF242424),
  ];
  
  List<Color> _currentGradient = [
    Colors.black,
    const Color(0xFF1E1E1E),
    const Color(0xFF242424),
  ];
  
  // Cache for extracted colors
  final Map<int, List<Color>> _colorCache = {};

  @override
  void initState() {
    super.initState();
    _pageController = PageController(viewportFraction: 0.92);
  }
  
  // Precompute all colors when data is available
  void _precomputeAllColors(List<Project> moments) async {
    if (_areColorsPrecomputed || moments.isEmpty) return;
    print("Starting precomputation of all colors...");
    _areColorsPrecomputed = true; // Mark as started

    for (int i = 0; i < moments.length; i++) {
      if (!_colorCache.containsKey(i)) {
        final String imagePath = 'assets/images/${(i % 3) + 1}.png';
        // Use compute to run extraction in an isolate
        try {
          List<Color> colors = await compute(_extractColorsIsolate, imagePath);
           if (mounted) {
             _colorCache[i] = colors;
             print("Precomputed color for index: $i");
             // If it's the first item, apply its color immediately
             if (i == 0) {
                setState(() {
                  _currentGradient = colors;
                });
             }
           }
        } catch(e) {
           print("Error during compute for index $i: $e");
           if(mounted) _colorCache[i] = _defaultGradient; // Cache default on error
        }
      }
    }
    print("Finished precomputation.");
  }
  
  // Handle page changes - apply precomputed colors instantly
  void _onPageChanged(int index) {
    if (index != _currentIndex) {
      print("Page changed to index: $index");
      setState(() {
        _currentIndex = index;
        // Apply color directly from cache (should be precomputed)
        _currentGradient = _colorCache[index] ?? _defaultGradient;
        print("Applied color for index $index from cache (or default)");
      });
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final userId = context.select<User?, String?>((user) => user?.uid);
    final dbService = context.watch<DatabaseService>();
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 400), // Slightly faster animation
          curve: Curves.easeOut,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: _currentGradient, 
              stops: const [0.0, 0.6, 1.0],
            ),
          ),
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
                    // Title
                    Text(
                      'Moments',
                      style: GoogleFonts.montserrat(
                        color: Colors.white,
                        fontSize: 42,
                        fontWeight: FontWeight.w600,
                        letterSpacing: -0.5,
                      ),
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
                          
                          // Trigger precomputation if not already done
                          if (!_areColorsPrecomputed) {
                             // Run async precomputation without awaiting
                             WidgetsBinding.instance.addPostFrameCallback((_) {
                               _precomputeAllColors(moments);
                             });
                          }
                          
                          return PageView.builder(
                            controller: _pageController,
                            itemCount: moments.length,
                            onPageChanged: _onPageChanged, // Use direct page change
                            physics: const PageScrollPhysics(), 
                            itemBuilder: (context, index) {
                              return Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 40.0),
                                child: _MomentCarouselCard(
                                  moment: moments[index],
                                  imageIndex: index,
                                  currentUserId: userId,
                                ),
                              );
                            },
                          );
                        },
                      ),
              ),
            ],
          ),
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
              style: theme.textTheme.headlineSmall?.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.w600,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 40.0),
              child: Text(
                'Moments you create or are invited to will appear here.',
                style: TextStyle(color: Colors.grey.shade400),
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
              child: const Text('Create Moment', style: TextStyle(fontSize: 16)),
            ),
          ],
        ),
      ),
    );
  }
}

// --- Moment Card Widget for Horizontal Carousel ---
class _MomentCarouselCard extends StatelessWidget {
  final Project moment;
  final int imageIndex;
  final String? currentUserId;

  const _MomentCarouselCard({
    required this.moment,
    required this.imageIndex,
    required this.currentUserId,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final String imagePath = 'assets/images/${(imageIndex % 3) + 1}.png';
    final bool isHosting = currentUserId != null && currentUserId == moment.organizerId;
    final dbService = Provider.of<DatabaseService>(context, listen: false);

    return Card(
      elevation: 1.0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(35.0),
      ),
      clipBehavior: Clip.antiAlias,
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
            
            // Layer 2: Gradient Overlay at bottom (for text visibility)
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              height: 70,
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.transparent, Colors.black.withOpacity(0.7)],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
                ),
              ),
            ),
            
            // Layer 3: Text Content (title/name at bottom center)
            Positioned(
              bottom: 20,
              left: 0,
              right: 0,
              child: Text(
                moment.title,
                style: theme.textTheme.headlineMedium?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                  fontSize: 38,
                ),
                textAlign: TextAlign.center,
              ),
            ),
            
            // Layer 4: Hosting Badge (pill-shaped)
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
                  child: const Text(
                    'Hosting',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ),
              
            // Layer 5: Delete button (only visible for organizer)
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
          title: const Text(
            'Delete Moment', 
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
          ),
          content: Text(
            'Are you sure you want to delete "${moment.title}"? This action cannot be undone.',
            style: const TextStyle(color: Colors.white70),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
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
              child: const Text(
                'Delete',
                style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        );
      },
    );
  }
}