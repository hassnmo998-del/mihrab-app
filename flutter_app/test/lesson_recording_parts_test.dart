import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_app/core/di/injection.dart';
import 'package:flutter_app/models/models.dart';
import 'package:flutter_app/services/data_service.dart';

/// درس تجاوز ساعة التسجيل: كل جزء سجل أرشيف مستقل بتسجيله، ولا يكتب جزء فوق آخر مهما
/// كان ترتيب انتهاء رفعهما.
void main() {
  late DataService data;
  late Mosque mosque;

  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    SharedPreferences.setMockInitialValues({});
    await initInjection();
    data = sl<DataService>();
  });

  setUp(() {
    for (final role in ['mosque_admin', 'sheikh', 'cashier', 'student']) {
      data.disconnectRole(role);
    }
    mosque = data.addMosque(name: 'جامع الأجزاء', address: '', city: 'دمشق', gender: 'male');
  });

  CommunityEvent lesson({required bool recurring}) => data.addCommunityEvent(
        mosqueId: mosque.id,
        title: 'شرح الأربعين',
        description: '',
        eventType: 'lesson',
        timingType: 'custom_time',
        targetAudience: 'general',
        eventDateTime: DateTime.now().subtract(const Duration(minutes: 70)),
        organizerType: 'mosque',
        organizerName: 'الشيخ',
        isRecurring: recurring,
        recurringDays: recurring ? 'السبت, الاثنين, الأربعاء' : null,
      );

  CommunityEvent byId(String id) => data.getCommunityEvents().firstWhere((e) => e.id == id);

  test('درس لمرة واحدة بجزأين: الجزء الأول هو الدرس، والثاني سجل «— الجزء 2» مستقل', () {
    final ev = lesson(recurring: false);

    data.changeEventStatus(ev.id, 'live');
    final part1 = data.finalizeLiveSession(ev.id)!;
    expect(part1, ev.id);
    expect(byId(ev.id).eventStatus, 'archived');

    // الشيخ تابع في جزء ثانٍ
    data.changeEventStatus(ev.id, 'live');
    final part2 = data.finalizeLiveSession(ev.id, part: 2)!;

    expect(part2, isNot(part1));
    expect(part2, startsWith('archived-${ev.id}-p2-'));
    final snapshot = byId(part2);
    expect(snapshot.title, 'شرح الأربعين — الجزء 2');
    expect(snapshot.eventStatus, 'archived');
    expect(snapshot.isRecurring, isFalse);
    expect(byId(ev.id).eventStatus, 'archived');
  });

  test('رفع الجزء الأول ينتهي بعد إنشاء الجزء الثاني (كان بلا إنترنت): كل تسجيل على سجله', () {
    final ev = lesson(recurring: false);
    data.changeEventStatus(ev.id, 'live');
    final part1 = data.finalizeLiveSession(ev.id)!;
    data.changeEventStatus(ev.id, 'live');
    final part2 = data.finalizeLiveSession(ev.id, part: 2)!;

    // الثاني رُفع أولاً، ثم الأول
    data.setEventAudioUrl(part2, 'tg:part-2');
    data.setEventAudioUrl(part1, 'tg:part-1');

    expect(byId(ev.id).audioRecordUrl, 'tg:part-1');
    expect(byId(part2).audioRecordUrl, 'tg:part-2');
  });

  test('رفع الجزء الأول ينتهي والجزء الثاني ما زال يُسجَّل: يُحفظ على الدرس', () {
    final ev = lesson(recurring: false);
    data.changeEventStatus(ev.id, 'live');
    final part1 = data.finalizeLiveSession(ev.id)!;
    data.changeEventStatus(ev.id, 'live'); // الجزء الثاني بدأ

    data.setEventAudioUrl(part1, 'tg:part-1');

    expect(byId(ev.id).audioRecordUrl, 'tg:part-1');
  });

  test('درس متكرر بجزأين: لقطتان مستقلتان، وموعده القادم يتقدّم مرة واحدة ويبقى «قادم»', () {
    final ev = lesson(recurring: true);
    data.changeEventStatus(ev.id, 'live');
    final part1 = data.finalizeLiveSession(ev.id)!;
    final nextAfterPart1 = byId(ev.id).eventDateTime;

    data.changeEventStatus(ev.id, 'live');
    final part2 = data.finalizeLiveSession(ev.id, part: 2)!;

    expect(part1, startsWith('archived-${ev.id}-'));
    expect(part2, startsWith('archived-${ev.id}-p2-'));
    expect(part1, isNot(part2));
    expect(byId(ev.id).eventStatus, 'upcoming');
    expect(byId(ev.id).eventDateTime, nextAfterPart1);

    data.setEventAudioUrl(part2, 'tg:b');
    data.setEventAudioUrl(part1, 'tg:a');
    expect(byId(part1).audioRecordUrl, 'tg:a');
    expect(byId(part2).audioRecordUrl, 'tg:b');
    expect(byId(ev.id).audioRecordUrl, isNull);
  });

  test('طلب رفع قديم موجّه إلى الدرس المتكرر نفسه: يذهب إلى لقطة جلسته لا إلى جزء تالٍ', () {
    final ev = lesson(recurring: true);
    data.changeEventStatus(ev.id, 'live');
    final part1 = data.finalizeLiveSession(ev.id)!;
    data.changeEventStatus(ev.id, 'live');
    final part2 = data.finalizeLiveSession(ev.id, part: 2)!;

    data.setEventAudioUrl(ev.id, 'tg:legacy');

    expect(byId(part1).audioRecordUrl, 'tg:legacy');
    expect(byId(part2).audioRecordUrl, isNull);
  });

  test('الجزءان يظهران في الأرشيف، وفي الترتيب الأحدث أولاً الجزء الثاني', () {
    final ev = lesson(recurring: false);
    data.changeEventStatus(ev.id, 'live');
    final part1 = data.finalizeLiveSession(ev.id)!;
    data.changeEventStatus(ev.id, 'live');
    final part2 = data.finalizeLiveSession(ev.id, part: 2)!;
    data.setEventAudioUrl(part1, 'tg:1');
    data.setEventAudioUrl(part2, 'tg:2');

    final archive = data
        .getCommunityEvents()
        .where((e) => e.mosqueId == mosque.id && (e.eventStatus == 'archived' || e.hasAudio))
        .toList()
      ..sort((a, b) => b.eventDateTime.compareTo(a.eventDateTime));
    expect(archive.map((e) => e.id), containsAll([part1, part2]));
    expect(archive.first.id, part2);
  });
}
