import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:ffmpeg_kit_flutter_full_gpl/ffmpeg_kit.dart';
import 'package:ffmpeg_kit_flutter_full_gpl/return_code.dart';
import 'package:firebase_storage/firebase_storage.dart';
import '../models/project.dart';
import '../services/storage_service.dart';
import '../services/database_service.dart';

typedef ProgressCallback = void Function(String message, double progress);
// Simpler callback for older code
typedef SimpleProgressCallback = void Function(double progress);

class VideoCompilationService {
  final StorageService _storageService;
  final DatabaseService _databaseService;
  final FirebaseStorage _storage = FirebaseStorage.instance;

  // Updated constructor to accept both services
  VideoCompilationService(this._storageService, {DatabaseService? databaseService})
      : _databaseService = databaseService ?? DatabaseService();

  /// Compiles multiple video clips into a single video
  /// Returns the download URL of the compiled video if successful
  /// 
  /// Supports both named parameter style and legacy positional parameter style
  Future<String?> compileVideos(
    dynamic projectOrId,
    List<VideoClip> clips,
    dynamic onProgressCallback, {
    // Named parameters for newer implementation
    String? projectId,
    ProgressCallback? onProgress,
  }) async {
    // Determine project ID
    final String actualProjectId = projectId ?? 
        (projectOrId is Project ? projectOrId.id : projectOrId as String);
    
    // Determine callback method
    final void Function(String, double) progressHandler;
    if (onProgress != null) {
      progressHandler = onProgress;
    } else if (onProgressCallback is ProgressCallback) {
      progressHandler = onProgressCallback;
    } else if (onProgressCallback is SimpleProgressCallback) {
      // Convert simple callback to detailed callback
      progressHandler = (message, progress) => onProgressCallback(progress);
    } else {
      // Default no-op callback
      progressHandler = (_, __) {};
    }
    
    print("Starting video compilation for project: $actualProjectId with ${clips.length} clips");
    
    if (clips.isEmpty) {
      progressHandler('No video clips to compile', 0);
      return null;
    }

    try {
      // Create a temporary directory to store downloaded videos
      final tempDir = await getTemporaryDirectory();
      final workingDir = Directory('${tempDir.path}/videoCompilation');
      if (await workingDir.exists()) {
        await workingDir.delete(recursive: true);
      }
      await workingDir.create(recursive: true);
      print("Working directory created: ${workingDir.path}");
      
      progressHandler('Downloading video clips...', 0.1);
      
      // Download all video clips
      final List<File> downloadedFiles = [];
      for (int i = 0; i < clips.length; i++) {
        final clip = clips[i];
        final downloadProgress = 0.1 + (0.4 * (i / clips.length));
        progressHandler('Downloading clip ${i+1} of ${clips.length}...', downloadProgress);
        print("Downloading clip ${i+1}: ${clip.videoUrl}");
        
        final file = await _downloadFile(
          clip.videoUrl, 
          '${workingDir.path}/clip_$i.mp4'
        );
        
        if (file != null) {
          print("Clip ${i+1} downloaded successfully: ${file.path} (${await file.length()} bytes)");
          downloadedFiles.add(file);
        } else {
          print("Failed to download clip ${i+1}");
        }
      }
      
      if (downloadedFiles.isEmpty) {
        print("No clips could be downloaded!");
        throw Exception('Failed to download any video clips');
      }
      
      print("Downloaded ${downloadedFiles.length} clips successfully");
      progressHandler('Preparing to compile videos...', 0.5);
      
      // Create file list for FFmpeg
      final fileListPath = '${workingDir.path}/file_list.txt';
      final fileListFile = File(fileListPath);
      final buffer = StringBuffer();
      
      for (final file in downloadedFiles) {
        buffer.writeln("file '${file.path}'");
      }
      
      await fileListFile.writeAsString(buffer.toString());
      print("Created FFmpeg file list at: $fileListPath");
      print("File list content: ${await fileListFile.readAsString()}");
      
      // Output file path
      final outputPath = '${workingDir.path}/compiled_video.mp4';
      
      // Execute FFmpeg command to concatenate videos
      progressHandler('Compiling videos...', 0.6);
      print("Starting FFmpeg compilation");
      
      final session = await FFmpegKit.execute(
        '-f concat -safe 0 -i $fileListPath -c copy $outputPath'
      );
      
      final returnCode = await session.getReturnCode();
      print("FFmpeg process completed with return code: ${returnCode?.getValue() ?? 'null'}");
      
      if (ReturnCode.isSuccess(returnCode)) {
        progressHandler('Compilation complete, uploading...', 0.8);
        
        // Upload the compiled video
        final outputFile = File(outputPath);
        if (!await outputFile.exists()) {
          print("Compiled video file not found at: $outputPath");
          throw Exception('Compiled video file not found');
        }
        
        print("Compiled video created successfully: $outputPath (${await outputFile.length()} bytes)");
        
        // Upload to Firebase Storage
        print("Uploading compiled video to Firebase");
        final downloadUrl = await _storageService.uploadCompiledVideo(
          actualProjectId, 
          outputFile
        );
        
        if (downloadUrl != null) {
          print("Compiled video uploaded. URL: $downloadUrl");
          
          // Update project with compiled video URL
          try {
            await _databaseService.updateProjectWithCompiledVideo(
              actualProjectId, 
              downloadUrl
            );
            print("Project database updated with compiled video URL");
          } catch (e) {
            print("Error updating project with video URL: $e");
            // Continue even if DB update fails, as video is still uploaded
          }
          
          progressHandler('Video compilation complete!', 1.0);
          return downloadUrl;
        } else {
          print("Failed to upload compiled video - no download URL returned");
          throw Exception('Failed to upload compiled video');
        }
      } else {
        final logs = await session.getLogs();
        print("FFmpeg process failed. Logs: ${logs.join("\n")}");
        throw Exception('FFmpeg process failed: ${logs.join("\n")}');
      }
    } catch (e) {
      print("Video compilation error: $e");
      print("Error stack trace: ${StackTrace.current}");
      progressHandler('Error: ${e.toString()}', 0);
      return null;
    }
  }
  
  /// Helper method to download a file from Firebase Storage
  Future<File?> _downloadFile(String url, String destinationPath) async {
    try {
      final ref = FirebaseStorage.instance.refFromURL(url);
      final file = File(destinationPath);
      await ref.writeToFile(file);
      return file;
    } catch (e) {
      print('Error downloading file: $e');
      return null;
    }
  }
} 