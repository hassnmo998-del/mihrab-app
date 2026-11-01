import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import '../services/app_update_service.dart';
import '../services/update/release_notes.dart';

// ─────────────────────────────────────────────
// UpdateDialog — حوار التحديث التفاعلي
// ─────────────────────────────────────────────

/// حوار يعرض الإصدار الجديد و**ما الجديد فيه بخط كبير ظاهر**، ثم تقدم التنزيل، ثم زر
/// التثبيت. زر الإجراء ثابت أسفل النافذة لا يتحرك مع تمرير الملاحظات فلا يختفي على
/// هاتف صغير. بعد ضغط «تحديث الآن» لا يتوقف التنزيل: إغلاق الحوار أو التطبيق لا يلغيه،
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

  late ParsedReleaseNotes _notes;

  bool get _isAndroid => !kIsWeb && Platform.isAndroid;

  @override
  void initState() {
    super.initState();
    _notes = ParsedReleaseNotes.parse(widget.info.releaseNotes);
  }

  @override
  void didUpdateWidget(covariant UpdateDialog old) {
    super.didUpdateWidget(old);
    if (old.info.releaseNotes != widget.info.releaseNotes) {
      _notes = ParsedReleaseNotes.parse(widget.info.releaseNotes);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: ListenableBuilder(
        listenable: widget.service,
        builder: (context, _) {
          final service = widget.service;
          final state = service.state;
          final isDark = Theme.of(context).brightness == Brightness.dark;

          return Dialog(
            insetPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 22),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
            clipBehavior: Clip.antiAlias,
            elevation: 12,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 500),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _buildHeader(state),
                  // الجسم وحده يُمرَّر (ملاحظات طويلة، خط مكبَّر، هاتف صغير)؛ الزر أسفله ثابت
                  Flexible(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(18, 16, 18, 8),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _buildStatusSection(service, state),
                          _buildWhatsNew(isDark),
                        ],
                      ),
                    ),
                  ),
                  _buildFooter(service, state, isDark),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  // ───────────────────────── الرأس ─────────────────────────

  Widget _buildHeader(SilentUpdateState state) {
    final title = switch (state) {
      SilentUpdateState.downloading => 'جارٍ تحديث محراب',
      SilentUpdateState.readyToInstall || SilentUpdateState.installing => 'تحديث محراب جاهز للتثبيت',
      _ => 'تحديث جديد متاح لمحراب',
    };
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 16),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [_emerald, _lightGreen],
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 46,
                height: 46,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.18),
                  shape: BoxShape.circle,
                ),
                child: const Text('🕌', style: TextStyle(fontSize: 24)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 19,
                    fontWeight: FontWeight.bold,
                    height: 1.3,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 10,
            runSpacing: 6,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFE9A8),
                  border: Border.all(color: _gold, width: 1.2),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  'الإصدار v${widget.info.version}',
                  style: const TextStyle(
                    color: Color(0xFF5A4300),
                    fontWeight: FontWeight.w800,
                    fontSize: 14.5,
                  ),
                ),
              ),
              Text(
                'أنت الآن على v${AppUpdateService.currentVersion}',
                style: TextStyle(fontSize: 12.5, color: Colors.white.withValues(alpha: 0.8)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ─────────────────────── ما الجديد ───────────────────────

  Widget _buildWhatsNew(bool isDark) {
    final n = _notes;
    if (n.isEmpty) return const SizedBox.shrink();
    final accent = isDark ? Colors.green.shade200 : _emerald;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Icon(Icons.auto_awesome_rounded, color: isDark ? _gold : const Color(0xFF996515), size: 22),
            const SizedBox(width: 8),
            const Expanded(
              child: Text(
                'ما الجديد في هذا الإصدار',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, height: 1.3),
              ),
            ),
          ],
        ),
        if (n.headline.isNotEmpty) ...[
          const SizedBox(height: 6),
          Text(
            n.headline,
            style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w700, height: 1.5, color: accent),
          ),
        ],
        const SizedBox(height: 12),
        if (n.current.isNotEmpty)
          for (final item in n.current) _noteCard(item, isDark)
        else if (n.plain.isNotEmpty)
          Container(
            padding: const EdgeInsets.all(14),
            margin: const EdgeInsets.only(bottom: 10),
            decoration: _cardDecoration(isDark),
            child: Text(n.plain, style: const TextStyle(fontSize: 15, height: 1.7)),
          ),
        if (n.previous.isNotEmpty) _buildPrevious(isDark),
      ],
    );
  }

  BoxDecoration _cardDecoration(bool isDark) => BoxDecoration(
        color: isDark ? Colors.white.withValues(alpha: 0.06) : _lightGreen.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _lightGreen.withValues(alpha: isDark ? 0.35 : 0.22)),
      );

  Widget _noteCard(ReleaseNoteItem item, bool isDark) {
    final bodyColor = Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.88);
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
      decoration: _cardDecoration(isDark),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 26,
            height: 26,
            margin: const EdgeInsets.only(top: 1),
            decoration: const BoxDecoration(color: _lightGreen, shape: BoxShape.circle),
            child: const Icon(Icons.check_rounded, color: Colors.white, size: 18),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (item.title.isNotEmpty)
                  Text(
                    item.title,
                    style: const TextStyle(fontSize: 15.5, fontWeight: FontWeight.w800, height: 1.4),
                  ),
                if (item.body.isNotEmpty)
                  Padding(
                    padding: EdgeInsets.only(top: item.title.isNotEmpty ? 3 : 0),
                    child: Text(
                      item.body,
                      style: TextStyle(
                        fontSize: item.title.isNotEmpty ? 14.5 : 15.5,
                        fontWeight: item.title.isNotEmpty ? FontWeight.w500 : FontWeight.w600,
                        height: 1.55,
                        color: bodyColor,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// الإصدارات السابقة مطوية: لا تزاحم الجديد، ومن أرادها فتحها.
  Widget _buildPrevious(bool isDark) {
    final muted = Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.72);
    return Theme(
      data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
      child: ExpansionTile(
        tilePadding: EdgeInsets.zero,
        childrenPadding: const EdgeInsets.only(bottom: 8),
        expandedCrossAxisAlignment: CrossAxisAlignment.start,
        title: Text(
          'ومن الإصدارات السابقة (${_notes.previous.length})',
          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: muted),
        ),
        children: [
          for (final item in _notes.previous)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('•  ', style: TextStyle(fontSize: 14, color: muted)),
                  Expanded(
                    child: Text(
                      item.title.isEmpty ? item.body : '${item.title}: ${item.body}',
                      style: TextStyle(fontSize: 13.5, height: 1.55, color: muted),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  // ─────────────────────── الحالة ───────────────────────

  Widget _buildStatusSection(AppUpdateService service, SilentUpdateState state) {
    if (state == SilentUpdateState.downloading) {
      final waiting = service.isWaitingForNetwork;
      return Padding(
        padding: const EdgeInsets.only(bottom: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    waiting ? 'بانتظار الاتصال بالإنترنت…' : 'جارٍ تنزيل التحديث...',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: waiting ? Colors.orange.shade800 : null,
                    ),
                  ),
                ),
                Text(
                  service.formattedProgress,
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: _lightGreen),
                ),
              ],
            ),
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: LinearProgressIndicator(
                value: service.downloadProgress > 0 ? service.downloadProgress : null,
                minHeight: 9,
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
              style: const TextStyle(fontSize: 12, height: 1.5, color: Colors.grey),
            ),
          ],
        ),
      );
    }

    if (state == SilentUpdateState.readyToInstall) {
      return Container(
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.green.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.green.withValues(alpha: 0.3)),
        ),
        child: Row(
          children: [
            const Icon(Icons.check_circle, color: Colors.green, size: 26),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                _isAndroid
                    ? 'اكتمل التنزيل! اضغط تثبيت لترقية التطبيق فوراً.'
                    : 'اكتمل التنزيل! اضغط لإعادة التشغيل وتثبيت التحديث.',
                style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold, fontSize: 14, height: 1.4),
              ),
            ),
          ],
        ),
      );
    }

    if (state == SilentUpdateState.error) {
      return Container(
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.red.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          children: [
            const Icon(Icons.error_outline, color: Colors.red, size: 22),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                service.errorMessage ?? 'تعذر تنزيل التحديث، تحقق من الاتصال.',
                style: const TextStyle(color: Colors.red, fontSize: 13, height: 1.4),
              ),
            ),
          ],
        ),
      );
    }

    return const SizedBox.shrink();
  }

  // ─────────────────────── الزر الثابت ───────────────────────

  Widget _buildFooter(AppUpdateService service, SilentUpdateState state, bool isDark) {
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 10, 18, 14),
      decoration: BoxDecoration(
        color: Theme.of(context).dialogTheme.backgroundColor ??
            Theme.of(context).colorScheme.surfaceContainerHigh,
        border: Border(
          top: BorderSide(color: Theme.of(context).dividerColor.withValues(alpha: 0.6)),
        ),
      ),
      child: _buildActionButtons(service, state),
    );
  }

  ButtonStyle get _primaryStyle => ElevatedButton.styleFrom(
        backgroundColor: _lightGreen,
        foregroundColor: Colors.white,
        minimumSize: const Size.fromHeight(52),
        elevation: 0,
        shadowColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      );

  static const TextStyle _primaryLabel =
      TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 16.5);

  Widget _laterButton() => TextButton(
        onPressed: () => Navigator.of(context).pop(),
        child: const Text('لاحقاً', style: TextStyle(color: Colors.grey, fontSize: 14.5)),
      );

  Widget _buildActionButtons(AppUpdateService service, SilentUpdateState state) {
    if (state == SilentUpdateState.downloading) {
      return TextButton.icon(
        onPressed: () => Navigator.of(context).pop(),
        icon: const Icon(Icons.expand_more_rounded, size: 20),
        label: const Text('متابعة في الخلفية', style: TextStyle(fontSize: 14.5)),
      );
    }

    if (state == SilentUpdateState.readyToInstall) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ElevatedButton.icon(
            onPressed: () => service.installDownloadedUpdate(),
            icon: const Icon(Icons.rocket_launch_rounded, color: Colors.white, size: 22),
            label: Text(
              _isAndroid ? 'تثبيت الآن 🚀' : 'إعادة التشغيل وتثبيت 🔄',
              style: _primaryLabel,
            ),
            style: _primaryStyle,
          ),
          _laterButton(),
        ],
      );
    }

    // متاح، أو تعذّر البدء
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ElevatedButton.icon(
          onPressed: () => service.startDownload(widget.info),
          icon: const Icon(Icons.download_rounded, color: Colors.white, size: 22),
          label: Text(
            state == SilentUpdateState.error ? 'إعادة المحاولة' : 'تحديث الآن',
            style: _primaryLabel,
          ),
          style: _primaryStyle,
        ),
        _laterButton(),
      ],
    );
  }
}
