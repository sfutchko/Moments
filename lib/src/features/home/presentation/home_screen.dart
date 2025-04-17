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
import 'package:cached_network_image/cached_network_image.dart';
import 'dart:math' as math;
import 'package:flutter/animation.dart';

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

// HomeScreen is now StatefulWidget
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

// Helper function to parse hex color string (e.g., #AARRGGBB)
Color? _hexToColor(String? hexString) {
  if (hexString == null || hexString.length < 7 || !hexString.startsWith('#')) {
    return null;
  }
  final buffer = StringBuffer();
  if (hexString.length == 7) buffer.write('ff'); // Add alpha if missing (e.g., #RRGGBB)
  buffer.write(hexString.substring(1)); 
  final int? colorValue = int.tryParse(buffer.toString(), radix: 16);
  return colorValue == null ? null : Color(colorValue);
}

class _HomeScreenState extends State<HomeScreen> with SingleTickerProviderStateMixin {
  final Map<String, List<Color>> _gradientCache = {};
  late final ValueNotifier<List<Color>> _backgroundGradientNotifier;
  List<Project> _moments = []; 
  Timer? _debounceTimer;
  late AnimationController _animationController;

  @override
  void initState() {
    super.initState();
    print('[_HomeScreenState] initState');
    _backgroundGradientNotifier = ValueNotifier<List<Color>>([
      Colors.black,
      const Color(0xFF231F20),
      const Color(0xFF2D2424),
    ]);
    
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 12),
    )..repeat(reverse: true);
  }
  
  @override
  void dispose() {
    _debounceTimer?.cancel();
    _backgroundGradientNotifier.dispose();
    _animationController.dispose();
    super.dispose();
  }

  // Generate gradient: Use stored hex OR fallback to dynamic generation
  Future<List<Color>> _generateGradient(Project project, int pageIndex) async {
    print('[_generateGradient] Generating gradient for project: ${project.id}, pageIndex: $pageIndex');

    // Try using pre-computed hex colors first
    final Color? color1 = _hexToColor(project.gradientColorHex1);
    final Color? color2 = _hexToColor(project.gradientColorHex2);
    final Color? color3 = _hexToColor(project.gradientColorHex3);

    if (color1 != null && color2 != null && color3 != null) {
      print('[_generateGradient] Using pre-computed hex colors.');
      return [color1, color2, color3];
    }

    // --- Fallback to dynamic generation if hex colors are missing --- 
    print('[_generateGradient] Pre-computed colors missing. Falling back to dynamic generation.');
    ImageProvider imageProvider;
    String imageSourceInfo;

    if (project.coverImageUrl != null && project.coverImageUrl!.isNotEmpty) {
      imageSourceInfo = 'Network: ${project.coverImageUrl}';
      imageProvider = CachedNetworkImageProvider(project.coverImageUrl!); 
    } else {
      // Use pageIndex for asset fallback
      final assetIndex = pageIndex % 3; // Assuming 3 default assets
      final fallbackAssetPath = 'assets/images/${assetIndex + 1}.png';
      imageSourceInfo = 'Asset fallback: $fallbackAssetPath'; 
      imageProvider = AssetImage(fallbackAssetPath);
    }

    print('[PaletteGenerator] Using image source for fallback: $imageSourceInfo');
    try {
      final PaletteGenerator palette = await PaletteGenerator.fromImageProvider(
        imageProvider, 
        maximumColorCount: 16, 
      );
      // ... (Same color selection logic as before) ...
       Color topColorFb = palette.darkVibrantColor?.color ?? palette.darkMutedColor?.color ?? Colors.black;
       Color middleColorFb = palette.vibrantColor?.color ?? palette.lightVibrantColor?.color ?? palette.dominantColor?.color ?? const Color(0xFF333333);
       Color bottomColorFb = palette.darkMutedColor?.color ?? palette.dominantColor?.color.withAlpha(200) ?? const Color(0xFF1A1A1A);
       if (topColorFb == middleColorFb) { middleColorFb = palette.lightMutedColor?.color ?? palette.dominantColor?.color ?? middleColorFb; }
       if (topColorFb == bottomColorFb || middleColorFb == bottomColorFb) { bottomColorFb = topColorFb == Colors.black ? const Color(0xFF111111) : Colors.black; }
       if (topColorFb == middleColorFb && middleColorFb == bottomColorFb) { middleColorFb = middleColorFb.withAlpha(200); bottomColorFb = middleColorFb.withAlpha(150); }

      final resultGradient = [topColorFb, middleColorFb, bottomColorFb];
      print('[PaletteGenerator] Fallback result gradient: $resultGradient');
      return resultGradient;

    } catch (e, stackTrace) {
      print('[PaletteGenerator] ERROR during fallback generation for ${project.id} using $imageSourceInfo:\n$e\n$stackTrace');
      return [ 
        Colors.black,
        const Color(0xFF231F20),
        const Color(0xFF2D2424),
      ];
    }
  }

  // Update function uses the new _generateGradient method
  Future<void> _updateBackgroundForPage(int pageIndex) async { 
    if (!mounted) return; 
    print('[_HomeScreenState] _updateBackgroundForPage called for pageIndex: $pageIndex');

    if (_moments.isEmpty || pageIndex < 0 || pageIndex >= _moments.length) {
        _backgroundGradientNotifier.value = [ Colors.black, const Color(0xFF231F20), const Color(0xFF2D2424) ];
        return;
    }
    final Project project = _moments[pageIndex];
    
    // Cache key logic remains the same (project ID or asset index string)
    final cacheKey = project.coverImageUrl?.isNotEmpty ?? false ? project.id : (pageIndex % 3).toString();
    print('[_HomeScreenState] Corresponding project ID: ${project.id}, Cache Key: $cacheKey');

    if (_gradientCache.containsKey(cacheKey)) {
       final cachedGradient = _gradientCache[cacheKey]!;
       if (!listEquals(_backgroundGradientNotifier.value, cachedGradient)) { 
         _backgroundGradientNotifier.value = cachedGradient;
         print('[_HomeScreenState] Notifier updated from cache.');
       }
       return;
    }

    print('[_HomeScreenState] Cache MISS for key: $cacheKey. Generating gradient...');
    try {
      // Call the unified generation function, passing project and index
      final List<Color> newGradient = await _generateGradient(project, pageIndex);
      print('[_HomeScreenState] Generation finished. Received gradient: $newGradient');

      _gradientCache[cacheKey] = newGradient;
      print('[_HomeScreenState] Stored gradient in cache for key: $cacheKey');

      // Update notifier if still mounted and gradient is different
      if (mounted && !listEquals(_backgroundGradientNotifier.value, newGradient)) { 
         _backgroundGradientNotifier.value = newGradient;
         print('[_HomeScreenState] Notifier updated after generation.');
      } 
    } catch (e, stackTrace) { // Catch errors during generation
        print("[_HomeScreenState] ERROR during gradient generation/update: $e\n$stackTrace");
        if (mounted) {
          _backgroundGradientNotifier.value = [ Colors.black, Colors.red.shade900, Colors.black]; 
        }
    }
  }

  // Simplified: only manages debounce timer
  void _handlePageChanged(int index) {
    if (!mounted) return;
    print('[_HomeScreenState] _handlePageChanged - Raw index: $index');
        
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 300), () {
      print('[_HomeScreenState] Debounce timer fired for index: $index');
      // Pass the latest index from the event to the update function
      _updateBackgroundForPage(index); 
    });
  }

  @override
  Widget build(BuildContext context) {
    // Dependencies needed by FutureBuilder and StreamBuilder
    final userId = context.select<User?, String?>((user) => user?.uid);
    final dbService = context.watch<DatabaseService>();
    final theme = Theme.of(context);

    return Scaffold(
      body: Stack(
        children: [
          // Layer 1: Background Container listening to ValueNotifier
          Positioned.fill( 
            child: ValueListenableBuilder<List<Color>>(
              valueListenable: _backgroundGradientNotifier,
              builder: (context, gradientColors, child) {
                print('[_HomeScreenState] ValueListenableBuilder rebuilding background container.');
                return AnimatedBuilder(
                  animation: _animationController,
                  builder: (context, child) {
                    return Stack(
                      children: [
                        // Base gradient layer
                        Container( 
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [
                                gradientColors[0],
                                gradientColors.length > 1 ? gradientColors[1] : gradientColors[0],
                                gradientColors.length > 2 ? gradientColors[2] : (gradientColors.length > 1 ? gradientColors[1] : gradientColors[0]),
                              ],
                              stops: const [0.0, 0.6, 1.0],
                            ),
                          ),
                        ),
                        
                        // Diagonal stripes for texture
                        Opacity(
                          opacity: 0.12,
                          child: Container(
                            decoration: BoxDecoration(
                              backgroundBlendMode: BlendMode.overlay,
                              gradient: LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: [
                                  Colors.transparent,
                                  Colors.white.withOpacity(0.1),
                                  Colors.transparent,
                                  Colors.white.withOpacity(0.1),
                                  Colors.transparent,
                                ],
                                stops: const [0.0, 0.2, 0.5, 0.8, 1.0],
                                tileMode: TileMode.repeated,
                              ),
                            ),
                          ),
                        ),
                        
                        // Glass blur blobs overlay - now animated
                        CustomPaint(
                          painter: GlassEffectPainter(
                            color1: gradientColors[0].withOpacity(0.5),
                            color2: gradientColors.length > 1 ? gradientColors[1].withOpacity(0.5) : gradientColors[0].withOpacity(0.3),
                            color3: gradientColors.length > 2 ? gradientColors[2].withOpacity(0.5) : (gradientColors.length > 1 ? gradientColors[1] : gradientColors[0]).withOpacity(0.3),
                            animationValue: _animationController.value,
                          ),
                          child: Container(),
                        ),
                        
                        // Light source effect at top
                        Container(
                          decoration: BoxDecoration(
                            gradient: RadialGradient(
                              center: const Alignment(0.0, -0.5),
                              radius: 0.8,
                              colors: [
                                Colors.white.withOpacity(0.3),
                                Colors.transparent,
                              ],
                              stops: const [0.0, 1.0],
                            ),
                          ),
                        ),
                        
                        // Vignette effect
                        Container(
                          decoration: BoxDecoration(
                            gradient: RadialGradient(
                              center: Alignment.center,
                              radius: 1.5,
                              colors: [
                                Colors.transparent,
                                Colors.black.withOpacity(0.15),
                              ],
                              stops: const [0.6, 1.0],
                            ),
                          ),
                        ),
                      ],
                    );
                  },
                );
              },
            ),
          ),
          // Layer 2: Main Content (SafeArea + Column)
          SafeArea( 
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
                // --- Main Content Area uses StreamBuilder for updates ---
                Expanded(
                  child: userId == null
                      ? const Center(child: CircularProgressIndicator())
                      : StreamBuilder<List<Project>>(
                          stream: dbService.getMomentsForUser(userId),
                          builder: (context, snapshot) {
                             // Updated post-frame callback logic
                             WidgetsBinding.instance.addPostFrameCallback((_) {
                               if (mounted) {
                                 final newMoments = snapshot.data ?? [];
                                 bool listJustLoadedOrChanged = _moments.isEmpty && newMoments.isNotEmpty || 
                                                              !listEquals(_moments.map((p) => p.id).toList(), newMoments.map((p) => p.id).toList());
                                  
                                 if (listJustLoadedOrChanged) {
                                    print('[_HomeScreenState] PostFrame: Data changed/loaded. Updating _moments state & triggering initial background update.');
                                    _moments = newMoments; 
                                    if (_moments.isNotEmpty) {
                                       // Call async but don't wait - let UI build
                                       _updateBackgroundForPage(0).ignore(); 
                                    } else {
                                       _updateBackgroundForPage(-1).ignore(); 
                                    }
                                 }
                               }
                             });
                             
                            // Process stream data for potential background updates later
                            final List<Project> currentStreamMoments = snapshot.data ?? [];
                            WidgetsBinding.instance.addPostFrameCallback((_) {
                              if (mounted) {
                                  bool listContentChanged = !listEquals(_moments.map((p) => p.id).toList(), currentStreamMoments.map((p) => p.id).toList());
                                  if (listContentChanged) {
                                      print("[_HomeScreenState] PostFrame: Stream updated list content.");
                                      _moments = currentStreamMoments;
                                      // Optional: Trigger background update maybe?
                                      // Already handled by onPageChanged debouncer mostly.
                                  }
                              }
                            });

                            // Build UI based on stream data
                            if (currentStreamMoments.isEmpty) {
                              return _buildEmptyState(context);
                            } else {
                              return MomentsPageView(
                                  moments: currentStreamMoments, // Use latest stream data
                                  userId: userId,
                                  onPageChanged: _handlePageChanged, 
                              );
                            }
                          },
                        ),
                ),
              ],
             ),
            ),
          ],
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

