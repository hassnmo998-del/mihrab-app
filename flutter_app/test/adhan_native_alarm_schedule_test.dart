import 'package:flutter_app/services/adhan_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Android sets its adhan alarms from this schedule and renews them from it after every
/// adhan, so each upcoming adhan must be in it exactly once: today's and tomorrow's
/// occurrence of a prayer are two alarms, not one.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('schedule covers two weeks of the five prayers, upcoming only, in order', () {
    final now = DateTime.now().millisecondsSinceEpoch;
    final schedule = AdhanService.instance.buildNativeAlarmSchedule();

    // Today's prayers that already passed are left out
    expect(schedule.length, inInclusiveRange(13 * 5, 14 * 5));
    expect(schedule.first['time'] as int, greaterThan(now));
    for (var i = 1; i < schedule.length; i++) {
      expect(schedule[i]['time'] as int, greaterThan(schedule[i - 1]['time'] as int));
    }
    expect(schedule.map((a) => a['name']), isNot(contains('الشروق')));
  });

  test('every day keeps its own alarm for each prayer', () {
    final schedule = AdhanService.instance.buildNativeAlarmSchedule();

    for (final prayer in ['الفجر', 'الظهر', 'العصر', 'المغرب', 'العشاء']) {
      final times = schedule.where((a) => a['name'] == prayer).map((a) => a['time'] as int).toList();
      expect(times.length, inInclusiveRange(13, 14), reason: prayer);
      for (var i = 1; i < times.length; i++) {
        final gap = Duration(milliseconds: times[i] - times[i - 1]);
        expect(gap.inHours, inInclusiveRange(23, 25), reason: prayer);
      }
    }
  });

  test('a prayer with its adhan switched off gets no alarm', () async {
    final service = AdhanService.instance;
    await service.setPrayerAdhanEnabled('العصر', false);
    addTearDown(() => service.setPrayerAdhanEnabled('العصر', true));

    final names = service.buildNativeAlarmSchedule(days: 3).map((a) => a['name']).toSet();
    expect(names, {'الفجر', 'الظهر', 'المغرب', 'العشاء'});
  });
}
