import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'supabase_remote_datasource.dart';

/// Manages the persistent FIFO background synchronization queue (`pending_sync_queue`).
/// Queues offline mutations and processes them automatically when connectivity is available.
class OfflineSyncQueueManager {
  static const String queueKey = 'pending_sync_queue';

  /// ما رفضه الخادم نهائياً، يُحفظ للتشخيص (آخر مئة) بدل أن يختفي بلا أثر.
  static const String rejectedKey = 'sync_rejected_log';

  /// مهلة كل عملية رفع: اتصال معلّق لا يُبقي الطابور كله مشغولاً.
  static Duration requestTimeout = const Duration(seconds: 25);

  /// بعد هذا العدد من ردود الخادم بخطأ على سجل واحد، يُتخطّى في الجولة (ولا يُسقط)
  /// كي لا يحجز سجل واحد كل ما بعده.
  static int stuckAfter = 20;

  /// هل الخطأ عابر (الشبكة مقطوعة، الخادم مشغول، مهلة)؟ السجل نفسه سليم وسيُقبل
  /// لاحقاً، فلا يُسقط من الطابور أبداً. غير العابر هو رفض الخادم للسجل ذاته.
  ///
  /// كان كل خطأ يُعدّ ثلاث مرات ثم يُسقط: تعديل أُجري بلا إنترنت يخرج من الطابور بعد
  /// أقل من دقيقة، ثم تحذفه المزامنة من الجهاز حين يعود الاتصال لأنه «غير موجود في
  /// السحابة ولا ينتظر الرفع».
  static bool isTransientError(Object error) {
    if (error is! PostgrestException) return true;
    final code = (error.code ?? '').trim().toUpperCase();
    // رمز حالة HTTP (ثلاثة أرقام). رموز PostgreSQL خمسة محارف وقد تكون كلها أرقاماً.
    final status = code.length <= 3 ? int.tryParse(code) : null;
    if (status != null) {
      return status >= 500 || status == 0 || status == 401 || status == 408 || status == 429;
    }
    // PostgREST: تعذّر الاتصال بقاعدة البيانات، انتهاء صلاحية الرمز
    if (const {'PGRST000', 'PGRST001', 'PGRST002', 'PGRST003', 'PGRST301', 'PGRST302'}.contains(code)) {
      return true;
    }
    // PostgreSQL: انقطاع اتصال، موارد غير كافية، تعارض مؤقت، إلغاء بمهلة، إيقاف الخادم
    return code.startsWith('08') ||
        code.startsWith('53') ||
        code.startsWith('57') ||
        code.startsWith('40') ||
        code.startsWith('XX');
  }

  final List<Map<String, dynamic>> _pendingSyncQueue = [];
  bool _isProcessingQueue = false;

  /// Current snapshot of queued offline operations
  List<Map<String, dynamic>> get pendingQueue => List.unmodifiable(_pendingSyncQueue);

  /// Whether the queue is currently dispatching operations
  bool get isProcessingQueue => _isProcessingQueue;

