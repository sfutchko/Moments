import 'dart:io';
import 'package:firebase_storage/firebase_storage.dart' as firebase_storage;

class StorageService {
  final firebase_storage.FirebaseStorage _storage = firebase_storage.FirebaseStorage.instance;

  /// Uploads a cover image for a specific moment.
  /// Returns the download URL on success, null on failure.
  Future<String?> uploadCoverImage(String momentId, File imageFile) async {
    try {
      // Define the path in Firebase Storage
      final String filePath = 'moment_covers/$momentId/cover.jpg';
      final firebase_storage.Reference ref = _storage.ref().child(filePath);

      print('Uploading cover image to: $filePath');
      // Upload the file
      firebase_storage.UploadTask uploadTask = ref.putFile(imageFile);

      // Wait for the upload to complete
      firebase_storage.TaskSnapshot snapshot = await uploadTask;
      print('Upload complete. Task state: ${snapshot.state}');

      // Get the download URL
      final String downloadUrl = await snapshot.ref.getDownloadURL();
      print('Download URL obtained: $downloadUrl');
      
      return downloadUrl;
    } on firebase_storage.FirebaseException catch (e) {
      print('Firebase Storage Error during upload: ${e.code} - ${e.message}');
      return null;
    } catch (e) {
      print('General Error during cover image upload: $e');
      return null;
    }
  }

  /// Deletes the cover image for a specific moment.
  /// Returns true on success, false on failure.
  Future<bool> deleteCoverImage(String momentId) async {
    try {
      final String filePath = 'moment_covers/$momentId/cover.jpg';
      final firebase_storage.Reference ref = _storage.ref().child(filePath);

      print('Deleting cover image at: $filePath');
      await ref.delete();
      print('Cover image deleted successfully from storage.');
      return true;
    } on firebase_storage.FirebaseException catch (e) {
      // Handle specific errors, e.g., object-not-found if it was already deleted
      if (e.code == 'object-not-found') {
        print('Cover image not found in storage (already deleted?). Assuming success.');
        return true; // Treat as success if it doesn't exist
      } 
      print('Firebase Storage Error during delete: ${e.code} - ${e.message}');
      return false;
    } catch (e) {
      print('General Error during cover image delete: $e');
      return false;
    }
  }
} 