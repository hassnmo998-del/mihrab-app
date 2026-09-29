import 'package:flutter_app/services/adhan_service.dart';
import 'package:flutter_test/flutter_test.dart';

/// The Android prayer bar counts down and switches phases on its own from this timeline,
/// so it must be complete, ordered, and carry an iqama for every prayer but sunrise.
void main() {
  test('notification timeline covers two weeks of the six daily events, in order', () {
    final timeline = AdhanService.instance.buildNotificationTimeline();

    expect(timeline.length, 14 * 6);
    for (var i = 1; i < timeline.length; i++) {
      expect(timeline[i]['adhan'] as int, greaterThan(timeline[i - 1]['adhan'] as int));
    }

    final today = DateTime.now();
    final first = DateTime.fromMillisecondsSinceEpoch(timeline.first['adhan'] as int);
    expect([first.year, first.month, first.day], [today.year, today.month, today.day]);
  });

  test('every prayer has its iqama after the adhan; sunrise has none', () {
    for (final e in AdhanService.instance.buildNotificationTimeline(days: 2)) {
      final adhan = e['adhan'] as int;
      final iqama = e['iqama'] as int;
      if (e['name'] == 'الشروق') {
        expect(iqama, 0);
      } else {
        expect(iqama, greaterThan(adhan));
        expect(Duration(milliseconds: iqama - adhan).inMinutes,
            AdhanService.instance.getIqamaMinutes(e['name'] as String));
      }
    }
  });
}
