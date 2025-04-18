import 'dart:async';
import 'package:flutter/material.dart';
import 'package:app_links/app_links.dart';
import '../features/join_project/presentation/join_project_screen.dart';

/// Service responsible for handling deep links within the app
class DeepLinkService {
  final GlobalKey<NavigatorState>? navigatorKey;
  final void Function(String) onMomentIdReceived;
  final AppLinks _appLinks = AppLinks();

  // Stream controller for broadcasting deep link events
  final StreamController<Uri> _deepLinkStreamController = StreamController<Uri>.broadcast();
  
  // Public stream that other parts of the app can listen to
  Stream<Uri> get deepLinkStream => _deepLinkStreamController.stream;

  // Flag to track if initial URI has been handled
  bool _initialUriHandled = false;

  DeepLinkService({
    this.navigatorKey,
    required this.onMomentIdReceived,
  });

  /// Handles the incoming URI and performs the appropriate action
  void handleUri(Uri uri) {
    if (uri.pathSegments.contains('join')) {
      final String? projectId = uri.queryParameters['projectId'];
      if (projectId != null) {
        debugPrint('Received project ID from deep link: $projectId');
        onMomentIdReceived(projectId);
      } else {
        debugPrint('No project ID found in deep link');
      }
    } else {
      debugPrint('Unrecognized deep link pattern: $uri');
    }
  }

  /// Extracts the project ID from a URI if it exists
  String? extractProjectId(Uri uri) {
    if (uri.pathSegments.contains('join')) {
      return uri.queryParameters['projectId'];
    }
    return null;
  }

  /// Navigates to the JoinProjectScreen with the extracted project ID
  void _navigateToJoinProject(String projectId) {
    // Make sure we have a navigator to use
    if (navigatorKey?.currentState == null) {
      debugPrint('DeepLinkService: Navigator not available');
      return;
    }
    
    navigatorKey!.currentState!.push(
      MaterialPageRoute(
        builder: (context) => JoinProjectScreen(projectId: projectId),
      ),
    );
  }

  // Initialize the deep link service
  Future<void> initialize() async {
    // Listen for subsequent links - this is working correctly
    _appLinks.uriLinkStream.listen((Uri? uri) {
      if (uri != null) {
        _deepLinkStreamController.add(uri);
        debugPrint('Deep link service: URI received: ${uri.toString()}');
        handleUri(uri);
      }
    }, onError: (Object err) {
      debugPrint('Deep link service: Error in URI stream: $err');
    });

    // We need to try to get the initial link - this matches the example code
    if (!_initialUriHandled) {
      _initialUriHandled = true;
      try {
        // This is the correct method for this package
        final uri = await _appLinks.getInitialLink();
        if (uri != null) {
          _deepLinkStreamController.add(uri);
          debugPrint('Deep link service: Initial URI: ${uri.toString()}');
          handleUri(uri);
        }
      } catch (e) {
        debugPrint('Deep link service: Error handling initial URI: $e');
      }
    }
  }

  // Dispose the service properly
  void dispose() {
    _deepLinkStreamController.close();
  }
} 