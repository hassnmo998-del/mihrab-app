import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:crypto/crypto.dart';

import 'update_models.dart';

/// ما وصل إليه التنزيل لحظة النداء.
class UpdateProgress {
  final UpdatePhase phase;
  final int received;
  final int total;

  const UpdateProgress(this.phase, this.received, this.total);
}

/// يُستدعى كل ثانية تقريباً. إعادة false توقف التنزيل فوراً (والجزء المنزَّل يبقى).
typedef UpdateTick = bool Function(UpdateProgress progress);

/// كل الروابط تخدم ملفاً غير الذي تصفه المهمة (حجم آخر أو بصمة أخرى):
/// بيانات الإصدار قديمة ويجب جلبها من جديد.
class UpdateContentMismatch implements Exception {
  final String message;
  const UpdateContentMismatch(this.message);

  @override
  String toString() => 'UpdateContentMismatch: $message';
}

/// هذا الرابط بعينه لا يصلح الآن (ملف آخر، أو 404): يُجرَّب الذي بعده.
class _SourceRejected implements Exception {
  final String reason;

  /// الملف على هذا الرابط ليس ملف المهمة (لا مجرد عطل عابر).
  final bool wrongContent;
  const _SourceRejected(this.reason, {this.wrongContent = false});

  @override
  String toString() => reason;
}

/// محرك تنزيل ملف التحديث.
///
/// لا يفشل بسبب الشبكة أبداً: ينقطع الاتصال فينتظر ويعيد، ويكمل من آخر بايت
/// وصل (HTTP Range) ولو بعد إعادة تشغيل الجهاز، لأن الجزء المنزَّل ملف على القرص.
/// يتوقف في حالتين فقط: طلب [UpdateTick] الإيقاف، أو اكتمال الملف.
///
/// سلامة الملف مضمونة بثلاثة فحوص: الحجم الذي يعلنه الخادم يطابق حجم المهمة
/// قبل قبول أي بايت، والملف لم يتبدل على الخادم بين محاولتين (ETag)، وبصمة
/// sha256 للملف الكامل تطابق بصمة المهمة قبل تسليمه.
class UpdateDownloader {
  UpdateDownloader({
    required this.dir,
    HttpClient Function()? clientFactory,
    Future<void> Function(Duration)? sleep,
    DateTime Function()? now,
    this.connectTimeout = const Duration(seconds: 20),
    this.idleTimeout = const Duration(seconds: 30),
    this.maxBackoff = const Duration(seconds: 30),
    this.backoffBase = const Duration(seconds: 1),
    this.tickInterval = const Duration(milliseconds: 700),
  })  : _clientFactory = clientFactory ?? HttpClient.new,
        _sleep = sleep ?? Future<void>.delayed,
        _now = now ?? DateTime.now;

  final Directory dir;
  final HttpClient Function() _clientFactory;
  final Future<void> Function(Duration) _sleep;
  final DateTime Function() _now;

  /// مهلة فتح الاتصال.
  final Duration connectTimeout;

  /// أقصى صمت بين بايت وآخر قبل اعتبار الاتصال ميتاً وإعادة فتحه.
  final Duration idleTimeout;

  /// الانتظار بعد فشل متكرر: [backoffBase] × 2، 4، 8… حتى [maxBackoff].
  final Duration maxBackoff;
  final Duration backoffBase;
  final Duration tickInterval;

  File finalFile(UpdateJob job) => File('${dir.path}${Platform.pathSeparator}${job.fileName}');
  File partFile(UpdateJob job) => File('${finalFile(job).path}.part');
  File _metaFile(UpdateJob job) => File('${finalFile(job).path}.meta');

  /// هل الملف النهائي موجود بحجمه الكامل؟
  Future<bool> isComplete(UpdateJob job) async {
    final file = finalFile(job);
    if (!await file.exists()) return false;
    return job.size <= 0 || await file.length() == job.size;
  }

  /// يحذف كل ما نُزّل لهذه المهمة.
  Future<void> discard(UpdateJob job) async {
    for (final f in [finalFile(job), partFile(job), _metaFile(job)]) {
      try {
        if (await f.exists()) await f.delete();
      } catch (_) {}
    }
  }

