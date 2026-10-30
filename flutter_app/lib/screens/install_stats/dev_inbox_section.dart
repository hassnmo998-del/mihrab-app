import 'package:flutter/material.dart';
import 'package:intl/intl.dart' show DateFormat;

import '../../core/theme/app_theme.dart';
import '../../services/developer_chat_service.dart';

/// صندوق رسائل المستخدمين لصاحب المشروع: داخل شاشة أرقام التطبيق نفسها وبكلمة سرها.
/// سطر لكل جهاز، الأحدث أولاً، وغير المقروء ظاهر. الردّ يمنح المستخدم رسالة إضافية.
class DevInboxSection extends StatefulWidget {
  final String secret;

  /// تُحقن في الاختبارات.
  final Future<List<DevInboxItem>> Function(String secret)? loadInbox;
  final Future<DevThread> Function(String secret, String installId)? loadThread;
  final Future<void> Function(String secret, String installId, String text)? reply;
  final Future<void> Function(String secret, String installId)? delete;

  const DevInboxSection({super.key, required this.secret, this.loadInbox, this.loadThread, this.reply, this.delete});

  @override
  State<DevInboxSection> createState() => _DevInboxSectionState();
}

class _DevInboxSectionState extends State<DevInboxSection> {
  List<DevInboxItem>? _items;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final items = await (widget.loadInbox ?? DeveloperChatService.adminInbox)(widget.secret);
      if (!mounted) return;
      setState(() => _items = items);
    } on DevChatException catch (e) {
      if (!mounted) return;
      setState(() => _error = switch (e.error) {
            DevChatError.wrongSecret => 'كلمة السر لم تعد صحيحة.',
            DevChatError.tooManyAttempts => 'محاولات خاطئة كثيرة. أعد المحاولة بعد دقائق.',
            _ => 'تعذّر تحميل الرسائل (الخدمة غير مفعّلة على الخادم بعد، أو لا إنترنت).',
          });
    } catch (_) {
      if (mounted) setState(() => _error = 'تعذّر تحميل الرسائل.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _open(DevInboxItem item) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => _DevThreadPage(
          secret: widget.secret,
          item: item,
          loadThread: widget.loadThread,
          reply: widget.reply,
          delete: widget.delete,
        ),
      ),
    );
    if (mounted) _load();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final items = _items ?? const <DevInboxItem>[];
    final unread = items.fold<int>(0, (a, e) => a + e.unread);
    return Container(
      key: const ValueKey('devInbox'),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.emeraldPrimary.withValues(alpha: 0.25), width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(Icons.forum_rounded, color: AppColors.emeraldPrimary),
              const SizedBox(width: 10),
              const Expanded(child: Text('رسائل المستخدمين', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold))),
              if (unread > 0)
                Container(
                  key: const ValueKey('devInboxUnread'),
                  padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
                  decoration: BoxDecoration(color: Colors.redAccent, borderRadius: BorderRadius.circular(12)),
                  child: Text('$unread جديدة', style: const TextStyle(color: Colors.white, fontSize: 11.5, fontWeight: FontWeight.bold)),
                ),
              IconButton(onPressed: _loading ? null : _load, tooltip: 'تحديث', icon: const Icon(Icons.refresh_rounded)),
            ],
          ),
          if (_loading && _items == null)
            const Padding(padding: EdgeInsets.all(20), child: Center(child: CircularProgressIndicator(strokeWidth: 2.5)))
          else if (_error != null)
            Padding(padding: const EdgeInsets.symmetric(vertical: 10), child: Text(_error!, style: const TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold)))
          else if (items.isEmpty)
            const Padding(padding: EdgeInsets.symmetric(vertical: 14), child: Text('لا رسائل بعد.'))
          else
            for (final it in items) _row(it, isDark),
        ],
      ),
    );
  }

  Widget _row(DevInboxItem it, bool isDark) {
    return InkWell(
      key: ValueKey('devInboxRow_${it.installId}'),
      onTap: () => _open(it),
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
        child: Row(
          children: [
            Icon(it.platform == 'windows' ? Icons.desktop_windows_outlined : Icons.smartphone_rounded, size: 22, color: Colors.grey),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        '${it.platform.isEmpty ? 'جهاز' : it.platform} ${it.version}',
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey),
                        textDirection: TextDirection.ltr,
                      ),
                      const Spacer(),
                      Text(DateFormat('d/M HH:mm').format(it.lastAt), style: const TextStyle(fontSize: 11, color: Colors.grey)),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${it.lastFromDev ? 'أنت: ' : ''}${it.lastBody}',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 13.5, fontWeight: it.unread > 0 ? FontWeight.bold : FontWeight.normal),
                  ),
                ],
              ),
            ),
            if (it.unread > 0) ...[
              const SizedBox(width: 8),
              CircleAvatar(radius: 11, backgroundColor: Colors.redAccent, child: Text('${it.unread}', style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold))),
            ],
          ],
        ),
      ),
    );
  }
}

