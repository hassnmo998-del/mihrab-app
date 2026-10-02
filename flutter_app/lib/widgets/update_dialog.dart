import 'dart:io';
import 'package:flutter/material.dart';
import '../services/app_update_service.dart';

// ─────────────────────────────────────────────
// UpdateDialog — حوار التحديث التفاعلي
// ─────────────────────────────────────────────

/// حوار يعرض الإصدار الجديد وملاحظاته، ثم تقدم التنزيل، ثم زر التثبيت.
/// بعد ضغط «تحديث الآن» لا يتوقف التنزيل: إغلاق الحوار أو التطبيق لا يلغيه،
/// وانقطاع الاتصال يظهر هنا انتظاراً لا خطأً.
class UpdateDialog extends StatefulWidget {
  final UpdateInfo info;
  final AppUpdateService service;

  const UpdateDialog({
    super.key,
    required this.info,
    required this.service,
  });

  /// مؤشر لتفادي فتح أكثر من نافذة تحديث في نفس الوقت
  static bool isShowing = false;

  /// طريقة مساعدة لعرض الحوار.
  static Future<void> show(
    BuildContext context,
    UpdateInfo info,
    AppUpdateService service,
  ) async {
    // صمام أمان قاطع وحاسم: لا تفتح نافذة التحديث إطلاقاً إذا لم يكن الإصدار أحدث قطعياً من الإصدار المثبت
    if (!service.isNewerVersion(info.version, AppUpdateService.currentVersion)) {
      return;
    }
    if (isShowing) return;
    isShowing = true;
    try {
      return await showDialog<void>(
        context: context,
        barrierDismissible: true,
        builder: (_) => UpdateDialog(info: info, service: service),
      );
    } finally {
      isShowing = false;
    }
  }

  @override
  State<UpdateDialog> createState() => _UpdateDialogState();
}