// MomentsPageView is now StatelessWidget
class MomentsPageView extends StatelessWidget {
  final List<Project> moments;
  final String? userId;
  final ValueChanged<int> onPageChanged; // Callback function
  
  const MomentsPageView({
    super.key,
    required this.moments,
    required this.userId,
    required this.onPageChanged, // Accept callback
  });
  
  @override
  Widget build(BuildContext context) {
     print('[MomentsPageView] build method');
    // No AnimatedContainer here anymore
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const SizedBox(height: 20),
          Container(
            height: 550,
            child: PageView.builder(
              itemCount: moments.length,
              controller: PageController(viewportFraction: 0.9),
              onPageChanged: onPageChanged, // Use the passed callback
              itemBuilder: (context, index) {
                final imageIndexForCard = index % 3; // Still assuming cyclic assets
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
                        moment: moments[index],
                        imageIndex: imageIndexForCard,
                        currentUserId: userId,
                      ),
                    ),
                  );
              },
            ),
          ),
          const SizedBox(height: 20),
        ],
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
    // Determine the correct image provider based on coverImageUrl
    final ImageProvider imageProvider;
    if (moment.coverImageUrl != null && moment.coverImageUrl!.isNotEmpty) {
      print('[_SimpleMomentCard] Using Network Image: ${moment.coverImageUrl}');
      imageProvider = CachedNetworkImageProvider(moment.coverImageUrl!); 
    } else {
      // Fallback to asset image using imageIndex
      final String imagePath = 'assets/images/${(imageIndex % 3) + 1}.png';
      print('[_SimpleMomentCard] Using Asset Image: $imagePath');
      imageProvider = AssetImage(imagePath);
    }
    
    final bool isHosting = currentUserId != null && currentUserId == moment.organizerId;
    final dbService = Provider.of<DatabaseService>(context, listen: false);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          showModalBottomSheet(
            context: context,
            isScrollControlled: true, // Allows modal to take full height
            backgroundColor: Colors.transparent, // Make background transparent
            builder: (context) => MomentDetailScreen(moment: moment), // Pass the moment data
          );
        },
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Layer 1: Background Image - Use the determined imageProvider
            Image( // Use generic Image widget
              image: imageProvider,
              fit: BoxFit.cover,
              // Add error builder for network images too
              errorBuilder: (context, error, stackTrace) {
                  print("Error loading image: $error"); // Log error
                  return Container(
                      color: Colors.grey.shade800, 
                      child: const Center(child: Icon(Icons.broken_image, color: Colors.grey))
                  );
              },
              // Optional: Add frameBuilder for loading indication if needed
              frameBuilder: (context, child, frame, wasSynchronouslyLoaded) {
                 if (wasSynchronouslyLoaded) return child;
                 return AnimatedOpacity(
                    opacity: frame == null ? 0 : 1,
                    duration: const Duration(milliseconds: 300),
                    curve: Curves.easeOut,
                    child: child,
                 );
              },
            ),
            
            // Layer: Faded bottom overlay (Simulated blur)
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

