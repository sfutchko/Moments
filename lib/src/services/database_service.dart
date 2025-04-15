import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/project.dart'; // Assuming project.dart is in models directory

class DatabaseService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // Reference to the projects collection
  CollectionReference get projectsCollection => _db.collection('projects');

  // Create a new project
  Future<void> createProject({
      required String title,
      required String organizerId,
      required String organizerName,
      Timestamp? deliveryDate,
  }) async {
    try {
      await projectsCollection.add({
        'title': title,
        'organizerId': organizerId,
        'organizerName': organizerName,
        'createdAt': Timestamp.now(),
        'contributorIds': [organizerId], // Start with organizer as a contributor
        'deliveryDate': deliveryDate,
        // 'clips': [], // Decide on clips structure (subcollection might be better)
        // Initialize other fields as needed
      });
      print('Project created successfully!');
    } catch (e) {
      print('Error creating project in DatabaseService: $e');
      // Re-throw the error so the UI layer can handle it
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
      // Delete the project document
      await projectsCollection.doc(projectId).delete();
      print('Project deleted successfully: $projectId');
      return true;
    } catch (e) {
      print('Error deleting project: $e');
      return false;
    }
  }

  // TODO: Add method to get projects for a user
  // Stream<List<Project>> getProjectsForUser(String userId) { ... }

  // TODO: Add method to get a single project details
  // Stream<Project> getProjectDetails(String projectId) { ... }

  // TODO: Add method to update project (e.g., add contributor, add clip)

  // TODO: Add methods for clip subcollection if used

} 