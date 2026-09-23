import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../../models/models.dart';
import '../../../presentation/widgets/widgets.dart';
import '../../../services/data_service.dart';

class StudentContactTab extends StatefulWidget {
  final Student student;
  final Sheikh sheikh;
  final Halaqa halaqa;
  final bool isDark;

  const StudentContactTab({
    super.key,
    required this.student,
    required this.sheikh,
    required this.halaqa,
    this.isDark = false,
  });

  @override
  State<StudentContactTab> createState() => _StudentContactTabState();
}

class _StudentContactTabState extends State<StudentContactTab> {
  final TextEditingController _msgController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  String _targetChat = 'sheikh'; // 'sheikh' or 'admin'

  @override
  void dispose() {
    _msgController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  void _sendMessage() {
    final text = _msgController.text.trim();
    if (text.isEmpty) return;

    final data = context.read<DataService>();
    final isAdminTarget = _targetChat == 'admin';

    data.sendMessage(
      studentId: widget.student.id,
      halaqaId: widget.student.halaqaId.isNotEmpty ? widget.student.halaqaId : widget.halaqa.id,
      senderType: 'parent',
      senderName: 'ولي أمر ${widget.student.fullName}',
      content: text,
      messageType: isAdminTarget ? 'admin_chat' : 'sheikh_chat',
    );

    _msgController.clear();
    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
  }

  @override
  Widget build(BuildContext context) {
    final data = context.watch<DataService>();
    final allMessages = data.getStudentMessages(widget.student.id);

    // فلترة الرسائل حسب الوجهة المحددة
    final messages = allMessages.where((m) {
      if (_targetChat == 'admin') {
        return m.messageType == 'admin_chat' || m.senderType == 'mosque_admin';
      } else {
        return m.messageType != 'admin_chat' && m.senderType != 'mosque_admin';
      }
    }).toList();

    messages.sort((a, b) => a.createdAt.compareTo(b.createdAt));
    final isDarkTheme = Theme.of(context).brightness == Brightness.dark;
    final dividerColor = isDarkTheme ? Colors.white12 : Colors.black12;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Target Selector Buttons (مشرفو الحلقة / إدارة المسجد)
        Container(
          padding: const EdgeInsets.all(3),
          decoration: BoxDecoration(
            color: isDarkTheme ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              Expanded(
                child: InkWell(
                  borderRadius: BorderRadius.circular(10),
                  onTap: () => setState(() => _targetChat = 'sheikh'),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    decoration: BoxDecoration(
                      color: _targetChat == 'sheikh'
                          ? AppColors.terracottaPrimary
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    alignment: Alignment.center,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.school_outlined,
                          size: 15,
                          color: _targetChat == 'sheikh'
                              ? Colors.white
                              : (isDarkTheme ? Colors.white70 : Colors.black87),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'مشرفو الحلقة',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 12.5,
                            color: _targetChat == 'sheikh'
                                ? Colors.white
                                : (isDarkTheme ? Colors.white70 : Colors.black87),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 4),
              Expanded(
                child: InkWell(
                  borderRadius: BorderRadius.circular(10),
                  onTap: () => setState(() => _targetChat = 'admin'),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    decoration: BoxDecoration(
                      color: _targetChat == 'admin'
                          ? AppColors.terracottaPrimary
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    alignment: Alignment.center,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.account_balance_outlined,
                          size: 15,
                          color: _targetChat == 'admin'
                              ? Colors.white
                              : (isDarkTheme ? Colors.white70 : Colors.black87),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'إدارة المسجد',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 12.5,
                            color: _targetChat == 'admin'
                                ? Colors.white
                                : (isDarkTheme ? Colors.white70 : Colors.black87),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 6),

        // Active Chat Header
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: isDarkTheme ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Row(
            children: [
              CircleAvatar(
                radius: 16,
                backgroundColor: AppColors.terracottaPrimary.withValues(alpha: 0.15),
                child: Icon(
                  _targetChat == 'admin' ? Icons.account_balance_outlined : Icons.school_outlined,
                  color: AppColors.terracottaPrimary,
                  size: 16,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _targetChat == 'admin'
                          ? 'إدارة المسجد العامة'
                          : 'فضيلة المحفظ ${widget.sheikh.fullName}',
                      style: AppTypography.titleBold(context, fontSize: 13),
                    ),
                    Text(
                      _targetChat == 'admin'
                          ? 'محادثة خاصة للشؤون الإدارية والتنظيمية'
                          : 'محادثة مباشرة • ${widget.halaqa.name}',
                      style: AppTypography.verveSubtitle(context).copyWith(fontSize: 11),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 6),
              const UnifiedBadge(
                label: 'متصل / مباشر',
                backgroundColor: Color(0xFFDCFCE7),
                textColor: Color(0xFF166534),
              ),
            ],
          ),
        ),
        const SizedBox(height: 4),
        Divider(height: 1, thickness: 0.8, color: dividerColor),
        const SizedBox(height: 4),

        // Message Thread
        Expanded(
          child: RefreshIndicator(
            onRefresh: () => data.syncWithSupabase(),
            child: messages.isEmpty
                ? ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    children: [
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
                        child: Text(
                          _targetChat == 'admin'
                              ? 'لا توجد رسائل مع إدارة المسجد حالياً. اكتب استفسارك للإدارة هنا.'
                              : 'لا توجد رسائل سابقة مع مشرفي الحلقة. اكتب استفسارك للشيخ هنا.',
                          style: AppTypography.verveSubtitle(context),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ],
                  )
                : ListView.builder(
                    physics: const AlwaysScrollableScrollPhysics(),
                    controller: _scrollController,
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                    itemCount: messages.length,
                    itemBuilder: (context, idx) {
              final msg = messages[idx];
              final isMe = msg.senderType == 'parent';
              final maxBubbleWidth = (MediaQuery.of(context).size.width * 0.75).clamp(200.0, 360.0);

              return Align(
                alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
                child: Container(
                  margin: const EdgeInsets.symmetric(vertical: 4),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  constraints: BoxConstraints(maxWidth: maxBubbleWidth),
                  decoration: BoxDecoration(
                    color: isMe
                        ? AppColors.terracottaPrimary
                        : (isDarkTheme ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                    borderRadius: BorderRadius.only(
                      topLeft: const Radius.circular(16),
                      topRight: const Radius.circular(16),
                      bottomLeft: Radius.circular(isMe ? 16 : 4),
                      bottomRight: Radius.circular(isMe ? 4 : 16),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (!isMe)
                        Text(
                          msg.senderName,
                          style: AppTypography.titleBold(
                            context,
                            fontSize: 11,
                            color: AppColors.terracottaPrimary,
                          ),
                        ),
                      if (!isMe) const SizedBox(height: 3),
                      Text(
                        msg.content,
                        style: AppTypography.bodyRegular(
                          context,
                          color: isMe ? Colors.white : (isDarkTheme ? Colors.white : AppColors.obsidianEspresso),
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Align(
                        alignment: Alignment.bottomLeft,
                        child: Text(
                          DateFormat('hh:mm a').format(msg.createdAt),
                          style: AppTypography.bodyRegular(
                            context,
                            fontSize: 10,
                            color: isMe ? Colors.white70 : Colors.grey,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ),
        const SizedBox(height: 4),
        Divider(height: 1, thickness: 0.8, color: dividerColor),
        const SizedBox(height: 4),

        // Compose Bar
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
          child: Row(
            children: [
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    color: isDarkTheme ? const Color(0xFF1E293B) : Colors.white,
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: dividerColor),
                  ),
                  child: Row(
                    children: [
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextField(
                          controller: _msgController,
                          style: AppTypography.bodyRegular(context, fontSize: 13),
                          decoration: InputDecoration(
                            hintText: _targetChat == 'admin'
                                ? 'اكتب رسالة لإدارة المسجد...'
                                : 'اكتب رسالة لمشرف الحلقة...',
                            hintStyle: AppTypography.verveSubtitle(context),
                            border: InputBorder.none,
                            contentPadding: const EdgeInsets.symmetric(vertical: 8),
                          ),
                          onSubmitted: (_) => _sendMessage(),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 8),
              GestureDetector(
                onTap: _sendMessage,
                child: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.terracottaPrimary,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.send_rounded, size: 18, color: Colors.white),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}