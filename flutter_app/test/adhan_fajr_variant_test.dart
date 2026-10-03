import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_app/models/adhan_sound.dart';
import 'package:flutter_app/services/adhan_audio_cache_manager.dart';
import 'package:flutter_app/services/adhan_data.dart';
import 'package:flutter_app/services/adhan_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/flaky_http_server.dart';

/// «الصلاة خير من النوم» للفجر وحده: أي ملف يُسلَّم للمؤذن لأي صلاة.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final cache = AdhanAudioCacheManager.instance;
  final service = AdhanService.instance;
  const fajrRecordings = {
    'iconic_makkah_ali_mullah',
    'iconic_makkah_yunus_khoja',
    'iconic_madinah_hakim',
    'iconic_alafasy_fajr',
  };

  String sha(String path) => sha256.convert(File(path).readAsBytesSync()).toString();

  group('الكتالوج والملفات المضمَّنة', () {
    test('التسجيلات التي فيها جملة الفجر لها ملفان، والباقي ملف واحد', () {
      final withFajr = AdhanData.allSounds.where((s) => s.hasFajrVariant).map((s) => s.id).toSet();
      // العفاسي تسجيله عادي، ويستعير للفجر تسجيل الفجر الذي له في المدخل الآخر
      expect(withFajr, {...fajrRecordings, 'iconic_alafasy'});
      expect(AdhanData.getById('iconic_alafasy').fajrUrl, AdhanData.getById('iconic_alafasy_fajr').fajrUrl);

      for (final sound in AdhanData.allSounds) {
        expect(sound.audioBytes, greaterThan(500 * 1024), reason: sound.id);
        expect(sound.audioSha256, hasLength(64), reason: sound.id);
        expect(sound.durationSeconds, greaterThan(100), reason: sound.id);
        if (sound.hasFajrVariant) {
          // ملف الفجر أطول: فيه الجملتان اللتان حُذفتا من العادي
          if (fajrRecordings.contains(sound.id)) {
            expect(sound.fajrBytes, greaterThan(sound.audioBytes), reason: sound.id);
          }
          expect(sound.fajrSha256, hasLength(64), reason: sound.id);
          expect(sound.fajrUrl, isNot(sound.audioUrl), reason: sound.id);
        }
      }
    });

    test('كل الملفات على خادمنا واسمها يحمل بصمتها، لا على archive.org', () {
      for (final sound in AdhanData.allSounds) {
        for (final (url, hash) in [
          (sound.audioUrl, sound.audioSha256),
          if (sound.hasFajrVariant) (sound.fajrUrl!, sound.fajrSha256),
        ]) {
          expect(url, startsWith('https://mltxsmonudbtnrloqawf.supabase.co/storage/v1/object/public/adhan/'));
          expect(url, endsWith('-${hash.substring(0, 8)}.mp3'), reason: sound.id);
        }
      }
    });

    test('الأذان الافتراضي المضمَّن (Flutter وأندرويد) هو ملفا الكتالوج نفسهما', () {
      final def = AdhanData.defaultSound;
      expect(def.id, AdhanAudioCacheManager.defaultSoundId);
      expect(sha('assets/audio/default_adhan.mp3'), def.audioSha256);
      expect(sha('assets/audio/default_adhan_fajr.mp3'), def.fajrSha256);
      expect(sha('android/app/src/main/res/raw/adhan_default.mp3'), def.audioSha256);
      expect(sha('android/app/src/main/res/raw/adhan_default_fajr.mp3'), def.fajrSha256);
    });

    test('لكل صوت غير الافتراضي معاينة مضمَّنة تُسمع بلا إنترنت', () {
      for (final sound in AdhanData.allSounds.skip(1)) {
        final clip = File('assets/audio/previews/${sound.id}.mp3');
        expect(clip.existsSync(), isTrue, reason: sound.id);
        expect(clip.lengthSync(), inInclusiveRange(40 * 1024, 220 * 1024), reason: sound.id);
      }
      final extra = Directory('assets/audio/previews').listSync().length;
      expect(extra, AdhanData.allSounds.length - 1);
    });

    test('الأذان الافتراضي: عادي لكل الصلوات وملف الفجر للفجر', () {
      final def = AdhanData.defaultSound;
      expect(cache.sourceFor(def).toString(), contains('audio/default_adhan.mp3'));
      expect(cache.sourceFor(def, fajr: true).toString(), contains('audio/default_adhan_fajr.mp3'));
      // مضمَّن في التطبيق: أندرويد يشغّله من res/raw بلا مسار
      expect(cache.nativePath(def, fajr: false), isNull);
      expect(cache.nativePath(def, fajr: true), isNull);
    });
  });

  test('الفجر وحده يأخذ ملف الفجر', () {
    expect(AdhanService.isFajrPrayer('الفجر'), isTrue);
    expect(AdhanService.isFajrPrayer('الفجر (غداً)'), isTrue);
    for (final prayer in ['الظهر', 'العصر', 'المغرب', 'العشاء', 'الشروق']) {
      expect(AdhanService.isFajrPrayer(prayer), isFalse, reason: prayer);
    }
  });

  group('ما يُسلَّم لمشغّل أندرويد', () {
    late Directory root;
    late Directory dir;
    late Directory legacyDir;

    File place(String url, int bytes) {
      final file = File('${dir.path}${Platform.pathSeparator}${Uri.parse(url).pathSegments.last}');
      file.createSync(recursive: true);
      final handle = file.openSync(mode: FileMode.write)..truncateSync(bytes);
      handle.closeSync();
      return file;
    }

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      root = Directory.systemTemp.createTempSync('mihrab_adhan_paths');
      dir = Directory('${root.path}${Platform.pathSeparator}v2');
      legacyDir = Directory('${root.path}${Platform.pathSeparator}adhan_audio')..createSync();
      await cache.debugConfigure(dir: dir, legacyDir: legacyDir);
    });

    tearDown(() {
      cache.dispose();
      service.dispose();
      try {
        root.deleteSync(recursive: true);
      } catch (_) {}
    });

    test('مؤذن بتسجيل فجر: مسار للعادي ومسار للفجر', () async {
      final sound = AdhanData.getById('iconic_makkah_yunus_khoja');
      final regular = place(sound.audioUrl, sound.audioBytes);
      final fajr = place(sound.fajrUrl!, sound.fajrBytes);
      await cache.refreshDownloadedCache();
      SharedPreferences.setMockInitialValues({'adhan_selected_sound_path': 'C:/old/one-file-for-all.mp3'});

      await service.setSelectedSound(sound);

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('adhan_selected_sound_id'), sound.id);
      expect(prefs.getString('adhan_sound_regular_path'), regular.path);
      expect(prefs.getString('adhan_sound_fajr_path'), fajr.path);
      // مفتاح «ملف واحد لكل الصلوات» القديم يُزال
      expect(prefs.getString('adhan_selected_sound_path'), isNull);
    });

    test('مؤذن بلا تسجيل فجر: مسار العادي فقط، فيُؤذَّن به للفجر أيضاً', () async {
      final sound = AdhanData.getById('iconic_qatami');
      final regular = place(sound.audioUrl, sound.audioBytes);
      await cache.refreshDownloadedCache();

      await service.setSelectedSound(sound);

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('adhan_sound_regular_path'), regular.path);
      expect(prefs.getString('adhan_sound_fajr_path'), isNull);
    });

    test('العودة إلى الأذان الافتراضي تمسح المسارين: يُشغَّل المضمَّن', () async {
      final sound = AdhanData.getById('iconic_makkah_yunus_khoja');
      place(sound.audioUrl, sound.audioBytes);
      place(sound.fajrUrl!, sound.fajrBytes);
      await cache.refreshDownloadedCache();
      await service.setSelectedSound(sound);

      await service.setSelectedSound(AdhanData.defaultSound);

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('adhan_sound_regular_path'), isNull);
      expect(prefs.getString('adhan_sound_fajr_path'), isNull);
    });

    test('ملف ناقص الحجم لا يُسلَّم للمشغّل', () async {
      final sound = AdhanData.getById('iconic_qatami');
      place(sound.audioUrl, sound.audioBytes - 1);
      await cache.refreshDownloadedCache();

      expect(cache.isSoundDownloaded(sound.id), isFalse);
      expect(cache.nativePath(sound, fajr: false), isNull);
      expect(cache.sourceFor(sound), isNull);
    });

    test('تسجيل قديم لمؤذن مختار: يبقى يُؤذَّن به إلى أن يصل الملفان', () async {
      final sound = AdhanData.getById('iconic_madinah_hakim');
      final legacy = File('${legacyDir.path}${Platform.pathSeparator}${sound.id}.mp3')
        ..writeAsBytesSync(pseudoRandomBytes(120 * 1024));
      await cache.refreshDownloadedCache();
      SharedPreferences.setMockInitialValues({'adhan_selected_sound_id': sound.id});

      await service.setSelectedSound(sound);
      var prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('adhan_sound_regular_path'), legacy.path);
      expect(prefs.getString('adhan_sound_fajr_path'), isNull);

      // وصل الملفان: المسارات تنتقل إليهما
      final regular = place(sound.audioUrl, sound.audioBytes);
      final fajr = place(sound.fajrUrl!, sound.fajrBytes);
      await service.setSelectedSound(sound);
      prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('adhan_sound_regular_path'), regular.path);
      expect(prefs.getString('adhan_sound_fajr_path'), fajr.path);
    });
  });

  group('اختيار مؤذن لم يُحمَّل بعد', () {
    late FlakyHttpServer server;
    late Directory root;

    setUp(() async {
      HttpOverrides.global = null;
      SharedPreferences.setMockInitialValues({});
      server = FlakyHttpServer();
      await server.start();
      root = Directory.systemTemp.createTempSync('mihrab_adhan_pick');
    });

    tearDown(() async {
      cache.dispose();
      service.dispose();
      await server.stop();
      try {
        root.deleteSync(recursive: true);
      } catch (_) {}
    });

    test('يصير صوت الأذان حين يكتمل تحميله، لا قبله', () async {
      final bytes = pseudoRandomBytes(200 * 1024);
      server.serve('/qatami.mp3', bytes);
      // معرّف حقيقي من الكتالوج بملف يخدمه خادم الاختبار
      final sound = AdhanSound(
        id: 'iconic_qatami',
        title: 'ناصر القطامي',
        category: 'اختبار',
        muezzinOrLocation: 'اختبار',
        audioUrl: server.url('/qatami.mp3'),
        audioBytes: bytes.length,
        audioSha256: sha256.convert(bytes).toString(),
        durationSeconds: 130,
      );
      await cache.debugConfigure(dir: Directory('${root.path}${Platform.pathSeparator}v2'), catalog: [sound]);
      await service.setSelectedSound(AdhanData.defaultSound);

      // كما تفعل نافذة اختيار الصوت
      await cache.queuePendingDownload(sound.id, isTargetSound: true);
      expect(service.selectedSoundNotifier.value.id, AdhanAudioCacheManager.defaultSoundId);
      expect(await cache.downloadSound(sound: sound), isTrue);
      await Future<void>.delayed(const Duration(milliseconds: 50));

      final prefs = await SharedPreferences.getInstance();
      expect(service.selectedSoundNotifier.value.id, 'iconic_qatami');
      expect(prefs.getString('adhan_selected_sound_id'), 'iconic_qatami');
      expect(prefs.getString(AdhanAudioCacheManager.pendingTargetPrefKey), isNull);
    });
  });
}
