import 'package:flutter_app/models/models.dart';
import 'package:flutter_app/screens/cashier/models/cashier_ledger_report.dart';
import 'package:flutter_test/flutter_test.dart';

/// اختبارات السجل الكامل للصراف: الفلترة بالجامع والفترة، والتجميع الذي
/// تُحاسب الإدارة الصرافَ على أساسه (نقاط + مال حسب تسعيرة الجوائز).
void main() {
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day, 10);
  final lastMonthDay = DateTime(now.year, now.month, 1)
      .subtract(const Duration(days: 5))
      .add(const Duration(hours: 9));

  Reward reward(String id, String mosqueId, String title,
          {bool active = true}) =>
      Reward(
        id: id,
        mosqueId: mosqueId,
        title: title,
        pointsCost: 100,
        isActive: active,
        createdAt: DateTime(2024, 1, 1),
      );

  Student student(String id, String mosqueId, String halaqaId, String name) =>
      Student(
        id: id,
        mosqueId: mosqueId,
        halaqaId: halaqaId,
        fullName: name,
        gender: 'male',
        phone: '0000',
        code: 'STD-$id',
      );

  Halaqa halaqa(String id, String mosqueId, String name) =>
      Halaqa(id: id, mosqueId: mosqueId, name: name);

  RewardRedemption redemption({
    required String id,
    required String studentId,
    required String mosqueId,
    required String rewardId,
    required String rewardTitle,
    required int points,
    required DateTime date,
    String status = 'dispensed',
  }) =>
      RewardRedemption(
        id: id,
        studentId: studentId,
        studentName: 'طالب $studentId',
        mosqueId: mosqueId,
        mosqueName: 'جامع $mosqueId',
        rewardId: rewardId,
        rewardTitle: rewardTitle,
        pointsSpent: points,
        redemptionCode: 'VCH-$id',
        status: status,
        redeemedAt: date,
        dispensedAt: status == 'dispensed' ? date : null,
        cashierName: 'أبو محمد',
      );

  final rewards = [
    reward('r1', 'm1', 'عصير'),
    reward('r2', 'm1', 'دفتر'),
    reward('r3', 'm2', 'قلم'),
    reward('r4', 'm1', 'جائزة موقوفة', active: false),
  ];
  final students = [
    student('s1', 'm1', 'h1', 'أحمد'),
    student('s2', 'm1', 'h2', 'خالد'),
    student('s3', 'm2', 'h3', 'عمر'),
  ];
  final halaqat = [
    halaqa('h1', 'm1', 'حلقة النور'),
    halaqa('h2', 'm1', 'حلقة الفرقان'),
    halaqa('h3', 'm2', 'حلقة الهدى'),
  ];
  final redemptions = [
    redemption(
        id: '1',
        studentId: 's1',
        mosqueId: 'm1',
        rewardId: 'r1',
        rewardTitle: 'عصير',
        points: 100,
        date: today),
    redemption(
        id: '2',
        studentId: 's1',
        mosqueId: 'm1',
        rewardId: 'r1',
        rewardTitle: 'عصير',
        points: 100,
        date: today),
    redemption(
        id: '3',
        studentId: 's2',
        mosqueId: 'm1',
        rewardId: 'r2',
        rewardTitle: 'دفتر',
        points: 250,
        date: today),
    // جامع آخر — يجب ألا يظهر عند اختيار m1
    redemption(
        id: '4',
        studentId: 's3',
        mosqueId: 'm2',
        rewardId: 'r3',
        rewardTitle: 'قلم',
        points: 60,
        date: today),
    // خارج الفترة (الشهر الماضي)
    redemption(
        id: '5',
        studentId: 's2',
        mosqueId: 'm1',
        rewardId: 'r1',
        rewardTitle: 'عصير',
        points: 100,
        date: lastMonthDay),
    // معلّقة
    redemption(
        id: '6',
        studentId: 's1',
        mosqueId: 'm1',
        rewardId: 'r2',
        rewardTitle: 'دفتر',
        points: 250,
        date: today,
        status: 'pending'),
    // معلّقة لجائزة أوقفتها الإدارة — تُستبعد دائماً
    redemption(
        id: '7',
        studentId: 's1',
        mosqueId: 'm1',
        rewardId: 'r4',
        rewardTitle: 'جائزة موقوفة',
        points: 500,
        date: today,
        status: 'pending'),
    // ملغاة — تُستبعد دائماً
    redemption(
        id: '8',
        studentId: 's2',
        mosqueId: 'm1',
        rewardId: 'r1',
        rewardTitle: 'عصير',
        points: 100,
        date: today,
        status: 'cancelled'),
  ];

  CashierLedgerReport build({
    String? mosqueId = 'm1',
    String? halaqaId,
    LedgerPeriod? period,
    Map<String, double> prices = const {},
    bool includePending = true,
  }) =>
      CashierLedgerReport.build(
        redemptions: redemptions,
        rewards: rewards,
        students: students,
        halaqat: halaqat,
        mosqueLabel: 'جامع الاختبار',
        period: period ?? LedgerPeriod.thisMonth(),
        cashierLabel: 'أبو محمد',
        mosqueId: mosqueId,
        halaqaId: halaqaId,
        unitPrices: prices,
        currency: 'ل.س',
        includePending: includePending,
      );

  group('فلترة السجل الكامل', () {
    test('يقتصر على الجامع المختار وعلى الفترة المحددة', () {
      final report = build();
      final ids = report.entries.map((e) => e.redemption.id).toSet();

      expect(ids.contains('4'), isFalse, reason: 'عملية من جامع آخر');
      expect(ids.contains('5'), isFalse, reason: 'عملية خارج الفترة');
      expect(ids.contains('7'), isFalse, reason: 'جائزة موقوفة ومعلّقة');
      expect(ids.contains('8'), isFalse, reason: 'عملية ملغاة');
      expect(ids, containsAll(<String>['1', '2', '3', '6']));
    });

    test('يفصل المسلّم عن المعلّق ويحسب النقاط لكل منهما', () {
      final report = build();
      expect(report.dispensedCount, 3);
      expect(report.dispensedPoints, 450); // 100 + 100 + 250
      expect(report.pendingCount, 1);
      expect(report.pendingPoints, 250);
      expect(report.beneficiaries, 2); // s1 و s2
    });

    test('استبعاد المعلّق يحذفه من الكشف دون المساس بالمسلّم', () {
      final report = build(includePending: false);
      expect(report.pendingCount, 0);
      expect(report.dispensedCount, 3);
      expect(report.dispensedPoints, 450);
    });

    test('فلتر الحلقة يقصر الكشف على طلابها', () {
      final report = build(halaqaId: 'h1');
      expect(
        report.entries.every((e) => e.halaqaName == 'حلقة النور'),
        isTrue,
      );
      expect(report.dispensedCount, 2); // عمليتا الطالب s1 المسلّمتان
    });

    test('فترة اليوم تلتقط عمليات اليوم، والشهر الماضي يلتقط ما قبلها', () {
      expect(build(period: LedgerPeriod.today()).dispensedCount, 3);

      final lastMonth = build(period: LedgerPeriod.lastMonth());
      final ids = lastMonth.entries.map((e) => e.redemption.id).toList();
      expect(ids, contains('5'));
      expect(ids, isNot(contains('1')));
    });

    test('كل الفترات وكل الجوامع تجمع كل شيء صالح', () {
      final report = build(mosqueId: null, period: const LedgerPeriod.all());
      final ids = report.entries.map((e) => e.redemption.id).toSet();
      expect(ids, containsAll(<String>['1', '2', '3', '4', '5', '6']));
      expect(ids.contains('7'), isFalse);
      expect(ids.contains('8'), isFalse);
    });
  });

  group('التجميع والمحاسبة', () {
    test('التجميع حسب الجائزة يعتمد المسلّم فقط', () {
      final report = build();
      final juice = report.byReward.firstWhere((g) => g.label == 'عصير');
      final notebook = report.byReward.firstWhere((g) => g.label == 'دفتر');

      expect(juice.count, 2);
      expect(juice.points, 200);
      // الدفتر المعلّق (id 6) لا يُحتسب ضمن المستحقات
      expect(notebook.count, 1);
      expect(notebook.points, 250);
    });

    test('التسعيرة تحوّل الجوائز المسلّمة إلى مبلغ مستحق', () {
      final report = build(prices: {'r1': 2500, 'r2': 7000});
      expect(report.hasPricing, isTrue);
      expect(report.dispensedMoney, 2500 * 2 + 7000);
      expect(report.unpricedRewards, isEmpty);
      expect(report.moneyText(report.dispensedMoney), '12,000 ل.س');
    });

    test('الجوائز غير المسعّرة تُرصد ولا تُحتسب بالمال', () {
      final report = build(prices: {'r1': 2500});
      expect(report.dispensedMoney, 5000);
      expect(report.unpricedRewards.map((g) => g.label), contains('دفتر'));
    });

    test('التجميع حسب الحلقة والطالب واليوم يغطي كل المسلّم', () {
      final report = build();
      expect(
        report.byHalaqa.fold<int>(0, (sum, g) => sum + g.count),
        report.dispensedCount,
      );
      expect(report.byStudent.length, 2);
      expect(report.byDay.fold<int>(0, (sum, g) => sum + g.points),
          report.dispensedPoints);
    });
  });

  group('التصدير', () {
    test('الكشف النصي يحمل الترويسة والملخص والمبلغ', () {
      final report = build(prices: {'r1': 2500, 'r2': 7000});
      final text = report.toPlainText();

      expect(text, contains('جامع الاختبار'));
      expect(text, contains('أبو محمد'));
      expect(text, contains('إجمالي النقاط المسحوبة: 450 نقطة'));
      expect(text, contains('المبلغ المستحق للصراف: 12,000 ل.س'));
      expect(text, contains('تفصيل العمليات'));
    });

    test('يمكن إصدار كشف مختصر دون تفصيل العمليات', () {
      final text = build().toPlainText(includeDetails: false);
      expect(text, contains('الملخص'));
      expect(text, isNot(contains('تفصيل العمليات')));
    });

    test('ملف CSV يبدأ بـ BOM ويحوي سطراً لكل عملية', () {
      final report = build();
      final csv = report.toCsv();
      final lines = csv.split('\r\n');

      expect(csv.codeUnitAt(0), 0xFEFF);
      expect(lines.first, contains('الطالب'));
      // ترويسة + عدد العمليات
      expect(
        lines.where((l) => l.startsWith('"') && l.contains('VCH-')).length,
        report.entries.length,
      );
      expect(csv, contains('التفصيل حسب الجائزة'));
    });

    test('القسائم المعلّقة لا يُذكر لها مبلغ (لا يُستحق إلا على المسلّم)', () {
      final report = build(prices: {'r1': 2500, 'r2': 7000});
      final pendingEntry =
          report.pending.firstWhere((e) => e.redemption.id == '6');
      final pendingLine = report
          .toPlainText()
          .split('\n')
          .firstWhere((l) => l.contains('القسيمة: VCH-6'));

      // السعر معروف للجائزة، لكنه لا يظهر ولا يدخل في الإجمالي
      expect(pendingEntry.unitPrice, 7000);
      expect(report.dispensedMoney, 2500 * 2 + 7000);
      expect(pendingLine, isNot(contains('ل.س')));

      final csvPendingRow = report
          .toCsv()
          .split('\r\n')
          .firstWhere((l) => l.contains('VCH-6'));
      expect(csvPendingRow, contains('"قيد الانتظار"'));
      expect(csvPendingRow, contains('"250","",'));
    });

    test('اسم الملف خالٍ من محارف المسارات الممنوعة', () {
      final name = build().fileNamePrefix();
      expect(RegExp(r'[\\/:*?"<>|\s]').hasMatch(name), isFalse);
    });
  });
}
