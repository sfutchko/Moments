import 'package:cloud_firestore/cloud_firestore.dart';

// Represents a single video clip contribution
class VideoClip {
  final String id; // Unique ID for the clip
  final String contributorId;
  final String contributorName; // Or fetch separately?
  final String videoUrl; // URL to the video file in Cloud Storage
  final Timestamp createdAt;
  // Add other relevant fields: duration, order, etc.

  VideoClip({
    required this.id,
    required this.contributorId,
    required this.contributorName,
    required this.videoUrl,
    required this.createdAt,
  });

  // TODO: Add factory constructor from Firestore DocumentSnapshot
  // TODO: Add method to convert to Firestore Map
}

// Represents a collaborative video project
class Project {
  final String id; // Firestore document ID
  final String title;
  final String organizerId; // User ID of the creator
  final String organizerName; // Optional: denormalized for display
  final Timestamp createdAt;
  final Timestamp? deliveryDate; // For scheduled delivery
  final List<String> contributorIds; // List of invited/joined user IDs
  final List<VideoClip> clips; // Embedded or reference to subcollection?
  final String? finalVideoUrl; // URL of the compiled video
  final String? themeId; // ID of the selected theme/template
  final String? soundAccentId; // ID of the selected sound accent
  final String? coverImageUrl; // Added field for cover image URL
  final String? gradientColorHex1;
  final String? gradientColorHex2;
  final String? gradientColorHex3;
  final String? occasion; // Add the new occasion field

  Project({
    required this.id,
    required this.title,
    required this.organizerId,
    required this.organizerName,
    required this.createdAt,
    this.deliveryDate,
    List<String>? contributorIds,
    List<VideoClip>? clips,
    this.finalVideoUrl,
    this.themeId,
    this.soundAccentId,
    this.coverImageUrl,
    this.gradientColorHex1,
    this.gradientColorHex2,
    this.gradientColorHex3,
    this.occasion, // Add to constructor
  }) : contributorIds = contributorIds ?? [],
       clips = clips ?? [];

  // Factory constructor to create a Project from a Firestore document
  factory Project.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data();
    if (data == null) {
      // Handle cases where data might be unexpectedly null, perhaps throw an error
      // or return a default/error state Project object.
      throw StateError('Missing data for Project ${doc.id}');
    }

    // TODO: Implement proper deserialization for nested VideoClip list if embedded
    // For now, clips list is initialized empty.

    return Project(
      id: doc.id,
      title: data['title'] as String? ?? 'Untitled Moment',
      organizerId: data['organizerId'] as String? ?? '',
      organizerName: data['organizerName'] as String? ?? '',
      createdAt: data['createdAt'] as Timestamp? ?? Timestamp.now(),
      deliveryDate: data['deliveryDate'] as Timestamp?,
      contributorIds: List<String>.from(data['contributorIds'] as List<dynamic>? ?? []),
      // clips: [], // Placeholder for clips deserialization
      finalVideoUrl: data['finalVideoUrl'] as String?,
      themeId: data['themeId'] as String?,
      soundAccentId: data['soundAccentId'] as String?,
      coverImageUrl: data['coverImageUrl'] as String?,
      gradientColorHex1: data['gradientColorHex1'] as String?,
      gradientColorHex2: data['gradientColorHex2'] as String?,
      gradientColorHex3: data['gradientColorHex3'] as String?,
      occasion: data['occasion'] as String?, // Add occasion to factory
    );
  }

  // TODO: Add method to convert to Firestore Map (toMap)
  Map<String, dynamic> toMap() {
    return {
      'title': title,
      'organizerId': organizerId,
      'organizerName': organizerName,
      'createdAt': createdAt,
      'deliveryDate': deliveryDate,
      'contributorIds': contributorIds,
      // Clips might need special handling if they are complex objects
      // 'clips': clips.map((clip) => clip.toMap()).toList(), // Example if VideoClip has toMap
      'finalVideoUrl': finalVideoUrl,
      'themeId': themeId,
      'soundAccentId': soundAccentId,
      'coverImageUrl': coverImageUrl,
      'gradientColorHex1': gradientColorHex1,
      'gradientColorHex2': gradientColorHex2,
      'gradientColorHex3': gradientColorHex3,
      'occasion': occasion, // Add occasion to map
    };
  }
} 