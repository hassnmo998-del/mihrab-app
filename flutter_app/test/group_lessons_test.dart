import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_app/models/models.dart';
import 'package:flutter_app/screens/discover/dialogs/lesson_speakers_field.dart';
import 'package:flutter_app/services/data_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('CommunityEvent group lesson model', () {
    CommunityEvent groupEvent() => CommunityEvent(
          id: 'ev-g',
          mosqueId: 'm1',
          title: 'درس مشترك',
          description: '',
          eventType: 'lesson',
          targetAudience: 'general',
          eventDateTime: DateTime(2026, 9, 23, 19),
          organizerType: 'sheikh',
          organizerName: 'الشيخ أحمد، الشيخ محمد',
          sheikhId: 's1',
          lessonFormat: 'group',
          sheikhIds: const ['s1', 's2'],
        );

    test('JSON round-trip keeps format and all sheikhs', () {
      final json = groupEvent().toJson();
      expect(json['lesson_format'], 'group');
      expect(json['sheikh_ids'], ['s1', 's2']);

      final parsed = CommunityEvent.fromJson(json);
      expect(parsed.isGroupLesson, isTrue);
      expect(parsed.allSheikhIds, ['s1', 's2']);
    });

    test('rows from before the migration read as single lessons', () {
      final json = groupEvent().toJson()
        ..remove('lesson_format')
        ..remove('sheikh_ids');
      final parsed = CommunityEvent.fromJson(json);
      expect(parsed.lessonFormat, 'single');
      expect(parsed.sheikhIds, isEmpty);
      expect(parsed.isGroupLesson, isFalse);
      expect(parsed.allSheikhIds, ['s1']);
    });

    test('every participating sheikh "gives" the lesson; others do not', () {
      final ev = groupEvent();
      expect(ev.involvesSheikh(sheikhId: 's1'), isTrue);
      expect(ev.involvesSheikh(sheikhId: 's2'), isTrue);
      expect(ev.involvesSheikh(sheikhId: 's3'), isFalse);
      // Name fallback still works for old single lessons saved without an id.
      final legacy = CommunityEvent.fromJson(ev.toJson()
        ..['sheikh_id'] = null
        ..['sheikh_ids'] = <String>[]
        ..['organizer_name'] = 'الشيخ خالد');
      expect(legacy.involvesSheikh(name: 'الشيخ خالد'), isTrue);
    });

    test('names are joined in order for the lecturers line', () {
      expect(LessonSpeakersField.joinNames(['الشيخ أحمد', ' ', 'الشيخ محمد']), 'الشيخ أحمد، الشيخ محمد');
    });
  });

  group('DataService group lessons', () {
    setUp(() => SharedPreferences.setMockInitialValues({}));

    test('creates a group lesson, edits keep the attachment, switching to single clears co-sheikhs', () async {
      final data = DataService();
      await data.init();
      final mosque = data.addMosque(name: 'جامع الدروس', address: 'الحي', city: 'دمشق', gender: 'male');
      final a = data.addSheikh(mosque.id, 'الشيخ أحمد', null);
      final b = data.addSheikh(mosque.id, 'الشيخ محمد', null);

      final ev = data.addCommunityEvent(
        mosqueId: mosque.id,
        title: 'درس مشترك',
        description: '',
        eventType: 'lesson',
        targetAudience: 'general',
        eventDateTime: DateTime.now(),
        organizerType: 'sheikh',
        organizerName: LessonSpeakersField.joinNames([a.fullName, b.fullName]),
        sheikhId: a.id,
        lessonFormat: 'group',
        sheikhIds: [a.id, b.id],
      );
      expect(ev.isGroupLesson, isTrue);
      expect(ev.involvesSheikh(sheikhId: b.id), isTrue);

      data.setEventVideoUrl(ev.id, 'tg:file:abc|ملخص.pdf');
      data.updateCommunityEvent(eventId: ev.id, title: 'درس مشترك (معدّل)', description: '', eventType: 'lesson');
      var stored = data.getCommunityEvents().firstWhere((e) => e.id == ev.id);
      expect(stored.videoRecordUrl, 'tg:file:abc|ملخص.pdf', reason: 'editing must not drop the attachment');
      expect(stored.allSheikhIds, [a.id, b.id]);

      data.updateCommunityEvent(
        eventId: ev.id,
        title: stored.title,
        description: '',
        eventType: 'lesson',
        lessonFormat: 'single',
        sheikhId: a.id,
      );
      stored = data.getCommunityEvents().firstWhere((e) => e.id == ev.id);
      expect(stored.isGroupLesson, isFalse);
      expect(stored.sheikhIds, isEmpty);
    });

    test('a co-sheikh from another mosque is rejected', () async {
      final data = DataService();
      await data.init();
      final home = data.addMosque(name: 'جامع أ', address: '', city: 'دمشق', gender: 'male');
      final other = data.addMosque(name: 'جامع ب', address: '', city: 'دمشق', gender: 'male');
      final a = data.addSheikh(home.id, 'الشيخ أحمد', null);
      final outsider = data.addSheikh(other.id, 'الشيخ الغريب', null);

      expect(
        () => data.addCommunityEvent(
          mosqueId: home.id,
          title: 'درس',
          description: '',
          eventType: 'lesson',
          targetAudience: 'general',
          eventDateTime: DateTime.now(),
          organizerType: 'sheikh',
          organizerName: 'x',
          sheikhId: a.id,
          lessonFormat: 'group',
          sheikhIds: [a.id, outsider.id],
        ),
        throwsStateError,
      );
    });
  });

  testWidgets('Speakers field: switch to group, announcer stays checked, others toggle', (tester) async {
    final sheikhs = [
      Sheikh(id: 's1', mosqueId: 'm', fullName: 'الشيخ أحمد', code: 'SHK-1'),
      Sheikh(id: 's2', mosqueId: 'm', fullName: 'الشيخ محمد', code: 'SHK-2'),
    ];
    var isGroup = false;
    var selected = <String>{'s1'};

    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: StatefulBuilder(
          builder: (context, setState) => LessonSpeakersField(
            isGroup: isGroup,
            onFormatChanged: (v) => setState(() => isGroup = v),
            sheikhs: sheikhs,
            selectedIds: selected,
            lockedSheikhId: 's1',
            onSelectionChanged: (ids) => setState(() => selected = ids),
            singleChild: const Text('single-inputs'),
          ),
        ),
      ),
    ));

    expect(find.text('single-inputs'), findsOneWidget);
    await tester.tap(find.text('جماعي'));
    await tester.pump();
    expect(find.text('single-inputs'), findsNothing);
    expect(find.text('الشيخ محمد'), findsOneWidget);

    // The announcer can't be removed from their own lesson.
    await tester.tap(find.text('الشيخ أحمد'));
    await tester.pump();
    expect(selected, {'s1'});

    await tester.tap(find.text('الشيخ محمد'));
    await tester.pump();
    expect(selected, {'s1', 's2'});
  });
}
