import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../core/theme/app_theme.dart';
import '../screens/help/help_center_screen.dart';
import '../services/help_state.dart';

/// زر «؟» في أعلى التطبيق بجانب الإعدادات: يومض حتى يفتح المستخدم شاشة التعلّم مرة،
/// ويومض من جديد حين يصله ردّ من المطوّر. الوميض معطّل في الاختبارات (حركة لا تنتهي).
class HelpAppBarButton extends StatefulWidget {
  final ButtonStyle? style;

  /// مفتاح يقرأ منه نافذة التعريف موضع الزر لتُظلِّل حوله.
  final GlobalKey? anchorKey;

  const HelpAppBarButton({super.key, this.style, this.anchorKey});

  @override
  State<HelpAppBarButton> createState() => _HelpAppBarButtonState();
}

class _HelpAppBarButtonState extends State<HelpAppBarButton> with SingleTickerProviderStateMixin {
  late final AnimationController _pulse = AnimationController(vsync: this, duration: const Duration(milliseconds: 1100));

  static bool get _animationsAllowed => kIsWeb || !Platform.environment.containsKey('FLUTTER_TEST');

  @override
  void initState() {
    super.initState();
    HelpState.instance.addListener(_sync);
    _sync();
  }

  @override
  void dispose() {
    HelpState.instance.removeListener(_sync);
    _pulse.dispose();
    super.dispose();
  }

  void _sync() {
    if (!mounted) return;
    final want = HelpState.instance.shouldPulse && _animationsAllowed;
    if (want && !_pulse.isAnimating) {
      _pulse.repeat(reverse: true);
    } else if (!want && _pulse.isAnimating) {
      _pulse.stop();
      _pulse.value = 0;
    }
    setState(() {});
  }

  void _open() {
    Navigator.push(context, MaterialPageRoute(builder: (_) => const HelpCenterScreen()));
  }

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).primaryColor;
    final state = HelpState.instance;
    final hasReply = state.unreadReply;
    return AnimatedBuilder(
      animation: _pulse,
      builder: (context, _) {
        final t = Curves.easeInOut.transform(_pulse.value);
        return Stack(
          alignment: Alignment.center,
          clipBehavior: Clip.none,
          children: [
            if (state.shouldPulse)
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.terracottaPrimary.withValues(alpha: 0.10 + 0.22 * t),
                  boxShadow: [BoxShadow(color: AppColors.terracottaPrimary.withValues(alpha: 0.45 * t), blurRadius: 12 * t, spreadRadius: 2 * t)],
                ),
              ),
            IconButton(
              key: widget.anchorKey,
              style: widget.style,
              tooltip: hasReply ? 'تعلّم الاستخدام (لديك ردّ جديد من المطوّر)' : 'تعلّم استخدام التطبيق',
              icon: Icon(Icons.help_outline_rounded, color: primary),
              onPressed: _open,
            ),
            if (hasReply)
              Positioned(
                top: 4,
                right: 4,
                child: Container(
                  width: 11,
                  height: 11,
                  decoration: BoxDecoration(color: Colors.redAccent, shape: BoxShape.circle, border: Border.all(color: Colors.white, width: 1.5)),
                ),
              ),
          ],
        );
      },
    );
  }
}
