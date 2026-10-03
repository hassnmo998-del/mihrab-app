import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_app/screens/discover/dialogs/adhan_sound_picker_dialog.dart';
import 'package:flutter_app/services/adhan_audio_cache_manager.dart';
import 'package:flutter_app/services/adhan_data.dart';
import 'package:flutter_app/services/adhan_service.dart';
import 'package:flutter_app/services/update/update_downloader.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// نافذة اختيار صوت الأذان: التحميل والاختيار بلا نافذة «فحص الإنترنت» ولا رفض.
/// (لا شبكة في هذه الاختبارات: كل طلب يفشل، فالتنزيل يبقى «جارياً» كما على شبكة مقطوعة.)
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final cache = AdhanAudioCacheManager.instance;
  final service = AdhanService.instance;
  late Directory root;

  Future<void> openPicker(WidgetTester tester, Size size) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.runAsync(() async {
      root = Directory.systemTemp.createTempSync('mihrab_adhan_picker');
      final dir = Directory('${root.path}${Platform.pathSeparator}v2');
      await cache.debugConfigure(
        dir: dir,
        downloader: UpdateDownloader(dir: dir, connectTimeout: const Duration(seconds: 1)),
      );
      await service.setSelectedSound(AdhanData.defaultSound);
    });
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Builder(
          builder: (context) => Center(
            child: ElevatedButton(
              onPressed: () => AdhanSoundPickerDialog.show(context, isDark: false),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    ));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
  }

  /// يوقف التنزيل الجاري ويصرف مؤقتاته قبل نهاية الاختبار.
  Future<void> close(WidgetTester tester) async {
    cache.dispose();
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 1500)));
    await tester.pump(const Duration(seconds: 3));
    await tester.pumpWidget(const SizedBox.shrink());
    try {
      root.deleteSync(recursive: true);
    } catch (_) {}
  }

  setUp(() => SharedPreferences.setMockInitialValues({}));

  for (final (name, size) in [('هاتف ضيق', const Size(320, 640)), ('لابتوب', const Size(1366, 768))]) {
    testWidgets('تُعرض بلا تجاوز وفيها الأصوات كلها ($name)', (tester) async {
      await openPicker(tester, size);

      expect(tester.takeException(), isNull);
      expect(find.text('${AdhanData.allSounds.length} صوت'), findsOneWidget);
      expect(find.text(AdhanData.defaultSound.title), findsOneWidget);
      // الافتراضي وحده «محلي»: مضمَّن في التطبيق
      expect(find.text('محلي'), findsOneWidget);
      await close(tester);
    });
  }

  testWidgets('زر التحميل يبدأ التنزيل فوراً: لا فحص إنترنت ولا رفض', (tester) async {
    await openPicker(tester, const Size(412, 900));
    final second = AdhanData.allSounds[1];

    await tester.tap(find.byIcon(Icons.download_rounded).first);
    await tester.pump();

    expect(cache.activeDownloadingIdsNotifier.value, {second.id});
    expect(find.textContaining('جاري تحميل أذان ${second.title}'), findsOneWidget);
    expect(find.text('جاري التحقق من توفر الإنترنت...'), findsNothing);
    expect(find.text('لا يوجد اتصال بالإنترنت'), findsNothing);
    // الصف يعرض التقدم بدل زر التحميل
    expect(find.text('0%'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await close(tester);
  });

  testWidgets('اختيار صوت غير محمَّل: يُحفظ الطلب ويبقى الأذان الحالي حتى يكتمل', (tester) async {
    await openPicker(tester, const Size(412, 900));
    final second = AdhanData.allSounds[1];

    await tester.tap(find.text(second.title));
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 100)));
    await tester.pumpAndSettle();

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString(AdhanAudioCacheManager.pendingTargetPrefKey), second.id);
    expect(prefs.getStringList(AdhanAudioCacheManager.pendingQueuePrefKey), contains(second.id));
    expect(service.selectedSoundNotifier.value.id, AdhanAudioCacheManager.defaultSoundId);
    expect(find.byType(AdhanSoundPickerDialog), findsNothing); // أُغلقت النافذة
    expect(find.byType(AlertDialog), findsNothing);
    expect(find.textContaining('بدأ تحميل أذان ${second.title}'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await close(tester);
  });

  testWidgets('اختيار الصوت المضمَّن يُعتمد فوراً', (tester) async {
    await openPicker(tester, const Size(412, 900));

    await tester.tap(find.text(AdhanData.defaultSound.title));
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
    await tester.pumpAndSettle();

    expect(find.byType(AdhanSoundPickerDialog), findsNothing);
    expect(find.textContaining('تم تعيين أذان ${AdhanData.defaultSound.title}'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await close(tester);
  });
}
