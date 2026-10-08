import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';

/// مصدر الصورة الشخصية (طالب، شيخ) لكل موضع يعرضها.
///
/// القيمة المحفوظة رابط، أو مسار ملف **على الجهاز الذي أضاف الصورة**. على جهاز آخر
/// الملف غير موجود، وفي المتصفح لا ملفات أصلاً؛ في الحالتين يعود `null` فتظهر الأحرف
/// الأولى بدل دائرة فارغة.
///
/// الصورة تُفكّ بحجم الدائرة التي تُعرض فيها لا بحجمها الأصلي: قائمة من عشرين طالباً
/// بصور كاميرا كاملة كانت تحجز مئات الميغابايت.
class ProfileImage {
  ProfileImage._();

  static final Map<String, bool> _found = {};
  static final Map<String, DateTime> _missingSince = {};

  /// يُنسى ما عُرف عن [path] (بعد حفظ صورة جديدة في المسار نفسه أو حذفها).
  static void forget(String path) {
    _found.remove(path);
    _missingSince.remove(path);
  }

  static bool _exists(String path) {
    if (_found[path] == true) return true;
    // ملف غائب يُعاد فحصه بعد نصف دقيقة، لا مع كل إعادة رسم
    final missing = _missingSince[path];
    if (missing != null && DateTime.now().difference(missing) < const Duration(seconds: 30)) {
      return false;
    }
    bool exists;
    try {
      exists = File(path).existsSync();
    } catch (_) {
      exists = false;
    }
    if (exists) {
      _found[path] = true;
      _missingSince.remove(path);
    } else {
      _missingSince[path] = DateTime.now();
    }
    return exists;
  }

  /// مصدر الصورة لدائرة نصف قطرها [radius]، أو `null` إن لم تكن هناك صورة تُعرض هنا.
  static ImageProvider? provider(String? url, {double radius = 24}) {
    final value = url?.trim() ?? '';
    if (value.isEmpty) return null;
    // ثلاثة أضعاف القطر تكفي أكثف الشاشات
    final width = (radius * 2 * 3).round().clamp(48, 512);

    if (value.startsWith('http://') || value.startsWith('https://')) {
      return ResizeImage(NetworkImage(value), width: width);
    }
    if (kIsWeb) return null;
    if (!_exists(value)) return null;
    return ResizeImage(FileImage(File(value)), width: width);
  }

  /// مصدر صورة اختيرت للتو (قبل الحفظ) لدائرة نصف قطرها [radius].
  static ImageProvider? fileProvider(File? file, {double radius = 24}) {
    if (file == null || kIsWeb) return null;
    return ResizeImage(FileImage(file), width: (radius * 2 * 3).round().clamp(48, 512));
  }
}
