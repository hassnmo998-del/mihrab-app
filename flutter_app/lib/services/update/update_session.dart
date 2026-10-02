import 'dart:async';
import 'dart:io';
import 'dart:math' as math;

import 'update_downloader.dart';
import 'update_feed.dart';
import 'update_models.dart';

/// جلسة تنزيل تحديث فوق مجلد على القرص، يشترك فيه طرفان: واجهة التطبيق،
/// ومهمة الخلفية التي تكمل والتطبيق مغلق أو بعد إعادة تشغيل الهاتف.
///
/// الملفات في المجلد:
///  - `job.json`    ما المطلوب تنزيله. وجوده يعني "تحديث قيد التنفيذ"؛ يبقى إلى
///                  أن يُثبَّت الإصدار، فيكمل التنزيل وحده بعد أي انقطاع.
///  - `status.json` نبضة من ينزّل الآن: هويته، ووقته، وكم وصل.
///  - `<الملف>.part` ثم `<الملف>` عند اكتماله والتحقق منه.
///
/// طرف واحد ينزّل في أي لحظة: من يكتب نبضته هو المالك، وغيره يراقب ويعرض
/// التقدم. إن صمت المالك أكثر من [staleAfter] (قُتل التطبيق، جُمّد) يتولى
/// المراقب التنزيل ويكمل من حيث وقف.
class UpdateSession {
  UpdateSession({
    required this.dir,
    required this.ownerId,
    UpdateDownloader? downloader,
    UpdateFeed? feed,
    Future<void> Function(Duration)? sleep,
    DateTime Function()? now,
    this.staleAfter = const Duration(seconds: 8),
    this.heartbeatEvery = const Duration(seconds: 2),
  })  : downloader = downloader ?? UpdateDownloader(dir: dir, sleep: sleep, now: now),
        _feed = feed ?? UpdateFeed(),
        _sleep = sleep ?? Future<void>.delayed,
        _now = now ?? DateTime.now;

  final Directory dir;
  final String ownerId;
  final UpdateDownloader downloader;
  final UpdateFeed _feed;
  final Future<void> Function(Duration) _sleep;
  final DateTime Function() _now;
  final Duration staleAfter;

  /// المالك يجدد نبضته بهذا الإيقاع ولو لم يصل بايت (اتصال يُفتح، خادم بطيء).
  /// تطبيق مجمَّد لا تعمل مؤقتاته، فتصمت نبضته ويتولى غيره.
  final Duration heartbeatEvery;

  File get _jobFile => File('${dir.path}${Platform.pathSeparator}job.json');
  File get _statusFile => File('${dir.path}${Platform.pathSeparator}status.json');

  // ───────────────────────────── المهمة ─────────────────────────────

  UpdateJob? readJob() {
    try {
      if (!_jobFile.existsSync()) return null;
      return UpdateJob.decode(_jobFile.readAsStringSync());
    } catch (_) {
      return null;
    }
  }

  /// يبدأ مهمة جديدة (أو يستبدل القائمة). ملفات أي إصدار آخر تُحذف.
  Future<void> writeJob(UpdateJob job) async {
    await dir.create(recursive: true);
    // المهمة أولاً: من ينزّل الآن يراها تبدّلت فيتوقف قبل أن تُحذف ملفاته
    _writeAtomic(_jobFile, job.encode());
    final keep = {
      _jobFile.path,
      downloader.finalFile(job).path,
      downloader.partFile(job).path,
      '${downloader.finalFile(job).path}.meta',
    };
    await for (final entity in dir.list()) {
      if (entity is File && !keep.contains(entity.path)) {
        try {
          await entity.delete();
        } catch (_) {}
      }
    }
  }

  /// ينهي المهمة ويحذف كل ما نُزّل (بعد التثبيت، أو لإعادة التنزيل من الصفر).
  Future<void> clear() async {
    try {
      if (await dir.exists()) await dir.delete(recursive: true);
    } catch (_) {}
  }

  UpdateStatus? readStatus() {
    try {
      if (!_statusFile.existsSync()) return null;
      return UpdateStatus.decode(_statusFile.readAsStringSync());
    } catch (_) {
      return null;
    }
  }

  /// ملف التحديث إن كان مكتملاً وجاهزاً للتثبيت.
  Future<File?> readyFile() async {
    final job = readJob();
    if (job == null || !await downloader.isComplete(job)) return null;
    return downloader.finalFile(job);
  }

  // ───────────────────────────── التشغيل ─────────────────────────────

  /// يعمل إلى أن يجهز ملف التحديث فيعيده. يعيد null إن أُلغيت المهمة، أو
  /// طلب [shouldStop] التوقف.
  ///
  /// لا يرمي ولا يستسلم: انقطاع الشبكة انتظار، وبيانات إصدار قديمة تُجلب من جديد.
  Future<File?> run({
    required void Function(UpdateStatus status) onStatus,
    bool Function()? shouldStop,
  }) async {
    bool stopping() => shouldStop?.call() ?? false;

    while (true) {
      if (stopping()) return null;
      final job = readJob();
      if (job == null) return null;

      if (await downloader.isComplete(job)) {
        onStatus(_status(job, UpdatePhase.ready, job.size, job.size));
        return downloader.finalFile(job);
      }

      final current = readStatus();
      if (current != null &&
          current.owner != ownerId &&
          current.version == job.version &&
          current.isFresh(_now(), staleAfter)) {
        // غيرنا ينزّل الآن: نعرض تقدمه وننتظر
        onStatus(current);
        await _sleep(const Duration(seconds: 1));
        continue;
      }

      if (!await _acquire(job)) continue;

      final keepAlive = Timer.periodic(heartbeatEvery, (_) => _touch());
      try {
        final file = await downloader.run(
          job,
          onTick: (p) => _beat(job, p, onStatus, stopping),
        );
        if (file != null) {
          final ready = _status(job, UpdatePhase.ready, job.size, job.size);
          _writeAtomic(_statusFile, ready.encode());
          onStatus(ready);
          return file;
        }
        // أُوقف: تولّى غيرنا، أو تبدّلت المهمة، أو طُلب التوقف — الحلقة تقرر
      } on UpdateContentMismatch {
        await _refreshJob(job, onStatus, stopping);
      } catch (_) {
        // خطأ غير متوقع لا يُنهي التحديث: نتمهل ونعيد
        await _pause(job, const Duration(seconds: 10), onStatus, stopping);
      } finally {
        keepAlive.cancel();
      }
    }
  }

