import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../core/theme/app_theme.dart';
import '../services/data_service.dart';
import 'super_admin/ministry_mosques_section.dart';

class SuperAdminScreen extends StatefulWidget {
  const SuperAdminScreen({super.key});

  @override
  State<SuperAdminScreen> createState() => _SuperAdminScreenState();
}

class _SuperAdminScreenState extends State<SuperAdminScreen> {
  String? _currentToken;
  bool _isGenerating = false;

  /// السحب للتحديث يُعلِم قسم المساجد ليعيد جلب الأرقام والصفحة الأولى من الخادم.
  final ValueNotifier<int> _refreshTick = ValueNotifier<int>(0);

  @override
  void initState() {
    super.initState();
    // سحب الأكواد المشتركة من السحابة فور فتح اللوحة على أي جهاز مشرف عام
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<DataService>().syncRegistrationTokens();
    });
  }

  @override
  void dispose() {
    _refreshTick.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final data = context.watch<DataService>();
    final tokens = data.getRegistrationTokens();
    final history = data.getTokenUsageHistory();
    final isDark = Theme.of(context).brightness == Brightness.dark;

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
          _refreshTick.value++;
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

              // المساجد: أرقام المنصة والبحث والصفحات من الخادم (انظر MinistryMosquesSection)
              MinistryMosquesSection(history: history, refresh: _refreshTick),
              const SizedBox(height: 30),
            ],
          ),
        ),
      ),
    );
  }
}
