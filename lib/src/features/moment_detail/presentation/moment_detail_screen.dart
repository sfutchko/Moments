import 'dart:io'; // Import dart:io for File
import 'dart:ui'; // For ImageFilter

import 'package:cached_network_image/cached_network_image.dart'; // Import cached_network_image
import 'package:flutter/material.dart';
import 'package:provider/provider.dart'; // If needed for actions later
import 'package:share_plus/share_plus.dart'; // Import share_plus
import 'package:image_picker/image_picker.dart'; // Import image_picker
import 'package:firebase_auth/firebase_auth.dart'; // Import FirebaseAuth
import 'package:palette_generator/palette_generator.dart'; // Import Palette Generator
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart'; // For Timestamp

import '../../../models/project.dart'; // Import the Project model
import '../../../services/database_service.dart'; // Import DatabaseService
import '../../../services/storage_service.dart'; // Import StorageService
import '../../../services/video_compilation_service.dart'; // Import VideoCompilationService
import '../../../services/video_sharing_service.dart'; // Import VideoSharingService
import '../../recording/presentation/prompt_display_screen.dart'; // Import PromptDisplayScreen
import 'video_player_screen.dart'; // Import our new VideoPlayerScreen
import '../../../services/invitation_service.dart'; // Import InvitationService
import 'components/invite_list_component.dart';
// TODO: Import other services if needed (e.g., DatabaseService for updates)

// Convert to StatefulWidget
class MomentDetailScreen extends StatefulWidget {
  // Keep initial moment for ID and fallback title
  final Project initialMoment;

  const MomentDetailScreen({super.key, required Project moment}) 
       : initialMoment = moment; // Assign to initialMoment

  @override
  State<MomentDetailScreen> createState() => _MomentDetailScreenState();
}

