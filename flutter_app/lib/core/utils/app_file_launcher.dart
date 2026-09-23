import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../services/telegram_media_resolver.dart';
import '../theme/app_theme.dart';

enum AppAttachmentType {
  video,
  document,
  audio,
  link,
  generic,
}

class AppAttachmentInfo {
  final AppAttachmentType type;
  final String title;
  final String subtitle;
  final IconData icon;
  final String actionLabel;
  final Color primaryColor;

  const AppAttachmentInfo({
    required this.type,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.actionLabel,
    required this.primaryColor,
  });
}

class AppFileLauncher {
  AppFileLauncher._();

  /// تفاصيل ذكية لنوع المرفق سواء كان رابطاً أو ملفاً محلياً
  static AppAttachmentInfo getAttachmentInfo(String pathOrUrl) {
    final clean = pathOrUrl.trim();
    final lower = clean.toLowerCase();

    // 0. مرفق عام مرفوع للأرشيف: نصنّفه حسب امتداد اسمه الأصلي
    if (TelegramMediaResolver.isFileRef(clean)) {
      final name = TelegramMediaResolver.fileNameOf(clean) ?? 'ملف مرفق';
      final info = getAttachmentInfo(name);
      return AppAttachmentInfo(
        type: info.type,
        title: info.title,
        subtitle: name,
        icon: info.icon,
        actionLabel: info.actionLabel,
        primaryColor: info.primaryColor,
      );
    }

    // 0.b مرجع دائم لوسائط محفوظة في أرشيف التطبيق (يُجدَّد رابطه عند الفتح)
    if (TelegramMediaResolver.isRef(clean)) {
      final isVideo = TelegramMediaResolver.isVideoRef(clean);
      return AppAttachmentInfo(
        type: isVideo ? AppAttachmentType.video : AppAttachmentType.audio,
        title: isVideo ? 'تسجيل مرئي (فيديو) متوفر 🎬' : 'تسجيل صوتي مرفق 🎙️',
        subtitle: 'محفوظ في المكتبة السحابية للتطبيق',
        icon: isVideo ? Icons.videocam_rounded : Icons.audio_file_rounded,
        actionLabel: isVideo ? 'مشاهدة الفيديو' : 'تشغيل الصوت',
        primaryColor: isVideo ? AppColors.emeraldPrimary : AppColors.gold,
      );
    }

    // 1. فحص إذا كان رابطاً شبكياً
    if (lower.startsWith('http://') || lower.startsWith('https://')) {
      if (lower.contains('youtube.com') || lower.contains('youtu.be') || lower.endsWith('.mp4') || lower.endsWith('.mkv')) {
        return AppAttachmentInfo(
          type: AppAttachmentType.video,
          title: 'تسجيل مرئي (فيديو) متوفر 🎬',
          subtitle: 'رابط سحابي / يوتيوب',
          icon: Icons.videocam_rounded,
          actionLabel: 'مشاهدة الفيديو',
          primaryColor: AppColors.emeraldPrimary,
        );
      }
      return AppAttachmentInfo(
        type: AppAttachmentType.link,
        title: 'رابط إلكتروني مرفق بالدرس 🔗',
        subtitle: clean.length > 45 ? '${clean.substring(0, 42)}...' : clean,
        icon: Icons.link_rounded,
        actionLabel: 'فتح الرابط',
        primaryColor: AppColors.terracottaPrimary,
      );
    }

    // 2. ملفات الفيديو
    final videoExts = ['.mp4', '.mkv', '.mov', '.avi', '.webm', '.3gp', '.flv'];
    if (videoExts.any((ext) => lower.endsWith(ext))) {
      final fileName = clean.split(RegExp(r'[\\/]')).last;
      return AppAttachmentInfo(
        type: AppAttachmentType.video,
        title: 'تسجيل مرئي (فيديو) متوفر 🎬',
        subtitle: fileName.isNotEmpty ? fileName : 'فيديو محفوظ على الجهاز',
        icon: Icons.videocam_rounded,
        actionLabel: 'مشاهدة الفيديو',
        primaryColor: AppColors.emeraldPrimary,
      );
    }

    // 3. المستندات وملفات الـ PDF
    final docExts = ['.pdf', '.doc', '.docx', '.ppt', '.pptx', '.xls', '.xlsx', '.txt'];
    if (docExts.any((ext) => lower.endsWith(ext))) {
      final fileName = clean.split(RegExp(r'[\\/]')).last;
      return AppAttachmentInfo(
        type: AppAttachmentType.document,
        title: 'مستند علمي مرفق (PDF / ملف) 📄',
        subtitle: fileName.isNotEmpty ? fileName : 'مستند مرفق',
        icon: lower.endsWith('.pdf') ? Icons.picture_as_pdf_rounded : Icons.description_rounded,
        actionLabel: 'فتح المستند',
        primaryColor: const Color(0xFF1E88E5),
      );
    }

    // 4. الملفات الصوتية
    final audioExts = ['.mp3', '.m4a', '.wav', '.aac', '.ogg', '.flac'];
    if (audioExts.any((ext) => lower.endsWith(ext))) {
      final fileName = clean.split(RegExp(r'[\\/]')).last;
      return AppAttachmentInfo(
        type: AppAttachmentType.audio,
        title: 'تسجيل صوتي إضافي مرفق 🎙️',
        subtitle: fileName.isNotEmpty ? fileName : 'ملف صوتي محفوظ',
        icon: Icons.audio_file_rounded,
        actionLabel: 'تشغيل الصوت',
        primaryColor: AppColors.gold,
      );
    }

    // 5. ملف عام
    final fileName = clean.split(RegExp(r'[\\/]')).last;
    return AppAttachmentInfo(
      type: AppAttachmentType.generic,
      title: 'ملف علمي مرفق بالدرس 📁',
      subtitle: fileName.isNotEmpty ? fileName : 'ملف محفوظ على الجهاز',
      icon: Icons.folder_zip_rounded,
      actionLabel: 'فتح الملف',
      primaryColor: const Color(0xFF6366F1),
    );
  }

