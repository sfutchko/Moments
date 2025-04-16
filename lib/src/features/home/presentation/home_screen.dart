import 'dart:async';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../services/auth_service.dart';
import '../../../services/database_service.dart';
import '../../../models/project.dart';
import '../../moment_detail/presentation/moment_detail_screen.dart';
import '../../create_moment/presentation/create_moment_screen.dart';
import '../../settings/presentation/settings_screen.dart';

// Specialized class to hold background colors
class BackgroundColors {
  final List<Color> colors;
  const BackgroundColors(this.colors);
  
  // Predefined gradients
  static const BackgroundColors defaultColors = BackgroundColors([
    Colors.black,
    Color(0xFF1E1E1E),
    Color(0xFF242424),
  ]);
  
  static const List<BackgroundColors> themeColors = [
    // Blue theme
    BackgroundColors([
      Colors.black,
      Color(0xFF1A1A2E),
      Color(0xFF16213E),
    ]),
    // Bronze theme
    BackgroundColors([
      Colors.black, 
      Color(0xFF231F20),
      Color(0xFF2D2424),
    ]),
    // Green theme
    BackgroundColors([
      Colors.black,
      Color(0xFF1A2F2F),
      Color(0xFF1F3B3B),
    ]),
  ];
  
  // Factory method to get colors by index
  static BackgroundColors forIndex(int index) {
    if (index < 0) return defaultColors;
    return themeColors[index % themeColors.length];
  }
}

// InheritedWidget to provide background colors
class BackgroundColorProvider extends InheritedWidget {
  final BackgroundColors colors;
  
  const BackgroundColorProvider({
    Key? key,
    required this.colors,
    required Widget child,
  }) : super(key: key, child: child);
  
  static BackgroundColorProvider of(BuildContext context) {
    final result = context.dependOnInheritedWidgetOfExactType<BackgroundColorProvider>();
    assert(result != null, 'No BackgroundColorProvider found in context');
    return result!;
  }
  
  @override
  bool updateShouldNotify(BackgroundColorProvider oldWidget) {
    return colors != oldWidget.colors;
  }
}

// Add a completely separate background widget
class AdaptiveBackground extends StatefulWidget {
  final Widget child;
  final int currentIndex;
  
  const AdaptiveBackground({
    super.key,
    required this.child,
    required this.currentIndex,
  });
  
  @override
  State<AdaptiveBackground> createState() => _AdaptiveBackgroundState();
}

class _AdaptiveBackgroundState extends State<AdaptiveBackground> {
  // Predefined gradients for each image type
  final List<List<Color>> _themeGradients = [
    // Blue theme
    [
      Colors.black,
      const Color(0xFF1A1A2E),
      const Color(0xFF16213E),
    ],
    // Bronze theme
    [
      Colors.black, 
      const Color(0xFF231F20),
      const Color(0xFF2D2424),
    ],
    // Green theme
    [
      Colors.black,
      const Color(0xFF1A2F2F),
      const Color(0xFF1F3B3B),
    ],
  ];
  
  @override
  Widget build(BuildContext context) {
    // Get the current gradient from the index
    final colors = _themeGradients[widget.currentIndex % _themeGradients.length];
    
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: colors,
          stops: const [0.0, 0.6, 1.0],
        ),
      ),
      child: widget.child,
    );
  }
}

// Background container that uses the colors from provider
class GradientBackground extends StatelessWidget {
  final Widget child;
  
  const GradientBackground({
    Key? key,
    required this.child,
  }) : super(key: key);
  
  @override
  Widget build(BuildContext context) {
    final colors = BackgroundColorProvider.of(context).colors;
    
    return AnimatedContainer(
      duration: const Duration(milliseconds: 500),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: colors.colors,
          stops: const [0.0, 0.6, 1.0],
        ),
      ),
      child: child,
    );
  }
}

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

// Background provider to separate state from UI
class BackgroundState extends ChangeNotifier {
  int _currentIndex = 0;
  
  // Predefined gradients for each theme
  final List<List<Color>> _themeGradients = [
    // Blue theme
    [
      Colors.black,
      const Color(0xFF1A1A2E),
      const Color(0xFF16213E),
    ],
    // Bronze theme
    [
      Colors.black, 
      const Color(0xFF231F20),
      const Color(0xFF2D2424),
    ],
    // Green theme
    [
      Colors.black,
      const Color(0xFF1A2F2F),
      const Color(0xFF1F3B3B),
    ],
  ];
  
  int get currentIndex => _currentIndex;
  
  List<Color> get currentGradient {
    final gradient = _themeGradients[_currentIndex % _themeGradients.length];
    print("Getting gradient for index $_currentIndex: $gradient");
    return gradient;
  }
      
  void updateIndex(int newIndex) {
    if (newIndex != _currentIndex && newIndex >= 0) {
      print("Updating background index from $_currentIndex to $newIndex");
      _currentIndex = newIndex;
      notifyListeners();
    }
  }
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
  
  // Predefined gradients for each theme
  final List<List<Color>> _themeGradients = [
    // Blue theme
    [
      Colors.black,
      const Color(0xFF1A1A2E),
      const Color(0xFF16213E),
    ],
    // Bronze theme
    [
      Colors.black, 
      const Color(0xFF231F20),
      const Color(0xFF2D2424),
    ],
    // Green theme
    [
      Colors.black,
      const Color(0xFF1A2F2F),
      const Color(0xFF1F3B3B),
    ],
  ];
  
  @override
  Widget build(BuildContext context) {
    final currentGradient = _themeGradients[_currentIndex % _themeGradients.length];
    final screenSize = MediaQuery.of(context).size;
    
    return AnimatedContainer(
      duration: const Duration(milliseconds: 500),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: currentGradient,
          stops: const [0.0, 0.6, 1.0],
        ),
      ),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const SizedBox(height: 20), // Space at top
            // Container with perfect height
            Container(
              height: 550, // Increased to 550px for perfect height
              child: PageView.builder(
                itemCount: widget.moments.length,
                controller: PageController(viewportFraction: 0.9),
                onPageChanged: (index) {
                  setState(() {
                    _currentIndex = index;
                  });
                },
                itemBuilder: (context, index) {
                  return Container(
                    margin: const EdgeInsets.symmetric(horizontal: 16.0),
                    // Remove red border and use a less noticeable corner radius
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
                        imageIndex: index,
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
            
            // Ultra-simple implementation matching reference exactly
            Positioned(
              bottom: 0,
              left: 8,
              right: 8,
              height: 145, // Exact height 
              child: ClipRRect(
                borderRadius: BorderRadius.circular(25),
                child: BackdropFilter(
                  filter: ui.ImageFilter.blur(sigmaX: 8.0, sigmaY: 8.0),
                  child: Container(
                    color: Color.fromRGBO(200, 180, 210, 0.18),
                    child: Center(
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