  /// Loads pending sync queue from local SharedPreferences
  Future<void> loadQueue() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final str = prefs.getString(queueKey);
      if (str != null) {
        final List list = jsonDecode(str);
        _pendingSyncQueue.clear();
        for (var item in list) {
          if (item is Map<String, dynamic>) {
            _pendingSyncQueue.add(item);
          }
        }
      }
    } catch (_) {}
  }

  /// Persists current sync queue to SharedPreferences
  Future<void> saveQueue() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(queueKey, jsonEncode(_pendingSyncQueue));
    } catch (_) {}
  }

  /// رفض لأن السجل يشير إلى سجل غير موجود في الخادم (قيد المفتاح الأجنبي).
  static bool _isMissingParent(Object error) =>
      error is PostgrestException && (error.code ?? '').trim() == '23503';

  /// Enqueue an upsert or delete operation into the persistent FIFO queue
  void queueSync({
    required String table,
    // 'upsert' (whole row), 'patch' (listed columns only, row must exist), 'delete'
    required String action,
    required Map<String, dynamic> data,
    String? id,
    SupabaseRemoteDataSource? remoteDataSource,
  }) {
    // تطهير أي عمليات سابقة متعلقة بنفس المعرف عند ورود أمر حذف لمنع تضارب العمليات
    if (action == 'delete' && id != null) {
      _pendingSyncQueue.removeWhere(
        (item) => item['table'] == table && (item['id'] == id || item['data']?['id'] == id),
      );
      // تنفيذ الحذف الفوري المباشر سحابياً عند توفر الاتصال
      if (remoteDataSource != null) {
        remoteDataSource.delete(table, matchingColumn: 'id', matchingValue: id).catchError((e) {
          debugPrint('⚠️ Immediate delete failed ($table.$id): $e');
        });
      }
    }

    _pendingSyncQueue.add({
      'table': table,
      'action': action,
      'data': data,
      'id': id,
      'queued_at': DateTime.now().toIso8601String(),
    });
    saveQueue();

    // Trigger non-blocking background dispatch if remote data source provided
    if (remoteDataSource != null) {
      processQueue(remoteDataSource);
    }
  }

  /// فحص ما إذا كان العنصر يحمل أمر حذف معلق في طابور المزامنة
  bool isPendingDelete(String table, String id) {
    return _pendingSyncQueue.any(
      (item) => item['table'] == table && item['action'] == 'delete' && item['id'] == id,
    );
  }

  /// فحص ما إذا كان العنصر يحمل أمر إضافة أو تعديل معلق في طابور المزامنة
  bool isPendingUpsert(String table, String id) {
    return _pendingSyncQueue.any(
      (item) =>
          item['table'] == table &&
          (item['action'] == 'upsert' || item['action'] == 'patch') &&
          (item['id'] == id || item['data']?['id'] == id),
    );
  }

  /// Clears the entire in-memory queue
  void clearQueue() {
    _pendingSyncQueue.clear();
  }

  /// Process queue sequentially. A transient failure (no network, busy server,
  /// timeout) stops the loop and keeps every item, in order, for the next attempt.
  /// Only a row the server itself rejects is removed, and it is logged.
  Future<void> processQueue(SupabaseRemoteDataSource remoteDataSource) async {
    final client = remoteDataSource.client;
    if (client == null || _isProcessingQueue || _pendingSyncQueue.isEmpty) {
      return;
    }
    _isProcessingQueue = true;

    try {
      final toRemove = <Map<String, dynamic>>[];
      // صفوف تُخطّيت في هذه الجولة: ما بعدها لنفس الصف ينتظرها كي لا ينقلب الترتيب
      final heldRows = <String>{};
      for (final item in List.from(_pendingSyncQueue)) {
        final rowKey = '${item['table']}|${item['id'] ?? item['data']?['id']}';
        if (heldRows.contains(rowKey)) continue;
        try {
          final table = item['table'] as String;
          final action = item['action'] as String;
          final data = item['data'] as Map<String, dynamic>;
          final id = item['id'] as String?;

          if (action == 'upsert') {
            await remoteDataSource.upsert(table, data).timeout(requestTimeout);
          } else if (action == 'patch' && id != null) {
            // تحديث الأعمدة المرسلة فقط: الحفظ الكامل للصف كان يسمح لجهاز
            // بنسخة قديمة أن يعيد كتابة حقول غيّرها جهاز آخر (مثل ربط الفرع).
            await remoteDataSource
                .update(
                  table,
                  data,
                  matchingColumn: 'id',
                  matchingValue: id,
                )
                .timeout(requestTimeout);
          } else if (action == 'delete' && id != null) {
            await remoteDataSource
                .delete(table, matchingColumn: 'id', matchingValue: id)
                .timeout(requestTimeout);
          }
          toRemove.add(item);
        } catch (e) {
          debugPrint('⚠️ SyncQueue error processing table ${item['table']}: $e');
          if (isTransientError(e)) {
            // لا إنترنت أو الخادم مشغول: يبقى العنصر وما بعده بترتيبهم للمحاولة التالية
            final retries = (item['retry_count'] as int? ?? 0) + 1;
            item['retry_count'] = retries;
            if (e is PostgrestException && retries >= stuckAfter) {
              // الخادم يردّ بخطأ على هذا السجل منذ مدة: يبقى في الطابور ولا يحجز غيره
              heldRows.add(rowKey);
              continue;
            }
            break;
          }
          if (heldRows.isNotEmpty && _isMissingParent(e)) {
            // سجل يتبع سجلاً عالقاً تُخطّي في هذه الجولة (حركة نقاط لطالب لم يُرفع بعد):
            // رفضه سببه غياب أصله مؤقتاً لا عيب فيه، فيبقى معه ولا يُسقط.
            item['retry_count'] = (item['retry_count'] as int? ?? 0) + 1;
            heldRows.add(rowKey);
            continue;
          }
          // الخادم رفض السجل نفسه (بيانات لا يقبلها): إبقاؤه يحجز كل ما بعده.
          debugPrint('⚠️ SyncQueue dropping item rejected by the server for table ${item['table']} ($e)');
          await _logRejected(item, e);
          toRemove.add(item);
          continue;
        }
      }
      if (toRemove.isNotEmpty) {
        _pendingSyncQueue.removeWhere((i) => toRemove.contains(i));
      }
      // حفظ الطابور لحفظ عدادات المحاولات وعدم ضياعها
      await saveQueue();
    } catch (e) {
      debugPrint('⚠️ SyncQueue outer exception: $e');
    } finally {
      _isProcessingQueue = false;
    }
  }

  Future<void> _logRejected(Map<String, dynamic> item, Object error) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(rejectedKey);
      final log = raw == null ? <dynamic>[] : (jsonDecode(raw) as List);
      log.add({
        'table': item['table'],
        'action': item['action'],
        'id': item['id'] ?? item['data']?['id'],
        'error': error.toString(),
        'at': DateTime.now().toIso8601String(),
        'data': item['data'],
      });
      while (log.length > 100) {
        log.removeAt(0);
      }
      await prefs.setString(rejectedKey, jsonEncode(log));
    } catch (_) {}
  }

  /// ما رفضه الخادم من عمليات (للتشخيص).
  static Future<List<Map<String, dynamic>>> rejectedLog() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(rejectedKey);
      if (raw == null) return const [];
      return [for (final e in jsonDecode(raw) as List) Map<String, dynamic>.from(e as Map)];
    } catch (_) {
      return const [];
    }
  }
}