  /// فتح الملف أو الرابط باستقرار تام على أنظمة Windows و Android
  static Future<void> open(BuildContext context, String pathOrUrl) async {
    var clean = pathOrUrl.trim();
    if (clean.isEmpty) {
      _showFeedback(context, 'لا يوجد مسار أو رابط صالح للفتح', isError: true);
      return;
    }

    // مرجع دائم: ننزّل الملف (مرة واحدة ثم من الذاكرة) ونفتحه بتطبيق الجهاز الافتراضي
    if (TelegramMediaResolver.isRef(clean)) {
      final local = await _downloadArchiveFile(context, clean);
      if (local == null) return;
      clean = local;
    } else if (TelegramMediaResolver.isExpiredLegacyLink(clean)) {
      // رابط محفوظ بنسخة قديمة من التطبيق: انتهت صلاحيته ولا يمكن تجديده
      _showFeedback(
        context,
        'هذا التسجيل محفوظ برابط قديم انتهت صلاحيته، يلزم إعادة رفعه من جديد',
        isError: true,
      );
      return;
    }

    // إذا كان رابط إنترنت (HTTP / HTTPS)
    if (clean.startsWith('http://') || clean.startsWith('https://')) {
      final opened = await _launchWebUrl(clean);
      if (!opened && context.mounted) {
        _showFeedback(context, 'تعذر فتح الرابط في التطبيق المناسب: $clean', isError: true);
      }
      return;
    }

    // إذا كان ملفاً محلياً على الجهاز
    final file = File(clean);
    if (!file.existsSync()) {
      if (context.mounted) {
        _showFeedback(context, 'الملف غير موجود على هذا الجهاز أو تم نقله:\n$clean', isError: true);
      }
      return;
    }

    try {
      // فتح الملف عبر مشغل النظام الافتراضي (يدعم أندرويد عبر FileProvider وويندوز عبر ShellExecute)
      final result = await OpenFilex.open(clean);
      if (result.type != ResultType.done) {
        // آلية احتياطية لويندوز في حال لم يكتمل الفتح
        if (Platform.isWindows) {
          try {
            await Process.run('cmd', ['/c', 'start', '""', clean], runInShell: true);
            return;
          } catch (_) {}
        }
        if (context.mounted) {
          _showFeedback(context, 'تعذر فتح الملف بالتطبيق الافتراضي: ${result.message}', isError: true);
        }
      }
    } catch (e) {
      if (Platform.isWindows) {
        try {
          await Process.run('cmd', ['/c', 'start', '""', clean], runInShell: true);
          return;
        } catch (_) {}
      }
      if (context.mounted) {
        _showFeedback(context, 'حدث خطأ أثناء محاولة فتح الملف: $e', isError: true);
      }
    }
  }

