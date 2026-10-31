import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'telegram_media_resolver.dart';

/// نوع الملف المرفوع: تسجيل الدرس الصوتي، فيديو قديم بالطابور، أو مرفق عام.
enum UploadKind { audio, video, document }

class PendingUpload {
  final String eventId;
  final String title;
  final String speaker;
  final String filePath;
  final int durationSeconds;
  final DateTime queuedAt;
  final UploadKind kind;

  /// الاسم الأصلي للمرفق كما اختاره المستخدم (للمستندات فقط).
  final String? fileName;

  /// مرجع الملف في الأرشيف بعد رفعه، ما دام لم يُربط بسجل درسه بعد (السجل لم يصل
  /// الجهاز، أو البيانات لم تُحمَّل). لا يُعاد الرفع، ويُعاد الربط فقط.
  final String? uploadedRef;

  PendingUpload({
    required this.eventId,
    required this.title,
    required this.speaker,
    required this.filePath,
    required this.durationSeconds,
    required this.queuedAt,
    this.kind = UploadKind.audio,
    this.fileName,
    this.uploadedRef,
  });

  bool get isVideo => kind == UploadKind.video;

  PendingUpload withUploadedRef(String ref) => PendingUpload(
        eventId: eventId,
        title: title,
        speaker: speaker,
        filePath: filePath,
        durationSeconds: durationSeconds,
        queuedAt: queuedAt,
        kind: kind,
        fileName: fileName,
        uploadedRef: ref,
      );

  Map<String, dynamic> toJson() => {
    'eventId': eventId,
    'title': title,
    'speaker': speaker,
    'filePath': filePath,
    'durationSeconds': durationSeconds,
    'queuedAt': queuedAt.toIso8601String(),
    'isVideo': isVideo,
    'kind': kind.name,
    'fileName': fileName,
    'uploadedRef': uploadedRef,
  };

  factory PendingUpload.fromJson(Map<String, dynamic> json) => PendingUpload(
    eventId: json['eventId'],
    title: json['title'],
    speaker: json['speaker'],
    filePath: json['filePath'],
    durationSeconds: json['durationSeconds'],
    queuedAt: DateTime.parse(json['queuedAt']),
    // Items queued by older versions only carried isVideo.
    kind: UploadKind.values.asNameMap()[json['kind']] ??
        ((json['isVideo'] ?? false) == true ? UploadKind.video : UploadKind.audio),
    fileName: json['fileName'],
    uploadedRef: json['uploadedRef'],
  );
}

class AudioUploadQueueManager extends ChangeNotifier {
  static const String _storageKey = 'pending_audio_uploads';
  static const String telegramBotToken = TelegramMediaResolver.botToken;
  static const String telegramChatId = '-1004356803065';

  final List<PendingUpload> _queue = [];
  bool _isUploading = false;

  // رفعٌ فشل (لا إنترنت غالباً) يُعاد وحده: بعد 30 ثانية ثم أطول حتى 5 دقائق.
  // قبل ذلك كان ينتظر إعادة فتح التطبيق.
  Timer? _retryTimer;
  int _failures = 0;

  /// أقصى انتظار لرفع ملف واحد: اتصال علِق لا يُبقي الطابور كله واقفاً.
  static const Duration uploadTimeout = Duration(minutes: 20);

  /// الانتظار قبل أول إعادة محاولة؛ يتضاعف مع كل فشل متتالٍ حتى خمس دقائق.
  @visibleForTesting
  Duration retryBase = const Duration(seconds: 30);

  /// للاختبارات: بديل عن الرفع الفعلي إلى أرشيف تيليجرام (رفع وربط معاً).
  @visibleForTesting
  Future<bool> Function(PendingUpload upload, File file)? debugUploader;

  /// للاختبارات: بديل عن الرفع وحده، يعيد مرجع الملف في الأرشيف ثم يمرّ بالربط الحقيقي.
  @visibleForTesting
  Future<String?> Function(PendingUpload upload, File file)? debugRefUploader;

  /// الانتظار قبل إعادة ربط ملف رُفع ولم يجد سجل درسه بعد على الجهاز.
  @visibleForTesting
  Duration linkRetry = const Duration(minutes: 1);

  List<PendingUpload> get queue => List.unmodifiable(_queue);
  bool get isUploading => _isUploading;

  Future<void> init() async {
    await _loadFromStorage();
    _processQueue();
  }

  /// يحاول الآن ما ينتظر الرفع (عند عودة التطبيق للواجهة أو عند المزامنة).
  void retryNow() {
    if (_queue.isEmpty) return;
    _retryTimer?.cancel();
    _processQueue();
  }