  /// ينزّل ملف [job] حتى يكتمل ويعيده، أو يعيد null إن أوقفه [onTick].
  ///
  /// يرمي [UpdateContentMismatch] فقط حين لا يطابق أي رابط وصف المهمة.
  Future<File?> run(UpdateJob job, {required UpdateTick onTick}) async {
    await dir.create(recursive: true);
    final part = partFile(job);
    final meta = await _readMeta(job);

    var source = 0;
    var failures = 0;
    // ملفات اكتمل حجمها وخالفت بصمتها (لا يصفّرها تقدم التنزيل)
    var hashFailures = 0;
    // روابط رفضناها لأن حجم ملفها غير حجم المهمة، منذ آخر تقدم
    final wrongSize = <int>{};

    while (true) {
      if (await isComplete(job)) return finalFile(job);

      final expected = job.size > 0 ? job.size : (meta['total'] as int? ?? 0);
      var have = await part.exists() ? await part.length() : 0;
      if (expected > 0 && have > expected) {
        await _resetPart(job, meta);
        have = 0;
      }

      if (expected > 0 && have == expected) {
        if (!onTick(UpdateProgress(UpdatePhase.verifying, have, expected))) return null;
        final verified = await _verify(part, job, onTick);
        if (verified == null) return null;
        if (verified) {
          final done = finalFile(job);
          if (await done.exists()) await done.delete();
          await part.rename(done.path);
          try {
            await _metaFile(job).delete();
          } catch (_) {}
          return done;
        }
        // الحجم صحيح والبصمة لا: ما نزل ليس ملف هذا الإصدار
        await _resetPart(job, meta);
        hashFailures++;
        source = (source + 1) % job.urls.length;
        if (hashFailures >= math.max(2, job.urls.length)) {
          throw const UpdateContentMismatch('بصمة الملف لا تطابق الإصدار');
        }
        continue;
      }

      if (!onTick(UpdateProgress(UpdatePhase.downloading, have, expected))) return null;

      try {
        final received = await _attempt(job, job.urls[source], have, meta, onTick);
        if (received == null) return null; // أوقفه onTick
        if (received > 0) {
          failures = 0;
          wrongSize.clear();
          continue;
        }
        // انتهى الرد بلا بايت واحد: يُعامل كانقطاع
        failures++;
      } on _SourceRejected catch (e) {
        if (e.wrongContent) {
          wrongSize.add(source);
          if (wrongSize.length >= job.urls.length) {
            throw UpdateContentMismatch(e.reason);
          }
        } else {
          failures++;
        }
        source = (source + 1) % job.urls.length;
        if (e.wrongContent) continue;
      } on FileSystemException catch (_) {
        // القرص ممتلئ أو الملف مقفل: ننتظر ونعيد، وما نزل يبقى
        if (!await _wait(const Duration(seconds: 20), UpdatePhase.noSpace, job, onTick)) return null;
        continue;
      } catch (_) {
        // انقطاع، مهلة، خطأ خادم: كلها عابرة. اتصال انقطع بعد أن أوصل بايتات
        // ليس فشلاً متكرراً: يُعاد سريعاً بلا تطويل الانتظار
        final after = await part.exists() ? await part.length() : 0;
        failures = after > have ? 1 : failures + 1;
        if (failures % 3 == 0) source = (source + 1) % job.urls.length;
      }

      final scaled = backoffBase * (1 << math.min(failures, 5));
      final backoff = scaled > maxBackoff ? maxBackoff : scaled;
      if (!await _wait(backoff, UpdatePhase.waiting, job, onTick)) return null;
    }
  }

  /// محاولة اتصال واحدة. تعيد عدد البايتات التي وصلت فيها، أو null إن طُلب الإيقاف.
  Future<int?> _attempt(
    UpdateJob job,
    String url,
    int have,
    Map<String, dynamic> meta,
    UpdateTick onTick,
  ) async {
    final part = partFile(job);
    // آخر نبضة كانت قبيل هذه المحاولة: إن طال فتح الاتصال فأول بايت يصل ينبض قبل كتابته
    var lastTick = _now();
    final client = _clientFactory()..connectionTimeout = connectTimeout;
    try {
      final request = await client.getUrl(Uri.parse(url)).timeout(connectTimeout);
      request.followRedirects = true;
      request.maxRedirects = 6;
      // بلا ضغط: الحجم والمدى يجب أن يكونا على بايتات الملف نفسها
      request.headers.set(HttpHeaders.acceptEncodingHeader, 'identity');
      if (have > 0) request.headers.set(HttpHeaders.rangeHeader, 'bytes=$have-');

      final response = await request.close().timeout(idleTimeout);
      final expected = job.size > 0 ? job.size : (meta['total'] as int? ?? 0);
      final etags = (meta['etags'] as Map<String, dynamic>?) ?? (meta['etags'] = <String, dynamic>{});
      final etag = response.headers.value(HttpHeaders.etagHeader);

      var offset = have;
      switch (response.statusCode) {
        case HttpStatus.partialContent:
          final range = _parseContentRange(response.headers.value(HttpHeaders.contentRangeHeader));
          if (range == null || range.start != have) {
            throw const HttpException('مدى غير متوقع من الخادم');
          }
          if (expected > 0 && range.total != expected) {
            throw _SourceRejected('حجم الملف على $url هو ${range.total} لا $expected', wrongContent: true);
          }
          final known = etags[url] as String?;
          if (known != null && etag != null && known != etag) {
            // الملف تبدّل على هذا الرابط بين محاولتين: ما نزل منه لا يُكمَل
            await _drain(response);
            await _resetPart(job, meta);
            return 0;
          }
          if (expected == 0) meta['total'] = range.total;
        case HttpStatus.ok:
          final length = response.contentLength;
          if (expected > 0 && length > 0 && length != expected) {
            throw _SourceRejected('حجم الملف على $url هو $length لا $expected', wrongContent: true);
          }
          // الخادم أرسل الملف من أوله (تجاهل المدى): نبدأ من الصفر
          offset = 0;
          if (expected == 0 && length > 0) meta['total'] = length;
        case HttpStatus.requestedRangeNotSatisfiable:
          await _drain(response);
          await _resetPart(job, meta);
          return 0;
        case HttpStatus.notFound:
        case HttpStatus.forbidden:
        case HttpStatus.gone:
        case HttpStatus.unauthorized:
          await _drain(response);
          throw _SourceRejected('$url أعاد ${response.statusCode}');
        default:
          await _drain(response);
          throw HttpException('HTTP ${response.statusCode}', uri: Uri.parse(url));
      }

      if (etag != null) etags[url] = etag;
      await _writeMeta(job, meta);

      final total = job.size > 0 ? job.size : (meta['total'] as int? ?? 0);
      final file = await part.open(mode: offset > 0 ? FileMode.append : FileMode.write);
      var written = 0;
      var stopped = false;
      try {
        await for (final chunk in response.timeout(idleTimeout)) {
          // قبل الكتابة: بعد تجميد طويل للتطبيق قد يكون غيرنا تولّى التنزيل
          if (_now().difference(lastTick) >= tickInterval) {
            await file.flush();
            lastTick = _now();
            if (!onTick(UpdateProgress(UpdatePhase.downloading, offset + written, total))) {
              stopped = true;
              break;
            }
          }
          if (total > 0 && offset + written + chunk.length > total) {
            throw _SourceRejected('$url أرسل أكثر من حجم الملف', wrongContent: true);
          }
          await file.writeFrom(chunk);
          written += chunk.length;
        }
      } finally {
        await file.flush();
        await file.close();
      }
      return stopped ? null : written;
    } finally {
      client.close(force: true);
    }
  }

