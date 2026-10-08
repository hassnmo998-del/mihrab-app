import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';

import '../../theme/app_theme.dart';

class ImageHelper {
  static final ImagePicker _picker = ImagePicker();

  /// أطول ضلع للصورة الشخصية المحفوظة.
  static const int maxSide = 512;

  static const String unreadableMessage = 'تعذّرت قراءة هذه الصورة. اختر صورة بصيغة JPG أو PNG.';
  static const String genericMessage = 'تعذّرت إضافة الصورة. حاول مرة أخرى.';

  /// يختار صورة، يقصّها مربعة حيث يتوفر القصّ، ثم يحفظ نسخة مصغّرة منها في مجلد
  /// التطبيق ويعيدها. أي تعذّر يُبلَّغ عبر [onProblem] ويعود `null`؛ لا يُرمى شيء.
  ///
  /// كان يعيد ملف المعرض أو ملف الذاكرة المؤقتة نفسه: على ويندوز صورة الكاميرا
  /// بحجمها الكامل (المنتقي لا يصغّر هناك)، وعلى أندرويد ملف يمسحه النظام متى شاء.
  static Future<File?> pickAndCropImage({
    ImageSource source = ImageSource.gallery,
    void Function(String message)? onProblem,
  }) async {
    if (kIsWeb) return null;
    try {
      final XFile? pickedFile = await _picker.pickImage(
        source: source,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 85,
      );
      if (pickedFile == null) return null;

      var path = pickedFile.path;
      if (Platform.isAndroid || Platform.isIOS) {
        final cropped = await _crop(path);
        if (cropped == _cancelled) return null;
        if (cropped != null) path = cropped;
        // تعذّر فتح القصّ: تُستعمل الصورة كما اختيرت بدل أن تضيع
      }

      final stored = await storeNormalized(path);
      if (stored == null) onProblem?.call(unreadableMessage);
      return stored;
    } catch (e) {
      debugPrint('ImageHelper Error: $e');
      onProblem?.call(genericMessage);
      return null;
    }
  }

  static const String _cancelled = '\u0000cancelled';

  /// مسار الصورة المقصوصة، أو [_cancelled] إن ألغى المستخدم، أو `null` إن تعذّر القصّ.
  static Future<String?> _crop(String sourcePath) async {
    try {
      final CroppedFile? croppedFile = await ImageCropper().cropImage(
        sourcePath: sourcePath,
        compressFormat: ImageCompressFormat.jpg,
        compressQuality: 80,
        aspectRatio: const CropAspectRatio(ratioX: 1, ratioY: 1),
        uiSettings: [
          AndroidUiSettings(
            toolbarTitle: 'تعديل الصورة الشخصية',
            toolbarColor: AppColors.terracottaPrimary,
            toolbarWidgetColor: Colors.white,
            activeControlsWidgetColor: AppColors.terracottaPrimary,
            initAspectRatio: CropAspectRatioPreset.square,
            lockAspectRatio: true,
            hideBottomControls: false,
          ),
          IOSUiSettings(
            title: 'تعديل الصورة الشخصية',
            aspectRatioLockEnabled: true,
            resetAspectRatioEnabled: false,
          ),
        ],
      );
      return croppedFile == null ? _cancelled : croppedFile.path;
    } catch (e) {
      debugPrint('ImageHelper crop unavailable: $e');
      return null;
    }
  }

  /// يفكّ الصورة، يصغّرها حتى لا يتجاوز أطول ضلع [maxSide]، ويحفظها PNG في مجلد
  /// التطبيق. يعيد `null` إن لم يكن الملف صورة مقروءة.
  @visibleForTesting
  static Future<File?> storeNormalized(String sourcePath, {Directory? directory}) async {
    ui.ImmutableBuffer? buffer;
    ui.ImageDescriptor? descriptor;
    ui.Codec? codec;
    ui.Image? image;
    try {
      final bytes = await File(sourcePath).readAsBytes();
      if (bytes.isEmpty) return null;
      buffer = await ui.ImmutableBuffer.fromUint8List(bytes);
      descriptor = await ui.ImageDescriptor.encoded(buffer);
      final longest = math.max(descriptor.width, descriptor.height);
      final scale = longest > maxSide ? maxSide / longest : 1.0;
      codec = await descriptor.instantiateCodec(
        targetWidth: math.max(1, (descriptor.width * scale).round()),
        targetHeight: math.max(1, (descriptor.height * scale).round()),
      );
      image = (await codec.getNextFrame()).image;
      final png = await image.toByteData(format: ui.ImageByteFormat.png);
      if (png == null) return null;

      final dir = directory ??
          Directory('${(await getApplicationSupportDirectory()).path}${Platform.pathSeparator}profile_images');
      await dir.create(recursive: true);
      final name =
          'img_${DateTime.now().microsecondsSinceEpoch}_${math.Random().nextInt(1 << 32).toRadixString(36)}.png';
      final file = File('${dir.path}${Platform.pathSeparator}$name');
      await file.writeAsBytes(png.buffer.asUint8List(png.offsetInBytes, png.lengthInBytes), flush: true);
      return file;
    } catch (e) {
      debugPrint('ImageHelper: unreadable image ($e)');
      return null;
    } finally {
      image?.dispose();
      codec?.dispose();
      descriptor?.dispose();
      buffer?.dispose();
    }
  }
}
