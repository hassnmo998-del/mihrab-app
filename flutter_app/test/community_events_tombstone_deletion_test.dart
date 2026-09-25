import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_app/data/datasources/local_storage_datasource.dart';
import 'package:flutter_app/data/datasources/offline_sync_queue_manager.dart';
import 'package:flutter_app/data/repositories/community_events_repository_impl.dart';
import 'package:flutter_app/models/community_event.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('Deleting a community event records a persistent tombstone and prevents resurrection', () async {
    final local = LocalStorageDataSource();
    final sync = OfflineSyncQueueManager();
    final repo = CommunityEventsRepositoryImpl(local, sync);

    final event = CommunityEvent(
      id: 'event-test-123',
      mosqueId: 'mosque-1',
      title: 'درس تجريبي',
      description: 'وصف',
      eventType: 'lesson',
      targetAudience: 'general',
      eventDateTime: DateTime.now(),
      organizerType: 'sheikh',
      organizerName: 'الشيخ',
    );

    local.communityEvents.add(event);
    expect(local.communityEvents.length, 1);

    // Delete event
    repo.deleteCommunityEvent('event-test-123');

    // Verify it is removed locally
    expect(local.communityEvents.isEmpty, true);

    // Verify tombstone is recorded
    expect(local.isEntityDeleted('event-test-123'), true);

    // Verify tombstone persists across a new instance after loadAllFromStorage
    await local.saveToStorage();

    final freshLocal = LocalStorageDataSource();
    await freshLocal.loadAllFromStorage();

    expect(freshLocal.isEntityDeleted('event-test-123'), true);
  });
}
