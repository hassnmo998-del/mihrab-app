import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/image_helper.dart';
import '../../core/utils/profile_image.dart';

class ProfileImagePicker extends StatelessWidget {
  final File? selectedImageFile;
  final String? initialImageUrl;
  final String fallbackName;
  final double radius;
  final ValueChanged<File?> onImageChanged;
  final bool isEditable;

  const ProfileImagePicker({
    super.key,
    this.selectedImageFile,
    this.initialImageUrl,
    this.fallbackName = '',
    this.radius = 46,
    required this.onImageChanged,
    this.isEditable = true,
  });

  bool get _isDesktop =>
      !kIsWeb && (Platform.isWindows || Platform.isLinux || Platform.isMacOS);

  /// يختار صورة ويبلّغ بها؛ أي تعذّر يظهر رسالةً بدل أن يمرّ بصمت.
  Future<void> _pick(ScaffoldMessengerState? messenger, ImageSource source) async {
    final file = await ImageHelper.pickAndCropImage(
      source: source,
      onProblem: (message) => messenger?.showSnackBar(SnackBar(content: Text(message))),
    );
    if (file != null) onImageChanged(file);
  }

  void _onPickerTapped(BuildContext context) async {
    final hasImage = selectedImageFile != null ||
        (initialImageUrl != null && initialImageUrl!.isNotEmpty);
    // يُلتقط قبل أي انتظار: السياق قد يزول أثناء اختيار الصورة
    final messenger = ScaffoldMessenger.maybeOf(context);

    // إذا كنا على الويندوز وما في صورة سابقة: نفتح مستعرض الملفات فوراً
    if (_isDesktop && !hasImage) {
      await _pick(messenger, ImageSource.gallery);
      return;
    }

    // إذا في صورة (أو كنا على موبايل) بنعرض القائمة السريعة
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showModalBottomSheet(
      context: context,
      backgroundColor: isDark ? AppTheme.darkSurface : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: isDark ? Colors.white24 : Colors.black12,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 14),
              Text(
                'الصورة الشخصية',
                style: AppTypography.titleBold(context, fontSize: 16),
              ),
              const SizedBox(height: 12),
              ListTile(
                leading: Icon(Icons.photo_library_outlined, color: AppColors.terracottaPrimary),
                title: Text(
                  _isDesktop ? 'اختيار صورة من جهاز الكمبيوتر' : 'اختيار من المعرض',
                  style: AppTypography.bodyRegular(context, fontSize: 14),
                ),
                onTap: () {
                  Navigator.pop(ctx);
                  _pick(messenger, ImageSource.gallery);
                },
              ),
              // خيار الكاميرا يظهر فقط على الموبايل
              if (!_isDesktop)
                ListTile(
                  leading: Icon(Icons.camera_alt_outlined, color: AppColors.goldDark),
                  title: Text('التقاط عبر الكاميرا', style: AppTypography.bodyRegular(context, fontSize: 14)),
                  onTap: () {
                    Navigator.pop(ctx);
                    _pick(messenger, ImageSource.camera);
                  },
                ),
              if (hasImage) ...[
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.delete_outline, color: Colors.redAccent),
                  title: Text(
                    'إزالة الصورة الحالية',
                    style: AppTypography.bodyRegular(context, fontSize: 14, color: Colors.redAccent),
                  ),
                  onTap: () {
                    Navigator.pop(ctx);
                    onImageChanged(null);
                  },
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  ImageProvider? _resolveImageProvider() =>
      ProfileImage.fileProvider(selectedImageFile, radius: radius) ??
      ProfileImage.provider(initialImageUrl, radius: radius);

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final imageProvider = _resolveImageProvider();

    final firstLetter = fallbackName.trim().isNotEmpty
        ? fallbackName.trim().substring(0, 1)
        : '';

    return Center(
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: isDark ? Colors.white24 : AppColors.terracottaPrimary.withValues(alpha: 0.35),
                width: 2.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.08),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: CircleAvatar(
              radius: radius,
              backgroundColor: isDark
                  ? AppColors.obsidianEspresso
                  : AppColors.terracottaPrimary.withValues(alpha: 0.12),
              // الصورة فوق الحرف الأول: إن غابت أو تعذّر فكّها بقي الحرف ظاهراً
              foregroundImage: imageProvider,
              onForegroundImageError: imageProvider == null ? null : (_, __) {},
              child: firstLetter.isNotEmpty
                  ? Text(
                      firstLetter,
                      style: AppTypography.font(
                        fontSize: radius * 0.85,
                        fontWeight: FontWeight.bold,
                        color: AppColors.terracottaPrimary,
                      ),
                    )
                  : Icon(
                      Icons.person,
                      size: radius * 1.05,
                      color: isDark ? Colors.white54 : AppColors.terracottaPrimary,
                    ),
            ),
          ),
          // الصورة تُحفظ ملفاً على الجهاز نفسه، والمتصفح (نسخة الآيفون) لا يحفظ ملفات
          if (isEditable && !kIsWeb)
            Positioned(
              bottom: 0,
              left: 0,
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () => _onPickerTapped(context),
                  borderRadius: BorderRadius.circular(20),
                  child: Container(
                    padding: const EdgeInsets.all(7),
                    decoration: BoxDecoration(
                      color: AppColors.terracottaPrimary,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: isDark ? AppTheme.darkSurface : Colors.white,
                        width: 2.2,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.2),
                          blurRadius: 6,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.camera_alt,
                      size: 16,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}