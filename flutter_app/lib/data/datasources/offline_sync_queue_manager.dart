import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'supabase_remote_datasource.dart';

/// Manages the persistent FIFO background synchronization queue (`pending_sync_queue`).
/// Queues offline mutations and processes them automatically when connectivity is available.
class OfflineSyncQueueManager {
  static const String queueKey = 'pending_sync_queue';

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

  /// Process queue sequentially. If a network failure occurs, the loop breaks
  /// preserving remaining items for subsequent attempts. Permanent failures drop after 5 retries.
  Future<void> processQueue(SupabaseRemoteDataSource remoteDataSource) async {
    final client = remoteDataSource.client;
    if (client == null || _isProcessingQueue || _pendingSyncQueue.isEmpty) {
      return;
    }
    _isProcessingQueue = true;

    try {
      final toRemove = <Map<String, dynamic>>[];
      for (final item in List.from(_pendingSyncQueue)) {
        try {
          final table = item['table'] as String;
          final action = item['action'] as String;
          final data = item['data'] as Map<String, dynamic>;
          final id = item['id'] as String?;

          if (action == 'upsert') {
            await remoteDataSource.upsert(table, data);
          } else if (action == 'patch' && id != null) {
            // تحديث الأعمدة المرسلة فقط: الحفظ الكامل للصف كان يسمح لجهاز
            // بنسخة قديمة أن يعيد كتابة حقول غيّرها جهاز آخر (مثل ربط الفرع).
            await remoteDataSource.update(
              table,
              data,
              matchingColumn: 'id',
              matchingValue: id,
            );
          } else if (action == 'delete' && id != null) {
            await remoteDataSource.delete(table, matchingColumn: 'id', matchingValue: id);
          }
          toRemove.add(item);
        } catch (e) {
          debugPrint('⚠️ SyncQueue error processing table ${item['table']}: $e');
          final isPostgrest = e is PostgrestException;
          final retries = (item['retry_count'] as int? ?? 0) + 1;
          item['retry_count'] = retries;
          // إذا كان الخطأ من قاعدة البيانات نفسها (رفض السجل/بيانات غير صالحة) أو تكرر أكثر من 3 مرات
          // نقوم بإسقاطه فوراً لمنع حظر بقية الطابور وعمليات الحذف.
          if (isPostgrest || retries >= 3) {
            debugPrint('⚠️ SyncQueue dropping permanently failing item for table ${item['table']} ($e)');
            toRemove.add(item);
            continue;
          }
          // Break on network error; keep rest for retry later
          break;
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
}

