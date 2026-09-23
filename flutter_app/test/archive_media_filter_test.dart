import 'package:flutter_app/core/utils/app_file_launcher.dart';
import 'package:flutter_app/models/models.dart';
import 'package:flutter_test/flutter_test.dart';

/// اختبارات فلتر نوع التسجيل في الأرشيف (الكل / فيديو / صوت).
///
/// حقل `videoRecordUrl` يحمل أي مرفق — فيديو أو مستند أو رابط — لذلك يعتمد
/// الفلتر على تصنيف المرفق لا على وجود القيمة، وهذا ما تحرسه هذه الاختبارات.
void main() {
  CommunityEvent event({String? audio, String? video}) => CommunityEvent(
        id: 'e1',
        mosqueId: 'm1',
        title: 'درس',
        description: 'وصف',
        eventType: 'lesson',
        targetAudience: 'general',
        organizerType: 'sheikh',
        organizerName: 'أبو عبادة',
        eventDateTime: DateTime(2026, 9, 21),
        audioRecordUrl: audio,
        videoRecordUrl: video,
      );

  /// نفس شرط الفلتر المطبّق في شاشة الأرشيف.
  bool isVideo(CommunityEvent e) {
    final url = e.videoRecordUrl;
    if (url == null || url.trim().isEmpty) return false;
    return AppFileLauncher.getAttachmentInfo(url).type ==
        AppAttachmentType.video;
  }

  group('تصنيف الفيديو في الأرشيف', () {
    test('مرجع فيديو من الأرشيف السحابي يُحتسب فيديو', () {
      expect(isVideo(event(video: 'tg:video:BAACAgQAAxkBAAI')), isTrue);
    });

    test('روابط وملفات الفيديو المباشرة تُحتسب فيديو', () {
      expect(isVideo(event(video: 'https://cdn.example.com/lesson.mp4')), isTrue);
      expect(isVideo(event(video: 'https://youtu.be/abc123')), isTrue);
      expect(isVideo(event(video: r'D:\دروس\lesson.mkv')), isTrue);
    });

    test('المستندات والروابط العامة لا تُحتسب فيديو رغم وجودها بنفس الحقل', () {
      expect(isVideo(event(video: 'https://example.com/notes.pdf')), isFalse);
      expect(isVideo(event(video: 'https://example.com/article')), isFalse);
      expect(isVideo(event(video: r'C:\ملفات\شرح.docx')), isFalse);
    });

    test('مرجع صوتي مرفق بالحقل نفسه لا يُحتسب فيديو', () {
      expect(isVideo(event(video: 'tg:audio:BAACAgQAAxkBAAI')), isFalse);
    });

    test('الدرس بلا مرفق ليس فيديو', () {
      expect(isVideo(event()), isFalse);
      expect(isVideo(event(video: '   ')), isFalse);
    });
  });

  group('تصنيف الصوت في الأرشيف', () {
    test('hasAudio يميّز التسجيلات الصوتية وحدها', () {
      expect(event(audio: 'tg:audio:XYZ').hasAudio, isTrue);
      expect(event(video: 'tg:video:XYZ').hasAudio, isFalse);
      expect(event().hasAudio, isFalse);
    });

    test('الدرس قد يحمل صوتاً وفيديو معاً فيظهر في الفلترين', () {
      final both = event(audio: 'tg:audio:A1', video: 'tg:video:V1');
      expect(both.hasAudio, isTrue);
      expect(isVideo(both), isTrue);
    });
  });
}
