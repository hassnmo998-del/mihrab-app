import 'dart:io';
import 'package:flutter/material.dart';
import '../services/app_update_service.dart';

// ─────────────────────────────────────────────
// UpdateDialog — حوار التحديث التفاعلي
// ─────────────────────────────────────────────

/// حوار جميل بتصميم Material يعرض معلومات الإصدار الجديد باللغة العربية،
/// مع شريط تقدم حقيقي، وإمكانية الإيقاف/الاستئناف أو التنزيل في الخلفية.
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
                  _buildHeader(),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
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
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildHeader() {
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
      child: const Row(
        children: [
          Text('🕌', style: TextStyle(fontSize: 26)),
          SizedBox(width: 12),
          Expanded(
            child: Text(
              'تحديث جديد متاح لمحراب',
              style: TextStyle(
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
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            const Text(
              'الإصدار الجديد:',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
            ),
            const SizedBox(width: 8),
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

  Widget _buildReleaseNotes() {
    if (widget.info.releaseNotes.isEmpty) return const SizedBox.shrink();

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
              widget.info.releaseNotes,
              style: const TextStyle(fontSize: 12.5, height: 1.6),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildStatusSection(AppUpdateService service, SilentUpdateState state) {
    if (state == SilentUpdateState.downloading) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('جارٍ تنزيل التحديث...', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
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
              color: _lightGreen,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            service.formattedSize,
            style: const TextStyle(fontSize: 12, color: Colors.grey),
          ),
        ],
      );
    }

    if (state == SilentUpdateState.paused) {
      return Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: Colors.orange.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            const Icon(Icons.pause_circle_outline, color: Colors.orange, size: 20),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'تم إيقاف التنزيل مؤقتاً عند ${service.formattedProgress}',
                style: const TextStyle(fontSize: 13, color: Colors.orange, fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
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
      return Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          TextButton.icon(
            onPressed: () {
              Navigator.of(context).pop();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('جارٍ تنزيل التحديث في الخلفية... يمكنك متابعته من الإعدادات'),
                  duration: Duration(seconds: 4),
                  behavior: SnackBarBehavior.floating,
                ),
              );
            },
            icon: const Icon(Icons.hide_source_rounded, size: 18),
            label: const Text('متابعة بالخلفية'),
          ),
          OutlinedButton.icon(
            onPressed: () => service.pauseOrCancelDownload(),
            icon: const Icon(Icons.pause_rounded, size: 18),
            label: const Text('إيقاف مؤقت'),
          ),
        ],
      );
    }

    if (state == SilentUpdateState.paused) {
      return Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('إغلاق'),
          ),
          const SizedBox(width: 8),
          ElevatedButton.icon(
            onPressed: () => service.resumeDownload(),
            icon: const Icon(Icons.play_arrow_rounded, color: Colors.white, size: 18),
            label: const Text('استئناف', style: TextStyle(color: Colors.white)),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.orange.shade800),
          ),
        ],
      );
    }

    if (state == SilentUpdateState.readyToInstall) {
      return Row(
        children: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('لاحقاً'),
          ),
          const Spacer(),
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

    // Default / idle / error
    return Row(
      children: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('لاحقاً', style: TextStyle(color: Colors.grey)),
        ),
        const Spacer(),
        OutlinedButton(
          onPressed: () {
            service.startDownload(widget.info);
            Navigator.of(context).pop();
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('بدأ تنزيل التحديث في الخلفية... يمكنك متابعة شريط التقدم من الإعدادات'),
                duration: Duration(seconds: 4),
                behavior: SnackBarBehavior.floating,
              ),
            );
          },
          child: const Text('تنزيل بالخلفية'),
        ),
        const SizedBox(width: 8),
        ElevatedButton.icon(
          onPressed: () => service.startDownload(widget.info),
          icon: const Icon(Icons.download_rounded, color: Colors.white, size: 18),
          label: const Text(
            'تحديث الآن',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
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