class _DevThreadPage extends StatefulWidget {
  final String secret;
  final DevInboxItem item;
  final Future<DevThread> Function(String secret, String installId)? loadThread;
  final Future<void> Function(String secret, String installId, String text)? reply;
  final Future<void> Function(String secret, String installId)? delete;

  const _DevThreadPage({required this.secret, required this.item, this.loadThread, this.reply, this.delete});

  @override
  State<_DevThreadPage> createState() => _DevThreadPageState();
}

class _DevThreadPageState extends State<_DevThreadPage> {
  final TextEditingController _input = TextEditingController();
  final ScrollController _scroll = ScrollController();
  List<DevMessage> _messages = const [];
  bool _loading = true;
  bool _sending = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _input.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final t = await (widget.loadThread ?? DeveloperChatService.adminThread)(widget.secret, widget.item.installId);
      if (!mounted) return;
      setState(() {
        _messages = t.messages;
        _error = null;
      });
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scroll.hasClients) _scroll.jumpTo(_scroll.position.maxScrollExtent);
      });
    } catch (_) {
      if (mounted) setState(() => _error = 'تعذّر تحميل المحادثة.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _send() async {
    final text = _input.text.trim();
    if (text.isEmpty || _sending) return;
    setState(() => _sending = true);
    try {
      await (widget.reply ?? DeveloperChatService.adminReply)(widget.secret, widget.item.installId, text);
      _input.clear();
      await _load();
    } catch (_) {
      if (mounted) setState(() => _error = 'تعذّر إرسال الردّ.');
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _delete() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('حذف المحادثة؟'),
        content: const Text('تُحذف كل رسائل هذا الجهاز ولا يمكن التراجع.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('تراجع')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), style: FilledButton.styleFrom(backgroundColor: Colors.redAccent), child: const Text('حذف')),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await (widget.delete ?? DeveloperChatService.adminDelete)(widget.secret, widget.item.installId);
      if (mounted) Navigator.pop(context);
    } catch (_) {
      if (mounted) setState(() => _error = 'تعذّر الحذف.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      appBar: AppBar(
        title: Text('${widget.item.platform} ${widget.item.version}', textDirection: TextDirection.ltr),
        actions: [IconButton(key: const ValueKey('devThreadDelete'), tooltip: 'حذف المحادثة', icon: const Icon(Icons.delete_outline_rounded), onPressed: _delete)],
      ),
      body: Column(
        children: [
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator(strokeWidth: 2.5))
                : ListView.builder(
                    controller: _scroll,
                    padding: const EdgeInsets.all(14),
                    itemCount: _messages.length,
                    itemBuilder: (_, i) {
                      final m = _messages[i];
                      return Align(
                        alignment: m.fromDev ? AlignmentDirectional.centerStart : AlignmentDirectional.centerEnd,
                        child: Container(
                          margin: const EdgeInsets.symmetric(vertical: 4),
                          constraints: const BoxConstraints(maxWidth: 460),
                          padding: const EdgeInsets.fromLTRB(14, 10, 14, 8),
                          decoration: BoxDecoration(
                            color: m.fromDev ? AppColors.emeraldPrimary : (isDark ? const Color(0xFF2B2F3A) : const Color(0xFFEFE7DD)),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(m.body, style: TextStyle(fontSize: 14, height: 1.5, color: m.fromDev ? Colors.white : null)),
                              const SizedBox(height: 4),
                              Text(DateFormat('d/M HH:mm').format(m.at), style: TextStyle(fontSize: 10, color: (m.fromDev ? Colors.white : Colors.grey).withValues(alpha: 0.75))),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
          if (_error != null) Padding(padding: const EdgeInsets.all(6), child: Text(_error!, style: const TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold))),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 6, 14, 12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(
                    child: TextField(
                      key: const ValueKey('devReplyInput'),
                      controller: _input,
                      minLines: 1,
                      maxLines: 5,
                      maxLength: 1000,
                      decoration: InputDecoration(hintText: 'ردّك…', counterText: '', isDense: true, border: OutlineInputBorder(borderRadius: BorderRadius.circular(16))),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton.filled(
                    key: const ValueKey('devReplySend'),
                    onPressed: _sending ? null : _send,
                    icon: _sending ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Icon(Icons.send_rounded),
                    tooltip: 'إرسال الردّ',
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