  void _scheduleRetry() {
    _retryTimer?.cancel();
    final wait = retryBase * (1 << math.min(_failures - 1, 4));
    const longest = Duration(minutes: 5);
    _retryTimer = Timer(wait > longest ? longest : wait, _processQueue);
  }

  Future<void> addToQueue({
    required String eventId,
    required String title,
    required String speaker,
    required String filePath,
    required int durationSeconds,
    UploadKind kind = UploadKind.audio,
    String? fileName,
  }) async {
    final upload = PendingUpload(
      eventId: eventId,
      title: title,
      speaker: speaker,
      filePath: filePath,
      durationSeconds: durationSeconds,
      queuedAt: DateTime.now(),
      kind: kind,
      fileName: fileName,
    );
    _queue.add(upload);
    await _saveToStorage();
    notifyListeners();
    _processQueue();
  }

  Future<void> _loadFromStorage() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final data = prefs.getString(_storageKey);
      if (data != null) {
        final List<dynamic> list = jsonDecode(data);
        _queue.clear();
        _queue.addAll(list.map((e) => PendingUpload.fromJson(e)));
        notifyListeners();
      }
    } catch (e) {
      debugPrint('Error loading upload queue: $e');
    }
  }

  Future<void> _saveToStorage() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_storageKey, jsonEncode(_queue.map((e) => e.toJson()).toList()));
    } catch (e) {
      debugPrint('Error saving upload queue: $e');
    }
  }

  Future<void> _processQueue() async {
    if (_isUploading || _queue.isEmpty) return;
    _retryTimer?.cancel();
    _isUploading = true;
    notifyListeners();

    var waitingForLink = false;
    var i = 0;
    while (i < _queue.length) {
      var current = _queue[i];
      final file = File(current.filePath);

      if (current.uploadedRef == null) {
        if (!file.existsSync()) {
          debugPrint('File not found for event ${current.eventId}, skipping.');
          _queue.removeAt(i);
          await _saveToStorage();
          notifyListeners();
          continue;
        }

        // A file over the archive limit can never be opened after upload, and retrying
        // it forever would block every upload behind it. Drop it from the queue but keep
        // the local file so nothing is lost.
        if (file.lengthSync() > MediaLimits.maxFileBytes) {
          debugPrint('⚠️ ${current.filePath} أكبر من ${MediaLimits.maxFileMbLabel}MB، أُزيل من طابور الرفع.');
          _queue.removeAt(i);
          await _saveToStorage();
          notifyListeners();
          continue;
        }

        final legacy = debugUploader;
        if (legacy != null) {
          if (await legacy(current, file)) {
            _failures = 0;
            _queue.removeAt(i);
            await _saveToStorage();
            notifyListeners();
            continue;
          }
          _failures++;
          _scheduleRetry();
          break;
        }

        final ref = await (debugRefUploader ?? _performUpload)(current, file);
        if (ref == null) {
          // Break on failure (likely network) and try again by itself later
          _failures++;
          _scheduleRetry();
          break;
        }
        _failures = 0;
        // المرجع يُحفظ قبل الربط: إن لم يُربط الآن لا يُرفع الملف مرة ثانية
        current = current.withUploadedRef(ref);
        _queue[i] = current;
        await _saveToStorage();
      }

      if (_attach(current)) {
        // الملف المحلي يُحذف بعد أن صار مربوطاً بدرسه فقط
        try {
          if (file.existsSync()) await file.delete();
        } catch (_) {}
        _queue.removeAt(i);
        await _saveToStorage();
        notifyListeners();
      } else {
        // سجل الدرس لم يصل الجهاز بعد: يبقى في الطابور ولا يوقف ما بعده
        waitingForLink = true;
        i++;
      }
    }

    _isUploading = false;
    if (waitingForLink && !(_retryTimer?.isActive ?? false)) {
      _retryTimer = Timer(linkRetry, _processQueue);
    }
    notifyListeners();
  }

  static bool _isVideoUpload(PendingUpload upload) {
    if (upload.kind == UploadKind.document) return false;
    final path = upload.filePath.toLowerCase();
    return upload.isVideo || path.endsWith('.mp4') || path.endsWith('.mkv') || path.endsWith('.mov');
  }

  /// يربط الملف المرفوع بسجل درسه. false: السجل غير موجود على الجهاز بعد، فيُعاد لاحقاً.
  bool _attach(PendingUpload upload) {
    final ref = upload.uploadedRef;
    final callback = _onMediaUploadSuccess;
    if (ref == null || callback == null) return false;
    final isDocument = upload.kind == UploadKind.document;
    // المستندات والفيديو يذهبان لحقل المرفق، والصوت لحقل التسجيل.
    final linked = callback(upload.eventId, ref, _isVideoUpload(upload) || isDocument);
    if (linked && !isDocument) _onUploadSuccess?.call(upload.eventId, ref);
    return linked;
  }

  /// يرفع الملف إلى أرشيف تيليجرام ويعيد مرجعه الدائم، أو null إن فشل.
  Future<String?> _performUpload(PendingUpload upload, File file) async {
    try {
      final isDocument = upload.kind == UploadKind.document;
      final isVideo = _isVideoUpload(upload);

      final endpoint = isDocument ? 'sendDocument' : (isVideo ? 'sendVideo' : 'sendAudio');
      final uri = Uri.parse('https://api.telegram.org/bot$telegramBotToken/$endpoint');
      
      final hours = (upload.durationSeconds ~/ 3600).toString().padLeft(2, '0');
      final minutes = ((upload.durationSeconds % 3600) ~/ 60).toString().padLeft(2, '0');
      final seconds = (upload.durationSeconds % 60).toString().padLeft(2, '0');
      final durationStr = upload.durationSeconds >= 3600 ? '$hours:$minutes:$seconds' : '$minutes:$seconds';

      final request = http.MultipartRequest('POST', uri)
        ..fields['chat_id'] = telegramChatId
        ..fields['caption'] = isDocument
            ? '📎 مرفق لدرس: ${upload.title}\nالمحاضر: ${upload.speaker}'
            : isVideo
                ? '🎬 تسجيل مرئي لدرس: ${upload.title}\nالمحاضر: ${upload.speaker}\nالمدة: $durationStr'
                : '🎙️ درس صوتي: ${upload.title}\nالمحاضر: ${upload.speaker}\nالمدة: $durationStr';

      if (isDocument) {
        request.files.add(await http.MultipartFile.fromPath(
          'document',
          file.path,
          filename: upload.fileName ?? file.uri.pathSegments.last,
        ));
      } else if (isVideo) {
        // تفعيل البث السريع والمستقر للمشاهدين مباشرة في الأرشيف
        request.fields['supports_streaming'] = 'true';
        request.files.add(await http.MultipartFile.fromPath('video', file.path));
      } else {
        request.fields['title'] = upload.title;
        request.fields['performer'] = upload.speaker;
        if (upload.durationSeconds > 0) {
          request.fields['duration'] = '${upload.durationSeconds}';
        }
        request.files.add(await http.MultipartFile.fromPath('audio', file.path));
      }

      final response = await request.send().timeout(uploadTimeout);
      if (response.statusCode != 200) return null;

      final responseBody =
          await response.stream.bytesToString().timeout(const Duration(minutes: 2));
      final jsonResponse = jsonDecode(responseBody);

      if (jsonResponse['ok'] == true) {
        final result = jsonResponse['result'];
        final mediaObj = isDocument
            ? (result['document'] ?? result['video'] ?? result['audio'])
            : isVideo
                ? (result['video'] ?? result['document'] ?? result['audio'])
                : (result['audio'] ?? result['document']);
        final fileId = mediaObj?['file_id'];

        if (fileId != null) {
          // نحفظ المعرّف الدائم لا الرابط: روابط تيليجرام تنتهي بعد ساعة،
          // بينما الـ file_id يبقى صالحاً دائماً ويُحوَّل لرابط طازج عند التشغيل.
          return isDocument
              ? TelegramMediaResolver.buildFileRef(
                  fileId: fileId,
                  fileName: upload.fileName ?? file.uri.pathSegments.last,
                )
              : TelegramMediaResolver.buildRef(fileId: fileId, isVideo: isVideo);
        }
      }
      return null;
    } catch (e) {
      debugPrint('Upload failed: $e');
      return null;
    }
  }

  // Callbacks لربطه بـ DataService
  /// يربط المرجع بسجل الدرس ويعيد true إن رُبط (أو لم يعد للربط معنى: السجل حُذف).
  bool Function(String eventId, String mediaUrl, bool isVideo)? _onMediaUploadSuccess;
  Function(String eventId, String audioUrl)? _onUploadSuccess;

  void setOnMediaUploadSuccess(bool Function(String, String, bool) callback) {
    _onMediaUploadSuccess = callback;
  }

  void setOnUploadSuccess(Function(String, String) callback) {
    _onUploadSuccess = callback;
  }
}
