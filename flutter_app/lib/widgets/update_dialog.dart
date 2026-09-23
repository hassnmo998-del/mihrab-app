import 'package:flutter/material.dart';

import '../services/app_update_service.dart';

// ─────────────────────────────────────────────
// حالات واجهة الحوار
// ─────────────────────────────────────────────

/// يُعبّر عن الحالة الحالية لعملية التحديث داخل الحوار.
enum UpdateDialogState {
  /// الحالة الافتراضية: في انتظار اختيار المستخدم
  idle,

  /// جارٍ التنزيل
  downloading,

  /// اكتمل التنزيل والتثبيت بنجاح
  done,

  /// حدث خطأ أثناء التنزيل أو التثبيت
  error,
}

// ─────────────────────────────────────────────
// UpdateDialog — حوار التحديث
// ─────────────────────────────────────────────

/// حوار جميل بتصميم Material يعرض معلومات الإصدار الجديد باللغة العربية.
///
/// الاستخدام:
/// ```dart
/// await UpdateDialog.show(context, updateInfo, AppUpdateService.instance);
/// ```
class UpdateDialog extends StatefulWidget {
  /// معلومات الإصدار الجديد
  final UpdateInfo info;

  /// مرجع لخدمة التحديث لتنفيذ التنزيل وتجاهل الإصدار
  final AppUpdateService service;

  const UpdateDialog({
    super.key,
    required this.info,
    required this.service,
  });

  /// طريقة مساعدة لعرض الحوار بدون الحاجة لإنشاء instance يدوياً.
  static Future<void> show(
    BuildContext context,
    UpdateInfo info,
    AppUpdateService service,
  ) async {
    return showDialog<void>(
      context: context,
      barrierDismissible: false, // منع الإغلاق بالضغط خارج الحوار أثناء التنزيل
      builder: (_) => UpdateDialog(info: info, service: service),
    );
  }

  @override
  State<UpdateDialog> createState() => _UpdateDialogState();
}

class _UpdateDialogState extends State<UpdateDialog> {
  // ── الحالة الداخلية ─────────────────────────
  UpdateDialogState _state = UpdateDialogState.idle;

  /// عدد البايتات التي تم استقبالها حتى الآن
  int _received = 0;

  /// الحجم الكلي للملف بالبايت (قد يكون صفراً إذا لم يُرسَل Content-Length)
  int _total = 0;

  /// رسالة الخطأ (تُعرض في حالة [UpdateDialogState.error])
  String? _errorMessage;

  /// هل اختار المستخدم تجاهل هذا الإصدار؟
  bool _dismissChecked = false;

  // ── الألوان ─────────────────────────────────
  static const Color _green       = Color(0xFF2E7D32);
  static const Color _lightGreen  = Color(0xFF43A047);
  static const Color _gold        = Color(0xFFFFB300);

  // ══════════════════════════════════════════════
  // منطق التنزيل
  // ══════════════════════════════════════════════

  Future<void> _startDownload() async {
    setState(() {
      _state    = UpdateDialogState.downloading;
      _received = 0;
      _total    = 0;
    });

    try {
      await widget.service.downloadAndInstall(
        widget.info,
        onProgress: (received, total) {
          if (mounted) {
            setState(() {
              _received = received;
              _total    = total;
            });
          }
        },
      );

      if (mounted) setState(() => _state = UpdateDialogState.done);
    } catch (e) {
      if (mounted) {
        setState(() {
          _state        = UpdateDialogState.error;
          _errorMessage = e.toString();
        });
      }
    }
  }