  /// الروابط كلها تخدم غير ما تصفه المهمة: صدر إصدار أحدث أثناء التنزيل، أو
  /// الموقع لم يُنشر بعد. نجلب وصف آخر إصدار ونكمل عليه.
  Future<void> _refreshJob(
    UpdateJob job,
    void Function(UpdateStatus) onStatus,
    bool Function() stopping,
  ) async {
    try {
      final latest = await _feed.fetchLatest();
      final fresh = UpdateJob.forPlatform(latest, job.platform);
      if (fresh != null &&
          fresh.signature != job.signature &&
          !isVersionNewer(job.version, fresh.version)) {
        final currentJob = readJob();
        // لا نكتب فوق مهمة بدّلها التطبيق في هذه الأثناء
        if (currentJob != null && currentJob.signature == job.signature) {
          await writeJob(fresh);
        }
        return;
      }
    } catch (_) {}
    // الوصف نفسه ما زال لا يطابق الملفات (نشر الموقع لم يكتمل): نعيد بعد قليل
    await downloader.discard(job);
    await _pause(job, const Duration(seconds: 60), onStatus, stopping);
  }

  Future<bool> _pause(
    UpdateJob job,
    Duration duration,
    void Function(UpdateStatus) onStatus,
    bool Function() stopping,
  ) async {
    final until = _now().add(duration);
    while (_now().isBefore(until)) {
      if (!_beat(job, const UpdateProgress(UpdatePhase.waiting, 0, 0), onStatus, stopping)) return false;
      await _sleep(const Duration(seconds: 1));
    }
    return true;
  }

  /// يحاول أن يصير المالك. يكتب نبضته ثم يتأكد بعد لحظة أنها ما زالت نبضته:
  /// إن حاول طرفان معاً فآخر من كتب هو الفائز والآخر يتراجع.
  Future<bool> _acquire(UpdateJob job) async {
    final part = downloader.partFile(job);
    final have = await part.exists() ? await part.length() : 0;
    try {
      await dir.create(recursive: true);
      _writeAtomic(_statusFile, _status(job, UpdatePhase.downloading, have, job.size).encode());
    } catch (_) {
      await _sleep(const Duration(seconds: 1));
      return false;
    }
    await _sleep(Duration(milliseconds: 300 + _random.nextInt(250)));
    return readStatus()?.owner == ownerId;
  }

  /// نبضة المالك: تتأكد أنه ما زال المالك وأن المهمة لم تتبدل، ثم تكتب التقدم.
  bool _beat(
    UpdateJob job,
    UpdateProgress progress,
    void Function(UpdateStatus) onStatus,
    bool Function() stopping,
  ) {
    if (stopping()) return false;
    final current = readStatus();
    if (current != null && current.owner != ownerId && current.isFresh(_now(), staleAfter)) {
      return false;
    }
    final jobNow = readJob();
    if (jobNow == null || jobNow.signature != job.signature) return false;

    final status = _status(job, progress.phase, progress.received, progress.total);
    try {
      _writeAtomic(_statusFile, status.encode());
    } catch (_) {
      // قرص ممتلئ: النبضة تفوت، والتنزيل نفسه سيبلّغ عن الخطأ
    }
    onStatus(status);
    return true;
  }

  /// يجدد وقت النبضة بلا تغيير التقدم، ما دمنا المالك.
  void _touch() {
    try {
      final current = readStatus();
      if (current == null || current.owner != ownerId) return;
      _writeAtomic(
        _statusFile,
        UpdateStatus(
          owner: ownerId,
          atMs: _now().millisecondsSinceEpoch,
          phase: current.phase,
          received: current.received,
          total: current.total,
          version: current.version,
        ).encode(),
      );
    } catch (_) {}
  }

  UpdateStatus _status(UpdateJob job, UpdatePhase phase, int received, int total) => UpdateStatus(
        owner: ownerId,
        atMs: _now().millisecondsSinceEpoch,
        phase: phase,
        received: received,
        total: total > 0 ? total : job.size,
        version: job.version,
      );

  /// كتابة ثم إعادة تسمية: القارئ يرى الملف القديم كاملاً أو الجديد كاملاً.
  void _writeAtomic(File file, String content) {
    final temp = File('${file.path}.$ownerId.tmp');
    temp.writeAsStringSync(content, flush: true);
    try {
      temp.renameSync(file.path);
    } on FileSystemException {
      // ويندوز يرفض الاستبدال إن كان قارئ يفتح الملف في اللحظة نفسها
      file.writeAsStringSync(content, flush: true);
      try {
        temp.deleteSync();
      } catch (_) {}
    }
  }

  static final math.Random _random = math.Random();
}
