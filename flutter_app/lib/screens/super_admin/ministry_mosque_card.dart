import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/theme/app_theme.dart';
import '../../data/datasources/ministry_remote.dart';
import '../../models/models.dart';
import 'dialogs/delete_mosque_confirm_dialog.dart';

/// بطاقة جامع في لوحة المشرف العام. تُبنى من [MinistryMosqueRow]: القادم من الخادم
/// بصفحات (الأرقام محسوبة هناك)، أو المبني من النسخة المحلية حين لا ترقية في الخادم.
class MinistryMosqueCard extends StatelessWidget {
  final MinistryMosqueRow row;

  /// تاريخ تسجيله وكود التسجيل المستعمل، من سجل الأكواد إن وُجد.
  final String? regDate;
  final String usedToken;

  /// بعد حذف الجامع بنجاح (لتزيله القائمة دون إعادة تحميل).
  final VoidCallback? onDeleted;

  const MinistryMosqueCard({
    super.key,
    required this.row,
    this.regDate,
    this.usedToken = '',
    this.onDeleted,
  });

  static String? _day(DateTime? t) {
    if (t == null) return null;
    final l = t.toLocal();
    return '${l.year}-${l.month.toString().padLeft(2, '0')}-${l.day.toString().padLeft(2, '0')}';
  }

  Mosque _asMosque() => Mosque(
        id: row.id,
        name: row.name,
        city: row.city,
        address: row.address,
        gender: row.gender,
        accessCode: row.accessCode ?? '',
      );

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final women = row.isWomenSection;
    final accent = women ? Colors.purpleAccent : AppColors.emeraldPrimary;
    final last = _day(row.lastActivity);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: women
              ? Colors.purpleAccent.withValues(alpha: 0.3)
              : AppColors.emeraldPrimary.withValues(alpha: 0.25),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.mosque, size: 20, color: accent),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      row.name,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                    if (row.city.isNotEmpty || (row.address?.isNotEmpty ?? false))
                      Text(
                        '${row.city}${(row.address?.isNotEmpty ?? false) ? ' - ${row.address}' : ''}',
                        style: TextStyle(
                          fontSize: 12,
                          color: isDark ? Colors.white60 : Colors.black54,
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          // الشارات في سطر يلتفّ: كانت تزاحم الاسم على عرض الهاتف
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              _chip(
                women ? 'فرع نسائي' : 'جامع عام',
                color: (women ? Colors.purple : AppColors.emeraldPrimary).withValues(alpha: 0.1),
                textColor: women ? Colors.purple : AppColors.emeraldPrimary,
                bold: true,
              ),
              if (regDate != null && regDate!.isNotEmpty)
                _chip('سُجّل في $regDate', icon: Icons.calendar_today_outlined, isDark: isDark),
              _chip(
                last == null ? 'لا نشاط بعد' : 'آخر نشاط: $last',
                icon: Icons.bolt_outlined,
                isDark: isDark,
              ),
            ],
          ),
          const SizedBox(height: 14),
          // أكواد القسم النسائي لا تظهر للمشرف العام: تبقى عند إدارته وحدها.
          if (women)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: isDark ? Colors.black26 : Colors.purple.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.purpleAccent.withValues(alpha: 0.2)),
              ),
              child: const Row(
                children: [
                  Icon(Icons.lock_outline, size: 18, color: Colors.purpleAccent),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'كود هذا القسم عند إدارته وحدها، ولا يُعرض هنا.',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
            )
          else
            _codeBar(
              context,
              label: 'كود الباركود',
              code: row.accessCode ?? '',
              icon: Icons.qr_code_2,
              isDark: isDark,
              copiedMessage: 'تم نسخ كود باركود جامع (${row.name}): ${row.accessCode} 📋',
            ),
          if (usedToken.isNotEmpty) ...[
            const SizedBox(height: 8),
            _codeBar(
              context,
              label: 'الكود المستخدم للتسجيل',
              code: usedToken,
              icon: Icons.vpn_key_outlined,
              isDark: isDark,
              small: true,
              copiedMessage: 'تم نسخ كود التسجيل المستخدم ($usedToken) 📋',
            ),
          ],
          const SizedBox(height: 12),
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 8,
            runSpacing: 10,
            children: [
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  _chip('${row.halaqatCount} حلقات', icon: Icons.menu_book, isDark: isDark),
                  _chip('${row.sheikhsCount} مشايخ', icon: Icons.person, isDark: isDark),
                  _chip('${row.studentsCount} طلاب', icon: Icons.people, isDark: isDark),
                ],
              ),
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.redAccent,
                  side: BorderSide(color: Colors.redAccent.withValues(alpha: 0.6)),
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  visualDensity: VisualDensity.compact,
                ),
                icon: const Icon(Icons.delete_forever, size: 16),
                label: const Text(
                  'حذف الجامع بالكامل',
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                ),
                onPressed: () async {
                  final deleted = await showDialog<bool>(
                    context: context,
                    barrierDismissible: false,
                    builder: (_) => DeleteMosqueConfirmDialog(mosque: _asMosque()),
                  );
                  if (deleted == true) onDeleted?.call();
                },
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _chip(
    String text, {
    IconData? icon,
    Color? color,
    Color? textColor,
    bool bold = false,
    bool isDark = false,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color ?? (isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.05)),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 12, color: isDark ? Colors.white60 : Colors.black54),
            const SizedBox(width: 4),
          ],
          Text(
            text,
            style: TextStyle(
              fontSize: 11,
              fontWeight: bold ? FontWeight.bold : FontWeight.normal,
              color: textColor ?? (isDark ? Colors.white70 : Colors.black87),
            ),
          ),
        ],
      ),
    );
  }

  Widget _codeBar(
    BuildContext context, {
    required String label,
    required String code,
    required IconData icon,
    required bool isDark,
    required String copiedMessage,
    bool small = false,
  }) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 12, vertical: small ? 6 : 8),
      decoration: BoxDecoration(
        color: isDark ? Colors.black26 : Colors.grey[100],
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: isDark ? Colors.white12 : Colors.grey[300]!),
      ),
      child: Row(
        children: [
          Icon(icon, size: small ? 15 : 20, color: small ? null : AppColors.emeraldPrimary),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(fontSize: 11, color: isDark ? Colors.white60 : Colors.black54),
                ),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: AlignmentDirectional.centerStart,
                  child: Text(
                    code,
                    maxLines: 1,
                    textDirection: TextDirection.ltr,
                    style: TextStyle(
                      fontFamily: 'monospace',
                      fontWeight: small ? FontWeight.bold : FontWeight.w900,
                      fontSize: small ? 12 : 14,
                      letterSpacing: small ? 0 : 1,
                      color: small
                          ? (isDark ? Colors.white70 : Colors.black87)
                          : AppColors.emeraldPrimary,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          IconButton(
            tooltip: 'نسخ',
            visualDensity: VisualDensity.compact,
            icon: Icon(Icons.copy, size: small ? 14 : 16, color: AppColors.emeraldPrimary),
            onPressed: code.isEmpty
                ? null
                : () {
                    Clipboard.setData(ClipboardData(text: code));
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(copiedMessage), duration: const Duration(seconds: 2)),
                    );
                  },
          ),
        ],
      ),
    );
  }
}
