import 'package:flutter/material.dart';

import '../services/data_service.dart';

/// نافذة دخول المشرف العام: بريد وكلمة مرور، كل خانة في مكانها بلا تلاصق، ورسالة الخطأ
/// داخل النافذة (الإشعار السفلي يظهر خلف حجابها).
///
/// تُغلق بـ `true` عند نجاح الدخول.
class SuperAdminLoginDialog extends StatefulWidget {
  final Future<SuperAdminLoginResult> Function(String email, String password) onLogin;

  const SuperAdminLoginDialog({super.key, required this.onLogin});

  @override
  State<SuperAdminLoginDialog> createState() => _SuperAdminLoginDialogState();
}

class _SuperAdminLoginDialogState extends State<SuperAdminLoginDialog> {
  final TextEditingController _email = TextEditingController();
  final TextEditingController _password = TextEditingController();
  final FocusNode _passwordFocus = FocusNode();

  bool _loading = false;
  bool _showPassword = false;
  String? _error;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    _passwordFocus.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_loading) return;
    if (_email.text.trim().isEmpty || _password.text.isEmpty) {
      setState(() => _error = 'أدخل البريد الإلكتروني وكلمة المرور');
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    final result = await widget.onLogin(_email.text, _password.text);
    if (!mounted) return;
    if (result == SuperAdminLoginResult.success) {
      Navigator.pop(context, true);
      return;
    }
    setState(() {
      _loading = false;
      _error = switch (result) {
        SuperAdminLoginResult.notAuthorized => 'هذا الحساب لا يملك صلاحية المشرف العام',
        SuperAdminLoginResult.unavailable => 'تعذر الوصول لخادم المصادقة، تحقق من اتصالك بالإنترنت',
        _ => 'بيانات الدخول غير صحيحة',
      };
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.brightness == Brightness.dark ? Colors.white60 : Colors.black54;

    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      titlePadding: const EdgeInsets.fromLTRB(22, 22, 22, 0),
      contentPadding: const EdgeInsets.fromLTRB(22, 14, 22, 6),
      actionsPadding: const EdgeInsets.fromLTRB(16, 4, 16, 14),
      title: Row(
        children: [
          Icon(Icons.admin_panel_settings_outlined, color: theme.primaryColor),
          const SizedBox(width: 10),
          const Expanded(child: Text('دخول المشرف العام', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold))),
        ],
      ),
      content: SizedBox(
        width: 360,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('خاص بإدارة المنصة.', style: TextStyle(fontSize: 12.5, color: muted)),
              const SizedBox(height: 16),
              TextField(
                key: const ValueKey('superAdminEmail'),
                controller: _email,
                enabled: !_loading,
                autofocus: true,
                keyboardType: TextInputType.emailAddress,
                textDirection: TextDirection.ltr,
                textInputAction: TextInputAction.next,
                autocorrect: false,
                autofillHints: const [AutofillHints.username, AutofillHints.email],
                decoration: const InputDecoration(
                  labelText: 'البريد الإلكتروني',
                  prefixIcon: Icon(Icons.alternate_email, size: 20),
                ),
                onSubmitted: (_) => _passwordFocus.requestFocus(),
              ),
              const SizedBox(height: 16),
              TextField(
                key: const ValueKey('superAdminPassword'),
                controller: _password,
                focusNode: _passwordFocus,
                enabled: !_loading,
                obscureText: !_showPassword,
                textDirection: TextDirection.ltr,
                textInputAction: TextInputAction.done,
                autocorrect: false,
                enableSuggestions: false,
                autofillHints: const [AutofillHints.password],
                decoration: InputDecoration(
                  labelText: 'كلمة المرور',
                  prefixIcon: const Icon(Icons.lock_outline, size: 20),
                  suffixIcon: IconButton(
                    tooltip: _showPassword ? 'إخفاء كلمة المرور' : 'إظهار كلمة المرور',
                    icon: Icon(_showPassword ? Icons.visibility_off_outlined : Icons.visibility_outlined, size: 20),
                    onPressed: () => setState(() => _showPassword = !_showPassword),
                  ),
                ),
                onSubmitted: (_) => _submit(),
              ),
              if (_error != null) ...[
                const SizedBox(height: 12),
                Text(
                  _error!,
                  key: const ValueKey('superAdminLoginError'),
                  style: const TextStyle(color: Colors.redAccent, fontSize: 12.5, fontWeight: FontWeight.w600),
                ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _loading ? null : () => Navigator.pop(context, false),
          child: const Text('إلغاء'),
        ),
        ElevatedButton(
          key: const ValueKey('superAdminLoginButton'),
          onPressed: _loading ? null : _submit,
          child: _loading
              ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
              : const Text('دخول'),
        ),
      ],
    );
  }
}
