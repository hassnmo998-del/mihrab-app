import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_app/data/help_videos_data.dart';

/// فهرس الفيديوهات التعليمية: كل عنصر له ملفه وغلافه المضمَّنان، وكل رتبة في البوابة لها فيديوها.
void main() {
  test('معرّفات الفيديوهات فريدة ومدتها وأوصافها موجودة', () {
    final ids = HelpVideos.all.map((v) => v.id).toList();
    expect(ids.toSet().length, ids.length);
    for (final v in HelpVideos.all) {
      expect(v.title.trim(), isNotEmpty, reason: v.id);
      expect(v.description.trim(), isNotEmpty, reason: v.id);
      expect(v.seconds, greaterThan(0), reason: v.id);
    }
  });

  test('لكل فيديو ملف وغلاف في assets، وكلاهما مذكور في pubspec', () {
    final pubspec = File('pubspec.yaml').readAsStringSync();
    expect(pubspec, contains('- assets/videos/'));
    expect(pubspec, contains('- assets/videos/posters/'));
    for (final v in HelpVideos.all) {
      final video = File(v.asset);
      final poster = File(v.poster);
      expect(video.existsSync(), isTrue, reason: 'ملف ناقص: ${v.asset}');
      expect(poster.existsSync(), isTrue, reason: 'غلاف ناقص: ${v.poster}');
      // مضمَّنة في التطبيق: حجم معقول لكل فيديو
      expect(video.lengthSync(), lessThan(14 * 1024 * 1024), reason: '${v.id} أثقل من المسموح');
    }
  });

  test('كل رتب البوابة لها فيديو في الدليل', () {
    for (final id in [
      HelpVideoIds.mosqueAdmin,
      HelpVideoIds.sheikh,
      HelpVideoIds.parent,
      HelpVideoIds.cashier,
      HelpVideoIds.women,
    ]) {
      final v = HelpVideos.byId(id);
      expect(v, isNotNull, reason: id);
      expect(v!.section, HelpVideoSection.admin);
    }
    expect(HelpVideos.byId('لا_يوجد'), isNull);
  });

  test('حجم الفيديوهات كلها مجتمعة في الحدّ المقبول للتطبيق', () {
    final total = HelpVideos.all.fold<int>(0, (a, v) => a + File(v.asset).lengthSync() + File(v.poster).lengthSync());
    expect(total, lessThan(42 * 1024 * 1024));
  });

  test('نص المدة يُقرأ عربياً', () {
    const base = HelpVideo(id: 'x', section: HelpVideoSection.general, title: 't', description: 'd', seconds: 42);
    expect(base.durationLabel, '42 ثانية');
    expect(const HelpVideo(id: 'x', section: HelpVideoSection.general, title: 't', description: 'd', seconds: 60).durationLabel, 'دقيقة');
    expect(const HelpVideo(id: 'x', section: HelpVideoSection.general, title: 't', description: 'd', seconds: 120).durationLabel, 'دقيقتان');
    expect(const HelpVideo(id: 'x', section: HelpVideoSection.general, title: 't', description: 'd', seconds: 203).durationLabel, '3:23 دقيقة');
  });
}
