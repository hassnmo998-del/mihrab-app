import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';

/// زر الدرس للمشرف مقسوماً نصفين في شكل واحد: نصف «بدء الدرس» يسجّل من هذا الهاتف،
/// ونصف «رفع ملف صوتي» لمن سجّل الدرس بجهاز آخر ويضع ملفه هنا.
class LessonRecordSplitButton extends StatelessWidget {
  /// الدرس جارٍ الآن: نصف التسجيل يصير «متابعة البث».
  final bool isLive;
  final VoidCallback onRecord;
  final VoidCallback onImport;

  const LessonRecordSplitButton({
    super.key,
    required this.isLive,
    required this.onRecord,
    required this.onImport,
  });

  static const recordKey = ValueKey('lessonRecordHalf');
  static const importKey = ValueKey('lessonImportHalf');

  @override
  Widget build(BuildContext context) {
    final recordColor = isLive ? Colors.red : AppColors.emeraldPrimary;
    // النصف الآخر أغمق بدرجة من لون الثيم نفسه، فيُقرأ زراً واحداً بجزأين
    final importColor = Color.alphaBlend(Colors.black.withValues(alpha: 0.24), AppColors.emeraldPrimary);

    return Material(
      elevation: 2,
      color: Colors.transparent,
      shape: const StadiumBorder(),
      clipBehavior: Clip.antiAlias,
      child: IntrinsicHeight(
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Flexible(
              child: _Half(
                key: recordKey,
                color: recordColor,
                icon: Icons.mic,
                label: isLive ? 'متابعة البث 🔴' : 'بدء الدرس 🎙️',
                tooltip: isLive ? 'العودة إلى التسجيل الجاري' : 'تسجيل الدرس من هذا الهاتف',
                onTap: onRecord,
              ),
            ),
            Container(width: 1.5, color: Colors.white.withValues(alpha: 0.6)),
            Flexible(
              child: _Half(
                key: importKey,
                color: importColor,
                icon: Icons.upload_file_rounded,
                label: 'رفع ملف صوتي',
                tooltip: 'سُجّل الدرس بجهاز آخر؟ ارفع ملفه الصوتي من هنا',
                onTap: onImport,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Half extends StatelessWidget {
  final Color color;
  final IconData icon;
  final String label;
  final String tooltip;
  final VoidCallback onTap;

  const _Half({
    super.key,
    required this.color,
    required this.icon,
    required this.label,
    required this.tooltip,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: color,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 8),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, size: 16, color: Colors.white),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 13.5,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
