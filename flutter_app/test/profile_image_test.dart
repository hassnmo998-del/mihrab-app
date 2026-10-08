import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_app/core/utils/image_helper.dart';
import 'package:flutter_app/core/utils/profile_image.dart';
import 'package:flutter_app/presentation/widgets/profile_image_picker.dart';

/// الصورة الشخصية: تُحفظ مصغّرة في مجلد التطبيق، وتُعرض بحجم دائرتها، وغيابها أو
/// تلفها يُظهر الحرف الأول بدل دائرة فارغة أو خطأ.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory dir;
  String at(String name) => '${dir.path}${Platform.pathSeparator}$name';

  setUp(() => dir = Directory.systemTemp.createTempSync('mihrab_profile_image_'));
  tearDown(() {
    try {
      dir.deleteSync(recursive: true);
    } catch (_) {}
  });

  /// صورة PNG حقيقية بالأبعاد المطلوبة.
  Future<File> photo(String name, int width, int height) async {
    final recorder = ui.PictureRecorder();
    Canvas(recorder).drawRect(
      Rect.fromLTWH(0, 0, width.toDouble(), height.toDouble()),
      Paint()..color = const Color(0xFF2E7D32),
    );
    final image = await recorder.endRecording().toImage(width, height);
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    image.dispose();
    return File(at(name))..writeAsBytesSync(bytes!.buffer.asUint8List());
  }

  Future<Size> sizeOf(File file) async {
    final buffer = await ui.ImmutableBuffer.fromUint8List(file.readAsBytesSync());
    final descriptor = await ui.ImageDescriptor.encoded(buffer);
    final size = Size(descriptor.width.toDouble(), descriptor.height.toDouble());
    descriptor.dispose();
    buffer.dispose();
    return size;
  }

  group('حفظ الصورة المختارة', () {
    testWidgets('صورة كاميرا كبيرة تُحفظ مصغّرة بنسبتها، في مجلد التطبيق لا في مكانها الأصلي', (tester) async {
      await tester.runAsync(() async {
        final big = await photo('camera.png', 4000, 3000);
        final target = Directory(at('profile_images'));

        final stored = await ImageHelper.storeNormalized(big.path, directory: target);

        expect(stored, isNotNull);
        expect(stored!.parent.path, target.path);
        expect(stored.path, isNot(big.path));
        expect(await sizeOf(stored), const Size(512, 384));
        expect(stored.lengthSync(), lessThan(big.lengthSync()));
        // الأصل لا يُمسّ
        expect(big.existsSync(), isTrue);
      });
    });

    testWidgets('صورة طولية وصورة صغيرة: الطولية تُصغَّر على ارتفاعها، والصغيرة لا تُكبَّر', (tester) async {
      await tester.runAsync(() async {
        final tall = await ImageHelper.storeNormalized((await photo('tall.png', 1000, 2000)).path,
            directory: Directory(at('out')));
        final small = await ImageHelper.storeNormalized((await photo('small.png', 120, 90)).path,
            directory: Directory(at('out')));

        expect(await sizeOf(tall!), const Size(256, 512));
        expect(await sizeOf(small!), const Size(120, 90));
        expect(tall.path, isNot(small.path));
      });
    });

    testWidgets('ملف ليس صورة، أو فارغ، أو غير موجود: لا شيء يُحفظ ولا خطأ يُرمى', (tester) async {
      await tester.runAsync(() async {
        final notImage = File(at('document.pdf'))..writeAsStringSync('%PDF-1.4 not an image at all');
        final empty = File(at('empty.jpg'))..writeAsBytesSync(const []);
        final out = Directory(at('out'));

        expect(await ImageHelper.storeNormalized(notImage.path, directory: out), isNull);
        expect(await ImageHelper.storeNormalized(empty.path, directory: out), isNull);
        expect(await ImageHelper.storeNormalized(at('missing.png'), directory: out), isNull);
        expect(out.existsSync() ? out.listSync() : const [], isEmpty);
      });
    });
  });

  group('مصدر الصورة عند العرض', () {
    test('لا قيمة، أو مسار ملف غير موجود على هذا الجهاز: لا صورة (يظهر الحرف)', () {
      expect(ProfileImage.provider(null), isNull);
      expect(ProfileImage.provider('   '), isNull);
      // مسار من هاتف آخر أو من ويندوز آخر
      expect(ProfileImage.provider('/data/user/0/com.masjed.mihrab/cache/scaled_1.jpg'), isNull);
      expect(ProfileImage.provider(r'C:\Users\someone\Pictures\photo.jpg'), isNull);
    });

    test('ملف موجود ورابط: يُفكّان بحجم الدائرة لا بالحجم الأصلي', () {
      final file = File(at('here.png'))..writeAsBytesSync(const [1, 2, 3]);

      final local = ProfileImage.provider(file.path, radius: 20);
      expect(local, isA<ResizeImage>());
      expect((local! as ResizeImage).width, 120);
      expect((local as ResizeImage).imageProvider, isA<FileImage>());

      final remote = ProfileImage.provider('https://example.org/a.jpg', radius: 46);
      expect((remote! as ResizeImage).width, 276);
      expect((remote as ResizeImage).imageProvider, isA<NetworkImage>());

      // دائرة كبيرة جداً لا تتجاوز الحدّ
      expect((ProfileImage.provider(file.path, radius: 400)! as ResizeImage).width, 512);
    });

    test('صورة أُضيفت بعد أن كان مسارها غائباً تظهر حين يُنسى ما عُرف عنه', () {
      final path = at('later.png');
      expect(ProfileImage.provider(path), isNull);

      File(path).writeAsBytesSync(const [1, 2, 3]);
      ProfileImage.forget(path);

      expect(ProfileImage.provider(path), isNotNull);
    });
  });

  group('الدائرة في الواجهة', () {
    Future<void> pump(WidgetTester tester, {String? url, File? file}) => tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: ProfileImagePicker(
                initialImageUrl: url,
                selectedImageFile: file,
                fallbackName: 'معاذ بن جبل',
                onImageChanged: (_) {},
              ),
            ),
          ),
        );

    testWidgets('مسار غائب: الحرف الأول ظاهر ولا صورة تُحمَّل ولا خطأ', (tester) async {
      await pump(tester, url: '/data/user/0/com.masjed.mihrab/cache/gone.jpg');
      await tester.pump();

      expect(find.text('م'), findsOneWidget);
      expect(tester.widget<CircleAvatar>(find.byType(CircleAvatar)).foregroundImage, isNull);
      expect(tester.takeException(), isNull);
    });

    testWidgets('ملف تالف (موجود وليس صورة): يبقى الحرف الأول ولا يصل الخطأ إلى الواجهة', (tester) async {
      final broken = File(at('broken.jpg'))..writeAsStringSync('this is not an image');
      await pump(tester, url: broken.path);
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 300)));
      await tester.pump();

      expect(find.text('م'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('صورة سليمة: تُحمَّل فوق الحرف بحجم الدائرة', (tester) async {
      late File good;
      await tester.runAsync(() async => good = await photo('good.png', 900, 900));
      await pump(tester, file: good);
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 300)));
      await tester.pump();

      final avatar = tester.widget<CircleAvatar>(find.byType(CircleAvatar));
      expect(avatar.foregroundImage, isA<ResizeImage>());
      expect((avatar.foregroundImage! as ResizeImage).width, 276);
      expect(tester.takeException(), isNull);
    });
  });
}