// Add this custom painter class at the bottom of the file, outside any other classes
class GlassEffectPainter extends CustomPainter {
  final Color color1;
  final Color color2;
  final Color color3;
  final double animationValue;
  
  GlassEffectPainter({
    required this.color1,
    required this.color2,
    required this.color3,
    required this.animationValue,
  });
  
  @override
  void paint(Canvas canvas, Size size) {
    final width = size.width;
    final height = size.height;
    
    // Use animationValue to modulate properties more noticeably
    final double timeFactor = math.sin(animationValue * math.pi); // Value cycles between 0 and 1 and back
    
    // Animate blobs with more size variation
    _drawGlassBlob(canvas, Offset(width * 0.2, height * 0.2), width * (0.5 + 0.1 * timeFactor), color1, timeFactor);
    _drawGlassBlob(canvas, Offset(width * 0.8, height * 0.3), width * (0.4 + 0.08 * timeFactor), color2, timeFactor);
    _drawGlassBlob(canvas, Offset(width * 0.5, height * 0.7), width * (0.6 + 0.12 * timeFactor), color3, timeFactor);
    _drawGlassBlob(canvas, Offset(width * 0.1, height * 0.8), width * (0.35 + 0.07 * timeFactor), color2, timeFactor);
    
    // Animate smaller highlight bubbles more noticeably
    _drawGlassBlob(canvas, Offset(width * 0.7, height * 0.15), width * (0.2 + 0.05 * timeFactor), Colors.white.withOpacity(0.15), timeFactor);
    _drawGlassBlob(canvas, Offset(width * 0.3, height * 0.6), width * (0.15 + 0.04 * timeFactor), Colors.white.withOpacity(0.1), timeFactor);
  }
  
