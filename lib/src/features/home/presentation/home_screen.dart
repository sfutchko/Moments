import 'dart:async';
import 'dart:ui' as ui;
import 'package:flutter/foundation.dart'; // Import for compute
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:palette_generator/palette_generator.dart'; // Import palette_generator
import 'package:flutter/services.dart' show rootBundle, HapticFeedback; // Import for rootBundle and haptic feedback
import 'package:cached_network_image/cached_network_image.dart';
import 'dart:math' as math;
import 'package:flutter/animation.dart';
import 'package:flutter/rendering.dart';
import 'dart:ui' show ImageFilter;

import '../../../services/auth_service.dart';
import '../../../services/database_service.dart';
import '../../../models/project.dart';
import '../../moment_detail/presentation/moment_detail_screen.dart';
import '../../create_moment/presentation/create_moment_screen.dart';
import '../../settings/presentation/settings_screen.dart';
import '../../../utils/image_provider_util.dart'; // Import our new utility class

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
    
    // Create image provider safely
    final ImageProvider imageProvider = _getSafeImageProvider(project.coverImageUrl, pageIndex);
    
    try {
      // Generate palette from image
      final PaletteGenerator paletteGenerator = await PaletteGenerator.fromImageProvider(
        imageProvider,
        size: const Size(200, 200), // Reduced size for performance
        maximumColorCount: 10,
      );
      
      Color topColorFb = paletteGenerator.darkVibrantColor?.color ?? paletteGenerator.darkMutedColor?.color ?? Colors.black;
      Color middleColorFb = paletteGenerator.vibrantColor?.color ?? paletteGenerator.lightVibrantColor?.color ?? paletteGenerator.dominantColor?.color ?? const Color(0xFF333333);
      Color bottomColorFb = paletteGenerator.darkMutedColor?.color ?? paletteGenerator.dominantColor?.color.withAlpha(200) ?? const Color(0xFF1A1A1A);
      if (topColorFb == middleColorFb) { middleColorFb = paletteGenerator.lightMutedColor?.color ?? paletteGenerator.dominantColor?.color ?? middleColorFb; }
      if (topColorFb == bottomColorFb || middleColorFb == bottomColorFb) { bottomColorFb = topColorFb == Colors.black ? const Color(0xFF111111) : Colors.black; }
      if (topColorFb == middleColorFb && middleColorFb == bottomColorFb) { middleColorFb = middleColorFb.withAlpha(200); bottomColorFb = middleColorFb.withAlpha(150); }

      final resultGradient = [topColorFb, middleColorFb, bottomColorFb];
      print('[PaletteGenerator] Fallback result gradient: $resultGradient');
      return resultGradient;

    } catch (e, stackTrace) {
      print('[PaletteGenerator] ERROR during fallback generation for ${project.id} using $imageProvider:\n$e\n$stackTrace');
      return [ 
        Colors.black,
        const Color(0xFF231F20),
        const Color(0xFF2D2424),
      ];
    }
  }

  // Updated to use the utility class
  ImageProvider _getSafeImageProvider(String? imageUrl, int index) {
    return ImageProviderUtil.getSafeImageProvider(
      imagePath: imageUrl,
      fallbackIndex: index
    );
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
    final user = Provider.of<User?>(context);
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
                // --- Enhanced Header Area with personalization --- 
                Padding(
                  padding: const EdgeInsets.fromLTRB(24.0, 8.0, 24.0, 0.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // App Title and Action Buttons Row
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          // Title with Nunito font
                          Text(
                            'Moments',
                            style: theme.textTheme.appTitle,
                          ),
                          const Spacer(),
                          // Add Button with improved feedback
                          Material(
                            color: Colors.transparent,
                            borderRadius: BorderRadius.circular(30),
                            child: InkWell(
                              borderRadius: BorderRadius.circular(30),
                              onTap: () {
                                HapticFeedback.mediumImpact();
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(builder: (context) => const CreateMomentScreen()),
                                );
                              },
                              child: Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(30),
                                  border: Border.all(
                                    color: Colors.white.withOpacity(0.2),
                                    width: 1,
                                  ),
                                ),
                                child: const Icon(
                                  Icons.add_circle_outline, 
                                  color: Colors.white,
                                  size: 24,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          // Profile Button with improved feedback
                          Material(
                            color: Colors.transparent,
                            borderRadius: BorderRadius.circular(30),
                            child: InkWell(
                              borderRadius: BorderRadius.circular(30),
                              onTap: () {
                                HapticFeedback.mediumImpact();
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(builder: (context) => const SettingsScreen()),
                                );
                              },
                              child: Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(30),
                                  border: Border.all(
                                    color: Colors.white.withOpacity(0.2),
                                    width: 1,
                                  ),
                                ),
                                child: const Icon(
                                  Icons.account_circle, 
                                  color: Colors.white,
                                  size: 24,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      
                      // Personalized welcome message
                      if (user != null && user.displayName != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 8.0, bottom: 8.0),
                          child: Row(
                            children: [
                              Text(
                                'Hello, ${user.displayName!.split(' ')[0]}',
                                style: GoogleFonts.nunito(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w500,
                                  color: Colors.white.withOpacity(0.9),
                                  letterSpacing: 0.2,
                                ),
                              ),
                              const SizedBox(width: 4),
                              Text(
                                '👋', 
                                style: TextStyle(fontSize: 16)
                              ),
                            ],
                          ),
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

// Enhanced version of MomentsPageView with subtle floating animation
class MomentsPageView extends StatefulWidget {
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
  State<MomentsPageView> createState() => _MomentsPageViewState();
}

class _MomentsPageViewState extends State<MomentsPageView> with SingleTickerProviderStateMixin {
  late PageController pageController;
  late ValueNotifier<int> currentPageNotifier;
  
  @override
  void initState() {
    super.initState();
    pageController = PageController(viewportFraction: 0.85);
    currentPageNotifier = ValueNotifier<int>(0);
  }

  @override
  void dispose() {
    pageController.dispose();
    currentPageNotifier.dispose();
    super.dispose();
  }
  
  // Function to handle page changes and update the indicator
  void handlePageChanged(int index) {
    currentPageNotifier.value = index;
    widget.onPageChanged(index);
  }

  @override
  Widget build(BuildContext context) {
    print('[MomentsPageView] build method');
    
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // Add a subtle page indicator at the top
        Container(
          height: 6,
          margin: const EdgeInsets.symmetric(vertical: 8),
          width: MediaQuery.of(context).size.width,
          child: ValueListenableBuilder<int>(
            valueListenable: currentPageNotifier,
            builder: (context, currentPage, _) {
              return PageIndicator(
                count: widget.moments.length,
                currentIndex: currentPage,
                onPageChanged: (index) {
                  // Animate to the selected page
                  pageController.animateToPage(
                    index,
                    duration: const Duration(milliseconds: 300),
                    curve: Curves.easeOut,
                  );
                },
              );
            },
          ),
        ),
        
        // Main card container with simplified rendering
        Expanded(
          child: PageView.builder(
            itemCount: widget.moments.length,
            controller: pageController,
            onPageChanged: handlePageChanged,
            itemBuilder: (context, index) {
              final imageIndexForCard = index % 3;
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 20.0),
                child: Hero(
                  tag: 'moment-${widget.moments[index].id}',
                  child: _EnhancedMomentCard(
                    moment: widget.moments[index],
                    imageIndex: imageIndexForCard,
                    currentUserId: widget.userId,
                    isActive: currentPageNotifier.value == index,
                  ),
                ),
              );
            },
          ),
        ),
        
        // Add a subtle hint to indicate users can tap to open moments
        Padding(
          padding: const EdgeInsets.only(bottom: 12.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.touch_app, size: 16, color: Colors.white.withOpacity(0.7)),
              const SizedBox(width: 6),
              Text(
                'Tap to open',
                style: GoogleFonts.nunito(
                  color: Colors.white.withOpacity(0.7),
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// New page indicator widget with improved visual hierarchy
class PageIndicator extends StatelessWidget {
  final int count;
  final int currentIndex;
  final ValueChanged<int> onPageChanged;
  
  const PageIndicator({
    super.key,
    required this.count,
    required this.currentIndex,
    required this.onPageChanged,
  });
  
  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: List.generate(count, (index) {
          final bool isActive = index == currentIndex;
          
          return GestureDetector(
            onTap: () => onPageChanged(index),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              margin: const EdgeInsets.symmetric(horizontal: 4),
              width: isActive ? 32 : 12, 
              height: isActive ? 4 : 3,
              decoration: BoxDecoration(
                color: isActive 
                  ? Colors.white 
                  : Colors.white.withOpacity(0.3),
                borderRadius: BorderRadius.circular(2),
                boxShadow: isActive ? [
                  BoxShadow(
                    color: Colors.white.withOpacity(0.5),
                    blurRadius: 4,
                    spreadRadius: 1,
                  )
                ] : null,
              ),
            ),
          );
        }),
      ),
    );
  }
}

// Renamed and enhanced Moment Card with improved visuals
class _EnhancedMomentCard extends StatelessWidget {
  final Project moment;
  final int imageIndex;
  final String? currentUserId;
  final bool isActive;

  const _EnhancedMomentCard({
    required this.moment,
    required this.imageIndex,
    required this.currentUserId,
    this.isActive = false,
  });

  @override
  Widget build(BuildContext context) {
    // Fixed image provider logic to distinguish between assets and network URLs
    ImageProvider getImageProvider() {
      return ImageProviderUtil.getSafeImageProvider(
        imagePath: moment.coverImageUrl,
        fallbackIndex: imageIndex
      );
    }
    
    final bool isHosting = currentUserId != null && currentUserId == moment.organizerId;
    final dbService = Provider.of<DatabaseService>(context, listen: false);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          // Add haptic feedback for a more tactile experience
          HapticFeedback.mediumImpact();
          
          showModalBottomSheet(
            context: context,
            isScrollControlled: true,
            backgroundColor: Colors.transparent,
            builder: (context) => MomentDetailScreen(moment: moment),
          );
        },
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Simple image background with overlay - avoiding transforms
            Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(28.0),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.25),
                    blurRadius: 20,
                    spreadRadius: 3,
                    offset: const Offset(0, 8),
                  ),
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 6,
                    spreadRadius: 1,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(28.0),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    // Basic image
                    Image(
                      image: getImageProvider(),
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) {
                        return Container(
                          color: Colors.grey.shade800,
                          child: const Center(child: Icon(Icons.broken_image, color: Colors.white, size: 42)),
                        );
                      },
                    ),
                    // Gradient overlay - no ShaderMask, just a Container
                    Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.transparent,
                            Colors.black.withOpacity(0.2),
                            Colors.black.withOpacity(0.5),
                          ],
                          stops: const [0.0, 0.6, 1.0],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            
            // Elegant title overlay with enhanced styling
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: ClipRRect(
                borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(28.0),
                  bottomRight: Radius.circular(28.0),
                ),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                  child: Container(
                    padding: const EdgeInsets.fromLTRB(20, 30, 20, 24),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.transparent,
                          Colors.black.withOpacity(0.2),
                          Colors.black.withOpacity(0.5),
                        ],
                        stops: const [0.0, 0.6, 1.0],
                      ),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        // Project title with elegant typography
                        Text(
                          moment.title,
                          style: GoogleFonts.playfairDisplay(
                            color: Colors.white,
                            fontSize: 38,
                            fontWeight: FontWeight.w500,
                            shadows: [
                              Shadow(
                                color: Colors.black.withOpacity(0.3),
                                offset: const Offset(0, 2),
                                blurRadius: 5,
                              ),
                            ],
                          ),
                          textAlign: TextAlign.center,
                        ),
                        
                        // Add a subtle divider
                        Container(
                          margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 80),
                          height: 1,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                Colors.transparent,
                                Colors.white.withOpacity(0.7),
                                Colors.transparent,
                              ],
                              stops: const [0.0, 0.5, 1.0],
                            ),
                          ),
                        ),
                        
                        // Add contributor count if available
                        if (moment.contributorIds.isNotEmpty)
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.people_outline,
                                color: Colors.white.withOpacity(0.8),
                                size: 16,
                              ),
                              const SizedBox(width: 5),
                              Text(
                                '${moment.contributorIds.length} contributor${moment.contributorIds.length == 1 ? '' : 's'}',
                                style: GoogleFonts.nunito(
                                  color: Colors.white.withOpacity(0.8),
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            
            // Enhanced hosting badge with animation
            if (isHosting)
              Positioned(
                top: 16.0,
                left: 16.0,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.25),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: Colors.white.withOpacity(0.5),
                      width: 1,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.2),
                        blurRadius: 4,
                        spreadRadius: 0,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.star_rounded,
                        color: Colors.white,
                        size: 16,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'Hosting',
                        style: GoogleFonts.nunito(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              
            // Redesigned delete button with better visual feedback
            if (isHosting)
              Positioned(
                top: 16.0,
                right: 16.0,
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(50),
                    onTap: () {
                      HapticFeedback.mediumImpact();
                      _confirmDelete(context, dbService, moment);
                    },
                    child: Container(
                      padding: const EdgeInsets.all(10.0),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.25),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: Colors.white.withOpacity(0.5),
                          width: 1,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.2),
                            blurRadius: 4,
                            spreadRadius: 0,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.delete_outline_rounded,
                        color: Colors.white,
                        size: 20,
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
  
  // Enhanced confirmation dialog with animations
  Future<void> _confirmDelete(BuildContext context, DatabaseService dbService, Project moment) async {
    return showDialog(
      context: context,
      barrierDismissible: true,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          backgroundColor: const Color(0xFF1A1A1A),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.red.shade300.withOpacity(0.2),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.delete_rounded,
                  color: Colors.red.shade300,
                ),
              ),
              const SizedBox(width: 12),
              Text(
                'Delete Moment', 
                style: GoogleFonts.nunito(
                  color: Colors.white, 
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
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
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
              ),
              child: Text(
                'Cancel', 
                style: GoogleFonts.nunito(
                  color: Colors.grey,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            ElevatedButton(
              onPressed: () async {
                Navigator.of(dialogContext).pop();
                
                // Show a more elegant loading indicator
                if (context.mounted) {
                  showDialog(
                    context: context,
                    barrierDismissible: false,
                    builder: (context) => Center(
                      child: Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.7),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: const CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 3,
                        ),
                      ),
                    ),
                  );
                }
                
                // Delete the project with error handling
                bool success = false;
                String errorMessage = '';
                
                try {
                  // Add a timeout to prevent hanging
                  success = await dbService.deleteProject(moment.id)
                      .timeout(const Duration(seconds: 10), onTimeout: () {
                    throw TimeoutException('Delete operation timed out');
                  });
                } catch (e) {
                  print('Error deleting moment: $e');
                  errorMessage = e.toString();
                } finally {
                  // Always dismiss the loading dialog if mounted
                  if (context.mounted) {
                    Navigator.of(context, rootNavigator: true).pop();
                  }
                }
                
                // Show result with a nicer, animated snackbar
                if (success && context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Row(
                        children: [
                          const Icon(Icons.check_circle, color: Colors.white),
                          const SizedBox(width: 12),
                          Text(
                            'Moment deleted successfully',
                            style: GoogleFonts.nunito(fontWeight: FontWeight.w600),
                          ),
                        ],
                      ),
                      backgroundColor: Colors.green.shade600,
                      behavior: SnackBarBehavior.floating,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                  );
                } else if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Row(
                        children: [
                          const Icon(Icons.error_outline, color: Colors.white),
                          const SizedBox(width: 12),
                          Flexible(
                            child: Text(
                              errorMessage.isNotEmpty 
                                ? 'Failed to delete moment: ${errorMessage.length > 50 ? errorMessage.substring(0, 50) + '...' : errorMessage}'
                                : 'Failed to delete moment',
                              style: GoogleFonts.nunito(fontWeight: FontWeight.w600),
                              overflow: TextOverflow.ellipsis,
                              maxLines: 2,
                            ),
                          ),
                        ],
                      ),
                      backgroundColor: Colors.red.shade600,
                      behavior: SnackBarBehavior.floating,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      duration: const Duration(seconds: 4),
                    ),
                  );
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red.shade700,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
              ),
              child: Text(
                'Delete',
                style: GoogleFonts.nunito(
                  color: Colors.white, 
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