import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';

/// Utility class for consistent image provider handling across the app.
class ImageProviderUtil {
  /// Default placeholder asset path for fallback images
  static const String defaultPlaceholderPath = 'assets/images/placeholder.png';

  /// Determines if a given path is an asset path using several checks
  static bool isAssetPath(String? path) {
    if (path == null || path.isEmpty) return false;
    
    return path.startsWith('assets/') || 
           path.contains('/assets/') ||
           (!path.contains('://') && !path.startsWith('http'));
  }
  
  /// Creates an appropriate ImageProvider based on the image path
  /// with consistent asset detection logic
  static ImageProvider getSafeImageProvider({
    required String? imagePath,
    String fallbackAssetPath = defaultPlaceholderPath,
    int? fallbackIndex,
  }) {
    // Handle null or empty path
    if (imagePath == null || imagePath.isEmpty) {
      // Use index-based fallback if provided, otherwise use default placeholder
      if (fallbackIndex != null) {
        final indexedFallback = 'assets/images/${(fallbackIndex % 3) + 1}.png';
        print('[ImageProviderUtil] Using indexed fallback: $indexedFallback');
        return AssetImage(indexedFallback);
      }
      print('[ImageProviderUtil] Using default placeholder: $fallbackAssetPath');
      return AssetImage(fallbackAssetPath);
    }
    
    // Check if it's an asset path
    if (isAssetPath(imagePath)) {
      print('[ImageProviderUtil] Using Asset Image: $imagePath');
      return AssetImage(imagePath);
    } else {
      // Using NetworkImage instead of CachedNetworkImageProvider to avoid Impeller texture issues
      // CachedNetworkImage widget will be used for UI rendering, which is safer
      print('[ImageProviderUtil] Using Network Image: $imagePath');
      return NetworkImage(imagePath);
    }
  }
  
  /// Returns a Widget for image display with consistent error handling
  static Widget getSafeImageWidget({
    required String? imageUrl,
    double? width,
    double? height,
    BoxFit fit = BoxFit.cover,
    Widget Function(BuildContext, Object, StackTrace?)? errorBuilder,
    Widget? placeholder,
    int? fallbackIndex,
  }) {
    if (imageUrl == null || imageUrl.isEmpty) {
      // Return placeholder or default asset
      return placeholder ?? 
             Image.asset(
               fallbackIndex != null 
                 ? 'assets/images/${(fallbackIndex % 3) + 1}.png' 
                 : defaultPlaceholderPath,
               fit: fit,
               width: width,
               height: height,
             );
    }
    
    final defaultErrorBuilder = (BuildContext context, Object error, StackTrace? stackTrace) {
      print('[ImageProviderUtil] Error loading image: $error');
      return placeholder ?? 
             Image.asset(
               fallbackIndex != null 
                 ? 'assets/images/${(fallbackIndex % 3) + 1}.png' 
                 : defaultPlaceholderPath,
               fit: fit,
               width: width,
               height: height,
             );
    };
    
    if (isAssetPath(imageUrl)) {
      print('[ImageProviderUtil] Loading Asset Image: $imageUrl');
      return Image.asset(
        imageUrl,
        fit: fit,
        width: width,
        height: height,
        errorBuilder: errorBuilder ?? defaultErrorBuilder,
      );
    } else {
      print('[ImageProviderUtil] Loading Network Image: $imageUrl');
      // Use CachedNetworkImage for widgets, which handles caching properly at the widget level
      return CachedNetworkImage(
        imageUrl: imageUrl,
        fit: fit,
        width: width,
        height: height,
        fadeOutDuration: const Duration(milliseconds: 300),
        fadeInDuration: const Duration(milliseconds: 300),
        placeholder: (context, url) => placeholder ?? 
                                      Container(
                                        color: Colors.grey.shade200.withOpacity(0.3),
                                        child: const Center(
                                          child: CircularProgressIndicator(),
                                        ),
                                      ),
        errorWidget: (context, url, error) {
          if (errorBuilder != null) {
            return errorBuilder(context, error, null);
          }
          return defaultErrorBuilder(context, error, null);
        },
      );
    }
  }
} 