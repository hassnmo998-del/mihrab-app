import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_app/services/app_update_service.dart';

void main() {
  group('AppUpdateService Unit Tests', () {
    final service = AppUpdateService.instance;

    test('isNewerVersion semver comparison logic', () {
      expect(service.isNewerVersion('1.0.1', '1.0.0'), isTrue);
      expect(service.isNewerVersion('1.1.0', '1.0.9'), isTrue);
      expect(service.isNewerVersion('2.0.0', '1.9.9'), isTrue);
      expect(service.isNewerVersion('1.0.0', '1.0.0'), isFalse);
      expect(service.isNewerVersion('1.0.0', '1.0.1'), isFalse);
      expect(service.isNewerVersion('1.0.1+2', '1.0.1'), isFalse);
    });

    test('Initial state of AppUpdateService', () {
      expect(service.state, equals(SilentUpdateState.idle));
      expect(service.downloadProgress, equals(0.0));
      expect(service.receivedBytes, equals(0));
      expect(service.totalBytes, equals(0));
    });

    test('Formatting helpers formatProgress and formatSize', () {
      service.downloadProgress = 0.45;
      service.receivedBytes = 45 * 1024 * 1024;
      service.totalBytes = 100 * 1024 * 1024;

      expect(service.formattedProgress, equals('45%'));
      expect(service.formattedSize, contains('45.0 ميغابايت من 100.0 ميغابايت'));
    });
  });
}
