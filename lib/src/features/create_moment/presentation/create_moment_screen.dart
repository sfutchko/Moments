import 'dart:io'; // Import dart:io

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart'; // Import Timestamp
import 'package:image_picker/image_picker.dart'; // Import ImagePicker
import 'package:palette_generator/palette_generator.dart'; // Import PaletteGenerator
import 'package:intl/intl.dart';

import '../../../services/auth_service.dart';
import '../../../services/database_service.dart';
import '../../../services/storage_service.dart'; // Import StorageService
import 'package:firebase_auth/firebase_auth.dart';
// Import intl for date formatting if desired
// import 'package:intl/intl.dart';

// Define Enum for Occasion
enum Occasion { mothersDay, fathersDay }

class CreateMomentScreen extends StatefulWidget {
  const CreateMomentScreen({super.key});

  @override
  State<CreateMomentScreen> createState() => _CreateMomentScreenState();
}

class _CreateMomentScreenState extends State<CreateMomentScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  DateTime? _selectedDeliveryDate;
  bool _isLoading = false;
  File? _selectedCoverImageFile; // State for selected image file
  
  // State for Occasion selection
  Occasion _selectedOccasion = Occasion.mothersDay; // Default to Mother's Day

  @override
  void dispose() {
    _titleController.dispose();
    super.dispose();
  }

  // --- Image Picker and Helpers --- 

  Future<ImageSource?> _showImageSourceDialog(BuildContext context) async {
    // ... (Same dialog logic as in MomentDetailScreen) ...
    return showDialog<ImageSource>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Select Image Source'),
        content: const Text('Choose where to get the image from:'),
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
            child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
            onPressed: () => Navigator.pop(context, null),
          ),
        ],
      ),
    );
  }

  Future<void> _pickCoverImage() async {
    if (_isLoading) return;
    final ImageSource? source = await _showImageSourceDialog(context);
    if (source == null) return;

    final imagePicker = ImagePicker();
    try {
      final XFile? pickedFile = await imagePicker.pickImage(source: source);
      if (pickedFile != null) {
        setState(() {
          _selectedCoverImageFile = File(pickedFile.path);
        });
      }
    } catch (e) {
      print("Error picking image: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error picking image: $e"), backgroundColor: Colors.red)
      );
    }
  }

  String _colorToHex(Color color) {
    return '#${color.value.toRadixString(16).padLeft(8, '0').toUpperCase()}';
  }

  Future<List<String?>> _precomputeGradientHex(File imageFile) async {
     // ... (Same precompute logic as in MomentDetailScreen) ...
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
      initialDate: _selectedDeliveryDate ?? DateTime.now().add(const Duration(days: 1)), // Start tomorrow or selected
      firstDate: DateTime.now(), // Can't schedule in the past
      lastDate: DateTime.now().add(const Duration(days: 365 * 2)), // Allow scheduling up to 2 years ahead
      // Customize date picker theme to match app style
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
    }
  }

  // --- Moment Creation Logic --- 
  Future<void> _createMoment() async {
      if (!(_formKey.currentState?.validate() ?? false)) return;
      setState(() { _isLoading = true; });

      final User? user = context.read<AuthService>().currentUser;
      final DatabaseService dbService = context.read<DatabaseService>();
      final StorageService storageService = context.read<StorageService>(); // Get StorageService

      if (user == null) {
          // Handle not logged in
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
      String? coverImageUrl; // To store URL if image is uploaded
      List<String?> gradientHex = [null, null, null]; // To store hex strings
      String? tempProjectId; // Temporary ID if we need to upload image first

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
              throw Exception("Cover image upload failed."); // Throw error to stop creation
           }
           print('Image uploaded and gradient precomputed.');
        }

        // --- Create Project Document in Firestore --- 
        await dbService.createProject(
            projectId: tempProjectId, // Pass temp ID if generated, otherwise Firestore creates one
            title: title,
            organizerId: user.uid,
            organizerName: organizerName,
            deliveryDate: _selectedDeliveryDate != null 
                            ? Timestamp.fromDate(_selectedDeliveryDate!)
                            : null,
            // Include image URL and gradient hex strings
            coverImageUrl: coverImageUrl, 
            gradientColorHex1: gradientHex[0],
            gradientColorHex2: gradientHex[1],
            gradientColorHex3: gradientHex[2],
            // Pass the selected occasion as a string
            occasion: _selectedOccasion.name, // e.g., "mothersDay" or "fathersDay"
        );
        
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
           const SnackBar(content: Text('Moment created!'))
        );
        Navigator.of(context).pop(); 

      } catch (e) {
         print("Error creating moment: $e");
         if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Failed to create moment: $e'), backgroundColor: Colors.red),
            );
      }
      } finally {
         if (mounted) {
      setState(() { _isLoading = false; });
         }
      }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    // Define the gradient here to reuse it
    final screenGradient = LinearGradient(
        colors: [
          Colors.pink.shade300,
          theme.primaryColor,
          Colors.blue.shade800,
        ],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      );

    return Container( // Wrap Scaffold in the Gradient Container
      decoration: BoxDecoration(gradient: screenGradient),
      child: Scaffold(
        backgroundColor: Colors.transparent, // Make scaffold background transparent
        extendBodyBehindAppBar: true,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.close, color: Colors.white), // Ensure icon is visible
            tooltip: 'Cancel',
            onPressed: () => Navigator.of(context).pop(),
          ),
          actions: [
            TextButton(
              onPressed: () {
                 print('Preview Tapped - Not Implemented');
              },
              // Ensure text contrast on gradient
              child: Text('Preview', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20.0),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                   const SizedBox(height: kToolbarHeight / 2), // Adjust top spacing
                  // --- UPDATED Cover Style Section --- 
                  Center(
                     child: InkWell(
                       onTap: _isLoading ? null : _pickCoverImage,
                       child: Container(
                         height: 150, // Adjust size as needed
                         width: 150,
                         decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.white.withOpacity(0.2)),
                            image: _selectedCoverImageFile != null 
                                 ? DecorationImage( // Show preview
                                     image: FileImage(_selectedCoverImageFile!),
                                     fit: BoxFit.cover,
                                   )
                                 : null, // No image if null
                         ),
                         child: _selectedCoverImageFile == null 
                             ? Column( // Placeholder if no image selected
                                  mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                                     Icon(Icons.add_photo_alternate_outlined, size: 40, color: Colors.white.withOpacity(0.7)),
                         const SizedBox(height: 8),
                                     Text('Add Cover Image', style: TextStyle(color: Colors.white.withOpacity(0.9)))
                      ],
                                )
                              : null, // Show nothing over the preview
                       )
                     )
                  ),
                   const SizedBox(height: 40),
                  // --- Section Card for Title/Date/Occasion --- 
                  _buildSectionCard(
                     context: context,
                     children: [
                       TextFormField(
                         controller: _titleController,
                         style: theme.textTheme.headlineSmall?.copyWith(color: Colors.white, fontWeight: FontWeight.bold),
                         decoration: InputDecoration(
                            hintText: 'Moment Title',
                            hintStyle: theme.textTheme.headlineSmall?.copyWith(color: Colors.white.withOpacity(0.5)),
                            border: InputBorder.none,
                            filled: false, 
                         ),
                         validator: (value) {
                           if (value == null || value.trim().isEmpty) {
                             return 'Please enter a moment title';
                           }
                           return null;
                         },
                       ),
                       const Divider(color: Colors.white24, height: 1),
                       ListTile(
                          leading: Icon(
                            _selectedDeliveryDate == null 
                              ? Icons.calendar_today_outlined 
                              : Icons.event_available,
                            color: _selectedDeliveryDate == null ? Colors.white70 : Colors.green.shade300,
                          ),
                          title: Text(
                            _selectedDeliveryDate == null 
                              ? 'Schedule Delivery (Optional)' 
                              : 'Deliver on: ${DateFormat.yMMMMd().format(_selectedDeliveryDate!)}',
                            style: theme.textTheme.bodyLarge?.copyWith(
                              color: _selectedDeliveryDate == null ? Colors.white : Colors.green.shade300,
                              fontWeight: _selectedDeliveryDate == null ? FontWeight.normal : FontWeight.bold,
                            ),
                          ),
                          subtitle: _selectedDeliveryDate == null 
                            ? null
                            : Text(
                              'The moment will be delivered automatically on this date',
                              style: theme.textTheme.bodySmall?.copyWith(color: Colors.white70),
                            ),
                          onTap: _selectDeliveryDate,
                          contentPadding: EdgeInsets.zero,
                          trailing: _selectedDeliveryDate == null
                            ? null
                            : IconButton(
                                icon: Icon(Icons.close, color: Colors.white60, size: 18),
                                onPressed: () => setState(() => _selectedDeliveryDate = null),
                                tooltip: 'Clear delivery date',
                              ),
                       ),
                       const Divider(color: Colors.white24, height: 1),
                       // --- Occasion Selector --- 
                       Padding(
                         padding: const EdgeInsets.symmetric(vertical: 12.0),
                         child: Center(
                           child: ToggleButtons(
                             isSelected: [
                               _selectedOccasion == Occasion.mothersDay,
                               _selectedOccasion == Occasion.fathersDay,
                             ],
                             onPressed: (int index) {
                               if (_isLoading) return;
                               setState(() {
                                 _selectedOccasion = Occasion.values[index];
                               });
                             },
                             // Styling to match the theme
                             borderRadius: BorderRadius.circular(20.0),
                             borderWidth: 1,
                             borderColor: Colors.white.withOpacity(0.3),
                             selectedBorderColor: Colors.white.withOpacity(0.8),
                             color: Colors.white.withOpacity(0.7), // Color for unselected text/icon
                             selectedColor: Colors.white, // Color for selected text/icon
                             fillColor: Colors.white.withOpacity(0.25), // Background of selected button
                             splashColor: theme.primaryColor.withOpacity(0.12),
                             constraints: const BoxConstraints(minHeight: 40.0, minWidth: 120.0), // Adjust size
                             children: const <Widget>[
                                Padding(
                                   padding: EdgeInsets.symmetric(horizontal: 16.0),
                                   child: Text("Mother's Day"),
                                ),
                                Padding(
                                   padding: EdgeInsets.symmetric(horizontal: 16.0),
                                   child: Text("Father's Day"),
                                ),
                             ],
                           ),
                         ),
                       ),
                     ]
                  ),
                   const SizedBox(height: 30),
                  // --- Create Button --- 
                  _isLoading
                    ? const Center(child: CircularProgressIndicator(color: Colors.white))
                    : ElevatedButton(
                        onPressed: _createMoment,
                        child: const Text('Save Moment'),
                        // Uses theme style
                      ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // Helper to build section cards with consistent styling
  Widget _buildSectionCard({required BuildContext context, required List<Widget> children}) {
     final theme = Theme.of(context);
     return Card(
       color: Colors.white.withOpacity(0.15), // Semi-transparent white card
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