import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_app/models/student.dart';
import 'package:flutter_app/screens/admin/design_studio/models/badge_design_config.dart';
import 'package:flutter_app/screens/admin/design_studio/models/poster_design_config.dart';
import 'package:flutter_app/screens/admin/design_studio/widgets/badge_card_render_view.dart';
import 'package:flutter_app/screens/admin/design_studio/widgets/honor_poster_render_view.dart';

void main() {
  group('Design Studio Models Test', () {
    test('BadgeDesignConfig default values and copyWith', () {
      const config = BadgeDesignConfig();
      expect(config.orientation, BadgeOrientation.portrait);
      expect(config.themeVariant, BadgeThemeVariant.ministerialGold);
      expect(config.showQr, true);

      final modified = config.copyWith(
        orientation: BadgeOrientation.landscape,
        themeVariant: BadgeThemeVariant.quranicEmerald,
        showPhone: true,
      );
      expect(modified.orientation, BadgeOrientation.landscape);
      expect(modified.themeVariant, BadgeThemeVariant.quranicEmerald);
      expect(modified.showPhone, true);
      expect(modified.showQr, true);
    });

    test('PosterDesignConfig default values and copyWith', () {
      const config = PosterDesignConfig();
      expect(config.aspectRatio, PosterAspectRatio.square1x1);
      expect(config.layoutType, PosterLayoutType.podiumTop3);

      final modified = config.copyWith(
        aspectRatio: PosterAspectRatio.story9x16,
        layoutType: PosterLayoutType.honorListTop5,
        title: 'لوحة الشرف الصيفية',
      );
      expect(modified.aspectRatio, PosterAspectRatio.story9x16);
      expect(modified.layoutType, PosterLayoutType.honorListTop5);
      expect(modified.title, 'لوحة الشرف الصيفية');
    });
  });

  group('Design Studio Widgets Render Test', () {
    final testStudent = Student(
      id: 'std_1',
      mosqueId: 'mosque_1',
      halaqaId: 'halaqa_1',
      fullName: 'محمد أحمد السعيد',
      gender: 'male',
      phone: '0912345678',
      totalPoints: 1250,
      code: 'STD-1001',
    );

    testWidgets('BadgeCardRenderView renders portrait badge with student name and code', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: BadgeCardRenderView(
              name: testStudent.fullName,
              roleLabel: 'طالب بالمسجد',
              code: testStudent.code,
              mosqueName: 'جامع الهدى الكبير',
              halaqaName: 'حلقة الإمام البخاري',
              sheikhName: 'الشيخ عبدالرحمن',
              config: const BadgeDesignConfig(orientation: BadgeOrientation.portrait),
            ),
          ),
        ),
      );

      expect(find.text('محمد أحمد السعيد'), findsOneWidget);
      expect(find.text('جامع الهدى الكبير'), findsOneWidget);
      expect(find.text('STD-1001'), findsOneWidget);
    });

    testWidgets('BadgeCardRenderView renders landscape badge', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: BadgeCardRenderView(
              name: testStudent.fullName,
              roleLabel: 'طالب بالمسجد',
              code: testStudent.code,
              mosqueName: 'جامع الهدى الكبير',
              config: const BadgeDesignConfig(orientation: BadgeOrientation.landscape),
            ),
          ),
        ),
      );

      expect(find.text('محمد أحمد السعيد'), findsOneWidget);
      expect(find.textContaining('STD-1001'), findsOneWidget);
    });

    testWidgets('HonorPosterRenderView renders podium for top students', (tester) async {
      final entries = [
        RankedStudentEntry(
          rank: 1,
          student: testStudent,
          halaqaName: 'حلقة النور',
          score: 1250,
        ),
      ];

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: HonorPosterRenderView(
              mosqueName: 'جامع النور',
              students: entries,
              config: const PosterDesignConfig(
                layoutType: PosterLayoutType.podiumTop3,
              ),
            ),
          ),
        ),
      );

      expect(find.text('جامع النور'), findsOneWidget);
      expect(find.text('محمد أحمد السعيد'), findsOneWidget);
      expect(find.text('1250 ن'), findsOneWidget);
    });
  });
}
