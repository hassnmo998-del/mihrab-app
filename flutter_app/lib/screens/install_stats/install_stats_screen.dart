import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/theme/app_theme.dart';
import '../../models/install_stats.dart';
import '../../services/install_presence.dart';
import 'install_stats_card.dart';

/// أرقام الأجهزة التي عليها التطبيق، لصاحب المشروع وحده.
///
/// ليست في لوحة المشرف العام (للمنصة أكثر من مشرف): مدخلها مخفي في الإعدادات، وكلمة سرها
/// يفحصها الخادم ولا تُكتب في التطبيق. بعد أول دخول ناجح تُحفظ على هذا الجهاز فلا تُطلب
/// ثانية، وزر القفل يمسحها.
class InstallStatsScreen extends StatefulWidget {
  final Future<InstallStats> Function(String secret) load;

  const InstallStatsScreen({super.key, this.load = InstallPresence.fetchStats});

  static const String secretPrefsKey = 'install_stats_secret';

  @override
  State<InstallStatsScreen> createState() => _InstallStatsScreenState();
}

class _InstallStatsScreenState extends State<InstallStatsScreen> {
  final TextEditingController _secretCtrl = TextEditingController();
  bool _ready = false;
  String? _secret;
  InstallStats? _initial;
  bool _obscure = true;
  bool _checking = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _restore();
  }

  @override
  void dispose() {
    _secretCtrl.dispose();
    super.dispose();
  }

  Future<void> _restore() async {
    String? saved;
    try {
      saved = (await SharedPreferences.getInstance()).getString(InstallStatsScreen.secretPrefsKey);
    } catch (_) {}
    if (!mounted) return;
    setState(() {
      _secret = (saved?.isEmpty ?? true) ? null : saved;
      _ready = true;
    });
  }

  Future<void> _unlock() async {
    final secret = _secretCtrl.text;
    if (InstallPresence.normalizeSecret(secret).isEmpty) {
      setState(() => _error = 'اكتب كلمة السر');
      return;
    }
    setState(() {
      _checking = true;
      _error = null;
    });
    try {
      final stats = await widget.load(secret);
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(InstallStatsScreen.secretPrefsKey, secret);
      } catch (_) {}
      if (!mounted) return;
      setState(() {
        _secret = secret;
        _initial = stats;
        _secretCtrl.clear();
      });
    } on InstallStatsException catch (e) {
      if (!mounted) return;
      setState(
        () => _error = switch (e.error) {
          InstallStatsError.wrongSecret => 'كلمة السر غير صحيحة',
          InstallStatsError.tooManyAttempts => 'محاولات خاطئة كثيرة. أعد المحاولة بعد دقائق.',
          InstallStatsError.unavailable => 'تعذّر الوصول إلى الخادم. تحقق من الإنترنت.',
        },
      );
    } finally {
      if (mounted) setState(() => _checking = false);
    }
  }

  /// يقفل الشاشة وينسى كلمة السر على هذا الجهاز.
  Future<void> _lock() async {
    try {
      (await SharedPreferences.getInstance()).remove(InstallStatsScreen.secretPrefsKey);
    } catch (_) {}
    if (!mounted) return;
    setState(() {
      _secret = null;
      _initial = null;
      _error = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final secret = _secret;
    return Scaffold(
      appBar: AppBar(
        title: const Text('أرقام التطبيق'),
        actions: [
          if (secret != null)
            IconButton(
              key: const ValueKey('installStatsLock'),
              icon: const Icon(Icons.lock_rounded),
              tooltip: 'قفل ونسيان كلمة السر على هذا الجهاز',
              onPressed: _lock,
            ),
        ],
      ),
      body: !_ready
          ? const Center(child: CircularProgressIndicator(strokeWidth: 2.5))
          : SingleChildScrollView(
              padding: EdgeInsets.symmetric(horizontal: MediaQuery.sizeOf(context).width < 600 ? 14 : 24, vertical: 20),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 760),
                  child: secret == null
                      ? _lockedView()
                      : InstallStatsCard(
                          key: ValueKey(secret),
                          load: () => widget.load(secret),
                          initial: _initial,
                          onEnterSecret: _lock,
                        ),
                ),
              ),
            ),
    );
  }

  Widget _lockedView() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.emeraldPrimary.withValues(alpha: 0.25), width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Icon(Icons.lock_outline_rounded, size: 40, color: AppColors.emeraldPrimary),
          const SizedBox(height: 10),
          const Text(
            'هذه الصفحة بكلمة سر',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 18),
          TextField(
            key: const ValueKey('installStatsSecret'),
            controller: _secretCtrl,
            obscureText: _obscure,
            enabled: !_checking,
            autocorrect: false,
            enableSuggestions: false,
            textDirection: TextDirection.ltr,
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => _unlock(),
            decoration: InputDecoration(
              labelText: 'كلمة السر',
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              suffixIcon: IconButton(
                icon: Icon(_obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined),
                tooltip: _obscure ? 'إظهار' : 'إخفاء',
                onPressed: () => setState(() => _obscure = !_obscure),
              ),
            ),
          ),
          if (_error != null) ...[
            const SizedBox(height: 10),
            Text(
              _error!,
              key: const ValueKey('installStatsSecretError'),
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold),
            ),
          ],
          const SizedBox(height: 16),
          FilledButton.icon(
            key: const ValueKey('installStatsUnlock'),
            onPressed: _checking ? null : _unlock,
            icon: _checking
                ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.lock_open_rounded),
            label: const Text('فتح'),
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.emeraldPrimary,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ],
      ),
    );
  }
}
