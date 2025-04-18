import 'dart:io';
import 'package:firebase_storage/firebase_storage.dart' as firebase_storage;
import 'package:firebase_auth/firebase_auth.dart';

class StorageService {
  final firebase_storage.FirebaseStorage _storage = firebase_storage.FirebaseStorage.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  /// Uploads a cover image for a specific moment.
  /// Returns the download URL on success, null on failure.
  Future<String?> uploadCoverImage(String momentId, File imageFile) async {
    try {
      String fileName = 'cover_$momentId.${imageFile.path.split('.').last}';
      final firebase_storage.Reference ref = _storage.ref().child('moments/$momentId/$fileName');

      print('Uploading cover image to: $fileName');
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
    // Assuming cover image name format: cover_{momentId}.{extension}
    // This is a simplification; a more robust way might store the exact filename in Firestore.
    // We'll try deleting common extensions.
    final extensions = ['jpg', 'jpeg', 'png', 'webp'];
    bool deleted = false;
    for (String ext in extensions) {
        String fileName = 'cover_$momentId.$ext';
        final firebase_storage.Reference ref = _storage.ref().child('moments/$momentId/$fileName');
        try {
            await ref.getDownloadURL(); // Check if file exists
            await ref.delete();
            print("Deleted cover image: $fileName");
            deleted = true; // Mark as deleted if successful
            break; // Exit loop once deleted
        } on firebase_storage.FirebaseException catch (e) {
            if (e.code == 'object-not-found') {
                // print("Cover image with extension .$ext not found, trying next...");
            } else {
                print("Error checking/deleting cover image $fileName: $e");
            }
        } catch (e) {
             print("General error deleting cover image $fileName: $e");
        }
    }
    if (!deleted) print("No cover image found to delete for $momentId with common extensions.");
    return deleted; // Return true if any version was successfully deleted
  }

  // Upload a video clip contribution for a Moment
  Future<String?> uploadVideoClip(String momentId, File videoFile) async {
    final String? userId = _auth.currentUser?.uid;
    if (userId == null) {
      print("Error: User not logged in.");
      return null;
    }
    
    try {
      // Unique filename using timestamp and user ID
      String timestamp = DateTime.now().millisecondsSinceEpoch.toString();
      String fileName = 'clip_${timestamp}_$userId.${videoFile.path.split('.').last}';
      
      final firebase_storage.Reference ref = _storage.ref().child('moments/$momentId/clips/$fileName');
      
      firebase_storage.UploadTask uploadTask = ref.putFile(
        videoFile,
        firebase_storage.SettableMetadata(contentType: 'video/mp4'), // Set content type for video
      );
      
      firebase_storage.TaskSnapshot snapshot = await uploadTask;
      String downloadUrl = await snapshot.ref.getDownloadURL();
      print("Video clip uploaded successfully: $downloadUrl");
      return downloadUrl;
    } catch (e) {
      print("Error uploading video clip: $e");
      return null;
    }
  }

  // TODO: Add function to delete video clip if needed
  // Future<bool> deleteVideoClip(String momentId, String clipFileName) async { ... }

  // Delete a video clip from storage
  Future<bool> deleteVideoClip(String momentId, String videoUrl) async {
    try {
      // Extract file name from the download URL 
      // The URL looks like: https://firebasestorage.googleapis.com/v0/b/bucket/o/moments%2FmomentId%2Fclips%2Fclip_filename.mp4?token...
      final Uri uri = Uri.parse(videoUrl);
      final String fullPath = Uri.decodeComponent(uri.path.split('/o/')[1].split('?')[0]);
      
      // Create a reference to the file
      final firebase_storage.Reference ref = _storage.ref().child(fullPath);
      
      // Delete the file
      await ref.delete();
      print("Video file at path $fullPath deleted successfully.");
      return true;
    } catch (e) {
      print("Error deleting video file: $e");
      return false;
    }
  }
  
  // Upload a compiled video for a moment
  Future<String?> uploadCompiledVideo(String momentId, File videoFile) async {
    final String? userId = _auth.currentUser?.uid;
    if (userId == null) {
      print("Error: User not logged in.");
      return null;
    }
    
    try {
      print("Starting compiled video upload for momentId: $momentId");
      print("Video file exists: ${await videoFile.exists()}");
      print("Video file size: ${await videoFile.length()} bytes");
      
      // Create a unique filename for the compiled video
      String timestamp = DateTime.now().millisecondsSinceEpoch.toString();
      String fileName = 'compiled_${timestamp}.${videoFile.path.split('.').last}';
      print("Generated filename: $fileName");
      
      // Store compiled videos in a separate 'compiled' folder
      final firebase_storage.Reference ref = _storage.ref().child('moments/$momentId/compiled/$fileName');
      print("Storage reference path: ${ref.fullPath}");
      
      // Upload with appropriate metadata
      firebase_storage.UploadTask uploadTask = ref.putFile(
        videoFile,
        firebase_storage.SettableMetadata(contentType: 'video/mp4'),
      );
      
      // Wait for upload to complete
      print("Upload task started");
      firebase_storage.TaskSnapshot snapshot = await uploadTask;
      print("Upload complete. Task state: ${snapshot.state}");
      
      String downloadUrl = await snapshot.ref.getDownloadURL();
      print("Download URL obtained: $downloadUrl");
      return downloadUrl;
    } on firebase_storage.FirebaseException catch (e) {
      print("Firebase Storage Error during compiled video upload: ${e.code} - ${e.message}");
      print("Error details: $e");
      return null;
    } catch (e) {
      print("General Error during compiled video upload: $e");
      print("Error stack trace: ${StackTrace.current}");
      return null;
    }
  }
} 