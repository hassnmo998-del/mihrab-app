import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../../models/models.dart';
import '../../../services/data_service.dart';

class SheikhMessagesTab extends StatefulWidget {
  final Sheikh sheikh;
  final List<Halaqa> halaqat;
  final bool isDark;

  const SheikhMessagesTab({
    super.key,
    required this.sheikh,
    required this.halaqat,
    required this.isDark,
  });

  @override
  State<SheikhMessagesTab> createState() => _SheikhMessagesTabState();
}

class _SheikhMessagesTabState extends State<SheikhMessagesTab> {
  Student? _selectedStudent;
  final TextEditingController _chatController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  @override
  void dispose() {
    _chatController.dispose();
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

  void _sendSheikhMessage(DataService data, Student student) {
    final text = _chatController.text.trim();
    if (text.isEmpty) return;

    data.sendMessage(
      studentId: student.id,
      halaqaId: student.halaqaId,
      senderType: 'sheikh',
      senderName: 'فضيلة الشيخ ${widget.sheikh.fullName}',
      content: text,
      messageType: 'note',
    );

    _chatController.clear();
    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
  }

  @override
  Widget build(BuildContext context) {
    final data = context.watch<DataService>();
    final students = data.getStudents(sheikhId: widget.sheikh.id);

    // إذا لم يختار الشيخ طالباً بعد، نعرض قائمة محادثات واتساب
    if (_selectedStudent == null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
            child: Text(
              'محادثات أولياء الأمور والطلاب (${students.length})',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: RefreshIndicator(
              onRefresh: () => context.read<DataService>().syncWithSupabase(),
              child: students.isEmpty
                  ? ListView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      children: [
                        SizedBox(height: MediaQuery.of(context).size.height * 0.2),
                        const Center(child: Text('لا يوجد طلاب مسجلين لديك حالياً')),
                      ],
                    )
                  : ListView.separated(
                      physics: const AlwaysScrollableScrollPhysics(),
                      itemCount: students.length,
                      separatorBuilder: (_, __) => Divider(height: 1, color: widget.isDark ? Colors.white12 : Colors.black12),
                      itemBuilder: (context, idx) {
                final s = students[idx];
                final msgs = data.getStudentMessages(s.id);
                final lastMsg = msgs.isNotEmpty ? msgs.last : null;

                return ListTile(
                  leading: CircleAvatar(
                    backgroundColor: AppColors.emeraldPrimary.withValues(alpha: 0.15),
                    child: Icon(Icons.person, color: AppColors.emeraldPrimary),
                  ),
                  title: Text(s.fullName, style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text(
                    lastMsg != null ? lastMsg.content : 'انقر لبدء المحادثة...',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 12.5),
                  ),
                  trailing: lastMsg != null
                      ? Text(
                    DateFormat('hh:mm a').format(lastMsg.createdAt),
                    style: const TextStyle(fontSize: 10, color: Colors.grey),
                  )
                      : null,
                  onTap: () {
                    setState(() => _selectedStudent = s);
                  },
                );
              },
            ),
          ),
        ),
      ],
    );
    }

    // واجهة الشات الخاصة بالطالب المحدد
    final student = _selectedStudent!;
    final messages = data.getStudentMessages(student.id);
    messages.sort((a, b) => a.createdAt.compareTo(b.createdAt));

    return Column(
      children: [
        // Chat Header with Back Button
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          decoration: BoxDecoration(
            color: widget.isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Row(
            children: [
              IconButton(
                icon: const Icon(Icons.arrow_back_ios, size: 18),
                onPressed: () => setState(() => _selectedStudent = null),
              ),
              CircleAvatar(
                radius: 18,
                backgroundColor: AppColors.terracottaPrimary.withValues(alpha: 0.2),
                child: Icon(Icons.person, size: 18, color: AppColors.terracottaPrimary),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'محادثة: ${student.fullName}',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                    ),
                    Text(
                      'ولي الأمر / الطالب',
                      style: TextStyle(fontSize: 11, color: widget.isDark ? Colors.white60 : Colors.black54),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),

        // Message Thread
        Expanded(
          child: ListView.builder(
            controller: _scrollController,
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
            itemCount: messages.length,
            itemBuilder: (context, idx) {
              final msg = messages[idx];
              final isMe = msg.senderType == 'sheikh';

              return Align(
                alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
                child: Container(
                  margin: const EdgeInsets.symmetric(vertical: 4),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  constraints: const BoxConstraints(maxWidth: 320),
                  decoration: BoxDecoration(
                    color: isMe
                        ? AppColors.terracottaPrimary
                        : (widget.isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
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
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 11,
                            color: widget.isDark ? const Color(0xFFFDE68A) : AppColors.goldDark,
                          ),
                        ),
                      if (!isMe) const SizedBox(height: 3),
                      Text(
                        msg.content,
                        style: TextStyle(
                          fontSize: 13,
                          color: isMe ? Colors.white : (widget.isDark ? Colors.white : Colors.black87),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Align(
                        alignment: Alignment.bottomLeft,
                        child: Text(
                          DateFormat('hh:mm a').format(msg.createdAt),
                          style: TextStyle(
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

        // Compose Bar
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _chatController,
                  decoration: InputDecoration(
                    hintText: 'اكتب ردك أو تنبيهك...',
                    filled: true,
                    fillColor: widget.isDark ? const Color(0xFF1E293B) : Colors.white,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(24), borderSide: BorderSide.none),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  ),
                  onSubmitted: (_) => _sendSheikhMessage(data, student),
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                style: IconButton.styleFrom(
                  backgroundColor: AppColors.terracottaPrimary,
                  foregroundColor: Colors.white,
                ),
                icon: const Icon(Icons.send_rounded, size: 18),
                onPressed: () => _sendSheikhMessage(data, student),
              ),
            ],
          ),
        ),
      ],
    );
  }
}