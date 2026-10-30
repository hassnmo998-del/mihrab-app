import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../data/datasources/supabase_remote_datasource.dart';
import 'app_update_service.dart';
import 'help_state.dart';
import 'install_presence.dart';

/// طلب إلى دالة في Supabase: يعيد JSON كما جاء، أو يرمي إن لم يصل.
typedef DevRpc = Future<dynamic> Function(String function, Map<String, dynamic> body);

enum DevChatError {
  /// استُنفدت الرسائل المسموحة (٣، وواحدة إضافية مع كل ردّ من المطوّر).
  limit,

  /// الخادم مشغول اليوم (سقف الرسائل اليومي العام).
  busy,
  tooLong,
  empty,

  /// لا إنترنت، أو الخدمة لم تُفعَّل على الخادم بعد.
  unavailable,

  /// أمور المطوّر: كلمة سر خاطئة / محاولات كثيرة.
  wrongSecret,
  tooManyAttempts,
}

class DevChatException implements Exception {
  final DevChatError error;
  const DevChatException(this.error);

  @override
  String toString() => 'DevChatException($error)';
}

@immutable
class DevMessage {
  final int id;
  final bool fromDev;
  final String body;
  final DateTime at;

  const DevMessage({required this.id, required this.fromDev, required this.body, required this.at});

  factory DevMessage.fromJson(Map<String, dynamic> j) => DevMessage(
        id: (j['id'] as num).toInt(),
        fromDev: j['from_dev'] == true,
        body: (j['body'] ?? '').toString(),
        at: DateTime.tryParse((j['at'] ?? '').toString())?.toLocal() ?? DateTime.now(),
      );
}

@immutable
class DevThread {
  final List<DevMessage> messages;

  /// كم رسالة بقيت لهذا الجهاز.
  final int remaining;

  const DevThread({required this.messages, required this.remaining});

  int get lastDevId => messages.where((m) => m.fromDev).fold(0, (a, m) => m.id > a ? m.id : a);
}

/// محادثة نصية بين المستخدم والمطوّر: ٣ رسائل من المستخدم، وكل ردّ منك يمنحه رسالة إضافية.
///
/// كل شيء يمرّ بدوال Supabase (`dev_msg_*`) لا بجداول: المفتاح العام يقدر على الجداول العادية،
/// أما جدول الرسائل فمخفي في المخطط `private`. الخادم نفسه يفرض الحدّ والطول والسقف اليومي،
/// والتطبيق هنا لا يثق بنفسه. ما يُرسل: معرّف الجهاز نفسه المستعمل في عدّ الأجهزة، المنصة، والإصدار.
class DeveloperChatService {
  DeveloperChatService._();

  static const int maxLength = 600;
  static const String seenKey = 'dev_chat_seen_id';

  @visibleForTesting
  static DevRpc rpc = _callRpc;

