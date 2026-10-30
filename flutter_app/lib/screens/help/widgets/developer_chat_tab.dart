import 'dart:async';
import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:intl/intl.dart' show DateFormat;

import '../../../core/theme/app_theme.dart';
import '../../../services/developer_chat_service.dart';

/// «تواصل مع المطوّر»: محادثة نصية، ٣ رسائل ويزيد لك رسالة مع كل ردّ.
class DeveloperChatTab extends StatefulWidget {
  /// تُحقن في الاختبارات بلا شبكة.
  final Future<DevThread> Function()? load;
  final Future<DevThread> Function(String text)? send;

  const DeveloperChatTab({super.key, this.load, this.send});

  @override
  State<DeveloperChatTab> createState() => _DeveloperChatTabState();
}

class _DeveloperChatTabState extends State<DeveloperChatTab> {
  final TextEditingController _input = TextEditingController();
  final ScrollController _scroll = ScrollController();
  DevThread? _thread;
  bool _loading = true;
  bool _sending = false;
  String? _error;
  Timer? _poll;

  @override
  void initState() {
    super.initState();
    _refresh(initial: true);
    // يلتقط الرد وهو مفتوح أمامه دون أن يسحب (لا مؤقّت دوري في الاختبارات)
    if (kIsWeb || !Platform.environment.containsKey('FLUTTER_TEST')) {
      _poll = Timer.periodic(const Duration(seconds: 25), (_) => _refresh());
    }
  }

  @override
  void dispose() {
    _poll?.cancel();
    _input.dispose();
    _scroll.dispose();
    super.dispose();
  }

  String _message(DevChatError e) => switch (e) {
        DevChatError.limit => 'استنفدت رسائلك الحالية. حين أردّ عليك ستستطيع الكتابة من جديد.',
        DevChatError.busy => 'الخدمة مزدحمة اليوم. حاول غداً بإذن الله.',
        DevChatError.tooLong => 'الرسالة طويلة. اختصرها إلى ${DeveloperChatService.maxLength} حرفاً.',
        DevChatError.empty => 'اكتب رسالتك أولاً.',
        _ => 'تعذّر الاتصال بالخادم. تحقق من الإنترنت وحاول لاحقاً.',
      };