  /// ينتظر [duration] وهو ينبض كل ثانية (ليبقى ظاهراً أنه حي، وليُسمع طلب الإيقاف).
  Future<bool> _wait(Duration duration, UpdatePhase phase, UpdateJob job, UpdateTick onTick) async {
    final part = partFile(job);
    final have = await part.exists() ? await part.length() : 0;
    final until = _now().add(duration);
    while (true) {
      if (!onTick(UpdateProgress(phase, have, job.size))) return false;
      final left = until.difference(_now());
      if (left <= Duration.zero) return true;
      await _sleep(left < const Duration(seconds: 1) ? left : const Duration(seconds: 1));
    }
  }

  /// true سليم، false تالف، null طُلب الإيقاف أثناء الفحص.
  Future<bool?> _verify(File file, UpdateJob job, UpdateTick onTick) async {
    if (job.sha256.isEmpty) return true;
    final digestSink = _DigestSink();
    final hasher = sha256.startChunkedConversion(digestSink);
    final size = await file.length();
    var lastTick = _now();
    await for (final chunk in file.openRead()) {
      hasher.add(chunk);
      if (_now().difference(lastTick) >= tickInterval) {
        lastTick = _now();
        if (!onTick(UpdateProgress(UpdatePhase.verifying, size, size))) return null;
      }
    }
    hasher.close();
    return digestSink.value.toString() == job.sha256.toLowerCase();
  }

  Future<void> _resetPart(UpdateJob job, Map<String, dynamic> meta) async {
    meta
      ..remove('etags')
      ..remove('total');
    for (final f in [partFile(job), _metaFile(job)]) {
      try {
        if (await f.exists()) await f.delete();
      } catch (_) {}
    }
  }

  Future<Map<String, dynamic>> _readMeta(UpdateJob job) async {
    try {
      final file = _metaFile(job);
      // بيانات جزء لم يعد موجوداً لا تعني شيئاً
      if (await file.exists() && await partFile(job).exists()) {
        return jsonDecode(await file.readAsString()) as Map<String, dynamic>;
      }
    } catch (_) {}
    return <String, dynamic>{};
  }

  Future<void> _writeMeta(UpdateJob job, Map<String, dynamic> meta) async {
    try {
      await _metaFile(job).writeAsString(jsonEncode(meta), flush: true);
    } catch (_) {}
  }

  static Future<void> _drain(HttpClientResponse response) async {
    try {
      await response.drain<void>().timeout(const Duration(seconds: 5));
    } catch (_) {}
  }

  /// "bytes 1000-1999/98778537"
  static ({int start, int total})? _parseContentRange(String? header) {
    final m = RegExp(r'bytes\s+(\d+)-\d+/(\d+)').firstMatch(header ?? '');
    if (m == null) return null;
    return (start: int.parse(m[1]!), total: int.parse(m[2]!));
  }
}

class _DigestSink implements Sink<Digest> {
  late Digest value;

  @override
  void add(Digest data) => value = data;

  @override
  void close() {}
}
