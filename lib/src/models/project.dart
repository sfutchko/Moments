import 'package:cloud_firestore/cloud_firestore.dart';

// Represents a single video clip contribution
class VideoClip {
  final String id; // Unique ID for the clip (Firestore doc ID)
  final String contributorId;
  final String contributorName; // Denormalized for display
  final String videoUrl; // URL to the video file in Cloud Storage
  final Timestamp createdAt;
  final String prompt; // The prompt the user responded to
  // Add other relevant fields: duration, order, etc.

  VideoClip({
    required this.id,
    required this.contributorId,
    required this.contributorName,
    required this.videoUrl,
    required this.createdAt,
    required this.prompt, // Add prompt
  });

  // Factory constructor from Firestore DocumentSnapshot
  factory VideoClip.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data();
    if (data == null) {
      throw StateError('Missing data for VideoClip ${doc.id}');
    }
    return VideoClip(
      id: doc.id,
      contributorId: data['contributorId'] as String? ?? '',
      contributorName: data['contributorName'] as String? ?? 'Anonymous',
      videoUrl: data['videoUrl'] as String? ?? '',
      createdAt: data['createdAt'] as Timestamp? ?? Timestamp.now(),
      prompt: data['prompt'] as String? ?? '', // Add prompt
    );
  }

  // Method to convert to Firestore Map
  Map<String, dynamic> toMap() {
    return {
      'contributorId': contributorId,
      'contributorName': contributorName,
      'videoUrl': videoUrl,
      'createdAt': createdAt,
      'prompt': prompt, // Add prompt
    };
  }
}

// Represents a collaborative video project
class Project {
  final String id;
  final String title;
  final String organizerId;
  final String organizerName;
  final Timestamp createdAt;
  final List<String> contributorIds;
  final String? coverImageUrl;
  final Timestamp? deliveryDate;
  final String? gradientColorHex1;
  final String? gradientColorHex2;
  final String? gradientColorHex3;
  final String? occasion;
  final String? compiledVideoUrl; // URL to the compiled video file
  final bool? isDelivered; // Whether the project has been delivered
  final Timestamp? deliveredAt; // When the project was delivered
  // Add other fields as needed

  Project({
    required this.id,
    required this.title,
    required this.organizerId,
    required this.organizerName,
    required this.createdAt,
    required this.contributorIds,
    this.coverImageUrl,
    this.deliveryDate,
    this.gradientColorHex1,
    this.gradientColorHex2,
    this.gradientColorHex3,
    this.occasion,
    this.compiledVideoUrl,
    this.isDelivered,
    this.deliveredAt,
  });

  // Factory constructor from Firestore DocumentSnapshot
  factory Project.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data();
    if (data == null) {
      throw StateError('Missing data for project ${doc.id}');
    }
    
    return Project(
      id: doc.id,
      title: data['title'] as String? ?? 'Untitled Moment',
      organizerId: data['organizerId'] as String? ?? '',
      organizerName: data['organizerName'] as String? ?? 'Anonymous',
      createdAt: data['createdAt'] as Timestamp? ?? Timestamp.now(),
      contributorIds: List<String>.from(data['contributorIds'] ?? []),
      coverImageUrl: data['coverImageUrl'] as String?,
      deliveryDate: data['deliveryDate'] as Timestamp?,
      gradientColorHex1: data['gradientColorHex1'] as String?,
      gradientColorHex2: data['gradientColorHex2'] as String?,
      gradientColorHex3: data['gradientColorHex3'] as String?,
      occasion: data['occasion'] as String?,
      compiledVideoUrl: data['compiledVideoUrl'] as String?,
      isDelivered: data['isDelivered'] as bool?,
      deliveredAt: data['deliveredAt'] as Timestamp?,
    );
  }

  // Conversion to Map for Firestore
  Map<String, dynamic> toMap() {
    return {
      'title': title,
      'organizerId': organizerId,
      'organizerName': organizerName,
      'createdAt': createdAt,
      'contributorIds': contributorIds,
      if (coverImageUrl != null) 'coverImageUrl': coverImageUrl,
      if (deliveryDate != null) 'deliveryDate': deliveryDate,
      if (gradientColorHex1 != null) 'gradientColorHex1': gradientColorHex1,
      if (gradientColorHex2 != null) 'gradientColorHex2': gradientColorHex2,
      if (gradientColorHex3 != null) 'gradientColorHex3': gradientColorHex3,
      if (occasion != null) 'occasion': occasion,
      if (compiledVideoUrl != null) 'compiledVideoUrl': compiledVideoUrl,
      if (isDelivered != null) 'isDelivered': isDelivered,
      if (deliveredAt != null) 'deliveredAt': deliveredAt,
    };
  }
} 