  static Future<dynamic> _callRpc(String function, Map<String, dynamic> body) async {
    const key = SupabaseRemoteDataSource.defaultSupabaseAnonKey;
    final res = await http
        .post(
          Uri.parse('${SupabaseRemoteDataSource.defaultSupabaseUrl}/rest/v1/rpc/$function'),
          headers: {'apikey': key, 'Authorization': 'Bearer $key', 'Content-Type': 'application/json'},
          body: jsonEncode(body),
        )
        .timeout(const Duration(seconds: 20));
    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw http.ClientException('HTTP ${res.statusCode}');
    }
    return jsonDecode(res.body);
  }

  static Future<dynamic> _call(String function, Map<String, dynamic> body) async {
    try {
      return await rpc(function, body);
    } on DevChatException {
      rethrow;
    } catch (_) {
      throw const DevChatException(DevChatError.unavailable);
    }
  }

  static void _throwIfError(dynamic res) {
    if (res is! Map || res['error'] == null) return;
    throw DevChatException(switch (res['error']) {
      'limit' => DevChatError.limit,
      'busy' => DevChatError.busy,
      'too_long' => DevChatError.tooLong,
      'empty' => DevChatError.empty,
      'wrong_secret' => DevChatError.wrongSecret,
      'too_many_attempts' => DevChatError.tooManyAttempts,
      _ => DevChatError.unavailable,
    });
  }

  static DevThread _parseThread(dynamic res) {
    _throwIfError(res);
    if (res is! Map) throw const DevChatException(DevChatError.unavailable);
    final list = (res['messages'] as List? ?? const [])
        .map((e) => DevMessage.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
    return DevThread(messages: list, remaining: (res['remaining'] as num?)?.toInt() ?? 0);
  }

  // ───────────── المستخدم ─────────────

  static Future<DevThread> loadThread() async {
    final id = await InstallPresence.currentInstallId();
    return _parseThread(await _call('dev_msg_thread', {'p_install_id': id}));
  }

  static Future<DevThread> send(String text) async {
    final body = text.trim();
    if (body.isEmpty) throw const DevChatException(DevChatError.empty);
    if (body.length > maxLength) throw const DevChatException(DevChatError.tooLong);
    final id = await InstallPresence.currentInstallId();
    final res = await _call('dev_msg_send', {
      'p_install_id': id,
      'p_body': body,
      'p_platform': InstallPresence.platformName,
      'p_version': AppUpdateService.currentVersion,
    });
    _throwIfError(res);
    return loadThread();
  }

  /// هل وصل ردّ لم يُقرأ؟ يُنادى بصمت عند الإقلاع، ويرفع وميض زر «؟» إن وُجد.
  static Future<void> refreshUnread() async {
    try {
      final id = await InstallPresence.currentInstallId();
      final prefs = await SharedPreferences.getInstance();
      final res = await _call('dev_msg_unread', {'p_install_id': id, 'p_after': prefs.getInt(seenKey) ?? 0});
      if (res is Map && ((res['count'] as num?)?.toInt() ?? 0) > 0) {
        HelpState.instance.setUnreadReply(true);
      }
    } catch (_) {
      // بلا إنترنت أو بلا خدمة: لا شيء يُقال
    }
  }

  /// قرأ المستخدم المحادثة: لا ردود جديدة بعد الآن.
  static Future<void> markRead(DevThread thread) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final last = thread.lastDevId;
      if (last > (prefs.getInt(seenKey) ?? 0)) await prefs.setInt(seenKey, last);
    } catch (_) {}
    HelpState.instance.setUnreadReply(false);
  }

  // ───────────── المطوّر (بكلمة السر نفسها لشاشة أرقام التطبيق) ─────────────

  static Future<List<DevInboxItem>> adminInbox(String secret) async {
    final res = await _call('dev_msg_admin_inbox', {'p_secret': InstallPresence.normalizeSecret(secret)});
    _throwIfError(res);
    final list = res is Map ? (res['threads'] as List? ?? const []) : const [];
    return list.map((e) => DevInboxItem.fromJson(Map<String, dynamic>.from(e as Map))).toList();
  }

  static Future<DevThread> adminThread(String secret, String installId) async {
    final res = await _call('dev_msg_admin_thread', {'p_secret': InstallPresence.normalizeSecret(secret), 'p_install_id': installId});
    return _parseThread(res);
  }

  static Future<void> adminReply(String secret, String installId, String text) async {
    final body = text.trim();
    if (body.isEmpty) throw const DevChatException(DevChatError.empty);
    final res = await _call('dev_msg_admin_reply', {
      'p_secret': InstallPresence.normalizeSecret(secret),
      'p_install_id': installId,
      'p_body': body,
    });
    _throwIfError(res);
  }

  static Future<void> adminDelete(String secret, String installId) async {
    final res = await _call('dev_msg_admin_delete', {'p_secret': InstallPresence.normalizeSecret(secret), 'p_install_id': installId});
    _throwIfError(res);
  }
}

@immutable
class DevInboxItem {
  final String installId;
  final String platform;
  final String version;
  final String lastBody;
  final bool lastFromDev;
  final DateTime lastAt;
  final int unread;
  final int total;

  const DevInboxItem({
    required this.installId,
    required this.platform,
    required this.version,
    required this.lastBody,
    required this.lastFromDev,
    required this.lastAt,
    required this.unread,
    required this.total,
  });

  factory DevInboxItem.fromJson(Map<String, dynamic> j) => DevInboxItem(
        installId: (j['install_id'] ?? '').toString(),
        platform: (j['platform'] ?? '').toString(),
        version: (j['version'] ?? '').toString(),
        lastBody: (j['last_body'] ?? '').toString(),
        lastFromDev: j['last_from_dev'] == true,
        lastAt: DateTime.tryParse((j['last_at'] ?? '').toString())?.toLocal() ?? DateTime.now(),
        unread: (j['unread'] as num?)?.toInt() ?? 0,
        total: (j['total'] as num?)?.toInt() ?? 0,
      );
}
