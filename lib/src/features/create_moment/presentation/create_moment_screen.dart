import 'dart:io'; // Import dart:io
import 'dart:ui' as ui;
import 'dart:math' show sin, pi;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart'; // Import Timestamp
import 'package:image_picker/image_picker.dart'; // Import ImagePicker
import 'package:palette_generator/palette_generator.dart'; // Import PaletteGenerator
import 'package:intl/intl.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter/services.dart';

import '../../../services/auth_service.dart';
import '../../../services/database_service.dart';
import '../../../services/storage_service.dart'; // Import StorageService
import 'package:firebase_auth/firebase_auth.dart';
// Import intl for date formatting if desired
// import 'package:intl/intl.dart';

// Define Enum for Occasion
enum Occasion { mothersDay, fathersDay, birthday, holiday, other }

class CreateMomentScreen extends StatefulWidget {
  const CreateMomentScreen({super.key});

  @override
  State<CreateMomentScreen> createState() => _CreateMomentScreenState();
}

class _CreateMomentScreenState extends State<CreateMomentScreen> with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  DateTime? _selectedDeliveryDate;
  bool _isLoading = false;
  File? _selectedCoverImageFile; // State for selected image file
  
  // Animation controllers
  late AnimationController _animationController;
  late Animation<double> _pulseAnimation;
  late Animation<double> _fadeAnimation;
  
  // Tracks whether user has interacted with inputs for selective guidance
  bool _hasInteractedWithCover = false;
  bool _hasInteractedWithTitle = false;
  
  // State for Occasion selection
  Occasion _selectedOccasion = Occasion.mothersDay; // Default to Mother's Day

  @override
  void initState() {
    super.initState();
    
    // Setup animations
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat(reverse: true);
    
    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.05).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: Curves.easeInOut,
      ),
    );
    
    _fadeAnimation = Tween<double>(begin: 0.7, end: 1.0).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: Curves.easeInOut,
      ),
    );
  }

  @override
  void dispose() {
    _animationController.dispose();
    _titleController.dispose();
    super.dispose();
  }

  // --- Image Picker and Helpers --- 

  Future<ImageSource?> _showImageSourceDialog(BuildContext context) async {
    HapticFeedback.mediumImpact();
    return showDialog<ImageSource>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.grey.shade900,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Select Image Source', 
          style: GoogleFonts.nunito(
            color: Colors.white, 
            fontWeight: FontWeight.bold
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Choose where to get your cover image from:',
              style: GoogleFonts.nunito(color: Colors.white70),
            ),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildSourceOption(
                  context: context,
                  source: ImageSource.camera,
                  icon: Icons.camera_alt,
                  label: 'Camera',
                  color: Colors.blue.shade300,
                ),
                _buildSourceOption(
                  context: context,
                  source: ImageSource.gallery,
                  icon: Icons.photo_library,
                  label: 'Gallery',
                  color: Colors.purple.shade300,
                ),
              ],
            ),
          ],
        ),
        actions: [
          TextButton(
            child: Text('Cancel', 
              style: GoogleFonts.nunito(
                color: Colors.grey,
                fontWeight: FontWeight.w600,
              ),
            ),
            onPressed: () => Navigator.pop(context, null),
          ),
        ],
      ),
    );
  }
  
  Widget _buildSourceOption({
    required BuildContext context,
    required ImageSource source,
    required IconData icon,
    required String label,
    required Color color,
  }) {
    return InkWell(
      onTap: () => Navigator.pop(context, source),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: color.withOpacity(0.15),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 36),
            const SizedBox(height: 8),
            Text(label, style: GoogleFonts.nunito(color: Colors.white)),
          ],
        ),
      ),
    );
  }

  Future<void> _pickCoverImage() async {
    if (_isLoading) return;
    setState(() => _hasInteractedWithCover = true);
    
    final ImageSource? source = await _showImageSourceDialog(context);
    if (source == null) return;

    final imagePicker = ImagePicker();
    try {
      final XFile? pickedFile = await imagePicker.pickImage(source: source);
      if (pickedFile != null) {
        setState(() {
          _selectedCoverImageFile = File(pickedFile.path);
        });
        
        // Give feedback
        HapticFeedback.lightImpact();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text("Cover image added! Looks great!"),
              backgroundColor: Colors.green.shade700,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            )
          );
        }
      }
    } catch (e) {
      print("Error picking image: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Error selecting image - please try again"),
            backgroundColor: Colors.red.shade700,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          )
        );
      }
    }
  }

  String _colorToHex(Color color) {
    return '#${color.value.toRadixString(16).padLeft(8, '0').toUpperCase()}';
  }

  Future<List<String?>> _precomputeGradientHex(File imageFile) async {
     try {
       final PaletteGenerator palette = await PaletteGenerator.fromImageProvider(
         FileImage(imageFile), 
         maximumColorCount: 16,
       );
       Color topColor = palette.darkVibrantColor?.color ?? palette.darkMutedColor?.color ?? Colors.black;
       Color middleColor = palette.vibrantColor?.color ?? palette.lightVibrantColor?.color ?? palette.dominantColor?.color ?? const Color(0xFF333333);
       Color bottomColor = palette.darkMutedColor?.color ?? palette.dominantColor?.color.withAlpha(200) ?? const Color(0xFF1A1A1A);
       if (topColor == middleColor) { middleColor = palette.lightMutedColor?.color ?? palette.dominantColor?.color ?? middleColor; }
       if (topColor == bottomColor || middleColor == bottomColor) { bottomColor = topColor == Colors.black ? const Color(0xFF111111) : Colors.black; }
       if (topColor == middleColor && middleColor == bottomColor) { middleColor = middleColor.withAlpha(200); bottomColor = middleColor.withAlpha(150); }
       return [_colorToHex(topColor), _colorToHex(middleColor), _colorToHex(bottomColor)];
     } catch (e, stackTrace) {
        print('[Precompute] ERROR generating palette from file: $e\n$stackTrace');
        return [null, null, null];
     }
  }

  // --- Date Picker --- 
  Future<void> _selectDeliveryDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDeliveryDate ?? DateTime.now().add(const Duration(days: 1)),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365 * 2)),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.dark(
              primary: Colors.purple.shade300,
              onPrimary: Colors.white,
              onSurface: Colors.white,
              surface: Colors.grey.shade900,
            ),
            dialogBackgroundColor: Colors.grey.shade900,
            textButtonTheme: TextButtonThemeData(
              style: TextButton.styleFrom(
                foregroundColor: Colors.white,
              ),
            ),
          ), 
          child: child!,
        );
      },
    );
    if (picked != null && picked != _selectedDeliveryDate) {
      setState(() {
        _selectedDeliveryDate = picked;
      });
      
      // Give feedback when date is selected
      HapticFeedback.lightImpact();
    }
  }

  // --- Moment Creation Logic --- 
  Future<void> _createMoment() async {
      if (!(_formKey.currentState?.validate() ?? false)) {
        // Give error feedback
        HapticFeedback.heavyImpact();
        return;
      }
      
      // Give success feedback
      HapticFeedback.mediumImpact();
      
      setState(() { _isLoading = true; });

      final User? user = context.read<AuthService>().currentUser;
      final DatabaseService dbService = context.read<DatabaseService>();
      final StorageService storageService = context.read<StorageService>();

      if (user == null) {
          if (mounted) {
             ScaffoldMessenger.of(context).showSnackBar(
                 const SnackBar(content: Text('Error: Not logged in.')),
             );
             setState(() { _isLoading = false; });
          }
          return;
      }

      final title = _titleController.text.trim();
      final organizerName = user.displayName ?? user.email ?? 'Unknown User';
      String? coverImageUrl;
      List<String?> gradientHex = [null, null, null];
      String? tempProjectId;

      try {
        // --- Handle Image Upload and Gradient Pre-computation FIRST --- 
        if (_selectedCoverImageFile != null) {
           print('Selected cover image found. Generating temp ID and uploading...');
           // Generate a temporary ID for storage path
           tempProjectId = dbService.projectsCollection.doc().id;
           print('Temporary Project ID for storage: $tempProjectId');

           // Precompute gradient
           gradientHex = await _precomputeGradientHex(_selectedCoverImageFile!);

           // Upload image
           coverImageUrl = await storageService.uploadCoverImage(tempProjectId, _selectedCoverImageFile!);
           
           if (coverImageUrl == null) {
              throw Exception("Cover image upload failed.");
           }
           print('Image uploaded and gradient precomputed.');
        }

        // --- Create Project Document in Firestore --- 
        await dbService.createProject(
            projectId: tempProjectId,
            title: title,
            organizerId: user.uid,
            organizerName: organizerName,
            deliveryDate: _selectedDeliveryDate != null 
                            ? Timestamp.fromDate(_selectedDeliveryDate!)
                            : null,
            coverImageUrl: coverImageUrl, 
            gradientColorHex1: gradientHex[0],
            gradientColorHex2: gradientHex[1],
            gradientColorHex3: gradientHex[2],
            occasion: _selectedOccasion.name,
        );
        
        if (!mounted) return;
        
        // Show success animation/feedback
        _showSuccessAnimation();
        
      } catch (e) {
         print("Error creating moment: $e");
         if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Failed to create moment: $e'), 
                backgroundColor: Colors.red.shade700,
                behavior: SnackBarBehavior.floating,
              ),
            );
            setState(() { _isLoading = false; });
         }
      }
  }
  
  void _showSuccessAnimation() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        elevation: 0,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.green.shade600,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.2),
                    blurRadius: 10,
                    spreadRadius: 2,
                  ),
                ],
              ),
              child: Column(
                children: [
                  const Icon(Icons.check_circle, color: Colors.white, size: 60),
                  const SizedBox(height: 16),
                  Text(
                    'Moment Created!',
                    style: GoogleFonts.nunito(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Your moment is ready to be shared.',
                    style: GoogleFonts.nunito(
                      color: Colors.white.withOpacity(0.9),
                      fontSize: 16,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
    
    // Delay a bit to show the success animation before returning
    Future.delayed(const Duration(milliseconds: 1200), () {
      if (mounted) {
        Navigator.of(context).pop(); // Close success dialog
        Navigator.of(context).pop(); // Return to previous screen
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;

    // Define an animated gradient for better visual appeal
    final screenGradient = LinearGradient(
      colors: [
        Colors.pink.shade400,
        Colors.purple.shade600,
        Colors.blue.shade800,
      ],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    );

    return Container(
      decoration: BoxDecoration(gradient: screenGradient),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        extendBodyBehindAppBar: true,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: IconButton(
            icon: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.black.withOpacity(0.2),
                border: Border.all(color: Colors.white.withOpacity(0.3)),
              ),
              child: const Icon(Icons.close, color: Colors.white, size: 20),
            ),
            tooltip: 'Cancel',
            onPressed: () {
              HapticFeedback.lightImpact();
              Navigator.of(context).pop();
            },
          ),
        ),
        body: Stack(
          children: [
            // Add subtle animated background pattern
            Positioned.fill(
              child: CustomPaint(
                painter: PatternPainter(
                  animationValue: _animationController.value,
                ),
              ),
            ),
            
            // Main content
            SafeArea(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20.0),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const SizedBox(height: 20),
                      
                      // Improved image upload area
                      _buildCoverImageSelector(),
                      
                      const SizedBox(height: 40),
                      
                      // Enhanced section for title, date, and occasion
                      _buildDetailsSection(context),
                      
                      const SizedBox(height: 40),
                      
                      // Enhanced save button
                      _buildSaveButton(),
                    ],
                  ),
                ),
              ),
            ),
            
            // Loading overlay
            if (_isLoading)
              Positioned.fill(
                child: Container(
                  color: Colors.black54,
                  child: Center(
                    child: Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.black87,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 3,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'Creating your moment...',
                            style: GoogleFonts.nunito(
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
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
  
  Widget _buildCoverImageSelector() {
    return AnimatedBuilder(
      animation: _animationController,
      builder: (context, child) {
        return Transform.scale(
          scale: _selectedCoverImageFile == null ? _pulseAnimation.value : 1.0,
          child: GestureDetector(
            onTap: _isLoading ? null : _pickCoverImage,
            child: Stack(
              alignment: Alignment.center,
              children: [
                // Main container with image or placeholder
                Container(
                  height: 200,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: _selectedCoverImageFile == null
                          ? Colors.white.withOpacity(_fadeAnimation.value * 0.3)
                          : Colors.white.withOpacity(0.3),
                      width: 1,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.2),
                        blurRadius: 15,
                        spreadRadius: 2,
                      ),
                    ],
                    image: _selectedCoverImageFile != null
                        ? DecorationImage(
                            image: FileImage(_selectedCoverImageFile!),
                            fit: BoxFit.cover,
                          )
                        : null,
                  ),
                  // Only show placeholder content if no image
                  child: _selectedCoverImageFile == null
                      ? Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: Colors.white.withOpacity(0.15),
                                border: Border.all(
                                  color: Colors.white.withOpacity(0.3),
                                ),
                              ),
                              child: Icon(
                                Icons.add_photo_alternate,
                                size: 40,
                                color: Colors.white.withOpacity(_fadeAnimation.value),
                              ),
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'Add Cover Image',
                              style: GoogleFonts.nunito(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            if (!_hasInteractedWithCover)
                              Padding(
                                padding: const EdgeInsets.only(top: 8),
                                child: Text(
                                  'A beautiful cover helps your moment stand out',
                                  style: GoogleFonts.nunito(
                                    color: Colors.white70,
                                    fontSize: 14,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ),
                          ],
                        )
                      : null,
                ),
                
                // Overlay for selected image (edit button)
                if (_selectedCoverImageFile != null)
                  Positioned(
                    bottom: 12,
                    right: 12,
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.6),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.edit,
                        color: Colors.white,
                        size: 20,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
  
  Widget _buildDetailsSection(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    
    return Container(
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.25),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: Colors.white.withOpacity(0.1),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.15),
            blurRadius: 20,
            spreadRadius: 1,
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: BackdropFilter(
          filter: ui.ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Title field with enhanced styling
                TextFormField(
                  controller: _titleController,
                  style: GoogleFonts.playfairDisplay(
                    color: Colors.white,
                    fontSize: 28,
                    fontWeight: FontWeight.w500,
                  ),
                  decoration: InputDecoration(
                    hintText: 'Moment Title',
                    hintStyle: GoogleFonts.playfairDisplay(
                      color: Colors.white.withOpacity(0.5),
                      fontSize: 28,
                      fontWeight: FontWeight.w500,
                    ),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    filled: true,
                    fillColor: Colors.black.withOpacity(0.2),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: Colors.white.withOpacity(0.2)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: Colors.white.withOpacity(0.4), width: 2),
                    ),
                    errorBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: Colors.red.shade300),
                    ),
                    focusedErrorBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: Colors.red.shade300, width: 2),
                    ),
                    errorStyle: GoogleFonts.nunito(
                      color: Colors.red.shade300,
                      fontSize: 12,
                    ),
                  ),
                  onChanged: (value) {
                    if (!_hasInteractedWithTitle && value.isNotEmpty) {
                      setState(() => _hasInteractedWithTitle = true);
                    }
                  },
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Please enter a title for your moment';
                    }
                    return null;
                  },
                ),
                
                if (!_hasInteractedWithTitle)
                  Padding(
                    padding: const EdgeInsets.only(top: 8, bottom: 12, left: 16),
                    child: Text(
                      'Give your moment a meaningful title',
                      style: GoogleFonts.nunito(
                        color: Colors.white70,
                        fontSize: 14,
                      ),
                    ),
                  ),
                  
                const Divider(color: Colors.white24, height: 24),
                
                // Date selector with enhanced styling
                GestureDetector(
                  onTap: _selectDeliveryDate,
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: _selectedDeliveryDate == null
                                ? Colors.white.withOpacity(0.1)
                                : Colors.green.withOpacity(0.2),
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: _selectedDeliveryDate == null
                                  ? Colors.white.withOpacity(0.3)
                                  : Colors.green.shade300.withOpacity(0.7),
                            ),
                          ),
                          child: Icon(
                            _selectedDeliveryDate == null
                                ? Icons.calendar_today_outlined
                                : Icons.event_available,
                            color: _selectedDeliveryDate == null
                                ? Colors.white70
                                : Colors.green.shade300,
                            size: 22,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _selectedDeliveryDate == null
                                    ? 'Schedule Delivery (Optional)'
                                    : 'Deliver on: ${DateFormat.yMMMMd().format(_selectedDeliveryDate!)}',
                                style: GoogleFonts.nunito(
                                  color: _selectedDeliveryDate == null
                                      ? Colors.white
                                      : Colors.green.shade300,
                                  fontSize: 16,
                                  fontWeight: _selectedDeliveryDate == null
                                      ? FontWeight.w500
                                      : FontWeight.bold,
                                ),
                              ),
                              if (_selectedDeliveryDate != null)
                                Text(
                                  'The moment will be delivered automatically',
                                  style: GoogleFonts.nunito(
                                    color: Colors.white70,
                                    fontSize: 14,
                                  ),
                                ),
                            ],
                          ),
                        ),
                        if (_selectedDeliveryDate != null)
                          IconButton(
                            icon: const Icon(Icons.close, color: Colors.white60, size: 18),
                            onPressed: () => setState(() => _selectedDeliveryDate = null),
                            tooltip: 'Clear delivery date',
                          ),
                      ],
                    ),
                  ),
                ),
                
                const Divider(color: Colors.white24, height: 24),
                
                // Occasion selector with enhanced styling
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Occasion',
                      style: GoogleFonts.nunito(
                        color: Colors.white70,
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: Wrap(
                        spacing: 12,
                        runSpacing: 12,
                        alignment: WrapAlignment.center,
                        children: [
                          _buildOccasionChip(
                            occasion: Occasion.mothersDay,
                            label: "Mother's Day",
                            icon: Icons.favorite,
                            color: Colors.pink.shade300,
                          ),
                          _buildOccasionChip(
                            occasion: Occasion.fathersDay,
                            label: "Father's Day",
                            icon: Icons.sports,
                            color: Colors.blue.shade300,
                          ),
                          _buildOccasionChip(
                            occasion: Occasion.birthday,
                            label: "Birthday",
                            icon: Icons.cake,
                            color: Colors.amber.shade300,
                          ),
                          _buildOccasionChip(
                            occasion: Occasion.holiday,
                            label: "Holiday",
                            icon: Icons.celebration,
                            color: Colors.green.shade300,
                          ),
                          _buildOccasionChip(
                            occasion: Occasion.other,
                            label: "Other",
                            icon: Icons.lightbulb_outline,
                            color: Colors.purple.shade300,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
  
  Widget _buildOccasionChip({
    required Occasion occasion,
    required String label,
    required IconData icon,
    required Color color,
  }) {
    final bool isSelected = _selectedOccasion == occasion;
    
    return GestureDetector(
      onTap: () {
        if (_isLoading) return;
        HapticFeedback.selectionClick();
        setState(() => _selectedOccasion = occasion);
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? color.withOpacity(0.3) : Colors.white.withOpacity(0.1),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? color : Colors.white.withOpacity(0.3),
            width: isSelected ? 2 : 1,
          ),
          boxShadow: isSelected ? [
            BoxShadow(
              color: color.withOpacity(0.3),
              blurRadius: 8,
              spreadRadius: 1,
            ),
          ] : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              color: isSelected ? color : Colors.white70,
              size: 18,
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: GoogleFonts.nunito(
                color: isSelected ? Colors.white : Colors.white70,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildSaveButton() {
    return AnimatedBuilder(
      animation: _animationController,
      builder: (context, child) {
        final bool canSave = _titleController.text.isNotEmpty;
        
        return GestureDetector(
          onTap: canSave && !_isLoading ? _createMoment : null,
          child: Container(
            height: 60,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Colors.purple.shade400,
                  Colors.blue.shade400,
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(30),
              boxShadow: [
                BoxShadow(
                  color: Colors.purple.withOpacity(0.3),
                  blurRadius: 12,
                  spreadRadius: 2,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Center(
              child: Text(
                'Save Moment',
                style: GoogleFonts.nunito(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.5,
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  // Helper to build section cards with consistent styling
  Widget _buildSectionCard({required BuildContext context, required List<Widget> children}) {
     return Card(
       color: Colors.white.withOpacity(0.15),
       shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
       elevation: 0,
       child: Padding(
         padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
         child: Column(
           crossAxisAlignment: CrossAxisAlignment.start,
           children: children,
         ),
       ),
     );
  }
}

// Custom painter for background pattern
class PatternPainter extends CustomPainter {
  final double animationValue;
  
  PatternPainter({required this.animationValue});
  
  @override
  void paint(Canvas canvas, Size size) {
    final double width = size.width;
    final double height = size.height;
    
    // Draw subtle dotted pattern
    final Paint dotPaint = Paint()
      ..color = Colors.white.withOpacity(0.05 + 0.03 * animationValue)
      ..style = PaintingStyle.fill;
      
    const double spacing = 30;
    const double dotSize = 2;
    
    for (double x = 0; x < width; x += spacing) {
      for (double y = 0; y < height; y += spacing) {
        // Add some variation with animation
        final double offset = 3 * sin((x + y) / 100 + animationValue * 2 * pi);
        canvas.drawCircle(
          Offset(x + offset, y + offset),
          dotSize,
          dotPaint,
        );
      }
    }
  }
  
  @override
  bool shouldRepaint(PatternPainter oldDelegate) {
    return oldDelegate.animationValue != animationValue;
  }
} 