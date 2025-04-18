import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import '../models/project.dart';
import 'video_sharing_service.dart';
import '../features/moment_detail/widgets/confetti_celebration.dart';

class DeliveryService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final VideoSharingService _sharingService = VideoSharingService();

  /// Check if a project is ready for delivery
  bool isReadyForDelivery(Project project) {
    // Must have a delivery date
    if (project.deliveryDate == null) return false;
    
    // Delivery date must be in the past
    final now = DateTime.now();
    final deliveryDateTime = project.deliveryDate!.toDate();
    if (deliveryDateTime.isAfter(now)) return false;
    
    // Must have a compiled video
    if (project.compiledVideoUrl == null || project.compiledVideoUrl!.isEmpty) return false;
    
    // Must not already be delivered
    final isDelivered = project.isDelivered ?? false;
    if (isDelivered) return false;
    
    return true;
  }

  /// Deliver a project's compiled video
  Future<bool> deliverProject(BuildContext context, Project project) async {
    if (!isReadyForDelivery(project)) {
      print('Project not ready for delivery: ${project.id}');
      return false;
    }
    
    try {
      // First, mark the project as delivered in Firestore
      await _db.collection('projects').doc(project.id).update({
        'isDelivered': true,
        'deliveredAt': FieldValue.serverTimestamp(),
      });
      
      print('Project marked as delivered: ${project.id}');
      
      // Show success notification
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${project.title} was delivered!'),
            backgroundColor: Colors.green,
          ),
        );
      }
      
      // Share the compiled video
      if (project.compiledVideoUrl != null && context.mounted) {
        // Determine recipient name based on project occasion
        final String recipientName = _getRecipientName(project);
        
        await _sharingService.shareVideo(
          videoUrl: project.compiledVideoUrl!,
          title: '$recipientName\'s Special Video',
          context: context,
          message: 'Here\'s a special video we made for $recipientName!',
        );
      }
      
      return true;
    } catch (e) {
      print('Error delivering project: $e');
      
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to deliver: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
      
      return false;
    }
  }
  
  /// Update a project's delivery date
  Future<bool> updateDeliveryDate(String projectId, DateTime newDeliveryDate) async {
    try {
      await _db.collection('projects').doc(projectId).update({
        'deliveryDate': Timestamp.fromDate(newDeliveryDate),
      });
      return true;
    } catch (e) {
      print('Error updating delivery date: $e');
      return false;
    }
  }
  
  /// Get project delivery status
  Stream<Map<String, dynamic>> getDeliveryStatus(String projectId) {
    return _db.collection('projects').doc(projectId)
      .snapshots()
      .map((snapshot) {
        final data = snapshot.data();
        if (data == null) return {};
        
        return {
          'isDelivered': data['isDelivered'] ?? false,
          'deliveryDate': data['deliveryDate'],
          'deliveredAt': data['deliveredAt'],
        };
      });
  }
  
  /// Helper to get recipient name based on occasion
  String _getRecipientName(Project project) {
    // Default to "Mom" if occasion is null or unknown
    if (project.occasion == null) return "Mom";
    
    final occasion = project.occasion!.toLowerCase();
    if (occasion.contains("father") || occasion == "dad" || occasion == "daddy") {
      return "Dad";
    } else if (occasion.contains("birthday")) {
      return "Birthday Person";
    } else if (occasion.contains("anniversary")) {
      return "Anniversary Couple";
    } else if (occasion.contains("graduation")) {
      return "Graduate";
    } else {
      // Default to Mom for "mother", "mom", "mommy", or any other occasion
      return "Mom";
    }
  }
  
  /// Show delivery celebration dialog
  Future<void> showDeliveryCelebration(BuildContext context, Project project) async {
    final String recipientName = _getRecipientName(project);
    
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Stack(
        children: [
          // Confetti animation in the background
          const ConfettiCelebration(
            particleCount: 100,
            duration: Duration(seconds: 5),
          ),
          
          // Celebration dialog
          DeliveryCelebrationDialog(
            projectTitle: project.title,
            recipientName: recipientName,
            onShare: () {
              Navigator.of(context).pop();
              
              if (project.compiledVideoUrl != null) {
                _sharingService.shareVideo(
                  videoUrl: project.compiledVideoUrl!,
                  title: '$recipientName\'s Special Video',
                  context: context,
                  message: 'Here\'s a special video we made for $recipientName!',
                );
              }
            },
          ),
        ],
      ),
    );
  }
}

/// Model extension to add isDelivered property
extension ProjectDeliveryExtension on Project {
  bool? get isDelivered => null; // This should come from Firestore
}

/// Celebration dialog shown when a project is delivered
class DeliveryCelebrationDialog extends StatefulWidget {
  final String projectTitle;
  final String recipientName;
  final VoidCallback onShare;

  const DeliveryCelebrationDialog({
    Key? key,
    required this.projectTitle,
    required this.recipientName,
    required this.onShare,
  }) : super(key: key);

  @override
  State<DeliveryCelebrationDialog> createState() => _DeliveryCelebrationDialogState();
}

class _DeliveryCelebrationDialogState extends State<DeliveryCelebrationDialog>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    
    _scaleAnimation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.elasticOut,
    );
    
    // Start animation
    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      child: AnimatedBuilder(
        animation: _scaleAnimation,
        builder: (context, child) {
          return Transform.scale(
            scale: _scaleAnimation.value,
            child: child,
          );
        },
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.blue.shade900,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.blue.withOpacity(0.3),
                blurRadius: 20,
                spreadRadius: 5,
              ),
            ],
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Colors.purple.shade700,
                Colors.blue.shade900,
              ],
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.celebration,
                  color: Colors.white,
                  size: 40,
                ),
              ),
              const SizedBox(height: 24),
              Text(
                'Special Delivery!',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                '${widget.projectTitle} has been delivered to ${widget.recipientName}!',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white.withOpacity(0.9),
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  ElevatedButton(
                    onPressed: () => Navigator.of(context).pop(),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white.withOpacity(0.2),
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                    ),
                    child: const Text('Close', style: TextStyle(color: Colors.white)),
                  ),
                  const SizedBox(width: 16),
                  ElevatedButton.icon(
                    icon: const Icon(Icons.share, color: Colors.blue),
                    label: const Text('Share', style: TextStyle(color: Colors.blue)),
                    onPressed: widget.onShare,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
} 