  /// ينزّل ملف الأرشيف إلى مجلد مؤقت ويعيد مساره المحلي، مع نافذة تقدّم قابلة للإلغاء.
  /// الملف المنزّل سابقاً يُفتح فوراً دون تنزيل جديد.
  static Future<String?> _downloadArchiveFile(BuildContext context, String ref) async {
    final fileId = TelegramMediaResolver.fileIdOf(ref);
    if (fileId == null) {
      _showFeedback(context, 'مرجع الملف غير صالح', isError: true);
      return null;
    }

    final cacheDir = Directory(
      '${(await getTemporaryDirectory()).path}${Platform.pathSeparator}mihrab_media'
      '${Platform.pathSeparator}${fileId.hashCode.toUnsigned(32)}',
    );
    if (cacheDir.existsSync()) {
      final cached = cacheDir
          .listSync()
          .whereType<File>()
          .where((f) => !f.path.endsWith('.part') && f.lengthSync() > 0)
          .firstOrNull;
      if (cached != null) return cached.path;
    }

    final resolved = await TelegramMediaResolver.resolveResult(ref);
    if (resolved.url == null) {
      if (context.mounted) {
        _showFeedback(context, TelegramMediaResolver.failureMessage(resolved.error), isError: true);
      }
      return null;
    }

    // اسم الملف: الأصلي للمرفقات، وإلا اسم من امتداد مسار تيليجرام.
    final urlName = Uri.parse(resolved.url!).pathSegments.last;
    final ext = urlName.contains('.') ? urlName.substring(urlName.lastIndexOf('.')) : '';
    final rawName = TelegramMediaResolver.fileNameOf(ref) ?? 'lesson_media$ext';
    final safeName = rawName.replaceAll(RegExp(r'[<>:"/\\|?*]'), '_');
    await cacheDir.create(recursive: true);
    final target = File('${cacheDir.path}${Platform.pathSeparator}$safeName');
    final partial = File('${target.path}.part');

    if (!context.mounted) return null;
    final progress = ValueNotifier<(int, int)>((0, 0));
    var cancelled = false;
    final client = http.Client();
    final dialogNavigator = Navigator.of(context, rootNavigator: true);

    unawaited(showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: const Text('جاري تجهيز الملف', style: TextStyle(fontSize: 16)),
        content: ValueListenableBuilder<(int, int)>(
          valueListenable: progress,
          builder: (_, value, __) {
            final (received, total) = value;
            return Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                LinearProgressIndicator(value: total > 0 ? received / total : null),
                const SizedBox(height: 10),
                Text(
                  total > 0
                      ? '${MediaLimits.formatMb(received)} / ${MediaLimits.formatMb(total)} ميغابايت'
                      : '${MediaLimits.formatMb(received)} ميغابايت',
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 12),
                ),
              ],
            );
          },
        ),
        actions: [
          TextButton(
            onPressed: () {
              cancelled = true;
              client.close();
              Navigator.of(ctx).pop();
            },
            child: const Text('إلغاء'),
          ),
        ],
      ),
    ));

    try {
      final response = await client.send(http.Request('GET', Uri.parse(resolved.url!)));
      if (response.statusCode != 200) throw HttpException('HTTP ${response.statusCode}');
      final total = response.contentLength ?? 0;
      final sink = partial.openWrite();
      var received = 0;
      try {
        await for (final chunk in response.stream) {
          sink.add(chunk);
          received += chunk.length;
          progress.value = (received, total);
        }
      } finally {
        await sink.close();
      }
      if (target.existsSync()) await target.delete();
      await partial.rename(target.path);
      if (!cancelled) dialogNavigator.pop();
      return cancelled ? null : target.path;
    } catch (e) {
      debugPrint('⚠️ فشل تنزيل ملف الأرشيف: $e');
      try {
        if (partial.existsSync()) await partial.delete();
      } catch (_) {}
      if (!cancelled) {
        dialogNavigator.pop();
        if (context.mounted) {
          _showFeedback(context, 'تعذّر تنزيل الملف، تحقق من الاتصال بالإنترنت وأعد المحاولة', isError: true);
        }
      }
      return null;
    } finally {
      client.close();
    }
  }

  /// يحاول فتح رابط ويب بعدة أوضاع بالتسلسل.
  ///
  /// لا نعتمد على [canLaunchUrl] كبوابة: على أندرويد 11+ يرجع false إذا لم
  /// تُعلَن نوايا VIEW في AndroidManifest، فكان الفيديو لا يفتح على الهاتف
  /// بينما يعمل على الديسكتوب. المحاولة المباشرة أصدق من الفحص.
  static Future<bool> _launchWebUrl(String url) async {
    final Uri uri;
    try {
      uri = Uri.parse(url);
    } catch (_) {
      return false;
    }

    const modes = [
      LaunchMode.externalApplication, // مشغّل الفيديو أو المتصفح الخارجي
      LaunchMode.platformDefault,
      LaunchMode.inAppBrowserView,
    ];

    for (final mode in modes) {
      try {
        if (await launchUrl(uri, mode: mode)) return true;
      } catch (e) {
        debugPrint('⚠️ فشل فتح الرابط بوضع $mode: $e');
      }
    }
    return false;
  }

  static void _showFeedback(BuildContext context, String message, {bool isError = false}) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
        ),
        backgroundColor: isError ? Colors.redAccent[700] : AppColors.emeraldPrimary,
        duration: const Duration(seconds: 4),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }
}