  Future<void> _refresh({bool initial = false}) async {
    try {
      final t = await (widget.load ?? DeveloperChatService.loadThread)();
      if (!mounted) return;
      final grew = (_thread?.messages.length ?? 0) != t.messages.length;
      setState(() {
        _thread = t;
        _loading = false;
        _error = null;
      });
      unawaited(DeveloperChatService.markRead(t));
      if (grew) _jumpToEnd();
    } on DevChatException catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        if (initial || _thread == null) _error = _message(e.error);
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        if (_thread == null) _error = _message(DevChatError.unavailable);
      });
    }
  }

  void _jumpToEnd() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) _scroll.jumpTo(_scroll.position.maxScrollExtent);
    });
  }

  Future<void> _send() async {
    final text = _input.text.trim();
    if (text.isEmpty || _sending) return;
    setState(() {
      _sending = true;
      _error = null;
    });
    try {
      final t = await (widget.send ?? DeveloperChatService.send)(text);
      if (!mounted) return;
      _input.clear();
      setState(() => _thread = t);
      _jumpToEnd();
    } on DevChatException catch (e) {
      if (mounted) setState(() => _error = _message(e.error));
    } catch (_) {
      if (mounted) setState(() => _error = _message(DevChatError.unavailable));
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final t = _thread;
    final canWrite = (t?.remaining ?? 0) > 0;
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 640),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 6),
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppColors.terracottaPrimary.withValues(alpha: isDark ? 0.14 : 0.08),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.terracottaPrimary.withValues(alpha: 0.25)),
                ),
                child: Row(
                  children: [
                    Icon(Icons.support_agent_rounded, color: AppColors.terracottaPrimary, size: 30),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'واجهتك مشكلة أو تريد ميزة جديدة؟ اكتب لي هنا برسالة نصية وأردّ عليك من نفس المكان.',
                        style: AppTypography.font(fontSize: 13, height: 1.5),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Expanded(child: _body(isDark)),
            if (_error != null && t != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 6),
                child: Text(_error!, key: const ValueKey('devChatError'), style: const TextStyle(color: Colors.redAccent, fontSize: 12.5, fontWeight: FontWeight.bold)),
              ),
            _composer(isDark, canWrite, t),
          ],
        ),
      ),
    );
  }

  Widget _body(bool isDark) {
    if (_loading) return const Center(child: CircularProgressIndicator(strokeWidth: 2.5));
    final t = _thread;
    if (t == null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.cloud_off_rounded, size: 40, color: isDark ? Colors.white38 : Colors.black38),
              const SizedBox(height: 10),
              Text(
                _error ?? 'تعذّر الاتصال بالخادم.',
                key: const ValueKey('devChatUnavailable'),
                textAlign: TextAlign.center,
                style: AppTypography.font(fontSize: 13.5, height: 1.5),
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: () {
                  setState(() => _loading = true);
                  _refresh(initial: true);
                },
                icon: const Icon(Icons.refresh_rounded, size: 18),
                label: const Text('إعادة المحاولة'),
              ),
            ],
          ),
        ),
      );
    }
    if (t.messages.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Text(
            'لا رسائل بعد. اكتب أول رسالة لك.',
            style: AppTypography.font(fontSize: 14, color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary),
          ),
        ),
      );
    }
    return ListView.builder(
      controller: _scroll,
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      itemCount: t.messages.length,
      itemBuilder: (_, i) => _Bubble(message: t.messages[i], isDark: isDark),
    );
  }

  Widget _composer(bool isDark, bool canWrite, DevThread? t) {
    final remaining = t?.remaining ?? 0;
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : Colors.white,
        border: Border(top: BorderSide(color: isDark ? AppColors.darkBorder : AppColors.lightBorder)),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (t != null)
              Align(
                alignment: AlignmentDirectional.centerStart,
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Text(
                    canWrite
                        ? 'المتبقي لك: $remaining ${remaining == 1 ? 'رسالة' : (remaining == 2 ? 'رسالتان' : 'رسائل')}'
                        : 'استنفدت رسائلك. ستستطيع الكتابة بعد ردّي.',
                    key: const ValueKey('devChatRemaining'),
                    style: AppTypography.font(fontSize: 12, fontWeight: FontWeight.bold, color: canWrite ? AppColors.terracottaPrimary : Colors.orange.shade800),
                  ),
                ),
              ),
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(
                  child: TextField(
                    key: const ValueKey('devChatInput'),
                    controller: _input,
                    enabled: canWrite && !_sending,
                    minLines: 1,
                    maxLines: 4,
                    maxLength: DeveloperChatService.maxLength,
                    textInputAction: TextInputAction.newline,
                    decoration: InputDecoration(
                      hintText: 'اكتب رسالتك…',
                      counterText: '',
                      isDense: true,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton.filled(
                  key: const ValueKey('devChatSend'),
                  onPressed: canWrite && !_sending ? _send : null,
                  style: IconButton.styleFrom(backgroundColor: AppColors.terracottaPrimary, foregroundColor: Colors.white, minimumSize: const Size(48, 48)),
                  icon: _sending
                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Icon(Icons.send_rounded),
                  tooltip: 'إرسال',
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _Bubble extends StatelessWidget {
  final DevMessage message;
  final bool isDark;

  const _Bubble({required this.message, required this.isDark});

  @override
  Widget build(BuildContext context) {
    final mine = !message.fromDev;
    final bg = mine ? AppColors.terracottaPrimary : (isDark ? const Color(0xFF2B2F3A) : const Color(0xFFEFE7DD));
    final fg = mine ? Colors.white : (isDark ? Colors.white : const Color(0xFF2A1810));
    final maxW = MediaQuery.sizeOf(context).width * 0.78;
    return Align(
      alignment: mine ? AlignmentDirectional.centerStart : AlignmentDirectional.centerEnd,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        constraints: BoxConstraints(maxWidth: maxW > 460 ? 460 : maxW),
        padding: const EdgeInsets.fromLTRB(14, 10, 14, 8),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(18),
            topRight: const Radius.circular(18),
            bottomLeft: Radius.circular(mine ? 4 : 18),
            bottomRight: Radius.circular(mine ? 18 : 4),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (!mine) Text('المطوّر', style: AppTypography.font(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.terracottaPrimary)),
            Text(message.body, style: AppTypography.font(fontSize: 14, height: 1.5, color: fg)),
            const SizedBox(height: 4),
            Text(DateFormat('d/M  HH:mm').format(message.at), style: TextStyle(fontSize: 10, color: fg.withValues(alpha: 0.7))),
          ],
        ),
      ),
    );
  }
}
