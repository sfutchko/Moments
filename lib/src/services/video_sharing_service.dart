import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:flutter/material.dart';

class VideoSharingService {
  /// Downloads a video from the given URL and returns the local file
  Future<File?> _downloadVideo(String videoUrl, String fileName) async {
    try {
      // Get temporary directory
      final directory = await getTemporaryDirectory();
      final filePath = '${directory.path}/$fileName';
      
      // Check if the file already exists (to avoid re-downloading)
      final file = File(filePath);
      if (await file.exists()) {
        print('Video already cached locally, using existing file');
        return file;
      }
      
      // Download the file
      print('Downloading video from: $videoUrl');
      final response = await http.get(Uri.parse(videoUrl));
      
      if (response.statusCode == 200) {
        // Save to file
        await file.writeAsBytes(response.bodyBytes);
        print('Video downloaded successfully to: $filePath');
        return file;
      } else {
        print('Failed to download video. Status code: ${response.statusCode}');
        return null;
      }
    } catch (e) {
      print('Error downloading video: $e');
      return null;
    }
  }

  /// Shares a video with other apps
  Future<void> shareVideo({
    required String videoUrl,
    required String title,
    required BuildContext context,
    String? message,
  }) async {
    try {
      // Show loading dialog
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const AlertDialog(
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text('Preparing video for sharing...'),
            ],
          ),
        ),
      );
      
      // Generate a filename from the title
      final String fileName = '${title.replaceAll(' ', '_').toLowerCase()}_video.mp4';
      
      // Download the video
      final videoFile = await _downloadVideo(videoUrl, fileName);
      
      // Close loading dialog
      Navigator.of(context, rootNavigator: true).pop();
      
      if (videoFile == null) {
        // Show error message
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to download video for sharing'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }
      
      // Share the video
      final shareResult = await Share.shareXFiles(
        [XFile(videoFile.path)],
        subject: title,
        text: message ?? 'Check out this special video!',
      );
      
      print('Share result: ${shareResult.status}');
      
      // Optional: Delete the file after sharing to save space
      // await videoFile.delete();
    } catch (e) {
      print('Error sharing video: $e');
      // Close dialog if still showing
      if (context.mounted) {
        Navigator.of(context, rootNavigator: true).pop();
        
        // Show error message
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error sharing video: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
} 