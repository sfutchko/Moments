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
import 'package:rxdart/rxdart.dart'; // Import rxdart for combineLatest2
import 'package:intl/intl.dart'; // Import intl for date formatting

import '../../../models/project.dart'; // Import the Project model
import '../../../services/database_service.dart'; // Import DatabaseService
import '../../../services/storage_service.dart'; // Import StorageService
import '../../../services/video_compilation_service.dart'; // Import VideoCompilationService
import '../../../services/video_sharing_service.dart'; // Import VideoSharingService
import '../../recording/presentation/prompt_display_screen.dart'; // Import PromptDisplayScreen
import 'video_player_screen.dart'; // Import our new VideoPlayerScreen
import '../../../services/invitation_service.dart'; // Import InvitationService
import 'components/invite_list_component.dart';
import '../../../services/delivery_service.dart';
import '../widgets/delivery_countdown_timer.dart';
import '../../../utils/image_provider_util.dart'; // Import our new utility class
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
  final DeliveryService _deliveryService = DeliveryService();

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
          child: Scaffold(
            extendBodyBehindAppBar: true,
            backgroundColor: Colors.black,
            body: Stack(
              fit: StackFit.expand,
              children: [
                // Full-screen image layer with simpler implementation
                Container(
                  decoration: BoxDecoration(
                    image: DecorationImage(
                      image: _getBackgroundImageProvider(),
                      fit: BoxFit.cover,
                    ),
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
                                          child: _buildContributionCards(context, displayMoment),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 24),
                             
                                // Delivery Countdown if date is set and only for host
                                if (displayMoment.deliveryDate != null && 
                                   displayMoment.organizerId == FirebaseAuth.instance.currentUser?.uid)
                                  DeliveryCountdownTimer(
                                    deliveryDate: displayMoment.deliveryDate,
                                    isHost: displayMoment.organizerId == FirebaseAuth.instance.currentUser?.uid,
                                    onDeliveryComplete: () => _handleDeliveryComplete(context, displayMoment),
                                    onChangeDate: () => _changeDeliveryDate(context, displayMoment, ScaffoldMessenger.of(context)),
                                  ),
                             
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
                
                // Edit button in top-right corner (only for project organizer)
                if (displayMoment.organizerId == FirebaseAuth.instance.currentUser?.uid)
                  Positioned(
                    top: topPadding + 40,
                    right: 16,
                    child: _buildEditButton(context, displayMoment),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  // Helper to get the background image provider
  ImageProvider _getBackgroundImageProvider() {
    return ImageProviderUtil.getSafeImageProvider(
      imagePath: widget.initialMoment.coverImageUrl,
      fallbackAssetPath: 'assets/images/placeholder.png'
    );
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
        if (mounted) {
          setState(() => _isLoading = false);
        }
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

  // Helper to build an elegant edit button
  Widget _buildEditButton(BuildContext context, Project project) {
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
              onTap: () => _showEditOptionsDialog(context, project),
              splashColor: Colors.white.withOpacity(0.1),
              highlightColor: Colors.white.withOpacity(0.05),
              child: const Center(
                child: Icon(
                  Icons.edit_outlined,
                  color: Colors.white,
                  size: 20,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  // Show edit options dialog
  void _showEditOptionsDialog(BuildContext context, Project project) {
    final theme = Theme.of(context);
    final scaffoldMessenger = ScaffoldMessenger.of(context);
    final navigatorContext = context;
    
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          decoration: BoxDecoration(
            color: Colors.grey.shade900,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          ),
          padding: const EdgeInsets.symmetric(vertical: 24),
          child: SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Row(
                    children: [
                      Icon(Icons.edit_note, size: 24, color: Colors.blue.shade300),
                      const SizedBox(width: 16),
                      Text(
                        'Edit Moment',
                        style: GoogleFonts.nunito(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                const Divider(height: 1, color: Colors.white24),
                ListTile(
                  leading: const Icon(Icons.calendar_today, color: Colors.white),
                  title: Text(
                    project.deliveryDate == null 
                      ? 'Set Delivery Date' 
                      : 'Change Delivery Date',
                    style: GoogleFonts.nunito(color: Colors.white),
                  ),
                  subtitle: project.deliveryDate != null 
                    ? Text(
                        DateFormat.yMMMMd().format(project.deliveryDate!.toDate()),
                        style: GoogleFonts.nunito(color: Colors.white70, fontSize: 12),
                      )
                    : null,
                  onTap: () {
                    Navigator.pop(context);
                    _changeDeliveryDate(navigatorContext, project, scaffoldMessenger);
                  },
                ),
                const Divider(height: 1, color: Colors.white24),
                ListTile(
                  leading: const Icon(Icons.title, color: Colors.white),
                  title: Text(
                    'Edit Title',
                    style: GoogleFonts.nunito(color: Colors.white),
                  ),
                  subtitle: Text(
                    project.title,
                    style: GoogleFonts.nunito(color: Colors.white70, fontSize: 12),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  onTap: () {
                    Navigator.pop(context);
                    _showEditTitleDialog(navigatorContext, project, scaffoldMessenger);
                  },
                ),
                const Divider(height: 1, color: Colors.white24),
                ListTile(
                  leading: const Icon(Icons.image, color: Colors.white),
                  title: Text(
                    project.coverImageUrl == null ? 'Add Cover Image' : 'Change Cover Image',
                    style: GoogleFonts.nunito(color: Colors.white),
                  ),
                  onTap: () {
                    Navigator.pop(context);
                    _handleImageTap(true, project);
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // Show edit title dialog
  void _showEditTitleDialog(BuildContext context, Project project, ScaffoldMessengerState scaffoldMessenger) {
    final TextEditingController titleController = TextEditingController(text: project.title);
    
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: Colors.grey.shade900,
        title: Text(
          'Edit Title',
          style: GoogleFonts.nunito(color: Colors.white),
        ),
        content: TextField(
          controller: titleController,
          style: GoogleFonts.nunito(color: Colors.white),
          decoration: InputDecoration(
            hintText: 'Enter new title',
            hintStyle: TextStyle(color: Colors.white.withOpacity(0.5)),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: Colors.white.withOpacity(0.2)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: Colors.white.withOpacity(0.2)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: Colors.blue.shade300),
            ),
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(
            child: Text(
              'Cancel',
              style: GoogleFonts.nunito(color: Colors.white70),
            ),
            onPressed: () => Navigator.pop(dialogContext),
          ),
          TextButton(
            child: Text(
              'Save',
              style: GoogleFonts.nunito(color: Colors.blue.shade300),
            ),
            onPressed: () async {
              final newTitle = titleController.text.trim();
              if (newTitle.isNotEmpty && newTitle != project.title) {
                Navigator.pop(dialogContext);
                
                setState(() => _isLoading = true);
                try {
                  final success = await context.read<DatabaseService>().updateProject(
                    project.id,
                    {'title': newTitle},
                  );
                  
                  if (mounted && success) {
                    scaffoldMessenger.showSnackBar(
                      const SnackBar(
                        content: Text('Title updated successfully'),
                        backgroundColor: Colors.green,
                      ),
                    );
                  }
                } catch (e) {
                  if (mounted) {
                    scaffoldMessenger.showSnackBar(
                      SnackBar(
                        content: Text('Error updating title: $e'),
                        backgroundColor: Colors.red,
                      ),
                    );
                  }
                } finally {
                  if (mounted) {
                    setState(() => _isLoading = false);
                  }
                }
              } else {
                Navigator.pop(dialogContext);
              }
            },
          ),
        ],
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

  // Enhanced widget to build contribution cards showing status
  Widget _buildContributionCards(BuildContext context, Project project) {
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: _combineInvitationsAndClips(project.id),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        
        final List<Map<String, dynamic>> contributionData = snapshot.data ?? [];
        
        // If no data, show empty placeholders
        if (contributionData.isEmpty) {
          return ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: 3,
            itemBuilder: (context, index) {
              // Use different gradient colors for visual appeal
              final colors = [
                [Colors.purple.withOpacity(0.3), Colors.blue.withOpacity(0.3)],
                [Colors.orange.withOpacity(0.3), Colors.pink.withOpacity(0.3)],
                [Colors.teal.withOpacity(0.3), Colors.green.withOpacity(0.3)],
              ];
              return Padding(
                padding: const EdgeInsets.only(right: 12),
                child: _buildEmptyPlaceholder(colors[index][0], colors[index][1]),
              );
            },
          );
        }
        
        // Display contributions with status
        return ListView.builder(
          scrollDirection: Axis.horizontal,
          itemCount: contributionData.length,
          itemBuilder: (context, index) {
            final item = contributionData[index];
            return Padding(
              padding: const EdgeInsets.only(right: 12),
              child: _buildContributionCard(context, project, item),
            );
          },
        );
      },
    );
  }

  // Stream that combines invitations and video clips for a unified view
  Stream<List<Map<String, dynamic>>> _combineInvitationsAndClips(String projectId) {
    final DatabaseService databaseService = DatabaseService();
    final InvitationService invitationService = InvitationService();
    
    return Rx.combineLatest2(
      invitationService.getInvitationsForProject(projectId),
      databaseService.getVideoClipsForProject(projectId),
      (QuerySnapshot invitationsSnapshot, List<VideoClip> clips) {
        final List<Map<String, dynamic>> result = [];
        
        // Process invitations
        for (var doc in invitationsSnapshot.docs) {
          final data = doc.data() as Map<String, dynamic>;
          final inviteeEmail = data['email'] as String;
          final inviteeName = data['name'] as String;
          final status = data['status'] as String;
          final invitedAt = data['invitedAt'] as Timestamp;
          final lastReminded = data['lastReminded'] as Timestamp?;
          
          // Check if this invitation already has a video contribution
          final hasContributed = clips.any((clip) => 
            clip.contributorName == inviteeName || 
            (clip.contributorId.isNotEmpty && data.containsKey('contributorId') && clip.contributorId == data['contributorId'])
          );
          
          // Only add if no contribution exists yet
          if (!hasContributed) {
            result.add({
              'type': 'invitation',
              'name': inviteeName,
              'email': inviteeEmail,
              'status': status,
              'timestamp': invitedAt,
              'lastReminded': lastReminded,
              'id': doc.id,
            });
          }
        }
        
        // Add all video clips as completed contributions
        for (var clip in clips) {
          result.add({
            'type': 'clip',
            'name': clip.contributorName,
            'contributorId': clip.contributorId,
            'timestamp': clip.createdAt,
            'videoUrl': clip.videoUrl,
            'id': clip.id,
          });
        }
        
        return result;
      }
    ).onErrorReturn([]);
  }

  // Widget for a single contribution card
  Widget _buildContributionCard(BuildContext context, Project project, Map<String, dynamic> item) {
    final isHost = FirebaseAuth.instance.currentUser?.uid == project.organizerId;
    final itemType = item['type'] as String;
    final name = item['name'] as String;
    
    if (itemType == 'clip') {
      // This is a completed contribution with a video
      return _buildCompletedContribution(context, item);
    } else {
      // This is a pending invitation
      return _buildPendingContribution(context, project, item, isHost);
    }
  }

  // Widget for an empty placeholder when no invitations exist
  Widget _buildEmptyPlaceholder(Color color1, Color color2) {
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        splashColor: Colors.white.withOpacity(0.1),
        highlightColor: Colors.white.withOpacity(0.05),
        onTap: () => _shareInvitation(context, widget.initialMoment),
        child: Container(
          width: 120,
          height: 160,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [color1, color2],
            ),
            border: Border.all(color: Colors.white.withOpacity(0.2), width: 0.5),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 10,
                spreadRadius: 2,
              ),
            ],
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.person_add_alt_rounded,
                color: Colors.white70,
                size: 36,
              ),
              const SizedBox(height: 12),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Text(
                  'Invite Someone',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.nunito(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
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
            ],
          ),
        ),
      ),
    );
  }

  // Widget for a pending contribution (invitation sent but no video yet)
  Widget _buildPendingContribution(BuildContext context, Project project, Map<String, dynamic> item, bool isHost) {
    final status = item['status'] as String;
    final name = item['name'] as String;
    final timestamp = item['timestamp'] as Timestamp;
    final lastReminded = item['lastReminded'] as Timestamp?;
    final id = item['id'] as String;
    
    // Calculate if we can send a reminder (only once per day)
    bool canRemind = isHost && (lastReminded == null || 
      DateTime.now().difference(lastReminded.toDate()).inHours >= 24);
      
    return Container(
      width: 120,
      height: 160,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.amber.withOpacity(0.3),
            Colors.orange.withOpacity(0.3),
          ],
        ),
        border: Border.all(color: Colors.white.withOpacity(0.3), width: 0.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            spreadRadius: 2,
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          splashColor: Colors.white.withOpacity(0.1),
          onTap: isHost ? () => _showInviteStatusDialog(context, item, project) : null,
          child: Stack(
            children: [
              // Status indicator at the top
              Align(
                alignment: Alignment.topCenter,
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.2),
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(16),
                      topRight: Radius.circular(16),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(right: 4),
                        child: Container(
                          width: 16,
                          height: 16,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.person,
                            color: Colors.amber.shade600,
                            size: 10,
                          ),
                        ),
                      ),
                      Text(
                        status == 'accepted' ? 'Joined' : 'Invited',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.nunito(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              
              // Content
              Padding(
                padding: const EdgeInsets.fromLTRB(8, 24, 8, 8),
                  child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                     children: [
                    // User avatar
                    CircleAvatar(
                      radius: 24,
                      backgroundColor: Colors.white.withOpacity(0.2),
                      child: Text(
                        _getInitials(name),
                        style: GoogleFonts.nunito(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    
                    // Name
                    Text(
                      name,
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.nunito(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    
                    const SizedBox(height: 4),
                    
                    // Status with icon
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.hourglass_empty,
                          size: 12,
                          color: Colors.white.withOpacity(0.8),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'Pending',
                          style: GoogleFonts.nunito(
                            color: Colors.white.withOpacity(0.8),
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              
              // Remind button for host
              if (project.organizerId == FirebaseAuth.instance.currentUser?.uid && canRemind)
                Positioned(
                  bottom: 8,
                  right: 8,
                  child: Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white.withOpacity(0.2),
                    ),
                    child: IconButton(
                      padding: EdgeInsets.zero,
                      icon: Icon(
                        Icons.notifications_none,
                        size: 16,
                        color: Colors.white,
                      ),
                      onPressed: () => _sendReminder(context, project, item),
                      tooltip: 'Send Reminder',
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  // Widget for a completed contribution with a video
  Widget _buildCompletedContribution(BuildContext context, Map<String, dynamic> item) {
    final name = item['name'] as String;
    final videoUrl = item['videoUrl'] as String;
    final timestamp = item['timestamp'] as Timestamp;
    final contributorId = item['contributorId'] as String;
    
    // Check if this contributor is the host
    final bool isHost = widget.initialMoment.organizerId == contributorId;
    
    return Container(
      width: 120,
      height: 160,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isHost ? [
            Colors.amber.withOpacity(0.5),
            Colors.orange.withOpacity(0.5),
          ] : [
            Colors.blue.withOpacity(0.4),
            Colors.purple.withOpacity(0.4),
          ],
        ),
        border: Border.all(
          color: isHost ? Colors.amber.withOpacity(0.5) : Colors.white.withOpacity(0.3), 
          width: isHost ? 1.0 : 0.5
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            spreadRadius: 2,
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          splashColor: Colors.white.withOpacity(0.1),
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => VideoPlayerScreen(
                  videoUrl: videoUrl,
                  contributorName: name,
                ),
              ),
            );
          },
          child: Stack(
            children: [
              // Status indicator at the top
              Align(
                alignment: Alignment.topCenter,
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  decoration: BoxDecoration(
                    color: isHost ? Colors.amber.withOpacity(0.4) : Colors.green.withOpacity(0.3),
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(16),
                      topRight: Radius.circular(16),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      if (isHost)
                        Padding(
                          padding: const EdgeInsets.only(right: 4),
                          child: Container(
                            width: 16,
                            height: 16,
                            decoration: BoxDecoration(
                              color: Colors.white,
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              Icons.workspace_premium,
                              color: Colors.amber.shade600,
                              size: 10,
                            ),
                          ),
                        ),
                      Text(
                        isHost ? 'Host' : 'Completed',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.nunito(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              
              // Content
              Padding(
                padding: const EdgeInsets.fromLTRB(8, 24, 8, 8),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // User avatar
                    CircleAvatar(
                      radius: 24,
                      backgroundColor: isHost 
                          ? Colors.amber.withOpacity(0.3)
                          : Colors.white.withOpacity(0.2),
                      child: Text(
                        _getInitials(name),
                        style: GoogleFonts.nunito(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    
                    // Name
                    Text(
                      name,
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.nunito(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    
                    const SizedBox(height: 4),
                    
                    // Added date with check icon
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.check_circle,
                          size: 12,
                          color: isHost ? Colors.amber.withOpacity(0.8) : Colors.green.withOpacity(0.8),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          _formatDate(timestamp),
                          style: GoogleFonts.nunito(
                            color: Colors.white.withOpacity(0.8),
                            fontSize: 10,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              
              // Play indicator
             Center(
                child: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.black.withOpacity(0.3),
                  ),
                  child: const Icon(
                    Icons.play_arrow,
                    color: Colors.white,
                    size: 24,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Helper method to send a reminder to invited participants
  Future<void> _sendReminder(BuildContext context, Project project, Map<String, dynamic> invitation) async {
    try {
      final invitationService = InvitationService();
      await invitationService.sendReminder(
        projectId: project.id,
        invitationId: invitation['id'],
        recipientName: invitation['name'],
        recipientEmail: invitation['email'],
      );
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Reminder sent to ${invitation['name']}'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to send reminder: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // Show detailed status dialog for an invitation
  void _showInviteStatusDialog(BuildContext context, Map<String, dynamic> invitation, Project project) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.grey[900],
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          'Invitation Status',
          style: GoogleFonts.nunito(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildStatusRow('Name', invitation['name']),
              _buildStatusRow('Email', invitation['email']),
              _buildStatusRow('Status', invitation['status']),
              _buildStatusRow('Invited On', _formatDateTime(invitation['timestamp'])),
              if (invitation['lastReminded'] != null)
                _buildStatusRow('Last Reminded', _formatDateTime(invitation['lastReminded'])),
            ],
          ),
        ),
        actions: [
          TextButton(
            child: Text(
              'Cancel',
              style: GoogleFonts.nunito(color: Colors.white70),
            ),
            onPressed: () => Navigator.of(context).pop(),
          ),
          TextButton(
            child: Text(
              'Send Reminder',
              style: GoogleFonts.nunito(color: Colors.blue),
            ),
            onPressed: () {
              Navigator.of(context).pop();
              _sendReminder(context, project, invitation);
            },
          ),
        ],
      ),
    );
  }

  // Helper for status dialog rows
  Widget _buildStatusRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              '$label:',
              style: GoogleFonts.nunito(
                fontWeight: FontWeight.bold,
                color: Colors.white70,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: GoogleFonts.nunito(color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  // Format date from timestamp
  String _formatDate(Timestamp timestamp) {
    final date = timestamp.toDate();
    return DateFormat.MMMd().format(date);
  }

  // Format date and time from timestamp
  String _formatDateTime(Timestamp timestamp) {
    final date = timestamp.toDate();
    return DateFormat.yMMMd().add_jm().format(date);
  }

  // Helper to handle delivery completion
  Future<void> _handleDeliveryComplete(BuildContext context, Project project) async {
    if (project.isDelivered == true) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('This moment has already been delivered.')),
      );
      return;
    }
    
    if (project.compiledVideoUrl == null || project.compiledVideoUrl!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please compile a video before delivering.'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }
    
    setState(() => _isLoading = true);
    
    try {
      final success = await _deliveryService.deliverProject(context, project);
      
      if (success && mounted) {
        // Show celebration dialog
        await _deliveryService.showDeliveryCelebration(context, project);
      }
    } catch (e) {
      print('Error during delivery: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Delivery error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  // Helper to change the delivery date
  Future<void> _changeDeliveryDate(BuildContext context, Project project, ScaffoldMessengerState scaffoldMessenger) async {
    final DateTime initialDate = project.deliveryDate?.toDate() ?? 
                            DateTime.now().add(const Duration(days: 1));
    
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365 * 2)),
    );
    
    if (picked != null && mounted) {
      setState(() => _isLoading = true);
      
      try {
        final success = await _deliveryService.updateDeliveryDate(project.id, picked);
        
        if (success && mounted) {
          scaffoldMessenger.showSnackBar(
            const SnackBar(
              content: Text('Delivery date updated!'),
              backgroundColor: Colors.green,
            ),
          );
        } else if (mounted) {
          scaffoldMessenger.showSnackBar(
            const SnackBar(
              content: Text('Failed to update delivery date.'),
              backgroundColor: Colors.red,
            ),
          );
        }
      } catch (e) {
        print('Error updating delivery date: $e');
        if (mounted) {
          scaffoldMessenger.showSnackBar(
            SnackBar(
              content: Text('Error: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      } finally {
        if (mounted) {
          setState(() => _isLoading = false);
        }
      }
    }
  }
} 