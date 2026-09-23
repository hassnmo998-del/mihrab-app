import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_app/core/theme/app_theme.dart';
import 'package:flutter_app/presentation/widgets/widgets.dart';

void main() {
  group('UnifiedCard Tests', () {
    testWidgets('UnifiedCard renders child with standard card styling', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: const Scaffold(
            body: UnifiedCard(
              child: Text('Card Content'),
            ),
          ),
        ),
      );

      expect(find.text('Card Content'), findsOneWidget);
      expect(find.byType(UnifiedCard), findsOneWidget);

      final container = tester.widget<Container>(
        find.descendant(of: find.byType(UnifiedCard), matching: find.byType(Container)).first,
      );
      final decoration = container.decoration as BoxDecoration;
      expect(decoration.borderRadius, AppRadius.card);
      expect(decoration.border, isNotNull);
    });

    testWidgets('UnifiedCard handles onTap properly', (tester) async {
      bool tapped = false;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: UnifiedCard(
              onTap: () => tapped = true,
              child: const Text('Tappable Card'),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Tappable Card'));
      expect(tapped, isTrue);
    });

    testWidgets('UnifiedCard.elevated renders with card shadow', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: UnifiedCard.elevated(
              child: const Text('Elevated Card'),
            ),
          ),
        ),
      );

      final container = tester.widget<Container>(
        find.descendant(of: find.byType(UnifiedCard), matching: find.byType(Container)).first,
      );
      final decoration = container.decoration as BoxDecoration;
      expect(decoration.boxShadow, isNotEmpty);
    });
  });

  group('UnifiedBadge Tests', () {
    testWidgets('UnifiedBadge renders semantic statuses correctly', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: Scaffold(
            body: Column(
              children: [
                UnifiedBadge.present(),
                UnifiedBadge.absent(),
                UnifiedBadge.late(),
                UnifiedBadge.active(),
                UnifiedBadge.finished(),
                UnifiedBadge.smartDetection(),
              ],
            ),
          ),
        ),
      );

      expect(find.text('حاضر'), findsOneWidget);
      expect(find.text('غائب'), findsOneWidget);
      expect(find.text('متأخر'), findsOneWidget);
      expect(find.text('جارية'), findsOneWidget);
      expect(find.text('منتهية'), findsOneWidget);
      expect(find.text('كشف ذكي'), findsOneWidget);
    });

    testWidgets('UnifiedBadge.fromStatus resolves statuses dynamically', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: Scaffold(
            body: Column(
              children: [
                UnifiedBadge.fromStatus('حاضر ✅'),
                UnifiedBadge.fromStatus('غائب ❌'),
                UnifiedBadge.fromStatus('متأخر ⏳'),
                UnifiedBadge.fromStatus('جارية حالياً 🟢'),
                UnifiedBadge.fromStatus('منتهية ⚪'),
                UnifiedBadge.fromStatus('كشف ذكي ±30 دقيقة ⏱️'),
              ],
            ),
          ),
        ),
      );

      expect(find.text('حاضر ✅'), findsOneWidget);
      expect(find.text('غائب ❌'), findsOneWidget);
      expect(find.text('متأخر ⏳'), findsOneWidget);
      expect(find.text('جارية حالياً 🟢'), findsOneWidget);
      expect(find.text('منتهية ⚪'), findsOneWidget);
      expect(find.text('كشف ذكي ±30 دقيقة ⏱️'), findsOneWidget);
    });
  });

  group('UnifiedDialog Tests', () {
    testWidgets('showUnifiedDialog displays title, message, and actions', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: Builder(
            builder: (context) => Scaffold(
              body: ElevatedButton(
                onPressed: () {
                  showUnifiedDialog(
                    context: context,
                    title: 'تنبيه مهم',
                    message: 'هل تريد المتابعة؟',
                    confirmText: 'نعم',
                    cancelText: 'لا',
                  );
                },
                child: const Text('Open Dialog'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open Dialog'));
      await tester.pumpAndSettle();

      expect(find.text('تنبيه مهم'), findsOneWidget);
      expect(find.text('هل تريد المتابعة؟'), findsOneWidget);
      expect(find.text('نعم'), findsOneWidget);
      expect(find.text('لا'), findsOneWidget);

      await tester.tap(find.text('نعم'));
      await tester.pumpAndSettle();

      expect(find.text('تنبيه مهم'), findsNothing);
    });
  });

  group('UnifiedDataTable Tests', () {
    testWidgets('UnifiedDataTable renders header and rows correctly', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: const Scaffold(
            body: UnifiedDataTable(
              columns: [
                DataColumn(label: Text('الاسم')),
                DataColumn(label: Text('الحلقة')),
              ],
              rows: [
                DataRow(cells: [
                  DataCell(Text('أحمد')),
                  DataCell(Text('حلقة أبي بكر')),
                ]),
              ],
            ),
          ),
        ),
      );

      expect(find.text('الاسم'), findsOneWidget);
      expect(find.text('الحلقة'), findsOneWidget);
      expect(find.text('أحمد'), findsOneWidget);
      expect(find.text('حلقة أبي بكر'), findsOneWidget);
    });

    testWidgets('UnifiedDataTable renders empty state when rows are empty', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: const Scaffold(
            body: UnifiedDataTable(
              columns: [
                DataColumn(label: Text('الاسم')),
              ],
              rows: [],
              emptyMessage: 'لا توجد بيانات حالياً',
            ),
          ),
        ),
      );

      expect(find.text('لا توجد بيانات حالياً'), findsOneWidget);
    });
  });
}
