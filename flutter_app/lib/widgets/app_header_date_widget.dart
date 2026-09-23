import 'package:flutter/material.dart';
import '../core/theme/app_colors.dart';
import '../core/theme/app_typography.dart';
import '../core/utils/hijri_date_helper.dart';

/// Interactive Header Date Widget placed under the app title.
/// Displays Hijri date by default and toggles to Gregorian on tap.
class AppHeaderDateWidget extends StatefulWidget {
  /// Smaller type for the slim phone header.
  final bool compact;

  const AppHeaderDateWidget({super.key, this.compact = false});

  @override
  State<AppHeaderDateWidget> createState() => _AppHeaderDateWidgetState();
}

class _AppHeaderDateWidgetState extends State<AppHeaderDateWidget> {
  bool _isHijri = true;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final now = DateTime.now();

    final formattedDate = _isHijri
        ? HijriDateHelper.formatHijri(now, includeSuffix: false)
        : HijriDateHelper.formatGregorian(now, includeSuffix: false);

    final badgeColor = _isHijri
        ? (isDark ? AppColors.emeraldLight : AppColors.emeraldPrimary)
        : (isDark ? AppColors.sunsetGlow : AppColors.terracottaPrimary);

    return InkWell(
      onTap: () {
        setState(() {
          _isHijri = !_isHijri;
        });
      },
      borderRadius: BorderRadius.circular(8),
      child: Tooltip(
        message: 'انقر للتحويل بين التقويم الهجري والميلادي',
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 2.0, horizontal: 2.0),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Icon(
                Icons.calendar_month_rounded,
                size: widget.compact ? 12 : 14,
                color: badgeColor.withValues(alpha: 0.95),
              ),
              const SizedBox(width: 4),
              // التاريخ الكامل أطول من العرض المتاح في الشاشات الضيّقة، فيجب أن
              // ينضغط بنقاط الحذف لا أن يفيض خارج الهيدر.
              Flexible(
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 250),
                  transitionBuilder:
                      (Widget child, Animation<double> animation) {
                        return FadeTransition(
                          opacity: animation,
                          child: SlideTransition(
                            position: Tween<Offset>(
                              begin: const Offset(0.0, 0.2),
                              end: Offset.zero,
                            ).animate(animation),
                            child: child,
                          ),
                        );
                      },
                  child: Text(
                    formattedDate,
                    key: ValueKey<bool>(_isHijri),
                    maxLines: 1,
                    softWrap: false,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.font(
                      fontSize: widget.compact ? 11.5 : 13,
                      fontWeight: FontWeight.w700,
                      color: isDark
                          ? Colors.white.withValues(alpha: 0.9)
                          : AppColors.lightTextPrimary,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 4),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                decoration: BoxDecoration(
                  color: badgeColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(
                    color: badgeColor.withValues(alpha: 0.25),
                    width: 0.5,
                  ),
                ),
                child: Text(
                  _isHijri ? 'هـ' : 'م',
                  style: AppTypography.font(
                    fontSize: 9.5,
                    fontWeight: FontWeight.bold,
                    color: badgeColor,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