  void _drawGlassBlob(Canvas canvas, Offset center, double size, Color color, double timeFactor) {
    // Animate opacity more noticeably (range 0.1 to 0.4)
    final double animatedOpacity = 0.15 + 0.25 * timeFactor; 
    
    // Outer glow
    final outerPaint = Paint()
      ..color = color.withOpacity(0.1 + animatedOpacity * 0.5) // Modulate opacity more
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 50);
    canvas.drawCircle(center, size, outerPaint);
    
    // Main blob
    final mainPaint = Paint()
      ..color = color.withOpacity(0.15 + animatedOpacity * 0.6) // Modulate opacity more
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 30);
    canvas.drawCircle(center, size * 0.8, mainPaint);
    
    // Inner highlight - make it shift more
    final innerPaint = Paint()
      ..color = Colors.white.withOpacity(0.1 + animatedOpacity * 0.3)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 15);
    canvas.drawCircle(
      Offset(center.dx - size * (0.2 + 0.1 * timeFactor), center.dy - size * (0.2 + 0.1 * timeFactor)), 
      size * 0.35, // Slightly larger highlight 
      innerPaint
    );
  }
  
  @override
  bool shouldRepaint(GlassEffectPainter oldDelegate) {
    // Repaint if colors or animation value change
    return color1 != oldDelegate.color1 || 
           color2 != oldDelegate.color2 || 
           color3 != oldDelegate.color3 ||
           animationValue != oldDelegate.animationValue;
  }
}