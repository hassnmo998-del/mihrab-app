import 'dart:convert';
import 'dart:io';
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

  PendingUpload({
    required this.eventId,
    required this.title,
    required this.speaker,
    required this.filePath,
    required this.durationSeconds,
    required this.queuedAt,
    this.kind = UploadKind.audio,
    this.fileName,
  });

  bool get isVideo => kind == UploadKind.video;

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
  );
}

class AudioUploadQueueManager extends ChangeNotifier {
  static const String _storageKey = 'pending_audio_uploads';
  static const String telegramBotToken = TelegramMediaResolver.botToken;
  static const String telegramChatId = '-1004356803065';

  final List<PendingUpload> _queue = [];
  bool _isUploading = false;

  List<PendingUpload> get queue => List.unmodifiable(_queue);
  bool get isUploading => _isUploading;

  Future<void> init() async {
    await _loadFromStorage();
    _processQueue();
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
    _isUploading = true;
    notifyListeners();

    while (_queue.isNotEmpty) {
      final current = _queue.first;
      final file = File(current.filePath);

      if (!file.existsSync()) {
        debugPrint('File not found for event ${current.eventId}, skipping.');
        _queue.removeAt(0);
        await _saveToStorage();
        notifyListeners();
        continue;
      }

      // A file over the archive limit can never be opened after upload, and retrying
      // it forever would block every upload behind it. Drop it from the queue but keep
      // the local file so nothing is lost.
      if (file.lengthSync() > MediaLimits.maxFileBytes) {
        debugPrint('⚠️ ${current.filePath} أكبر من ${MediaLimits.maxFileMbLabel}MB، أُزيل من طابور الرفع.');
        _queue.removeAt(0);
        await _saveToStorage();
        notifyListeners();
        continue;
      }

      bool success = await _performUpload(current, file);
      if (success) {
        _queue.removeAt(0);
        await _saveToStorage();
        notifyListeners();
      } else {
        // Break on failure (likely network) to retry later
        break;
      }
    }

    _isUploading = false;
    notifyListeners();
  }

  Future<bool> _performUpload(PendingUpload upload, File file) async {
    try {
      final isDocument = upload.kind == UploadKind.document;
      final isVideo = !isDocument &&
          (upload.isVideo ||
              upload.filePath.toLowerCase().endsWith('.mp4') ||
              upload.filePath.toLowerCase().endsWith('.mkv') ||
              upload.filePath.toLowerCase().endsWith('.mov'));

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
        request.files.add(await http.MultipartFile.fromPath('audio', file.path));
      }

      final response = await request.send();
      if (response.statusCode != 200) return false;

      final responseBody = await response.stream.bytesToString();
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
          final permanentRef = isDocument
              ? TelegramMediaResolver.buildFileRef(
                  fileId: fileId,
                  fileName: upload.fileName ?? file.uri.pathSegments.last,
                )
              : TelegramMediaResolver.buildRef(fileId: fileId, isVideo: isVideo);

          // المستندات والفيديو يذهبان لحقل المرفق، والصوت لحقل التسجيل.
          _onMediaUploadSuccess?.call(upload.eventId, permanentRef, isVideo || isDocument);
          if (!isDocument) _onUploadSuccess?.call(upload.eventId, permanentRef);

          // حذف الملف المحلي بعد النجاح لتوفير المساحة
          try { await file.delete(); } catch (_) {}
          return true;
        }
      }
      return false;
    } catch (e) {
      debugPrint('Upload failed: $e');
      return false;
    }
  }

  // Callbacks لربطه بـ DataService
  Function(String eventId, String mediaUrl, bool isVideo)? _onMediaUploadSuccess;
  Function(String eventId, String audioUrl)? _onUploadSuccess;

  void setOnMediaUploadSuccess(Function(String, String, bool) callback) {
    _onMediaUploadSuccess = callback;
  }

  void setOnUploadSuccess(Function(String, String) callback) {
    _onUploadSuccess = callback;
  }
}
