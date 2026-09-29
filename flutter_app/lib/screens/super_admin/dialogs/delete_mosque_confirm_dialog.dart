import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../models/models.dart';
import '../../../../services/data_service.dart';

class DeleteMosqueConfirmDialog extends StatefulWidget {
  final Mosque mosque;

  const DeleteMosqueConfirmDialog({
    super.key,
    required this.mosque,
  });

  @override
  State<DeleteMosqueConfirmDialog> createState() => _DeleteMosqueConfirmDialogState();
}

class _DeleteMosqueConfirmDialogState extends State<DeleteMosqueConfirmDialog> {
  Timer? _timer;
  int _secondsLeft = 10;
  bool _isDeleting = false;

  @override
  void initState() {
    super.initState();
    _startCountdown();
  }

  void _startCountdown() {
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_secondsLeft > 1) {
        if (mounted) {
          setState(() {
            _secondsLeft--;
          });
        }
      } else {
        if (mounted) {
          setState(() {
            _secondsLeft = 0;
          });
        }
        timer.cancel();
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final mosque = widget.mosque;

    return AlertDialog(
      backgroundColor: isDark ? const Color(0xFF1E1E24) : Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
        side: BorderSide(color: Colors.redAccent.withValues(alpha: 0.4), width: 1.5),
      ),
      titlePadding: const EdgeInsets.fromLTRB(24, 24, 24, 8),
      contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
      actionsPadding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.redAccent.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.warning_amber_rounded,
              color: Colors.redAccent,
              size: 28,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'تحذير شديد الخطورة!',
                  style: AppTypography.font(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.redAccent,
                  ),
                ),
                Text(
                  'حذف جامع بالكامل مع كافة بياناته',
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
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 8),
            // بطاقة تفاصيل المسجد المراد حذفه
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.grey[100],
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Colors.redAccent.withValues(alpha: 0.3)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.mosque, size: 20, color: AppColors.emeraldPrimary),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          mosque.name,
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  if ((mosque.address?.isNotEmpty ?? false) || mosque.city.isNotEmpty)
                    Text(
                      '${mosque.city} - ${mosque.address ?? ""}',
                      style: TextStyle(fontSize: 12, color: isDark ? Colors.white70 : Colors.black54),
                    ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.black12,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      'كود المسجد: ${mosque.accessCode}',
                      style: const TextStyle(fontFamily: 'monospace', fontWeight: FontWeight.bold, fontSize: 12),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            // قائمة ما سيتم حذفه وتطهيره
            Text(
              '⚠️ سيتم استئصال ومسح ما يلي نهائياً:',
              style: AppTypography.font(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.redAccent),
            ),
            const SizedBox(height: 8),
            _buildBulletItem('كافة الشيوخ والمعلمات التابعين للمسجد.', isDark),
            _buildBulletItem('كافة الحلقات القرآنية والمسابقات والفعاليات.', isDark),
            _buildBulletItem('سجلات الطلاب بالكامل وتاريخ التسميع والنقاط والحضور.', isDark),
            _buildBulletItem('أي جلسات دخول نشطة أو محفوظة لهذا الجامع على هذا الجهاز.', isDark),
            _buildBulletItem('حذف السجلات سحابياً من خوادم Supabase فوراً.', isDark),
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.redAccent.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Text(
                '⛔ هذا الإجراء نهائي ولا يمكن التراجع عنه أو استعادة البيانات بعد تأكيده إطلاقاً.',
                style: TextStyle(color: Colors.redAccent, fontSize: 11, fontWeight: FontWeight.w600),
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: 16),
            // مؤقت العد التنازلي (10 ثوانٍ)
            if (_secondsLeft > 0)
              Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.timer_outlined, size: 16, color: Colors.orange),
                      const SizedBox(width: 6),
                      Text(
                        'يرجى القراءة بتمعّن، زر التأكيد سيتفعّل بعد: $_secondsLeft ثوانٍ',
                        style: const TextStyle(fontSize: 12, color: Colors.orange, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: (10 - _secondsLeft) / 10.0,
                      backgroundColor: isDark ? Colors.white10 : Colors.black12,
                      valueColor: const AlwaysStoppedAnimation<Color>(Colors.orange),
                      minHeight: 4,
                    ),
                  ),
                ],
              )
            else
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.check_circle_outline, size: 16, color: Colors.redAccent),
                  const SizedBox(width: 6),
                  Text(
                    'أنت الآن مؤهل لتأكيد الحذف إذا كنت متأكداً تماماً',
                    style: TextStyle(fontSize: 12, color: isDark ? Colors.white70 : Colors.black87),
                  ),
                ],
              ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isDeleting ? null : () => Navigator.pop(context),
          child: const Text('إلغاء وتراجع'),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: _secondsLeft == 0 ? Colors.redAccent : Colors.grey[700],
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
          onPressed: (_secondsLeft > 0 || _isDeleting)
              ? null
              : () async {
                  setState(() => _isDeleting = true);
                  final data = context.read<DataService>();
                  final scaffoldMessenger = ScaffoldMessenger.of(context);
                  final navigator = Navigator.of(context);
                  final mosqueName = mosque.name;

                  try {
                    await data.deleteMosqueCompletely(mosque.id);
                    if (mounted) {
                      navigator.pop(true);
                      scaffoldMessenger.showSnackBar(
                        SnackBar(
                          content: Text('تم حذف جامع ($mosqueName) وكافة بياناته نهائياً بنجاح 🗑️'),
                          backgroundColor: Colors.redAccent,
                          duration: const Duration(seconds: 4),
                        ),
                      );
                    }
                  } catch (e) {
                    if (mounted) {
                      setState(() => _isDeleting = false);
                      scaffoldMessenger.showSnackBar(
                        SnackBar(content: Text('حدث خطأ أثناء الحذف: $e')),
                      );
                    }
                  }
                },
          child: _isDeleting
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                )
              : Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.delete_forever, size: 18),
                    const SizedBox(width: 6),
                    Text(
                      _secondsLeft > 0
                          ? 'انتظر ($_secondsLeft ث)...'
                          : 'أنا متأكد، احذف الجامع نهائياً',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
        ),
      ],
    );
  }

  Widget _buildBulletItem(String text, bool isDark) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('• ', style: TextStyle(color: Colors.redAccent, fontSize: 14, fontWeight: FontWeight.bold)),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 12,
                color: isDark ? Colors.white70 : Colors.black87,
                height: 1.3,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
