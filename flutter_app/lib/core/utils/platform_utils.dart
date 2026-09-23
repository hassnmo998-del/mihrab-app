import 'dart:io';
import 'package:flutter/foundation.dart';

/// Platform utility functions for handling platform-specific features
class PlatformUtils {
  static bool get isAndroid => defaultTargetPlatform == TargetPlatform.android;
  static bool get isIOS => defaultTargetPlatform == TargetPlatform.iOS;
  static bool get isWindows => defaultTargetPlatform == TargetPlatform.windows;
  static bool get isMacOS => defaultTargetPlatform == TargetPlatform.macOS;
  static bool get isLinux => defaultTargetPlatform == TargetPlatform.linux;
  static bool get isWeb => kIsWeb;

  static bool get isMobile => isAndroid || isIOS;
  static bool get isDesktop => isWindows || isMacOS || isLinux;

  /// Check if platform supports audio recording
  static bool get supportsAudioRecording => isMobile || isDesktop;

  /// Check if platform supports background tasks (foreground service)
  static bool get supportsForegroundTask => isAndroid || isIOS;

  /// Check if platform supports window manager
  static bool get supportsWindowManager => isWindows || isMacOS || isLinux;

  /// Safely get application documents directory
  static Future<String> getAppDocumentsPath() async {
    if (isWeb) {
      return '';
    }
    try {
      if (isAndroid || isIOS) {
        // Mobile paths are handled by path_provider
        return '';
      } else if (isWindows || isMacOS || isLinux) {
        // Desktop paths
        return '';
      }
    } catch (e) {
      debugPrint('⚠️ Error getting app documents path: $e');
    }
    return '';
  }

  /// Check if running in Flutter test
  static bool get isTestMode {
    try {
      return Platform.environment.containsKey('FLUTTER_TEST');
    } catch (e) {
      return false;
    }
  }
}
