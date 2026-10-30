import 'dart:ui';

import 'package:flutter/material.dart';

import '../core/theme/app_theme.dart';
import '../screens/help/help_center_screen.dart';
import '../services/help_state.dart';

/// أول فتحة بعد التثبيت أو بعد التحديث إلى هذا الإصدار: الشاشة تتغبّش، وتبقى أيقونة «؟» واضحة
/// يشير إليها سهم، لتدلّ المستخدم على أسرع طريق لتعلّم الاستخدام. زر تخطٍّ، ولا تظهر ثانية.
class HelpCoachOverlay {
  HelpCoachOverlay._();

  static OverlayEntry? _entry;

  /// يعرض النافذة إن لم تُعرض من قبل. [anchor] مفتاح زر «؟» ليُحسب موضعه.
  static void showIfNeeded(BuildContext context, GlobalKey anchor) {
    final state = HelpState.instance;
    if (!state.shouldShowCoach || _entry != null) return;
    final overlay = Overlay.maybeOf(context, rootOverlay: true);
    final box = anchor.currentContext?.findRenderObject();
    if (overlay == null || box is! RenderBox || !box.attached || !box.hasSize) return;
    final rect = box.localToGlobal(Offset.zero) & box.size;

    late final OverlayEntry entry;
    void close() {
      entry.remove();
      _entry = null;
    }

    entry = OverlayEntry(
      builder: (ctx) => _CoachView(
        target: rect,
        onSkip: () {
          HelpState.instance.markCoachSeen();
          close();
        },
        onOpen: () {
          HelpState.instance.markCoachSeen();
          close();
          Navigator.of(context).push(MaterialPageRoute(builder: (_) => const HelpCenterScreen()));
        },
      ),
    );
    _entry = entry;
    overlay.insert(entry);
  }

  @visibleForTesting
  static void dismissForTest() {
    _entry?.remove();
    _entry = null;
  }
}

class _HoleClipper extends CustomClipper<Path> {
  final Rect hole;

  _HoleClipper(this.hole);

  @override
  Path getClip(Size size) => Path.combine(
        PathOperation.difference,
        Path()..addRect(Offset.zero & size),
        Path()..addOval(hole),
      );

  @override
  bool shouldReclip(_HoleClipper old) => old.hole != hole;
}

class _CoachView extends StatelessWidget {
  final Rect target;
  final VoidCallback onSkip;
  final VoidCallback onOpen;

  const _CoachView({required this.target, required this.onSkip, required this.onOpen});

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final hole = Rect.fromCenter(center: target.center, width: target.width + 22, height: target.height + 22);
    // الفقاعة تحت الزر، وتبقى داخل الشاشة
    const bubbleWidth = 300.0;
    final bubbleLeft = (target.center.dx - bubbleWidth / 2).clamp(12.0, size.width - bubbleWidth - 12);
    final bubbleTop = hole.bottom + 20;
    return Material(
      type: MaterialType.transparency,
      child: Directionality(
        textDirection: TextDirection.rtl,
        child: Stack(
          children: [
            Positioned.fill(
              child: ClipPath(
                clipper: _HoleClipper(hole),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 7, sigmaY: 7),
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () {},
                    child: ColoredBox(color: Colors.black.withValues(alpha: 0.42)),
                  ),
                ),
              ),
            ),
            // حلقة حول الزر، وضغطها يفتح التعلّم مباشرة
            Positioned(
              left: hole.left,
              top: hole.top,
              width: hole.width,
              height: hole.height,
              child: GestureDetector(
                key: const ValueKey('helpCoachTarget'),
                onTap: onOpen,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: AppColors.terracottaPrimary, width: 3),
                    boxShadow: [BoxShadow(color: AppColors.terracottaPrimary.withValues(alpha: 0.6), blurRadius: 18, spreadRadius: 2)],
                  ),
                ),
              ),
            ),
            Positioned(
              left: target.center.dx - 12,
              top: hole.bottom + 2,
              child: CustomPaint(size: const Size(24, 20), painter: _ArrowPainter()),
            ),
            Positioned(
              left: bubbleLeft,
              top: bubbleTop,
              width: bubbleWidth,
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.35), blurRadius: 24, offset: const Offset(0, 8))],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.help_outline_rounded, color: AppColors.terracottaPrimary, size: 26),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'تعلّم استخدام التطبيق',
                            style: AppTypography.font(fontSize: 16.5, fontWeight: FontWeight.w800, color: const Color(0xFF2A1810)),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'اضغط على علامة «؟» لتشاهد فيديوهات قصيرة تشرح كل شيء، ولتتواصل معي إن احتجت أي مساعدة.',
                      style: AppTypography.font(fontSize: 13, height: 1.55, color: const Color(0xFF4B3A31)),
                    ),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        Expanded(
                          child: FilledButton(
                            key: const ValueKey('helpCoachOpen'),
                            onPressed: onOpen,
                            style: FilledButton.styleFrom(backgroundColor: AppColors.terracottaPrimary, padding: const EdgeInsets.symmetric(vertical: 12)),
                            child: Text('أرِني الفيديوهات', style: AppTypography.font(fontSize: 13.5, fontWeight: FontWeight.bold, color: Colors.white)),
                          ),
                        ),
                        const SizedBox(width: 8),
                        TextButton(
                          key: const ValueKey('helpCoachSkip'),
                          onPressed: onSkip,
                          child: Text('تخطّي', style: AppTypography.font(fontSize: 13.5, color: const Color(0xFF6B5A50))),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ArrowPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final path = Path()
      ..moveTo(size.width / 2, 0)
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();
    canvas.drawPath(path, Paint()..color = Colors.white);
  }

  @override
  bool shouldRepaint(_ArrowPainter old) => false;
}
