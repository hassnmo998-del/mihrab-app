import 'package:flutter/material.dart';
import '../../../core/theme/app_typography.dart';
import '../../../models/library_book.dart';

/// غلاف كتاب جلدي بزخرفة مذهّبة وكعب ظاهر.
///
/// يُرسم دائماً بمقاس تصميم ثابت ثم يُكبَّر أو يُصغَّر كصورة إلى [width]×[height]،
/// فلا يضيق محتواه مهما صغر الغلاف ولا يتأثر بتكبير خط النظام. والغلاف كله
/// طبقة رسم واحدة تُعاد كما هي أثناء التمرير.
class RealisticBookCover extends StatelessWidget {
  final LibraryBook book;
  final double width;
  final double height;
  final bool showRibbon;
  final bool isBookmarked;
  final double elevation;

  const RealisticBookCover({
    super.key,
    required this.book,
    this.width = 120,
    this.height = 174,
    this.showRibbon = true,
    this.isBookmarked = false,
    this.elevation = 8.0,
  });

  /// مقاس التصميم ونسبته؛ كل الأبعاد في الداخل منسوبة إليه.
  static const double designWidth = 120;
  static const double designHeight = 174;
  static const double aspectRatio = designWidth / designHeight;

  static const Color _gold = Color(0xFFD4AF37);
  static const Color _goldLight = Color(0xFFE5C158);

  @override
  Widget build(BuildContext context) {
    final scale = width / designWidth;
    final radius = BorderRadius.only(
      topRight: Radius.circular(4 * scale),
      bottomRight: Radius.circular(4 * scale),
      topLeft: Radius.circular(9 * scale),
      bottomLeft: Radius.circular(9 * scale),
    );

    return RepaintBoundary(
      child: Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          borderRadius: radius,
          boxShadow: elevation <= 0
              ? null
              : [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.34),
                    offset: Offset(-2 * scale, 4 * scale),
                    blurRadius: elevation,
                  ),
                ],
        ),
        child: ClipRRect(
          borderRadius: radius,
          child: FittedBox(
            fit: BoxFit.fill,
            child: SizedBox(
              width: designWidth,
              height: designHeight,
              child: MediaQuery.withNoTextScaling(child: _buildDesign()),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDesign() {
    final baseColor = Color(book.coverColor);
    final hsl = HSLColor.fromColor(baseColor);
    final darker = hsl.withLightness((hsl.lightness * 0.7).clamp(0.0, 1.0)).toColor();
    final lighter = hsl.withLightness((hsl.lightness * 1.25).clamp(0.0, 1.0)).toColor();
    final imageUrl = book.coverImageUrl;

    return Stack(
      fit: StackFit.expand,
      children: [
        if (imageUrl != null && imageUrl.isNotEmpty)
          Image.network(
            imageUrl,
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => _buildLeather(baseColor, darker, lighter),
          )
        else
          _buildLeather(baseColor, darker, lighter),

        // الكعب: تظليل أسطواني على الطرف الأيمن (جهة تجليد الكتاب العربي)
        Positioned(
          top: 0,
          bottom: 0,
          right: 0,
          width: 14,
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Colors.black.withValues(alpha: 0.45),
                  Colors.black.withValues(alpha: 0.12),
                  Colors.white.withValues(alpha: 0.20),
                  Colors.black.withValues(alpha: 0.35),
                ],
                stops: const [0.0, 0.4, 0.7, 1.0],
              ),
            ),
          ),
        ),

        // حافة الورق على الطرف الأيسر
        const Positioned(
          top: 3,
          bottom: 3,
          left: 0,
          width: 3,
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: Color(0xFFF1EADB),
              borderRadius: BorderRadius.horizontal(left: Radius.circular(2)),
            ),
          ),
        ),

        if (showRibbon)
          Positioned(
            top: 0,
            right: 28,
            child: CustomPaint(
              size: const Size(13, 30),
              painter: _RibbonPainter(color: isBookmarked ? _gold : const Color(0xFFB71C1C)),
            ),
          ),
      ],
    );
  }

  Widget _buildLeather(Color base, Color darker, Color lighter) {
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: RadialGradient(
          center: const Alignment(0.1, -0.2),
          radius: 1.1,
          colors: [lighter, base, darker, Colors.black.withValues(alpha: 0.85)],
          stops: const [0.0, 0.45, 0.82, 1.0],
        ),
      ),
      child: Padding(
        // الهامش الأيمن أوسع ليبقى الإطار خارج الكعب
        padding: const EdgeInsets.fromLTRB(7, 7, 17, 7),
        child: DecoratedBox(
          decoration: BoxDecoration(
            border: Border.all(color: _gold.withValues(alpha: 0.75), width: 1.2),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Padding(
            padding: const EdgeInsets.all(3),
            child: DecoratedBox(
              decoration: BoxDecoration(
                border: Border.all(color: _goldLight.withValues(alpha: 0.4), width: 0.8),
                borderRadius: BorderRadius.circular(2),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 8),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.auto_stories_rounded, size: 18, color: _goldLight.withValues(alpha: 0.85)),
                    const SizedBox(height: 5),
                    _goldRule(46),
                    const SizedBox(height: 7),
                    Flexible(
                      child: Text(
                        book.shortTitle,
                        style: AppTypography.font(
                          fontSize: 13.5,
                          fontWeight: FontWeight.bold,
                          height: 1.3,
                          color: const Color(0xFFFFF9E6),
                          shadows: [
                            Shadow(
                              color: Colors.black.withValues(alpha: 0.9),
                              offset: const Offset(1, 1),
                              blurRadius: 2,
                            ),
                          ],
                        ),
                        textAlign: TextAlign.center,
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(height: 7),
                    _goldRule(26),
                    const SizedBox(height: 6),
                    Text(
                      _authorShort(book.author),
                      style: AppTypography.font(
                        fontSize: 8.5,
                        height: 1.35,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFFE0CEAA),
                      ),
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  static Widget _goldRule(double width) {
    return Container(
      width: width,
      height: 1.1,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.transparent, Color(0xFFF3E5AB), _gold, Colors.transparent],
        ),
      ),
    );
  }

  /// الاسم بلا سنة الوفاة وما بعدها: "ابن القيم (ت 751 هـ)" ← "ابن القيم".
  static String _authorShort(String author) => author.split('(').first.trim();
}

class _RibbonPainter extends CustomPainter {
  final Color color;
  _RibbonPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final path = Path()
      ..moveTo(0, 0)
      ..lineTo(size.width, 0)
      ..lineTo(size.width, size.height)
      ..lineTo(size.width / 2, size.height - 6)
      ..lineTo(0, size.height)
      ..close();

    canvas.drawPath(
      path.shift(const Offset(1, 1.5)),
      Paint()..color = Colors.black.withValues(alpha: 0.3),
    );
    canvas.drawPath(path, Paint()..color = color);
    canvas.drawLine(
      Offset(size.width / 2, 0),
      Offset(size.width / 2, size.height - 7),
      Paint()
        ..color = Colors.white.withValues(alpha: 0.25)
        ..strokeWidth = 1.0,
    );
  }

  @override
  bool shouldRepaint(covariant _RibbonPainter oldDelegate) => oldDelegate.color != color;
}