  // ══════════════════════════════════════════════
  // بناء واجهة المستخدم
  // ══════════════════════════════════════════════

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl, // دعم اتجاه النص العربي
      child: Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        clipBehavior: Clip.antiAlias,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildHeader(),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildVersionBadge(),
                  const SizedBox(height: 12),
                  _buildReleaseNotes(),
                  const SizedBox(height: 16),
                  _buildStatusSection(),
                  const SizedBox(height: 8),
                  _buildDismissCheckbox(),
                  const SizedBox(height: 12),
                  _buildButtons(),
                  const SizedBox(height: 8),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── شريط العنوان الأخضر ──────────────────────
  Widget _buildHeader() {
    return Container(
      width: double.infinity,
      color: _green,
      padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 20),
      child: const Row(
        children: [
          Text('🎉', style: TextStyle(fontSize: 24)),
          SizedBox(width: 10),
          Text(
            'تحديث جديد متاح',
            style: TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  // ── شارة رقم الإصدار ─────────────────────────
  Widget _buildVersionBadge() {
    return Row(
      children: [
        const Text(
          'الإصدار الجديد:',
          style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
        ),
        const SizedBox(width: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          decoration: BoxDecoration(
            color: _gold.withValues(alpha: 0.15),
            border: Border.all(color: _gold, width: 1.5),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            'v${widget.info.version}',
            style: const TextStyle(
              color: _gold,
              fontWeight: FontWeight.bold,
              fontSize: 15,
            ),
          ),
        ),
      ],
    );
  }

  // ── ملاحظات الإصدار ───────────────────────────
  Widget _buildReleaseNotes() {
    if (widget.info.releaseNotes.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'ما الجديد:',
          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 6),
        Container(
          constraints: const BoxConstraints(maxHeight: 200),
          decoration: BoxDecoration(
            color: Colors.grey.shade100,
            borderRadius: BorderRadius.circular(10),
          ),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(10),
            child: Text(
              widget.info.releaseNotes,
              style: const TextStyle(fontSize: 13, height: 1.6),
            ),
          ),
        ),
      ],
    );
  }

  // ── قسم الحالة (تقدم / نجاح / خطأ) ──────────
  Widget _buildStatusSection() {
    switch (_state) {
      case UpdateDialogState.downloading:
        return _buildDownloadProgress();
      case UpdateDialogState.done:
        return _buildDoneState();
      case UpdateDialogState.error:
        return _buildErrorState();
      case UpdateDialogState.idle:
        return const SizedBox.shrink();
    }
  }

  /// شريط التقدم مع نص الحجم المُنزَّل
  Widget _buildDownloadProgress() {
    final receivedMb = (_received / 1024 / 1024).toStringAsFixed(1);
    final totalMb    = _total > 0 ? (_total / 1024 / 1024).toStringAsFixed(1) : '---';
    final progress   = _total > 0 ? _received / _total : null; // null → غير محدد

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        LinearProgressIndicator(
          value: progress,
          backgroundColor: Colors.grey.shade200,
          color: _lightGreen,
          minHeight: 8,
          borderRadius: BorderRadius.circular(4),
        ),
        const SizedBox(height: 8),
        Text(
          'جاري التحميل... $receivedMb MB من $totalMb MB',
          style: const TextStyle(fontSize: 13, color: Colors.grey),
        ),
      ],
    );
  }

  /// رسالة نجاح التثبيت
  Widget _buildDoneState() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.green.shade50,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.green.shade200),
      ),
      child: const Row(
        children: [
          Icon(Icons.check_circle, color: _lightGreen, size: 28),
          SizedBox(width: 10),
          Expanded(
            child: Text(
              'تم التثبيت — أعد تشغيل التطبيق',
              style: TextStyle(color: _green, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  /// رسالة الخطأ
  Widget _buildErrorState() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.red.shade50,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.red.shade200),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.error_outline, color: Colors.red, size: 28),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              _errorMessage ?? 'حدث خطأ غير متوقع.',
              style: const TextStyle(color: Colors.red, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }

  // ── خانة تجاهل الإصدار ───────────────────────
  Widget _buildDismissCheckbox() {
    // لا نعرضها أثناء التنزيل
    if (_state == UpdateDialogState.downloading) return const SizedBox.shrink();

    return Row(
      children: [
        Checkbox(
          value: _dismissChecked,
          activeColor: _green,
          onChanged: (value) async {
            if (value == null) return;
            setState(() => _dismissChecked = value);
            if (value) {
              // حفظ قرار التجاهل فوراً
              await widget.service.dismissVersion(widget.info.version);
            }
          },
        ),
        const Text('تجاهل هذا الإصدار', style: TextStyle(fontSize: 14)),
      ],
    );
  }

  // ── أزرار الإجراءات ───────────────────────────
  Widget _buildButtons() {
    // نُخفي الأزرار أثناء التنزيل
    if (_state == UpdateDialogState.downloading) return const SizedBox.shrink();

    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        // زر "لاحقاً"
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('لاحقاً', style: TextStyle(color: Colors.grey)),
        ),
        const SizedBox(width: 8),

        // زر "تحديث الآن" (يُعرض فقط في حالتَي idle و error)
        if (_state == UpdateDialogState.idle || _state == UpdateDialogState.error)
          ElevatedButton.icon(
            onPressed: _startDownload,
            icon: const Icon(Icons.download_rounded, color: Colors.white),
            label: const Text(
              'تحديث الآن',
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: _green,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            ),
          ),
      ],
    );
  }
}
