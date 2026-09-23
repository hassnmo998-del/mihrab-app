import 'package:flutter/foundation.dart';
import 'platform_utils.dart';

/// Safe wrapper for platform-specific features
class PlatformWrappers {
  /// Safely start foreground task (Android/iOS only)
  static Future<void> startForegroundTask({
    required String notificationTitle,
    required String notificationText,
  }) async {
    if (!PlatformUtils.supportsForegroundTask) return;

    try {
      // Conditional import is handled at compile time
      // For Windows/Desktop: this becomes a no-op
      // For Mobile: this calls the actual flutter_foreground_task
      if (defaultTargetPlatform.toString().contains('android') ||
          defaultTargetPlatform.toString().contains('iOS')) {
        // Dynamic import would go here if we could use it
        // For now, callers should check PlatformUtils.supportsForegroundTask
      }
    } catch (e) {
      debugPrint('⚠️ Foreground task not available: $e');
    }
  }

  /// Safely stop foreground task (Android/iOS only)
  static Future<void> stopForegroundTask() async {
    if (!PlatformUtils.supportsForegroundTask) return;

    try {
      if (defaultTargetPlatform.toString().contains('android') ||
          defaultTargetPlatform.toString().contains('iOS')) {
        // Dynamic import would go here
      }
    } catch (e) {
      debugPrint('⚠️ Stop foreground task not available: $e');
    }
  }

  /// Safely initialize window manager (Desktop only)
  static Future<void> initWindowManager() async {
    if (!PlatformUtils.supportsWindowManager) return;

    try {
      if (defaultTargetPlatform.toString().contains('windows') ||
          defaultTargetPlatform.toString().contains('macOS') ||
          defaultTargetPlatform.toString().contains('linux')) {
        // window_manager initialization would go here
      }
    } catch (e) {
      debugPrint('⚠️ Window manager not available: $e');
    }
  }

  /// Safely set window size (Desktop only)
  static Future<void> setWindowSize({
    required double width,
    required double height,
  }) async {
    if (!PlatformUtils.supportsWindowManager) return;

    try {
      if (defaultTargetPlatform.toString().contains('windows') ||
          defaultTargetPlatform.toString().contains('macOS') ||
          defaultTargetPlatform.toString().contains('linux')) {
        // window_manager setSize would go here
      }
    } catch (e) {
      debugPrint('⚠️ Set window size not available: $e');
    }
  }
}