class _MomentDetailScreenState extends State<MomentDetailScreen> {
  bool _isLoading = false; // State for loading indicator
  bool _isCompiling = false; // State for compilation in progress
  String _compilationStatus = ''; // Status message for compilation
  double _compilationProgress = 0.0; // Progress for compilation
  String? _compiledVideoUrl; // URL of the compiled video if available
  final ScrollController _scrollController = ScrollController();
  double _imageScale = 1.0;
  final double _initialImageScale = 1.0;
  final double _maxImageScale = 1.15; // How much the image zooms
  final VideoSharingService _sharingService = VideoSharingService();

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.hasClients) {
      double offset = _scrollController.offset;
      // Calculate scale based on scroll offset (adjust sensitivity as needed)
      double delta = (offset * 0.0005).clamp(0.0, _maxImageScale - _initialImageScale);
      setState(() {
        _imageScale = _initialImageScale + delta;
      });
    }
  }

  // Method to handle sharing the invitation
  void _shareInvitation(BuildContext context, Project moment) {
    final invitationService = InvitationService();
    invitationService.showInviteDialog(context, moment);
  }

  // Helper method to show image source selection dialog
  Future<ImageSource?> _showImageSourceDialog(BuildContext context) async {
    return showDialog<ImageSource>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Select Image Source'),
        content: const Text('Choose where to get the image from:'), // Added content
        actions: <Widget>[
          TextButton(
            child: const Text('Camera'),
            onPressed: () => Navigator.pop(context, ImageSource.camera),
          ),
          TextButton(
            child: const Text('Gallery'),
            onPressed: () => Navigator.pop(context, ImageSource.gallery),
          ),
           TextButton(
            child: const Text('Cancel', style: TextStyle(color: Colors.grey)), // Added cancel
            onPressed: () => Navigator.pop(context, null),
          ),
        ],
      ),
    );
  }

  // Helper method to get the correct moment ID (using widget.initialMoment)
  String get _momentId => widget.initialMoment.id;

  // --- Main tap handler --- 
  Future<void> _handleImageTap(bool isOrganizer, Project currentMoment) async {
    if (_isLoading) return;
    final bool hasCoverImage = currentMoment.coverImageUrl != null && currentMoment.coverImageUrl!.isNotEmpty;

    if (isOrganizer && hasCoverImage) {
      await _showOrganizerImageOptions(currentMoment); // Pass currentMoment
    } else {
      // Allow organizer to pick even if no image, otherwise check if organizer
      if (isOrganizer) {
        await _pickAndUploadImage(currentMoment); // Pass currentMoment
      } else {
        // Maybe show a message that only organizer can add/change?
         ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Only the organizer can change the cover image.'))
         );
      }
    }
  }

  // --- Dialog for organizer options ---
  Future<void> _showOrganizerImageOptions(Project currentMoment) async {
     await showModalBottomSheet(
        context: context,
        builder: (context) {
          return SafeArea(
            child: Wrap(
              children: <Widget>[
                ListTile(
                  leading: const Icon(Icons.photo_library), 
                  title: const Text('Change Image'),
                  onTap: () {
                    Navigator.pop(context); 
                    _pickAndUploadImage(currentMoment); // Pass currentMoment
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.delete_outline, color: Colors.red),
                  title: const Text('Delete Current Image', style: TextStyle(color: Colors.red)),
                  onTap: () {
                    Navigator.pop(context); 
                    _confirmAndDeleteImage(currentMoment); // Pass currentMoment
                  },
                ),
                 ListTile(
                   leading: const Icon(Icons.cancel), 
                   title: const Text('Cancel'),
                   onTap: () => Navigator.pop(context),
                 ),
              ],
            ),
          );
        },
     );
  }

   // --- Confirmation and Deletion Logic --- 
  Future<void> _confirmAndDeleteImage(Project currentMoment) async {
      final confirm = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
           title: const Text('Delete Cover Image?'),
           content: const Text('Are you sure you want to remove the current cover image?'),
           actions: [
              TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
              TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Delete', style: TextStyle(color: Colors.red))),
           ],
        )
      ) ?? false;

      if (confirm) {
        await _deleteCoverImage(currentMoment); // Pass currentMoment
      }
  }

  Future<void> _deleteCoverImage(Project currentMoment) async {
     if (_isLoading) return;
     setState(() => _isLoading = true);

     // Use ID from the passed currentMoment
     final String momentId = currentMoment.id; 
     final storageService = context.read<StorageService>();
     final dbService = context.read<DatabaseService>();

     try {
         print('Attempting to delete cover image for $momentId...');
         bool storageDeleteSuccess = await storageService.deleteCoverImage(momentId);

         if (storageDeleteSuccess) {
             print('Storage deletion successful. Updating Firestore...');
             Map<String, dynamic> updateData = {
               'coverImageUrl': null,
               'gradientColorHex1': null,
               'gradientColorHex2': null,
               'gradientColorHex3': null,
             };
             bool firestoreUpdateSuccess = await dbService.updateProject(momentId, updateData);

             if (firestoreUpdateSuccess) {
                 print('Cover image successfully deleted and Firestore updated.');
                 if (mounted) {
                     ScaffoldMessenger.of(context).showSnackBar(
                       const SnackBar(content: Text('Cover image deleted.'), backgroundColor: Colors.green)
                     );
                 }
             } else {
                 print('Storage deleted, but failed to update Firestore.');
                 // Might want to show a more specific error
                 if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                       const SnackBar(content: Text('Error updating database after deletion.'), backgroundColor: Colors.orange)
                    );
                 }
             }
         } else {
             print('Failed to delete image from Storage.');
              if (mounted) {
                 ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Failed to delete cover image file.'), backgroundColor: Colors.red)
                 );
              }
         }

     } catch (e, stackTrace) {
         print('Error during cover image deletion process: $e\n$stackTrace');
          if (mounted) {
             ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('An error occurred during deletion: $e'), backgroundColor: Colors.red)
             );
          }
     } finally {
         if (mounted) {
            setState(() => _isLoading = false);
         }
     }
  }

  // Helper to convert Color to Hex String (e.g., #AARRGGBB)
  String _colorToHex(Color color) {
    return '#${color.value.toRadixString(16).padLeft(8, '0').toUpperCase()}';
  }

  // Pre-compute gradient colors from a File
  Future<List<String?>> _precomputeGradientHex(File imageFile) async {
     print('[Precompute] Starting palette generation from file...');
     try {
       // Generate palette from FileImageProvider
       final PaletteGenerator palette = await PaletteGenerator.fromImageProvider(
         FileImage(imageFile), // Use FileImageProvider
         maximumColorCount: 16,
       );
       print('[Precompute] Palette generated. Dominant: ${palette.dominantColor?.color}');

       // Same color selection logic as before
       Color topColor = palette.darkVibrantColor?.color ?? palette.darkMutedColor?.color ?? Colors.black;
       Color middleColor = palette.vibrantColor?.color ?? palette.lightVibrantColor?.color ?? palette.dominantColor?.color ?? const Color(0xFF333333);
       Color bottomColor = palette.darkMutedColor?.color ?? palette.dominantColor?.color.withAlpha(200) ?? const Color(0xFF1A1A1A);
       // ... (distinction checks) ...
        if (topColor == middleColor) { middleColor = palette.lightMutedColor?.color ?? palette.dominantColor?.color ?? middleColor; }
        if (topColor == bottomColor || middleColor == bottomColor) { bottomColor = topColor == Colors.black ? const Color(0xFF111111) : Colors.black; }
        if (topColor == middleColor && middleColor == bottomColor) { middleColor = middleColor.withAlpha(200); bottomColor = middleColor.withAlpha(150); }

       final resultHex = [_colorToHex(topColor), _colorToHex(middleColor), _colorToHex(bottomColor)];
       print('[Precompute] Result gradient hex: $resultHex');
       return resultHex;
     } catch (e, stackTrace) {
        print('[Precompute] ERROR generating palette from file: $e\n$stackTrace');
        return [null, null, null]; // Return nulls on error
     }
  }

  // --- Pick and Upload Logic ---
  Future<void> _pickAndUploadImage(Project currentMoment) async {
    if (_isLoading) return; 
    
    final ImageSource? source = await _showImageSourceDialog(context);
    if (source == null) return;
    
    setState(() => _isLoading = true);

    final imagePicker = ImagePicker();
    final storageService = context.read<StorageService>();
    final dbService = context.read<DatabaseService>();
    // Use ID from the passed currentMoment
    final String momentId = currentMoment.id;

    try {
      final XFile? pickedFile = await imagePicker.pickImage(source: source);
      if (pickedFile == null) {
        print('No image selected or taken.');
        if (mounted) setState(() => _isLoading = false);
        return;
      }
      File imageFile = File(pickedFile.path);

      // --- Pre-compute gradient BEFORE upload --- 
      List<String?> gradientHex = await _precomputeGradientHex(imageFile);

      // --- Upload Image --- 
      final String? downloadUrl = await storageService.uploadCoverImage(momentId, imageFile);

      if (downloadUrl != null) {
        print('Updating Firestore with URL and precomputed gradient...');
        // --- Update Firestore with URL AND Gradient Hex Strings --- 
        Map<String, dynamic> updateData = {
          'coverImageUrl': downloadUrl,
          'gradientColorHex1': gradientHex[0],
          'gradientColorHex2': gradientHex[1],
          'gradientColorHex3': gradientHex[2],
        };
        bool success = await dbService.updateProject(momentId, updateData);
        
        if (success && mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Cover image updated!'), backgroundColor: Colors.green)
            );
        } else if (!success && mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Failed to save cover image URL.'), backgroundColor: Colors.red)
            );
        }
      } else {
         if(mounted) {
             ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Failed to upload cover image.'), backgroundColor: Colors.red)
             );
          }
      }
    } catch (e, stackTrace) {
       print('Error during image pick/upload: $e\n$stackTrace');
       if(mounted) {
         ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('An error occurred: $e'), backgroundColor: Colors.red)
         );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final screenHeight = MediaQuery.of(context).size.height;
    final screenWidth = MediaQuery.of(context).size.width;
    final topPadding = MediaQuery.of(context).padding.top;
    final bottomPadding = MediaQuery.of(context).padding.bottom;

    // --- Use StreamBuilder to get live updates --- 
    final dbService = context.watch<DatabaseService>();
    final String momentId = widget.initialMoment.id;

    return StreamBuilder<Project?>(
      stream: dbService.getProjectDetails(momentId), 
      builder: (context, snapshot) {
        // Use initial data as fallback while loading or if error
        final Project displayMoment = snapshot.data ?? widget.initialMoment;
        final String displayTitle = displayMoment.title;
        final String displayOrganizerName = displayMoment.organizerName;

        // Determine avatar initials
        final nameParts = displayOrganizerName.split(' ');
        final initials = nameParts.length >= 2
            ? (nameParts[0].isNotEmpty ? nameParts[0][0] : '?') + (nameParts[1].isNotEmpty ? nameParts[1][0] : '')
            : (nameParts.isNotEmpty && nameParts[0].isNotEmpty ? nameParts[0][0] : '?');

        // Show loading indicator or error state before main build if needed
        if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) {
          return const Scaffold(backgroundColor: Colors.black, body: Center(child: CircularProgressIndicator()));
        }
        if (snapshot.hasError) {
          return Scaffold(backgroundColor: Colors.black, body: Center(child: Text('Error loading moment', style: TextStyle(color: Colors.red))));
        }
        if (!snapshot.hasData) {
          return Scaffold(backgroundColor: Colors.black, body: Center(child: Text('Moment not found', style: TextStyle(color: Colors.white))));
        }

        // --- Main Build Structure --- 
        return ClipRRect(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24.0)),
          child: GestureDetector(
            onVerticalDragUpdate: (details) {
              if (details.primaryDelta != null && details.primaryDelta! > 0) {
                // Swiping down - scale the image based on drag amount
                final scaleFactor = 1.0 + (details.primaryDelta! / 500);
                setState(() {
                  _imageScale = (_imageScale * scaleFactor).clamp(1.0, 1.3);
                });
              }
            },
            onVerticalDragEnd: (details) {
              // Reset scale when drag ends
              setState(() {
                _imageScale = 1.0;
              });
            },
            child: Scaffold(
              extendBodyBehindAppBar: true,
              backgroundColor: Colors.black,
              body: Stack(
                fit: StackFit.expand,
                children: [
                  // Full-screen image layer
                  Transform.scale(
                    scale: _imageScale,
                    child: Image(
                      image: _getBackgroundImageProvider(),
                      fit: BoxFit.cover,
                      height: double.infinity,
                      width: double.infinity,
                      errorBuilder: (context, error, stackTrace) {
                        print("Error loading background image: $error");
                        return Container(color: Colors.grey.shade900);
                      },
                    ),
                  ),
                  
                  // Main Content with integrated frosted effect
                  CustomScrollView(
                    physics: const BouncingScrollPhysics(),
                    slivers: [
                      // Clear top area - just a spacer
                      SliverToBoxAdapter(
                        child: SizedBox(height: screenHeight * 0.45),
                      ),
                      
                      // Frosted content area
                      SliverToBoxAdapter(
                        child: ClipRect(
                          child: BackdropFilter(
                            filter: ImageFilter.blur(sigmaX: 10.0, sigmaY: 10.0),
                            child: Container(
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment.topCenter,
                                  end: Alignment.bottomCenter,
                                  colors: [
                                    Colors.transparent,
                                    _getGradientStartColor(displayMoment).withOpacity(0.1),
                                    _getGradientEndColor(displayMoment).withOpacity(0.5),
                                  ],
                                  stops: const [0.0, 0.2, 1.0],
                                ),
                              ),
        child: Column(
                                children: [
                                  // Title section
                                  Padding(
                                    padding: const EdgeInsets.fromLTRB(24.0, 24.0, 24.0, 20.0),
                                    child: Text(
                                      displayTitle,
                                      textAlign: TextAlign.center,
                                      style: GoogleFonts.nunito(
                                        fontSize: 52,
                                        fontWeight: FontWeight.w700,
                                        color: Colors.white,
                                        shadows: [const Shadow(blurRadius: 8.0, color: Colors.black54, offset: Offset(1, 1))]
                                      ),
                                    ),
                                  ),
                                  
                                  // Action Buttons
                                  Padding(
                                    padding: const EdgeInsets.symmetric(horizontal: 24.0),
                                    child: Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
                                        Expanded(
                                          child: _buildActionButton(
                                            context: context,
                                            icon: Icons.spatial_audio_off,
                                            label: 'Send a Note',
                                            onTap: () { print('Send Note Tapped'); },
                                          ),
                                        ),
                                        const SizedBox(width: 16),
                                        Expanded(
                                          child: _buildActionButton(
                                            context: context,
                                            icon: Icons.ios_share,
                                            label: 'Invite Guests',
                                            onTap: () => _shareInvitation(context, displayMoment),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(height: 32),
                                  
                                  // Contributions Section
                                  Padding(
                                    padding: const EdgeInsets.symmetric(horizontal: 24.0),
                                    child: Text(
                                      'Contributions', 
                                      style: theme.textTheme.headlineSmall?.copyWith(
                                        color: Colors.white.withOpacity(0.9),
                                        fontWeight: FontWeight.w600,
                                      )
                                    ),
                                  ),
                                  const SizedBox(height: 16),
                                  
                                  // Video Button
                                  Center(
                                    child: _buildVideoButton(context, displayMoment),
                                  ),
                                  const SizedBox(height: 24),

                                  // Placeholder for video list/grid
                                  Padding(
                                    padding: const EdgeInsets.symmetric(horizontal: 24.0),
                                    child: Container(
                                      height: 140,
                                      width: double.infinity,
                                      decoration: BoxDecoration(
                                        borderRadius: BorderRadius.circular(16),
                                        color: Colors.transparent,
                                      ),
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          // Use StreamBuilder to display actual video clips
                                          SizedBox(
                                            height: 140,
                                            child: StreamBuilder<List<VideoClip>>(
                                              stream: context.read<DatabaseService>().getVideoClipsForProject(displayMoment.id),
                                              builder: (context, snapshot) {
                                                if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) {
                                                  return const Center(child: CircularProgressIndicator());
                                                }
                                                
                                                final clips = snapshot.data ?? [];
                                                final currentUserId = FirebaseAuth.instance.currentUser?.uid;
                                                final bool hasContributed = currentUserId != null && 
                                                    clips.any((clip) => clip.contributorId == currentUserId);
                                                
                                                // Always show 3 items (placeholders or real videos)
                                                return ListView.separated(
                                                  scrollDirection: Axis.horizontal,
                                                  itemCount: 3,
                                                  separatorBuilder: (context, index) => const SizedBox(width: 12),
                                                  itemBuilder: (context, index) {
                                                    // If we have a clip at this index, show it
                                                    if (index < clips.length) {
                                                      return _buildVideoThumbnail(clips[index]);
                                                    } else {
                                                      // Otherwise show a placeholder with different colors based on index
                                                      final colors = [
                                                        [Colors.blue.withOpacity(0.3), Colors.indigo.withOpacity(0.3)],
                                                        [Colors.purple.withOpacity(0.3), Colors.pink.withOpacity(0.3)],
                                                        [Colors.amber.withOpacity(0.3), Colors.orange.withOpacity(0.3)]
                                                      ];
                                                      return _buildVideoPlaceholder(
                                                        color1: colors[index % 3][0], 
                                                        color2: colors[index % 3][1]
                                                      );
                                                    }
                                                  },
                                                );
                                              },
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 24),

                                  // Final Video Compilation Placeholder
                                  Padding(
                                    padding: const EdgeInsets.symmetric(horizontal: 24.0),
                                    child: ClipRRect(
                                      borderRadius: BorderRadius.circular(16),
                                      child: BackdropFilter(
                                        filter: ImageFilter.blur(sigmaX: 5.0, sigmaY: 5.0),
                                        child: Container(
                                          height: displayMoment.compiledVideoUrl != null ? 180 : 180,
                                          width: double.infinity,
                                          decoration: BoxDecoration(
                                            gradient: LinearGradient(
                                              begin: Alignment.topLeft,
                                              end: Alignment.bottomRight,
                                              colors: [
                                                Colors.white.withOpacity(0.25),
                                                Colors.white.withOpacity(0.15),
                                              ],
                                            ),
                                            borderRadius: BorderRadius.circular(16),
                                            border: Border.all(color: Colors.white.withOpacity(0.3), width: 0.5),
                                          ),
                                          child: displayMoment.compiledVideoUrl != null
                                            ? _buildCompiledVideoPreview(displayMoment)
                                            : _buildCreateVideoSection(displayMoment),
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  
                                  // Invitees Section
                                  InviteListComponent(
                                    projectId: displayMoment.id,
                                    invitationService: InvitationService(),
                                    onAddNewInvite: () => _shareInvitation(context, displayMoment),
                                  ),
                                  const SizedBox(height: 16),
                                  
                                  // Hosted By Card
                                  Center(
                                    child: _buildHostedByCard(context, initials, displayOrganizerName),
                                  ),
                                  SizedBox(height: bottomPadding > 0 ? bottomPadding + 10 : 20),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  // Close button in top-left corner
                  Positioned(
                    top: topPadding + 40, // Increased from 16 to 40 to move it lower
                    left: 16,
                    child: _buildCloseButton(context),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  // Helper to get the background image provider
  ImageProvider _getBackgroundImageProvider() {
     if (widget.initialMoment.coverImageUrl != null && widget.initialMoment.coverImageUrl!.isNotEmpty) {
       return CachedNetworkImageProvider(widget.initialMoment.coverImageUrl!);
     } else {
       // Consistent placeholder fallback
       return const AssetImage('assets/images/placeholder.png');
     }
  }

  // Helper to build action buttons with enhanced glassmorphism
  Widget _buildActionButton({required BuildContext context, required IconData icon, required String label, required VoidCallback onTap}) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(30.0),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 5.0, sigmaY: 5.0),
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Colors.white.withOpacity(0.3),
                Colors.white.withOpacity(0.15),
              ],
            ),
            borderRadius: BorderRadius.circular(30.0),
            border: Border.all(color: Colors.white.withOpacity(0.4), width: 0.5),
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: onTap,
              splashColor: Colors.white.withOpacity(0.1),
              highlightColor: Colors.white.withOpacity(0.05),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      icon, 
                      size: 20, 
                      color: Colors.white,
                    ),
                    const SizedBox(width: 10),
                    Text(
                      label,
                      style: GoogleFonts.nunito(
                        fontWeight: FontWeight.w600,
                        fontSize: 16,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  // Helper for Video Button - extracted for cleaner code
  Widget _buildVideoButton(BuildContext context, Project moment) { // Pass moment
    return StreamBuilder<List<VideoClip>>(
      stream: context.read<DatabaseService>().getVideoClipsForProject(moment.id),
      builder: (context, snapshot) {
        final clips = snapshot.data ?? [];
        final currentUserId = FirebaseAuth.instance.currentUser?.uid;
        final bool hasContributed = currentUserId != null && 
            clips.any((clip) => clip.contributorId == currentUserId);
            
        return ClipRRect(
          borderRadius: BorderRadius.circular(16.0),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 6.0, sigmaY: 6.0),
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Colors.white.withOpacity(hasContributed ? 0.15 : 0.25),
                    Colors.white.withOpacity(hasContributed ? 0.1 : 0.15),
                  ],
                ),
                borderRadius: BorderRadius.circular(16.0),
                border: Border.all(color: Colors.white.withOpacity(hasContributed ? 0.2 : 0.3), width: 0.7),
              ),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: hasContributed ? () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('You\'ve already added your video contribution'),
                        backgroundColor: Colors.orange,
                      )
                    );
                  } : () {
                    print('Add Video Tapped - Navigating to Prompt Screen');
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => PromptDisplayScreen(project: moment), // Navigate to prompt screen
                      ),
                    );
                  },
                  splashColor: Colors.white.withOpacity(0.1),
                  highlightColor: Colors.white.withOpacity(0.05),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 26, vertical: 14),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          hasContributed ? Icons.videocam_off : Icons.videocam_rounded,
                          size: 22,
                          color: Colors.white.withOpacity(hasContributed ? 0.6 : 1.0),
                        ),
                        const SizedBox(width: 12),
                        Text(
                          hasContributed ? 'Video Added' : 'Add Your Video Clip',
                          style: GoogleFonts.nunito(
                            fontWeight: FontWeight.w600,
                            fontSize: 16,
                            letterSpacing: 0.3,
                            color: Colors.white.withOpacity(hasContributed ? 0.6 : 1.0),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      }
    );
  }

  // Helper to build the "Hosted By" card with enhanced glassmorphism
  Widget _buildHostedByCard(BuildContext context, String initials, String organizerName) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(20.0),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 5.0, sigmaY: 5.0),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 18.0, vertical: 14.0),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Colors.white.withOpacity(0.3),
                Colors.white.withOpacity(0.15),
              ],
            ),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.white.withOpacity(0.4), width: 0.5),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 4,
                      spreadRadius: 0,
                    ),
                  ],
                ),
                child: CircleAvatar(
                  radius: 18,
                  backgroundColor: Colors.green.shade400,
                  child: Text(
                    initials.toUpperCase(),
                    style: GoogleFonts.nunito(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Text(
                'Hosted by $organizerName',
                style: GoogleFonts.nunito(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                  fontSize: 16,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Improved circular button (for close and options buttons)
  Widget _buildCircularButton({
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return ClipOval(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 5.0, sigmaY: 5.0),
        child: Container(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.black.withOpacity(0.2),
            border: Border.all(color: Colors.white.withOpacity(0.3), width: 0.5),
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: onTap,
              customBorder: const CircleBorder(),
              splashColor: Colors.white.withOpacity(0.1),
              highlightColor: Colors.white.withOpacity(0.05),
              child: Padding(
                padding: const EdgeInsets.all(8.0),
                child: Icon(icon, color: Colors.white, size: 22),
              ),
            ),
          ),
        ),
      ),
    );
  }

  // Helper to get gradient start color (upper part of frosted area)
  Color _getGradientStartColor(Project moment) {
    // If project has color data, use it
    if (moment.gradientColorHex1 != null && moment.gradientColorHex1!.isNotEmpty) {
      try {
        return Color(int.parse(moment.gradientColorHex1!.substring(1), radix: 16));
      } catch (e) {
        print('Error parsing gradient color 1: $e');
      }
    }
    // Default: dark teal/blue
    return const Color(0xFF062C40);
  }
  
  // Helper to get gradient end color (lower part of frosted area)
  Color _getGradientEndColor(Project moment) {
    // If project has color data, use it
    if (moment.gradientColorHex3 != null && moment.gradientColorHex3!.isNotEmpty) {
      try {
        return Color(int.parse(moment.gradientColorHex3!.substring(1), radix: 16));
      } catch (e) {
        print('Error parsing gradient color 3: $e');
      }
    }
    // Default: deep blue/black
    return const Color(0xFF041C28);
  }

  // Helper to create a video placeholder thumbnail
  Widget _buildVideoPlaceholder({required Color color1, required Color color2}) {
    return Container(
      width: 120,
      height: 140,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [color1, color2],
        ),
        border: Border.all(color: Colors.white.withOpacity(0.2), width: 0.5),
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Video placeholder content
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.videocam,
                color: Colors.white70,
                size: 32,
              ),
              const SizedBox(height: 8),
              Container(
                width: 70,
                height: 8,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(4),
                  color: Colors.white.withOpacity(0.3),
                ),
              ),
              const SizedBox(height: 6),
              Container(
                width: 50,
                height: 8,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(4),
                  color: Colors.white.withOpacity(0.2),
                ),
              ),
            ],
          ),
          
          // Play button overlay
          const Icon(
            Icons.play_circle_fill,
            color: Colors.white54,
            size: 36,
          ),
        ],
      ),
    );
  }

  // Build a video thumbnail from an actual VideoClip
  Widget _buildVideoThumbnail(VideoClip clip) {
    final currentUserId = FirebaseAuth.instance.currentUser?.uid;
    final bool isHost = widget.initialMoment.organizerId == currentUserId;
    
    return GestureDetector(
      onTap: () {
        // Navigate to video player screen
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => VideoPlayerScreen(
              videoUrl: clip.videoUrl,
              contributorName: clip.contributorName,
            ),
          ),
        );
      },
      onLongPress: isHost ? () => _showDeleteVideoDialog(clip) : null,
      child: Container(
        width: 120,
        height: 140,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Colors.blue.withOpacity(0.4),
              Colors.purple.withOpacity(0.4),
            ],
          ),
          border: Border.all(color: Colors.white.withOpacity(0.3), width: 0.5),
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            // Clip info
            Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Contributor initials or icon
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white.withOpacity(0.3),
                  ),
                  child: Center(
                    child: Text(
                      _getInitials(clip.contributorName),
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8.0),
                  child: Text(
                    clip.contributorName,
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.9),
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _formatTimestamp(clip.createdAt),
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.7),
                    fontSize: 10,
                  ),
                ),
              ],
            ),
            
            // Play button overlay
            const Icon(
              Icons.play_circle_fill,
              color: Colors.white,
              size: 40,
            ),
            
            // Delete icon indicator for host (only shown if isHost)
            if (isHost)
              Positioned(
                top: 5,
                right: 5,
                child: Container(
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    color: Colors.red.withOpacity(0.8),
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 1),
                  ),
                  child: const Icon(
                    Icons.delete,
                    color: Colors.white,
                    size: 14,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
  
  // Show a confirmation dialog for deleting a video
  Future<void> _showDeleteVideoDialog(VideoClip clip) async {
    final bool confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Video?'),
        content: Text('Are you sure you want to delete ${clip.contributorName}\'s video?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    ) ?? false;
    
    if (confirm) {
      setState(() => _isLoading = true);
      
      try {
        // Delete from storage first
        final storageService = context.read<StorageService>();
        final dbService = context.read<DatabaseService>();
        
        final bool storageSuccess = await storageService.deleteVideoClip(
          widget.initialMoment.id,
          clip.videoUrl,
        );
        
        if (storageSuccess) {
          // Then delete from Firestore
          final bool dbSuccess = await dbService.deleteVideoClip(
            widget.initialMoment.id,
            clip.id,
          );
          
          if (dbSuccess) {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Video deleted successfully'),
                  backgroundColor: Colors.green,
                ),
              );
            }
          } else {
            throw Exception('Error deleting video metadata from database');
          }
        } else {
          throw Exception('Error deleting video file from storage');
        }
      } catch (e) {
        print('Error deleting video: $e');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error deleting video: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      } finally {
        if (mounted) setState(() => _isLoading = false);
      }
    }
  }

  // Helper to get initials from a name
  String _getInitials(String name) {
    if (name.isEmpty) return '?';
    final nameParts = name.split(' ');
    if (nameParts.length > 1) {
      return '${nameParts[0][0]}${nameParts[1][0]}'.toUpperCase();
    }
    return name[0].toUpperCase();
  }
  
  // Helper to format timestamp
  String _formatTimestamp(Timestamp timestamp) {
    final date = timestamp.toDate();
    final now = DateTime.now();
    
    if (now.difference(date).inDays < 1) {
      return 'Today';
    } else if (now.difference(date).inDays < 2) {
      return 'Yesterday';
    } else {
      return '${date.month}/${date.day}';
    }
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
  
  // Helper to get formatted recipient text with additional text
  String _getRecipientText(Project project, String additionalText) {
    return "${_getRecipientName(project)}'s $additionalText";
  }

  // Helper to build an elegant close button
  Widget _buildCloseButton(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(30),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 5.0, sigmaY: 5.0),
        child: Container(
          height: 40,
          width: 40,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight, 
              colors: [
                Colors.white.withOpacity(0.3),
                Colors.white.withOpacity(0.15),
              ],
            ),
            border: Border.all(color: Colors.white.withOpacity(0.3), width: 0.5),
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              customBorder: const CircleBorder(),
              onTap: () => Navigator.of(context).pop(),
              splashColor: Colors.white.withOpacity(0.1),
              highlightColor: Colors.white.withOpacity(0.05),
              child: const Center(
                child: Icon(
                  Icons.close_rounded,
                  color: Colors.white,
                  size: 22,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  // Method to handle video compilation
  Future<void> _handleCompileVideoTap(BuildContext context, Project project) async {
    // Don't allow starting a new compilation if one is already in progress
    if (_isCompiling) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Compilation already in progress'))
      );
      return;
    }
    
    // Check if we already have a compiled video
    if (_compiledVideoUrl != null || project.compiledVideoUrl != null) {
      // Navigate to video player to view the compiled video
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => VideoPlayerScreen(
            videoUrl: _compiledVideoUrl ?? project.compiledVideoUrl!,
            contributorName: 'Compiled Video',
          ),
        ),
      );
      return;
    }
    
    // Get video clips from database
    final dbService = context.read<DatabaseService>();
    final List<VideoClip> clips = await dbService.getVideoClipsForProjectSync(project.id);
    
    if (clips.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No video clips available to compile'),
          backgroundColor: Colors.orange,
        )
      );
      return;
    }
    
    // Update state to show compilation is in progress
    setState(() {
      _isCompiling = true;
      _compilationStatus = 'Starting compilation...';
      _compilationProgress = 0.0;
    });
    
    // Create VideoCompilationService
    final storageService = context.read<StorageService>();
    final videoCompilationService = VideoCompilationService(
      storageService, 
      databaseService: dbService
    );
    
    try {
      // Start compilation with updated API
      final String? downloadUrl = await videoCompilationService.compileVideos(
        project.id,
        clips,
        (String message, double progress) {
          setState(() {
            _compilationStatus = message;
            _compilationProgress = progress;
          });
        },
      );
      
      if (downloadUrl != null) {
        setState(() {
          _compiledVideoUrl = downloadUrl;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Video compilation complete!'),
              backgroundColor: Colors.green,
            )
          );
        });
        
        // Open the compiled video automatically
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => VideoPlayerScreen(
              videoUrl: downloadUrl,
              contributorName: 'Compiled Video',
            ),
          ),
        );
      } else {
        throw Exception('Failed to get download URL for compiled video');
      }
    } catch (e) {
      print('Error during video compilation: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error compiling video: ${e.toString()}'),
            backgroundColor: Colors.red,
          )
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isCompiling = false;
        });
      }
    }
  }

  // Helper to build the compiled video preview section
  Widget _buildCompiledVideoPreview(Project project) {
    return Stack(
      alignment: Alignment.center,
      children: [
        Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Title and subtitle
            Text(
              _getRecipientText(project, 'Special Video'),
              style: GoogleFonts.nunito(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 18,
              ),
            ),
            const SizedBox(height: 4),
            
            // Video thumbnail with play button
            Container(
              height: 100,
              width: double.infinity,
              margin: const EdgeInsets.symmetric(horizontal: 24),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                color: Colors.black26,
                border: Border.all(color: Colors.white.withOpacity(0.4), width: 1),
              ),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  // Gradient background
                  Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          Colors.purple.withOpacity(0.4),
                          Colors.blue.withOpacity(0.2),
                        ],
                      ),
                    ),
                  ),
                  
                  // Play button and text
                  Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        Icons.play_circle_fill,
                        color: Colors.white,
                        size: 40,
                      ),
                      const SizedBox(height: 5),
                      Text(
                        'Play ${_getRecipientName(project)}\'s Video',
                        style: GoogleFonts.nunito(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                  
                  // Clickable overlay
                  Material(
                    color: Colors.transparent,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(12),
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => VideoPlayerScreen(
                              videoUrl: project.compiledVideoUrl!,
                              contributorName: '${_getRecipientName(project)}\'s Video',
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
            
            const SizedBox(height: 4),
            
            // Share button
            ClipRRect(
              borderRadius: BorderRadius.circular(30),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 3.0, sigmaY: 3.0),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: () => _shareCompiledVideo(project),
                    splashColor: Colors.white.withOpacity(0.1),
                    highlightColor: Colors.white.withOpacity(0.05),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            Colors.blue.withOpacity(0.6),
                            Colors.blue.withOpacity(0.4),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(30),
                        border: Border.all(color: Colors.white.withOpacity(0.3), width: 0.5),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.share,
                            color: Colors.white,
                            size: 16,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            'Share Video',
                            style: GoogleFonts.nunito(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
  
  // Method to share the compiled video
  Future<void> _shareCompiledVideo(Project project) async {
    // Make sure we have a compiled video URL
    final String? videoUrl = project.compiledVideoUrl ?? _compiledVideoUrl;
    if (videoUrl == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("No compiled video available to share"))
      );
      return;
    }
    
    // Share the video using our sharing service
    await _sharingService.shareVideo(
      videoUrl: videoUrl,
      title: '${_getRecipientName(project)}\'s Special Video',
      context: context,
      message: 'Check out this special video we made for ${_getRecipientName(project)}!',
    );
  }

  // Helper to build the create video section
  Widget _buildCreateVideoSection(Project project) {
    return Stack(
      alignment: Alignment.center,
      children: [
        // Video compilation placeholder content
        Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Video icon with heart
            Stack(
              alignment: Alignment.center,
              children: [
                const Icon(
                  Icons.video_library,
                  color: Colors.white,
                  size: 48,
                ),
                Positioned(
                  right: 0,
                  bottom: 0,
                  child: Container(
                    padding: const EdgeInsets.all(2),
                    decoration: const BoxDecoration(
                      color: Colors.red,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.favorite,
                      color: Colors.white,
                      size: 12,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              _getRecipientText(project, 'Special Moments'),
              style: GoogleFonts.nunito(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 6),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 40),
              child: Text(
                'Combine all videos into one special gift for ${_getRecipientName(project)}',
                textAlign: TextAlign.center,
                style: GoogleFonts.nunito(
                  color: Colors.white.withOpacity(0.7),
                  fontSize: 14,
                ),
              ),
            ),
            const SizedBox(height: 18),
            // Create video button
            ClipRRect(
              borderRadius: BorderRadius.circular(30),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 5.0, sigmaY: 5.0),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: () => _handleCompileVideoTap(context, project),
                    splashColor: Colors.white.withOpacity(0.1),
                    highlightColor: Colors.white.withOpacity(0.05),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            Colors.pink.withOpacity(0.6),
                            Colors.red.withOpacity(0.4),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(30),
                        border: Border.all(color: Colors.white.withOpacity(0.3), width: 0.5),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.auto_awesome,
                            color: Colors.white,
                            size: 18,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            _isCompiling ? 'Compiling...' : 'Create ${_getRecipientName(project)}\'s Video',
                            style: GoogleFonts.nunito(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
            if (_isCompiling)
              Padding(
                padding: const EdgeInsets.only(top: 8.0),
                child: Column(
                  children: [
                    Text(
                      _compilationStatus,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                      ),
                    ),
                    SizedBox(height: 4),
                    LinearProgressIndicator(
                      value: _compilationProgress,
                      backgroundColor: Colors.white.withOpacity(0.2),
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.pink),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ],
    );
  }
} 