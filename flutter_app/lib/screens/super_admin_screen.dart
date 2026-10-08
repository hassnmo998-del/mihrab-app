import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../core/theme/app_theme.dart';
import '../services/data_service.dart';
import 'super_admin/dialogs/delete_mosque_confirm_dialog.dart';

class SuperAdminScreen extends StatefulWidget {
  const SuperAdminScreen({super.key});

  @override
  State<SuperAdminScreen> createState() => _SuperAdminScreenState();
}

class _SuperAdminScreenState extends State<SuperAdminScreen> {
  String? _currentToken;
  bool _isGenerating = false;

  @override
  void initState() {
    super.initState();
    // سحب الأكواد المشتركة من السحابة فور فتح اللوحة على أي جهاز مشرف عام
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<DataService>().syncRegistrationTokens();
    });
  }

  String? _formatTimestamp(dynamic raw) {
    if (raw == null) return null;
    final s = raw.toString().trim();
    if (s.isEmpty) return null;
    if (s.contains('T')) {
      return s.split('T')[0];
    }
    return s;
  }

  @override
  Widget build(BuildContext context) {
    final data = context.watch<DataService>();
    final tokens = data.getRegistrationTokens();
    final mosques = data.getMosques();
    final history = data.getTokenUsageHistory();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // سجلات الأكواد التي لا تطابق أي مسجد نشط حالياً (إن وجدت)
    final orphanHistory = history.where((h) {
      final hCode = (h['mosqueAccessCode'] ?? '').toString().trim().toUpperCase();
      final hName = (h['mosqueName'] ?? '').toString().trim();
      return !mosques.any((m) =>
          (hCode.isNotEmpty && m.accessCode.trim().toUpperCase() == hCode) ||
          (hName.isNotEmpty && m.name.trim() == hName));
    }).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('لوحة تحكم المشرف العام'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'تسجيل الخروج من لوحة المشرف العام',
            onPressed: () {
              data.disconnectRole('super_admin');
              Navigator.pop(context);
            },
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          await data.syncWithSupabase();
          await data.syncRegistrationTokens();
        },
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: EdgeInsets.symmetric(
            horizontal: MediaQuery.sizeOf(context).width < 600 ? 14 : 24,
            vertical: 20,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // بنر الترحيب والتوليد
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: AppColors.sunsetTwilightGradient,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Column(
                  children: [
                    const Icon(Icons.security, size: 48, color: Colors.white),
                    const SizedBox(height: 12),
                    Text(
                      'توليد أكواد تسجيل المساجد الجديدة',
                      style: AppTypography.font(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'كل كود يتم توليده صالح للاستخدام مرة واحدة فقط لفتح جامع جديد.',
                      style: TextStyle(color: Colors.white70, fontSize: 12),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: _isGenerating
                    ? null
                    : () async {
                        setState(() => _isGenerating = true);
                        final token = await data.generateRegistrationToken();
                        if (!mounted) return;
                        setState(() {
                          _currentToken = token;
                          _isGenerating = false;
                        });
                      },
                icon: _isGenerating
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : const Icon(Icons.add_circle_outline),
                label: Text(_isGenerating ? 'جارٍ رفع الكود للسحابة...' : 'توليد باركود جديد الآن'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.emeraldPrimary,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
              ),

              // عرض الباركود المولّد حالياً
              if (_currentToken != null) ...[
                const SizedBox(height: 30),
                Center(
                  child: Column(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.1), blurRadius: 10)],
                        ),
                        child: QrImageView(
                          data: _currentToken!,
                          version: QrVersions.auto,
                          size: 200.0,
                          eyeStyle: QrEyeStyle(eyeShape: QrEyeShape.square, color: AppColors.obsidianEspresso),
                          dataModuleStyle: QrDataModuleStyle(dataModuleShape: QrDataModuleShape.square, color: AppColors.obsidianEspresso),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Wrap(
                        alignment: WrapAlignment.center,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        spacing: 12,
                        runSpacing: 8,
                        children: [
                          Text(
                            _currentToken!,
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, letterSpacing: 2),
                          ),
                          ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.emeraldPrimary,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            ),
                            icon: const Icon(Icons.copy, size: 16),
                            label: const Text('نسخ كود الباركود', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                            onPressed: () {
                              Clipboard.setData(ClipboardData(text: _currentToken!));
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('تم نسخ كود الباركود للحافظة بنجاح 📋'), duration: Duration(seconds: 2)),
                              );
                            },
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'اجعل مدير الجامع الجديد يصور هذا الكود لفتح شاشة التسجيل',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 36),

              // الأكواد النشطة غير المستخدمة
              Row(
                children: [
                  Icon(Icons.history, color: AppColors.goldDark),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text('الأكواد النشطة غير المستخدمة (${tokens.length})',
                        style: const TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              if (tokens.isEmpty)
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: isDark ? Colors.white.withValues(alpha: 0.03) : Colors.grey[100],
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Center(child: Text('لا توجد أكواد نشطة غير مستخدمة حالياً')),
                )
              else
                ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: tokens.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (context, idx) {
                    final t = tokens[idx];
                    return ListTile(
                      tileColor: isDark ? Colors.white10 : Colors.grey[100],
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      title: Text(t, style: const TextStyle(fontFamily: 'monospace', fontWeight: FontWeight.bold)),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.copy, size: 18),
                            tooltip: 'نسخ الكود',
                            onPressed: () {
                              Clipboard.setData(ClipboardData(text: t));
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('تم نسخ الكود 📋'), duration: Duration(seconds: 1)),
                              );
                            },
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete_outline, color: Colors.redAccent, size: 18),
                            tooltip: 'حذف الكود',
                            onPressed: () {
                              data.deleteRegistrationToken(t);
                            },
                          ),
                        ],
                      ),
                      onTap: () => setState(() => _currentToken = t),
                    );
                  },
                ),
              const SizedBox(height: 40),

              // ==========================================
              // قسم المساجد المسجلة المدمج (يشمل بيانات المسجد وتاريخ التسجيل والأكواد المستعادة)
              // ==========================================
              Row(
                children: [
                  Icon(Icons.mosque_rounded, color: AppColors.emeraldPrimary),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'المساجد المسجلة في المنصة (${mosques.length})',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              if (mosques.isEmpty)
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: isDark ? Colors.white.withValues(alpha: 0.03) : Colors.grey[100],
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Center(
                    child: Text('لا توجد مساجد مسجلة في المنصة حالياً'),
                  ),
                )
              else
                ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: mosques.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 14),
                  itemBuilder: (context, idx) {
                    final m = mosques[idx];
                    final halaqatCount = data.getHalaqat(mosqueId: m.id).length;
                    final sheikhsCount = data.getSheikhs(mosqueId: m.id).length;
                    final studentsCount = data.getStudents(mosqueId: m.id).length;

                    // استخراج سجل التسجيل المقترن بهذا المسجد (إن وُجد) لدمجه في نفس البطاقة
                    Map<String, dynamic>? regInfo;
                    for (final h in history) {
                      final hCode = (h['mosqueAccessCode'] ?? '').toString().trim().toUpperCase();
                      final hName = (h['mosqueName'] ?? '').toString().trim();
                      if ((hCode.isNotEmpty && hCode == m.accessCode.trim().toUpperCase()) ||
                          (hName.isNotEmpty && hName == m.name.trim())) {
                        regInfo = h;
                        break;
                      }
                    }
                    final regDate = _formatTimestamp(regInfo?['timestamp']);
                    final usedToken = (regInfo?['token'] ?? '').toString().trim();

                    return Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: m.isWomenSection
                              ? Colors.purpleAccent.withValues(alpha: 0.3)
                              : AppColors.emeraldPrimary.withValues(alpha: 0.25),
                          width: 1.5,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.04),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // 1. رأس البطاقة: اسم المسجد، العنوان، تاريخ التسجيل، وشارة نوع الجامع
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: (m.isWomenSection ? Colors.purpleAccent : AppColors.emeraldPrimary)
                                      .withValues(alpha: 0.12),
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  Icons.mosque,
                                  size: 20,
                                  color: m.isWomenSection ? Colors.purpleAccent : AppColors.emeraldPrimary,
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      m.name,
                                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                                    ),
                                    if (m.city.isNotEmpty || (m.address?.isNotEmpty ?? false))
                                      Text(
                                        '${m.city}${(m.address?.isNotEmpty ?? false) ? ' - ${m.address}' : ''}',
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: isDark ? Colors.white60 : Colors.black54,
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          // الشارات في سطر يلتفّ: كانت تزاحم الاسم على عرض الهاتف
                          Wrap(
                            spacing: 6,
                            runSpacing: 6,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: (m.isWomenSection ? Colors.purple : AppColors.emeraldPrimary)
                                      .withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  m.isWomenSection ? 'فرع نسائي' : 'جامع عام',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    color: m.isWomenSection ? Colors.purple : AppColors.emeraldPrimary,
                                  ),
                                ),
                              ),
                              if (regDate != null && regDate.isNotEmpty)
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.05),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(Icons.calendar_today_outlined,
                                          size: 11, color: isDark ? Colors.white60 : Colors.black54),
                                      const SizedBox(width: 4),
                                      Text(
                                        'سُجّل في $regDate',
                                        style: TextStyle(fontSize: 11, color: isDark ? Colors.white70 : Colors.black87),
                                      ),
                                    ],
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(height: 14),

                          // 2. شريط كود الباركود / كود الوصول مع زر النسخ السريع.
                          //    أكواد القسم النسائي لا تظهر للمشرف العام: تبقى عند إدارته وحدها.
                          if (m.isWomenSection)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                              decoration: BoxDecoration(
                                color: isDark ? Colors.black26 : Colors.purple.withValues(alpha: 0.05),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: Colors.purpleAccent.withValues(alpha: 0.2)),
                              ),
                              child: const Row(
                                children: [
                                  Icon(Icons.lock_outline, size: 18, color: Colors.purpleAccent),
                                  SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      'كود هذا القسم عند إدارته وحدها، ولا يُعرض هنا.',
                                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                                    ),
                                  ),
                                ],
                              ),
                            )
                          else
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            decoration: BoxDecoration(
                              color: isDark ? Colors.black26 : Colors.grey[100],
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: isDark ? Colors.white12 : Colors.grey[300]!),
                            ),
                            child: Row(
                              children: [
                                Icon(Icons.qr_code_2, size: 20, color: AppColors.emeraldPrimary),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'كود الباركود',
                                        style: TextStyle(fontSize: 11, color: isDark ? Colors.white60 : Colors.black54),
                                      ),
                                      FittedBox(
                                        fit: BoxFit.scaleDown,
                                        alignment: AlignmentDirectional.centerStart,
                                        child: Text(
                                          m.accessCode,
                                          maxLines: 1,
                                          textDirection: TextDirection.ltr,
                                          style: TextStyle(
                                            fontFamily: 'monospace',
                                            fontWeight: FontWeight.w900,
                                            fontSize: 14,
                                            letterSpacing: 1,
                                            color: AppColors.emeraldPrimary,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 8),
                                ElevatedButton.icon(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: AppColors.emeraldPrimary,
                                    foregroundColor: Colors.white,
                                    elevation: 0,
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                    visualDensity: VisualDensity.compact,
                                  ),
                                  icon: const Icon(Icons.copy, size: 14),
                                  label: const Text(
                                    'نسخ',
                                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                                  ),
                                  onPressed: () {
                                    Clipboard.setData(ClipboardData(text: m.accessCode));
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text('تم نسخ كود باركود جامع (${m.name}): ${m.accessCode} 📋'),
                                        duration: const Duration(seconds: 2),
                                      ),
                                    );
                                  },
                                ),
                              ],
                            ),
                          ),

                          // 4. كود التسجيل المستخدم في فتح هذا الجامع (مدمج من تاريخ الأكواد المستعادة)
                          if (usedToken.isNotEmpty) ...[
                            const SizedBox(height: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                              decoration: BoxDecoration(
                                color: isDark ? Colors.white.withValues(alpha: 0.03) : Colors.black.withValues(alpha: 0.03),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: isDark ? Colors.white10 : Colors.black12),
                              ),
                              child: Row(
                                children: [
                                  Icon(Icons.vpn_key_outlined, size: 15, color: isDark ? Colors.white60 : Colors.black54),
                                  const SizedBox(width: 6),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'الكود المستخدم للتسجيل',
                                          style: TextStyle(fontSize: 11, color: isDark ? Colors.white60 : Colors.black54),
                                        ),
                                        FittedBox(
                                          fit: BoxFit.scaleDown,
                                          alignment: AlignmentDirectional.centerStart,
                                          child: Text(
                                            usedToken,
                                            maxLines: 1,
                                            textDirection: TextDirection.ltr,
                                            style: TextStyle(
                                              fontFamily: 'monospace',
                                              fontSize: 12,
                                              fontWeight: FontWeight.bold,
                                              color: isDark ? Colors.white70 : Colors.black87,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  InkWell(
                                    onTap: () {
                                      Clipboard.setData(ClipboardData(text: usedToken));
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(
                                          content: Text('تم نسخ كود التسجيل المستخدم ($usedToken) 📋'),
                                          duration: const Duration(seconds: 1),
                                        ),
                                      );
                                    },
                                    borderRadius: BorderRadius.circular(6),
                                    child: Padding(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(Icons.copy, size: 13, color: AppColors.emeraldPrimary),
                                          const SizedBox(width: 4),
                                          Text(
                                            'نسخ',
                                            style: TextStyle(fontSize: 11, color: AppColors.emeraldPrimary, fontWeight: FontWeight.bold),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],

                          const SizedBox(height: 12),
                          // 5. الإحصائيات وزر الحذف النهائي بعشر ثوانٍ
                          Wrap(
                            alignment: WrapAlignment.spaceBetween,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            spacing: 8,
                            runSpacing: 10,
                            children: [
                              Wrap(
                                spacing: 6,
                                runSpacing: 6,
                                children: [
                                  _buildStatChip(Icons.menu_book, '$halaqatCount حلقات', isDark),
                                  _buildStatChip(Icons.person, '$sheikhsCount مشايخ', isDark),
                                  _buildStatChip(Icons.people, '$studentsCount طلاب', isDark),
                                ],
                              ),
                              OutlinedButton.icon(
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: Colors.redAccent,
                                  side: BorderSide(color: Colors.redAccent.withValues(alpha: 0.6)),
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                  visualDensity: VisualDensity.compact,
                                ),
                                icon: const Icon(Icons.delete_forever, size: 16),
                                label: const Text('حذف الجامع بالكامل', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                                onPressed: () {
                                  showDialog(
                                    context: context,
                                    barrierDismissible: false,
                                    builder: (_) => DeleteMosqueConfirmDialog(mosque: m),
                                  );
                                },
                              ),
                            ],
                          ),
                        ],
                      ),
                    );
                  },
                ),

              // عرض أي سجلات قديمة لمساجد غير موجودة حالياً فقط كاحتياط لعدم ضياع أي بيان
              if (orphanHistory.isNotEmpty) ...[
                const SizedBox(height: 36),
                Row(
                  children: [
                    const Icon(Icons.history_toggle_off_rounded, color: Colors.grey),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'سجلات تسجيل سابقة أخرى (${orphanHistory.length})',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.grey),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: orphanHistory.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (context, idx) {
                    final h = orphanHistory.reversed.toList()[idx];
                    final mosqueAccessCode = (h['mosqueAccessCode'] ?? '').toString();
                    final usedToken = (h['token'] ?? '').toString();
                    final timestamp = _formatTimestamp(h['timestamp']);

                    return Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: isDark ? Colors.white.withValues(alpha: 0.03) : Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.grey.withValues(alpha: 0.2)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  (h['mosqueName'] ?? 'مسجد سابق').toString(),
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                                ),
                              ),
                              if (mosqueAccessCode.isNotEmpty)
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      mosqueAccessCode,
                                      style: const TextStyle(fontFamily: 'monospace', fontWeight: FontWeight.bold, fontSize: 12),
                                    ),
                                    IconButton(
                                      icon: const Icon(Icons.copy, size: 14),
                                      onPressed: () {
                                        Clipboard.setData(ClipboardData(text: mosqueAccessCode));
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          SnackBar(content: Text('تم نسخ كود المسجد ($mosqueAccessCode) 📋'), duration: const Duration(seconds: 1)),
                                        );
                                      },
                                    ),
                                  ],
                                ),
                            ],
                          ),
                          if (usedToken.isNotEmpty)
                            Text('الكود المستخدم: $usedToken', style: const TextStyle(fontSize: 11, color: Colors.grey)),
                          if (timestamp != null)
                            Text('بتاريخ: $timestamp', style: const TextStyle(fontSize: 10, color: Colors.grey)),
                        ],
                      ),
                    );
                  },
                ),
              ],
              const SizedBox(height: 30),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatChip(IconData icon, String text, bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: isDark ? Colors.white60 : Colors.black54),
          const SizedBox(width: 4),
          Text(text, style: TextStyle(fontSize: 11, color: isDark ? Colors.white70 : Colors.black87)),
        ],
      ),
    );
  }
}
