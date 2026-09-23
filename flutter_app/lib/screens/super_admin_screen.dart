import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../core/theme/app_theme.dart';
import '../services/data_service.dart';

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

  @override
  Widget build(BuildContext context) {
    final data = context.watch<DataService>();
    final tokens = data.getRegistrationTokens();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('لوحة تحكم المشرف العام'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () {
              data.disconnectRole('super_admin');
              Navigator.pop(context);
            },
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () => data.syncWithSupabase(),
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(24),
          child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
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
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          _currentToken!,
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, letterSpacing: 2),
                        ),
                        const SizedBox(width: 12),
                        IconButton(
                          icon: Icon(Icons.copy, size: 20, color: AppColors.emeraldPrimary),
                          onPressed: () {
                            Clipboard.setData(ClipboardData(text: _currentToken!));
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('تم نسخ الكود للحافظة 📋'), duration: Duration(seconds: 1)),
                            );
                          },
                        ),
                      ],
                    ),
                    const Text('اجعل مدير الجامع الجديد يصور هذا الكود لفتح شاشة التسجيل'),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 40),

            // Active Unused Tokens Section
            Row(
              children: [
                Icon(Icons.history, color: AppColors.goldDark),
                const SizedBox(width: 8),
                Text('الأكواد النشطة غير المستخدمة (${tokens.length})', style: const TextStyle(fontWeight: FontWeight.bold)),
              ],
            ),
            const SizedBox(height: 12),
            if (tokens.isEmpty)
              const Center(child: Text('لا توجد أكواد نشطة حالياً'))
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
                          onPressed: () {
                            Clipboard.setData(ClipboardData(text: t));
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('تم نسخ الكود 📋'), duration: Duration(seconds: 1)),
                            );
                          },
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete_outline, color: Colors.redAccent, size: 18),
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

            // Registration History Section
            Row(
              children: [
                Icon(Icons.assignment_turned_in_rounded, color: AppColors.emeraldPrimary),
                const SizedBox(width: 8),
                Text('تاريخ التسجيل واستعادة الأكواد (${data.getTokenUsageHistory().length})',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
              ],
            ),
            const SizedBox(height: 12),
            if (data.getTokenUsageHistory().isEmpty)
              const Center(child: Padding(
                padding: EdgeInsets.all(20),
                child: Text('لا يوجد سجل تسجيلات حالياً'),
              ))
            else
              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: data.getTokenUsageHistory().length,
                separatorBuilder: (_, __) => const SizedBox(height: 10),
                itemBuilder: (context, idx) {
                  final h = data.getTokenUsageHistory().reversed.toList()[idx];
                  return Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppColors.emeraldPrimary.withValues(alpha: 0.2)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Text(
                                h['mosqueName'] ?? 'مسجد جديد',
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: AppColors.emeraldPrimary.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                h['mosqueAccessCode'] ?? '',
                                style: TextStyle(
                                  fontFamily: 'monospace',
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.emeraldPrimary,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(
                          h['mosqueAddress'] ?? '',
                          style: TextStyle(fontSize: 12, color: isDark ? Colors.white60 : Colors.black54),
                        ),
                        const Divider(height: 20),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'الكود المستخدم: ${h['token']}',
                              style: const TextStyle(fontSize: 10, color: Colors.grey),
                            ),
                            Text(
                              'بتاريخ: ${h['timestamp']?.split('T')[0]}',
                              style: const TextStyle(fontSize: 10, color: Colors.grey),
                            ),
                          ],
                        ),
                      ],
                    ),
                  );
                },
              ),
            const SizedBox(height: 30),
          ],
        ),
      ),
      ),
    );
  }
}
