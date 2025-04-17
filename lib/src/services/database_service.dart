import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/project.dart'; // Assuming project.dart is in models directory

class DatabaseService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

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
    return projectsCollection
        .where('contributorIds', arrayContains: userId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) {
          try {
            // Use the factory constructor for mapping
            return snapshot.docs.map((doc) {
                 // Ensure the document data is cast correctly for the factory
                 final typedDoc = doc as QueryDocumentSnapshot<Map<String, dynamic>>;
                 return Project.fromFirestore(typedDoc);
            }).toList();
          } catch (e) {
             print("Error mapping moments snapshot: $e");
             return <Project>[]; // Return empty list on mapping error
          }
        }).handleError((error) {
           print("Error fetching moments stream for user $userId: $error");
           return <Project>[]; // Return empty list on stream error
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

  // TODO: Add method to get projects for a user
  // Stream<List<Project>> getProjectsForUser(String userId) { ... }

  // Get a stream for a single project document
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

  // TODO: Add method to update project (e.g., add contributor, add clip)

  // TODO: Add methods for clip subcollection if used

} 