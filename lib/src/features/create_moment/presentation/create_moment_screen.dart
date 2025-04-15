import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart'; // Import Timestamp

import '../../../services/auth_service.dart';
import '../../../services/database_service.dart';
import 'package:firebase_auth/firebase_auth.dart';
// Import intl for date formatting if desired
// import 'package:intl/intl.dart';

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

  @override
  void dispose() {
    _titleController.dispose();
    super.dispose();
  }

  // --- Implement _selectDeliveryDate method --- 
  Future<void> _selectDeliveryDate() async {
     final DateTime? picked = await showDatePicker(
        context: context,
        initialDate: _selectedDeliveryDate ?? DateTime.now().add(const Duration(days: 1)), // Start tomorrow or selected
        firstDate: DateTime.now(), // Can't schedule in the past
        lastDate: DateTime.now().add(const Duration(days: 365 * 2)), // Allow scheduling up to 2 years ahead
        // TODO: Customize date picker theme to match app style
        // builder: (context, child) { ... }
     );
     if (picked != null && picked != _selectedDeliveryDate) {
        setState(() {
           _selectedDeliveryDate = picked;
        });
     }
  }

  // --- Update _createMoment method --- 
  Future<void> _createMoment() async {
      if (!(_formKey.currentState?.validate() ?? false)) return;
      setState(() { _isLoading = true; });

      final User? user = Provider.of<AuthService>(context, listen: false).currentUser;
      final DatabaseService dbService = Provider.of<DatabaseService>(context, listen: false);

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
      bool success = false;

      try {
        // Pass the selected delivery date (as Timestamp) to the service
        await dbService.createProject(
            title: title,
            organizerId: user.uid,
            organizerName: organizerName,
            deliveryDate: _selectedDeliveryDate != null 
                            ? Timestamp.fromDate(_selectedDeliveryDate!)
                            : null,
        );
        success = true;
      } catch (e) {
         print("Error creating moment: $e");
         success = false;
      }

      if (!mounted) return;
      setState(() { _isLoading = false; });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(success ? 'Moment created!' : 'Failed to create moment.')),
      );
      if (success) {
         Navigator.of(context).pop(); // Go back on success
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
                  // --- Placeholder for Cover Style --- 
                  Center(
                    child: Column(
                      children: [
                         Icon(Icons.image_outlined, size: 60, color: Colors.white.withOpacity(0.7)),
                         const SizedBox(height: 8),
                         TextButton(
                            onPressed: () { print('Choose cover style - NI'); }, 
                            child: Text('Choose Cover Style', style: TextStyle(color: Colors.white.withOpacity(0.9)))
                         )
                      ],
                    ),
                  ),
                   const SizedBox(height: 40),
                  // --- Section Card for Title/Date --- 
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
                       const Divider(color: Colors.white24, height: 24),
                       ListTile(
                          leading: const Icon(Icons.calendar_today_outlined, color: Colors.white70),
                          title: Text(
                            _selectedDeliveryDate == null 
                               ? 'Schedule Delivery (Optional)' 
                               // Use DateFormat for nicer formatting if intl is added
                               // : 'Deliver on: ${DateFormat.yMMMd().format(_selectedDeliveryDate!)}',
                               : 'Deliver on: ${_selectedDeliveryDate!.month}/${_selectedDeliveryDate!.day}/${_selectedDeliveryDate!.year}', 
                            style: theme.textTheme.bodyLarge?.copyWith(color: Colors.white),
                          ),
                          onTap: _selectDeliveryDate, // Call the implemented method
                          contentPadding: EdgeInsets.zero,
                       )
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