class _UpdateDialogState extends State<UpdateDialog> {
  static const Color _emerald    = Color(0xFF1B5E20);
  static const Color _lightGreen = Color(0xFF2E7D32);
  static const Color _gold       = Color(0xFFD4AF37);

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: ListenableBuilder(
        listenable: widget.service,
        builder: (context, _) {
          final service = widget.service;
          final state = service.state;

          return Dialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
            clipBehavior: Clip.antiAlias,
            elevation: 10,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildHeader(state),
                  // الجسم يُمرَّر إن لم تتسع له الشاشة (هاتف صغير، خط مكبَّر، ملاحظات طويلة)
                  Flexible(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(20, 16, 20, 14),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _buildVersionBadge(),
                          const SizedBox(height: 12),
                          _buildReleaseNotes(),
                          const SizedBox(height: 14),
                          _buildStatusSection(service, state),
                          const SizedBox(height: 12),
                          _buildActionButtons(service, state),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildHeader(SilentUpdateState state) {
    final title = switch (state) {
      SilentUpdateState.downloading => 'جارٍ تحديث محراب',
      SilentUpdateState.readyToInstall || SilentUpdateState.installing => 'تحديث محراب جاهز للتثبيت',
      _ => 'تحديث جديد متاح لمحراب',
    };
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 20),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [_emerald, _lightGreen],
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
        ),
      ),
      child: Row(
        children: [
          const Text('🕌', style: TextStyle(fontSize: 26)),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              title,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVersionBadge() {
    return Wrap(
      alignment: WrapAlignment.spaceBetween,
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: 8,
      runSpacing: 6,
      children: [
        Wrap(
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 8,
          runSpacing: 4,
          children: [
            const Text(
              'الإصدار الجديد:',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
              decoration: BoxDecoration(
                color: _gold.withValues(alpha: 0.15),
                border: Border.all(color: _gold, width: 1.2),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Text(
                'v${widget.info.version}',
                style: const TextStyle(
                  color: Color(0xFF996515),
                  fontWeight: FontWeight.bold,
                  fontSize: 13.5,
                ),
              ),
            ),
          ],
        ),
        Text(
          'الحالي: v${AppUpdateService.currentVersion}',
          style: const TextStyle(fontSize: 12, color: Colors.grey),
        ),
      ],
    );
  }

  String _formattedNotes(String raw) {
    var text = raw.trim();
    if (text.isEmpty) return '';
    // إذا كان الوصف مجرد رابط تغييرات تلقائي من جيت هاب دون نص مخصص
    if (text.contains('Full Changelog') && (text.startsWith('**Full Changelog**') || text.startsWith('Full Changelog'))) {
      return '• تحسينات عامة في الأداء واستقرار التطبيق.\n• إصلاحات برمجية وتحديثات شاملة.';
    }
    // إزالة علامات الماركداون العريضة والترويسات ليظهر النص العربي بشكل مريح
    text = text.replaceAll(RegExp(r'^\s*#+\s*', multiLine: true), '');
    text = text.replaceAll('**', '');
    text = text.replaceAll('__', '');
    return text.trim();
  }

  Widget _buildReleaseNotes() {
    final notes = _formattedNotes(widget.info.releaseNotes);
    if (notes.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'أبرز التحسينات والمزايا:',
          style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 6),
        Container(
          constraints: const BoxConstraints(maxHeight: 140),
          decoration: BoxDecoration(
            color: Colors.grey.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(12),
          ),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(12),
            child: Text(
              notes,
              style: const TextStyle(fontSize: 12.5, height: 1.6),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildStatusSection(AppUpdateService service, SilentUpdateState state) {
    if (state == SilentUpdateState.downloading) {
      final waiting = service.isWaitingForNetwork;
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  waiting ? 'بانتظار الاتصال بالإنترنت…' : 'جارٍ تنزيل التحديث...',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: waiting ? Colors.orange.shade800 : null,
                  ),
                ),
              ),
              Text(
                service.formattedProgress,
                style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.bold, color: _lightGreen),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: service.downloadProgress > 0 ? service.downloadProgress : null,
              minHeight: 8,
              backgroundColor: Colors.grey.shade200,
              color: waiting ? Colors.orange : _lightGreen,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            service.formattedSize,
            style: const TextStyle(fontSize: 12, color: Colors.grey),
          ),
          const SizedBox(height: 6),
          Text(
            waiting
                ? 'ما نزل محفوظ. يُستكمل التنزيل تلقائياً حين يعود الاتصال، ولو أغلقت التطبيق.'
                : 'يستمر التنزيل إلى أن يكتمل ولو أغلقت هذه النافذة أو التطبيق.',
            style: const TextStyle(fontSize: 11.5, height: 1.5, color: Colors.grey),
          ),
        ],
      );
    }

    if (state == SilentUpdateState.readyToInstall) {
      return Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.green.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.green.withValues(alpha: 0.3)),
        ),
        child: Row(
          children: [
            const Icon(Icons.check_circle, color: Colors.green, size: 24),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                Platform.isAndroid
                    ? 'اكتمل التنزيل! اضغط تثبيت لترقية التطبيق فوراً.'
                    : 'اكتمل التنزيل! اضغط لإعادة التشغيل وتثبيت التحديث.',
                style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold, fontSize: 13),
              ),
            ),
          ],
        ),
      );
    }

    if (state == SilentUpdateState.error) {
      return Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: Colors.red.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            const Icon(Icons.error_outline, color: Colors.red, size: 20),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                service.errorMessage ?? 'تعذر تنزيل التحديث، تحقق من الاتصال.',
                style: const TextStyle(color: Colors.red, fontSize: 12),
              ),
            ),
          ],
        ),
      );
    }

    return const SizedBox.shrink();
  }

  Widget _buildActionButtons(AppUpdateService service, SilentUpdateState state) {
    if (state == SilentUpdateState.downloading) {
      return Align(
        alignment: AlignmentDirectional.centerEnd,
        child: TextButton.icon(
          onPressed: () => Navigator.of(context).pop(),
          icon: const Icon(Icons.expand_more_rounded, size: 18),
          label: const Text('متابعة في الخلفية'),
        ),
      );
    }

    if (state == SilentUpdateState.readyToInstall) {
      return Wrap(
        alignment: WrapAlignment.spaceBetween,
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: 8,
        runSpacing: 4,
        children: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('لاحقاً'),
          ),
          ElevatedButton.icon(
            onPressed: () => service.installDownloadedUpdate(),
            icon: const Icon(Icons.rocket_launch_rounded, color: Colors.white, size: 18),
            label: Text(
              Platform.isAndroid ? 'تثبيت الآن 🚀' : 'إعادة التشغيل وتثبيت 🔄',
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: _lightGreen,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
            ),
          ),
        ],
      );
    }

    // متاح، أو تعذّر البدء
    return Wrap(
      alignment: WrapAlignment.spaceBetween,
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: 8,
      runSpacing: 4,
      children: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('لاحقاً', style: TextStyle(color: Colors.grey)),
        ),
        ElevatedButton.icon(
          onPressed: () => service.startDownload(widget.info),
          icon: const Icon(Icons.download_rounded, color: Colors.white, size: 18),
          label: Text(
            state == SilentUpdateState.error ? 'إعادة المحاولة' : 'تحديث الآن',
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
          ),
          style: ElevatedButton.styleFrom(
            backgroundColor: _lightGreen,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
          ),
        ),
      ],
    );
  }
}
