import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_app/services/adhan_data.dart';
import 'package:flutter_app/services/adhan_service.dart';
import 'package:flutter_app/screens/discover/widgets/adhan_audio_card.dart';
import 'package:flutter_app/screens/discover/widgets/prayer_times_qibla_view.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('AdhanData Catalog Tests', () {
    test('contains over 100 authentic Adhan sounds', () {
      expect(AdhanData.allSounds.length, greaterThanOrEqualTo(100));
      expect(AdhanData.allSounds.length, equals(111));
    });

    test('default sound is valid and from Haram Makkah', () {
      final def = AdhanData.defaultSound;
      expect(def.id, isNotEmpty);
      expect(def.audioUrl, startsWith('http'));
      expect(def.category, equals('الحرمان الشريفان'));
    });

    test('all categories are properly defined and populated', () {
      expect(AdhanData.categories.contains('الكل'), isTrue);
      expect(AdhanData.categories.contains('الحرمان الشريفان'), isTrue);
      expect(AdhanData.categories.contains('الشام وفلسطين'), isTrue);
      expect(AdhanData.categories.contains('مصر والأزهر'), isTrue);
      expect(AdhanData.categories.contains('الخليج العربي'), isTrue);
      expect(AdhanData.categories.contains('العالم الإسلامي'), isTrue);

      for (final cat in AdhanData.categories) {
        if (cat == 'الكل') continue;
        final count = AdhanData.allSounds.where((s) => s.category == cat).length;
        expect(count, greaterThan(0), reason: 'Category $cat should not be empty');
      }
    });

    test('getById returns matching sound or default fallback', () {
      final known = AdhanData.getById('iconic_alaqsa_blessed');
      expect(known.title, contains('الأقصى'));

      final unknown = AdhanData.getById('non_existent_id');
      expect(unknown.id, equals(AdhanData.defaultSound.id));
    });
  });

  group('AdhanService Logic & Iqama Countdown Tests', () {
    test('calculateTodaySchedule returns all 6 prayer entries', () {
      final schedule = AdhanService.instance.calculateTodaySchedule();
      expect(schedule.length, equals(6));

      final names = schedule.map((p) => p['name'] as String).toList();
      expect(names, containsAll(['الفجر', 'الشروق', 'الظهر', 'العصر', 'المغرب', 'العشاء']));
    });

    test('Iqama duration is configurable per prayer', () async {
      final service = AdhanService.instance;
      expect(service.getIqamaMinutes('المغرب'), equals(10));
      expect(service.getIqamaMinutes('الفجر'), equals(25));

      await service.setIqamaMinutes('المغرب', 15);
      expect(service.getIqamaMinutes('المغرب'), equals(15));
    });

    test('getCurrentPrayerState returns valid state and positive remaining duration', () {
      final state = AdhanService.instance.getCurrentPrayerState();
      expect(state.prayerName, isNotEmpty);
      expect(state.remaining.isNegative, isFalse);
      expect(state.nextPrayerName, isNotEmpty);
    });

    test('Volume clamping and setting operates properly', () async {
      final service = AdhanService.instance;
      await service.setVolume(0.8);
      expect(service.volume, equals(0.8));

      await service.setVolume(1.5);
      expect(service.volume, equals(1.0));

      await service.setVolume(-0.2);
      expect(service.volume, equals(0.0));
    });

    test('Master enable toggle persists properly', () async {
      final service = AdhanService.instance;
      await service.setAdhanEnabled(true);
      expect(service.isEnabledNotifier.value, isTrue);

      await service.setAdhanEnabled(false);
      expect(service.isEnabledNotifier.value, isFalse);
    });
  });

  group('UI Widgets Rendering Tests', () {
    tearDown(() {
      AdhanService.instance.dispose();
    });

    testWidgets('AdhanAudioCard renders title, sound name, and transport pills',
        (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: AdhanAudioCard(isDark: false),
          ),
        ),
      );
      await tester.pump();

      expect(find.byType(AdhanAudioCard), findsOneWidget);
      expect(find.text('اختيار الصوت (111)'), findsOneWidget);
      expect(find.text('أوقات الإقامة'), findsOneWidget);
      expect(find.byIcon(Icons.play_arrow_rounded), findsOneWidget);

      await tester.pumpWidget(const SizedBox.shrink());
    });

    testWidgets('PrayerTimesQiblaView renders AdhanAudioCard and Hero countdown',
        (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: PrayerTimesQiblaView(isDark: false),
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.byType(AdhanAudioCard), findsOneWidget);
      expect(find.byType(PrayerTimesQiblaView), findsOneWidget);
      expect(find.text('الفجر'), findsOneWidget);
      expect(find.text('الظهر'), findsOneWidget);
      expect(find.text('العصر'), findsOneWidget);
      expect(find.text('المغرب'), findsOneWidget);
      expect(find.text('العشاء'), findsOneWidget);

      await tester.pumpWidget(const SizedBox.shrink());
      AdhanService.instance.dispose();
    });
  });
}
