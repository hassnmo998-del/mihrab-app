import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:image_picker/image_picker.dart';
import '../../theme/app_theme.dart';

class ImageHelper {
  static final ImagePicker _picker = ImagePicker();

  /// التقاط صورة وقصها بنسبة 1:1 مربعة ومضغوطة
  static Future<File?> pickAndCropImage({
    ImageSource source = ImageSource.gallery,
  }) async {
    try {
      // 1. اختيار الصورة مع تحديد أبعاد وجودة أولية لتوفير المساحة
      final XFile? pickedFile = await _picker.pickImage(
        source: source,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 85,
      );

      if (pickedFile == null) return null;

      // 2. إذا كنا على بيئة تدعم واجهة القص (أندرويد / iOS)
      if (!kIsWeb && (Platform.isAndroid || Platform.isIOS)) {
        final CroppedFile? croppedFile = await ImageCropper().cropImage(
          sourcePath: pickedFile.path,
          compressFormat: ImageCompressFormat.jpg,
          compressQuality: 80, // ضغط الحجم ليصبح بين 50 إلى 80 كيلوبايت
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

        if (croppedFile == null) return null; // ألغى المستخدم عملية القص
        return File(croppedFile.path);
      }

      // 3. على بيئة Windows Desktop: إرجاع ملف الصورة مباشرة لتجنب أي تعارض
      return File(pickedFile.path);
    } catch (e) {
      debugPrint('ImageHelper Error: $e');
      return null;
    }
  }
}