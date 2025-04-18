import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'package:flutter/services.dart';
import '../../../services/video_sharing_service.dart';

class VideoPlayerScreen extends StatefulWidget {
  final String videoUrl;
  final String contributorName;

  const VideoPlayerScreen({
    Key? key,
    required this.videoUrl,
    required this.contributorName,
  }) : super(key: key);

  @override
  State<VideoPlayerScreen> createState() => _VideoPlayerScreenState();
}

class _VideoPlayerScreenState extends State<VideoPlayerScreen> {
  late VideoPlayerController _controller;
  bool _isInitialized = false;
  final VideoSharingService _sharingService = VideoSharingService();

  @override
  void initState() {
    super.initState();
    
    // Lock to portrait mode for video playback
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]);
    
    // Setup video controller with the provided URL
    _controller = VideoPlayerController.networkUrl(Uri.parse(widget.videoUrl))
      ..initialize().then((_) {
        if (mounted) {
          setState(() {
            _isInitialized = true;
            // Auto-play when ready
            _controller.play();
          });
        }
      }).catchError((error) {
        print('Error initializing video: $error');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error playing video: $error'),
              backgroundColor: Colors.red,
            ),
          );
        }
      });
  }

  @override
  void dispose() {
    // Reset orientation settings when leaving
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    
    _controller.dispose();
    super.dispose();
  }

  // Method to handle video sharing
  Future<void> _shareVideo() async {
    await _sharingService.shareVideo(
      videoUrl: widget.videoUrl,
      title: widget.contributorName,
      context: context,
      message: 'Check out this special video I made for you!',
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        title: Text(widget.contributorName),
        foregroundColor: Colors.white,
        actions: [
          // Share button in the app bar
          IconButton(
            icon: const Icon(Icons.share, color: Colors.white),
            onPressed: _shareVideo,
            tooltip: 'Share Video',
          ),
        ],
      ),
      body: Center(
        child: _isInitialized
            ? AspectRatio(
                aspectRatio: _controller.value.aspectRatio,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    VideoPlayer(_controller),
                    // Simple play/pause button
                    GestureDetector(
                      onTap: () {
                        setState(() {
                          if (_controller.value.isPlaying) {
                            _controller.pause();
                          } else {
                            _controller.play();
                          }
                        });
                      },
                      child: CircleAvatar(
                        backgroundColor: Colors.black54,
                        radius: 30,
                        child: Icon(
                          _controller.value.isPlaying ? Icons.pause : Icons.play_arrow,
                          size: 30,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
              )
            : const CircularProgressIndicator(color: Colors.white),
      ),
      bottomNavigationBar: _buildBottomControls(),
    );
  }

  Widget _buildBottomControls() {
    if (!_isInitialized) return Container();
    
    return Container(
      height: 100,
      color: Colors.black,
      child: Column(
        children: [
          // Progress indicator
          VideoProgressIndicator(
            _controller,
            allowScrubbing: true,
            colors: const VideoProgressColors(
              playedColor: Colors.white,
              bufferedColor: Colors.white24,
              backgroundColor: Colors.grey,
            ),
            padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 16.0),
          ),
          
          // Add a dedicated share button at the bottom
          Padding(
            padding: const EdgeInsets.all(12.0),
            child: ElevatedButton.icon(
              icon: const Icon(Icons.share),
              label: const Text('Share Video'),
              onPressed: _shareVideo,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
                foregroundColor: Colors.white,
                minimumSize: const Size(double.infinity, 40),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
} 