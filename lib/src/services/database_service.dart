import 'package:cloud_firestore/cloud_firestore.dart' show FirebaseFirestore, CollectionReference, DocumentSnapshot, FieldValue, Timestamp, QuerySnapshot;
import 'package:firebase_auth/firebase_auth.dart';
import '../models/project.dart'; // Assuming project.dart is in models directory
import 'package:rxdart/rxdart.dart';

class DatabaseService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Reference to the projects collection
  CollectionReference get projectsCollection => _db.collection('projects');

  // Create a new project - Updated signature and logic
  Future<void> createProject({
      String? projectId, // Optional ID (used if image uploaded first)
      required String title,
      required String organizerId,
      required String organizerName,
      Timestamp? deliveryDate,
      String? coverImageUrl,
      String? gradientColorHex1,
      String? gradientColorHex2,
      String? gradientColorHex3,
      String? occasion, // Add the new occasion field
  }) async {
    try {
      // Prepare data map, including new fields only if they have values
      final Map<String, dynamic> projectData = {
        'title': title,
        'organizerId': organizerId,
        'organizerName': organizerName,
        'createdAt': Timestamp.now(),
        'contributorIds': [organizerId], 
        if (deliveryDate != null) 'deliveryDate': deliveryDate,
        if (coverImageUrl != null) 'coverImageUrl': coverImageUrl,
        if (gradientColorHex1 != null) 'gradientColorHex1': gradientColorHex1,
        if (gradientColorHex2 != null) 'gradientColorHex2': gradientColorHex2,
        if (gradientColorHex3 != null) 'gradientColorHex3': gradientColorHex3,
        if (occasion != null) 'occasion': occasion, // Add occasion to data map
        // Add other default fields if necessary
      };

      // Use set with specific ID if provided, otherwise add for auto-ID
      if (projectId != null) {
        print('Creating project with provided ID: $projectId');
        await projectsCollection.doc(projectId).set(projectData);
      } else {
        print('Creating project with auto-generated ID...');
        await projectsCollection.add(projectData);
      }
      
      print('Project created successfully!');
    } catch (e) {
      print('Error creating project in DatabaseService: $e');
      rethrow;
    }
  }

  // Get a stream of projects where the user is either the organizer or a contributor
  Stream<List<Project>> getMomentsForUser(String userId) {
    print('Fetching moments for user ID: $userId');

    // Query for projects where user is the organizer
    final organizerQuery = _db
        .collection('projects')
        .where('organizerId', isEqualTo: userId);

    // Query for projects where user is a contributor
    final contributorQuery = _db
        .collection('projects')
        .where('contributorIds', arrayContains: userId);

    // Combine the results of both queries
    // Note: This might fetch projects where the user is both organizer and contributor twice.
    // We will deduplicate based on the project ID.
    return CombineLatestStream.combine2(
      organizerQuery.snapshots(),
      contributorQuery.snapshots(),
      (QuerySnapshot<Map<String, dynamic>> organizerSnapshot,
       QuerySnapshot<Map<String, dynamic>> contributorSnapshot) {
        final Map<String, Project> projectsMap = {};

        // Process organizer projects
        for (var doc in organizerSnapshot.docs) {
          try {
            final project = Project.fromFirestore(doc);
            projectsMap[project.id] = project;
          } catch (e) {
            print('Error parsing organizer project ${doc.id}: $e');
          }
        }

        // Process contributor projects, adding only if not already present
        for (var doc in contributorSnapshot.docs) {
          try {
            final project = Project.fromFirestore(doc);
            // Add only if the ID isn't already in the map (avoids duplicates)
            projectsMap.putIfAbsent(project.id, () => project);
          } catch (e) {
            print('Error parsing contributor project ${doc.id}: $e');
          }
        }
        
        // Sort by createdAt descending (most recent first)
        final projectList = projectsMap.values.toList();
        projectList.sort((a, b) => b.createdAt.compareTo(a.createdAt));
        
        print('Combined and deduplicated moments count: ${projectList.length}');
        return projectList;
      },
    ).handleError((error) {
      print("Error combining project streams: $error");
      return <Project>[]; // Return empty list on error
    });
  }

  // Delete a project by ID
  Future<bool> deleteProject(String projectId) async {
    try {
      await projectsCollection.doc(projectId).delete();
      print('Project deleted successfully: $projectId');
      return true;
    } catch (e) {
      print('Error deleting project: $e');
      return false;
    }
  }

  // Method to update specific fields of a project document
  Future<bool> updateProject(String projectId, Map<String, dynamic> data) async {
    try {
      await projectsCollection.doc(projectId).update(data);
      print('Project updated successfully: $projectId with data $data');
      return true;
    } catch (e) {
      print('Error updating project $projectId: $e');
      return false;
    }
  }

  // Add a user as a contributor to a project
  Future<bool> addContributorToProject(String projectId, String userId, String userName) async {
    try {
      // First get the current document to check if user is already a contributor
      DocumentSnapshot doc = await projectsCollection.doc(projectId).get();
      
      if (!doc.exists) {
        print('Project $projectId does not exist');
        return false;
      }
      
      Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
      List<String> contributors = List<String>.from(data['contributorIds'] ?? []);
      
      // Check if user is already a contributor
      if (!contributors.contains(userId)) {
        // Add the user to the contributorIds array using arrayUnion
        await projectsCollection.doc(projectId).update({
          'contributorIds': FieldValue.arrayUnion([userId])
        });
        print('Added user $userId as contributor to project $projectId');
      } else {
        print('User $userId is already a contributor to project $projectId');
      }
      
      return true;
    } catch (e) {
      print('Error adding contributor to project $projectId: $e');
      return false;
    }
  }

  // TODO: Add method to get projects for a user
  // Stream<List<Project>> getProjectsForUser(String userId) { ... }

  /// Get a stream for a single project document
  Stream<Project?> getProjectDetails(String projectId) {
    return projectsCollection
        .doc(projectId)
        .snapshots()
        .map((snapshot) {
          try {
            if (snapshot.exists && snapshot.data() != null) {
              // Cast the snapshot to the expected type for the factory
              final typedDoc = snapshot as DocumentSnapshot<Map<String, dynamic>>;
              return Project.fromFirestore(typedDoc);
            } else {
              return null; // Document doesn't exist
            }
          } catch (e) {
            print("Error mapping project details snapshot for $projectId: $e");
            return null; // Return null on error
          }
        }).handleError((error) {
          print("Error fetching project details stream for $projectId: $error");
          return null; // Return null on stream error
        });
  }
  
  /// Get a project's details synchronously (non-stream version)
  Future<Project?> getProjectDetailsSync(String projectId) async {
    try {
      final snapshot = await projectsCollection.doc(projectId).get();
      
      if (snapshot.exists && snapshot.data() != null) {
        // Cast the snapshot to the expected type for the factory
        final typedDoc = snapshot as DocumentSnapshot<Map<String, dynamic>>;
        return Project.fromFirestore(typedDoc);
      }
      return null; // Document doesn't exist
    } catch (e) {
      print("Error getting project details synchronously for $projectId: $e");
      return null; // Return null on error
    }
  }

  // TODO: Add method to update project (e.g., add contributor, add clip)

  // TODO: Add methods for clip subcollection if used

  // Add a new video clip to a project's subcollection
  Future<bool> addVideoClipToProject({
    required String projectId,
    required String videoUrl,
    required String contributorId,
    required String contributorName, 
    required String prompt, // Add prompt
  }) async {
    try {
      final clipData = VideoClip(
        id: '', // Firestore will generate ID
        contributorId: contributorId,
        contributorName: contributorName, 
        videoUrl: videoUrl,
        createdAt: Timestamp.now(), 
        prompt: prompt,
      ).toMap(); // Use the toMap method

      await _db
          .collection('projects')
          .doc(projectId)
          .collection('clips') // Add to 'clips' subcollection
          .add(clipData);
      
      print("Video clip added successfully to project $projectId");
      return true;
    } catch (e) {
      print("Error adding video clip to project $projectId: $e");
      return false;
    }
  }

  // TODO: Add methods to get/stream clips for a project
  // Stream<List<VideoClip>> getVideoClipsForProject(String projectId) { ... }

  // Get a stream of all video clips for a specific project
  Stream<List<VideoClip>> getVideoClipsForProject(String projectId) {
    return _db
        .collection('projects')
        .doc(projectId)
        .collection('clips')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) {
          try {
            return snapshot.docs
                .map((doc) {
                  // Cast the document to the expected type
                  final typedDoc = doc as DocumentSnapshot<Map<String, dynamic>>;
                  return VideoClip.fromFirestore(typedDoc);
                })
                .toList();
          } catch (e) {
            print("Error mapping video clips for project $projectId: $e");
            return <VideoClip>[];
          }
        });
  }

  // Get all video clips for a specific project synchronously
  Future<List<VideoClip>> getVideoClipsForProjectSync(String projectId) async {
    try {
      final snapshot = await _db
          .collection('projects')
          .doc(projectId)
          .collection('clips')
          .orderBy('createdAt', descending: false) // Get in chronological order for compilation
          .get();
      
      final clips = snapshot.docs
          .map((doc) {
            final typedDoc = doc as DocumentSnapshot<Map<String, dynamic>>;
            return VideoClip.fromFirestore(typedDoc);
          })
          .toList();
      
      print("Fetched ${clips.length} clips for project $projectId synchronously");
      return clips;
    } catch (e) {
      print("Error getting video clips synchronously for project $projectId: $e");
      return <VideoClip>[];
    }
  }

  // TODO: Add method to delete a video clip (requires clip ID)
  
  // Delete a video clip by ID
  Future<bool> deleteVideoClip(String projectId, String clipId) async {
    try {
      await _db
          .collection('projects')
          .doc(projectId)
          .collection('clips')
          .doc(clipId)
          .delete();
      
      print("Video clip $clipId successfully deleted from project $projectId");
      return true;
    } catch (e) {
      print("Error deleting video clip $clipId from project $projectId: $e");
      return false;
    }
  }
  
  /// Updates a project with a compiled video URL
  Future<void> updateProjectWithCompiledVideo(String projectId, String compiledVideoUrl) async {
    try {
      await _db.collection('projects').doc(projectId).update({
        'compiledVideoUrl': compiledVideoUrl,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      print("Project updated with compiled video URL");
    } catch (e) {
      print("Error updating project with compiled video URL: $e");
      rethrow;
    }
  }

  // --- User Operations (Example) ---
  Future<Map<String, dynamic>?> getUserProfile(String userId) async {
     // Example: Fetch user profile data if stored separately
     try {
       DocumentSnapshot doc = await _db.collection('users').doc(userId).get();
       return doc.data() as Map<String, dynamic>?;
     } catch (e) {
       print("Error fetching user profile: $e");
       return null;
     }
  }
} 