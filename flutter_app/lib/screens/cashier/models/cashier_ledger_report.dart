import 'package:intl/intl.dart';

import '../../../models/models.dart';

/// نطاق زمني مغلق يُستخدم لتحديد فترة السجل الكامل.
class LedgerPeriod {
  /// بداية الفترة (مشمولة). `null` تعني «من البداية».
  final DateTime? from;

  /// نهاية الفترة (مشمولة حتى آخر لحظة من اليوم). `null` تعني «حتى الآن».
  final DateTime? to;

  /// وصف الفترة كما يظهر في الكشف (مثل: «هذا الشهر»).
  final String label;

  const LedgerPeriod({this.from, this.to, required this.label});

  const LedgerPeriod.all()
      : from = null,
        to = null,
        label = 'كل الفترات';

  factory LedgerPeriod.today() {
    final now = DateTime.now();
    final day = DateTime(now.year, now.month, now.day);
    return LedgerPeriod(from: day, to: day, label: 'اليوم');
  }

  factory LedgerPeriod.thisWeek() {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    // الأسبوع يبدأ من السبت كما هو متعارف عليه محلياً
    final daysSinceSaturday = (now.weekday + 1) % 7;
    return LedgerPeriod(
      from: today.subtract(Duration(days: daysSinceSaturday)),
      to: today,
      label: 'هذا الأسبوع',
    );
  }

  factory LedgerPeriod.thisMonth() {
    final now = DateTime.now();
    return LedgerPeriod(
      from: DateTime(now.year, now.month, 1),
      to: DateTime(now.year, now.month, now.day),
      label: 'هذا الشهر',
    );
  }

  factory LedgerPeriod.lastMonth() {
    final now = DateTime.now();
    final firstOfThisMonth = DateTime(now.year, now.month, 1);
    final lastMonthEnd = firstOfThisMonth.subtract(const Duration(days: 1));
    return LedgerPeriod(
      from: DateTime(lastMonthEnd.year, lastMonthEnd.month, 1),
      to: lastMonthEnd,
      label: 'الشهر الماضي',
    );
  }

  factory LedgerPeriod.custom(DateTime from, DateTime to) {
    final f = DateTime(from.year, from.month, from.day);
    final t = DateTime(to.year, to.month, to.day);
    final fmt = DateFormat('yyyy/MM/dd');
    return LedgerPeriod(
      from: f,
      to: t,
      label: 'من ${fmt.format(f)} إلى ${fmt.format(t)}',
    );
  }

  bool contains(DateTime date) {
    if (from != null && date.isBefore(from!)) return false;
    if (to != null) {
      final endOfDay = DateTime(to!.year, to!.month, to!.day, 23, 59, 59, 999);
      if (date.isAfter(endOfDay)) return false;
    }
    return true;
  }
}

/// سطر واحد في السجل الكامل، مُجهّز بكل الحقول التي تحتاجها الإدارة.
class LedgerEntry {
  final RewardRedemption redemption;
  final String studentCode;
  final String halaqaName;

  /// سعر الوحدة بالمال إن أُدخل لهذه الجائزة (وإلا `null`).
  final double? unitPrice;

  const LedgerEntry({
    required this.redemption,
    required this.studentCode,
    required this.halaqaName,
    this.unitPrice,
  });

  bool get isDispensed => redemption.status == 'dispensed';

  /// التاريخ المعتمد: تاريخ التسليم إن تم، وإلا تاريخ الطلب.
  DateTime get date => redemption.dispensedAt ?? redemption.redeemedAt;

  int get points => redemption.pointsSpent;

  double get money => unitPrice ?? 0;
}

/// مجموع تجميعي (حسب الجائزة أو الحلقة أو الطالب أو اليوم).
class LedgerGroup {
  final String key;
  final String label;

  /// تفصيل إضافي يظهر تحت العنوان (كود الطالب مثلاً).
  final String? subtitle;

  int count = 0;
  int points = 0;
  double money = 0;
  bool hasPrice = false;

  LedgerGroup({required this.key, required this.label, this.subtitle});
}

/// السجل الكامل: يُبنى مرة واحدة من البيانات الخام ثم تقرأ منه الواجهة والتصدير.
///
/// الغاية منه أن يسلّم الصرافُ الإدارةَ كشفاً واحداً يجيب عن: أي جامع، أي فترة،
/// كم نقطة انسحبت، وما الذي يستحقه الصراف بالمال مقابل الجوائز التي سلّمها.
class CashierLedgerReport {
  /// مفتاح الجائزة المعتمد في التجميع والتسعير.
  ///
  /// يعتمد المعرّف عادة، ويسقط إلى العنوان في السجلات القديمة التي لا تحمل
  /// معرّف جائزة، كي لا ينفصل السعر المُدخل عن مجموعته.
  static String rewardKey(RewardRedemption r) =>
      r.rewardId.isEmpty ? r.rewardTitle : r.rewardId;

  static final DateFormat dateFmt = DateFormat('yyyy/MM/dd');
  static final DateFormat dateTimeFmt = DateFormat('yyyy/MM/dd • hh:mm a');
  static final NumberFormat _intFmt = NumberFormat('#,##0', 'en');
  static final NumberFormat _moneyFmt = NumberFormat('#,##0.##', 'en');

  final String mosqueLabel;
  final LedgerPeriod period;
  final String cashierLabel;
  final String currency;
  final DateTime generatedAt;

  /// كل العمليات ضمن النطاق (المسلّمة والمعلّقة) مرتبة من الأحدث للأقدم.
  final List<LedgerEntry> entries;

  final List<LedgerEntry> dispensed;
  final List<LedgerEntry> pending;

  final List<LedgerGroup> byReward;
  final List<LedgerGroup> byHalaqa;
  final List<LedgerGroup> byStudent;
  final List<LedgerGroup> byDay;

  const CashierLedgerReport._({
    required this.mosqueLabel,
    required this.period,
    required this.cashierLabel,
    required this.currency,
    required this.generatedAt,
    required this.entries,
    required this.dispensed,
    required this.pending,
    required this.byReward,
    required this.byHalaqa,
    required this.byStudent,
    required this.byDay,
  });

  factory CashierLedgerReport.build({
    required List<RewardRedemption> redemptions,
    required List<Reward> rewards,
    required List<Student> students,
    required List<Halaqa> halaqat,
    required String mosqueLabel,
    required LedgerPeriod period,
    required String cashierLabel,
    String? mosqueId,
    String? halaqaId,
    Map<String, double> unitPrices = const {},
    String currency = '',
    bool includePending = true,
  }) {
    final studentById = {for (final s in students) s.id: s};
    final halaqaById = {for (final h in halaqat) h.id: h};
    final rewardById = {for (final r in rewards) r.id: r};

    final entries = <LedgerEntry>[];
    for (final r in redemptions) {
      if (r.status == 'cancelled') continue;
      if (!includePending && r.status != 'dispensed') continue;
      if (mosqueId != null && mosqueId.isNotEmpty && r.mosqueId != mosqueId) {
        continue;
      }

      // الطلبات المعلّقة لجوائز أوقفتها الإدارة لا تُحمّل على الجامع
      if (r.status == 'pending') {
        final reward = rewardById[r.rewardId];
        if (reward != null && !reward.isActive) continue;
      }

      final student = studentById[r.studentId];
      final studentHalaqaId = student?.halaqaId;
      if (halaqaId != null &&
          halaqaId.isNotEmpty &&
          studentHalaqaId != halaqaId) {
        continue;
      }

      final date = r.dispensedAt ?? r.redeemedAt;
      if (!period.contains(date)) continue;

      entries.add(LedgerEntry(
        redemption: r,
        studentCode: student?.code ?? '—',
        halaqaName: (studentHalaqaId != null && studentHalaqaId.isNotEmpty)
            ? (halaqaById[studentHalaqaId]?.name ?? 'حلقة غير محددة')
            : 'حلقة غير محددة',
        unitPrice: unitPrices[rewardKey(r)],
      ));
    }

    entries.sort((a, b) => b.date.compareTo(a.date));

    final dispensed = entries.where((e) => e.isDispensed).toList();
    final pending = entries.where((e) => !e.isDispensed).toList();

    // المستحقات تُحسب على ما سُلّم فعلياً فقط
    List<LedgerGroup> group(
      String Function(LedgerEntry) keyOf,
      String Function(LedgerEntry) labelOf, {
      String? Function(LedgerEntry)? subtitleOf,
    }) {
      final map = <String, LedgerGroup>{};
      for (final e in dispensed) {
        final key = keyOf(e);
        final g = map.putIfAbsent(
          key,
          () => LedgerGroup(
            key: key,
            label: labelOf(e),
            subtitle: subtitleOf?.call(e),
          ),
        );
        g.count += 1;
        g.points += e.points;
        if (e.unitPrice != null) {
          g.money += e.unitPrice!;
          g.hasPrice = true;
        }
      }
      return map.values.toList()..sort((a, b) => b.points.compareTo(a.points));
    }

    final byReward = group(
      (e) => rewardKey(e.redemption),
      (e) => e.redemption.rewardTitle.isEmpty
          ? 'جائزة غير محددة'
          : e.redemption.rewardTitle,
    );

    final byHalaqa = group((e) => e.halaqaName, (e) => e.halaqaName);

    final byStudent = group(
      (e) => e.redemption.studentId,
      (e) => e.redemption.studentName,
      subtitleOf: (e) => e.studentCode,
    );

    final byDay = group(
      (e) => dateFmt.format(e.date),
      (e) => dateFmt.format(e.date),
    )..sort((a, b) => b.key.compareTo(a.key));

    return CashierLedgerReport._(
      mosqueLabel: mosqueLabel,
      period: period,
      cashierLabel: cashierLabel,
      currency: currency,
      generatedAt: DateTime.now(),
      entries: entries,
      dispensed: dispensed,
      pending: pending,
      byReward: byReward,
      byHalaqa: byHalaqa,
      byStudent: byStudent,
      byDay: byDay,
    );
  }

  int get dispensedCount => dispensed.length;
  int get pendingCount => pending.length;
  int get dispensedPoints => dispensed.fold<int>(0, (sum, e) => sum + e.points);
  int get pendingPoints => pending.fold<int>(0, (sum, e) => sum + e.points);

  /// عدد الطلاب المستفيدين (لا يُحتسب الطالب الواحد أكثر من مرة).
  int get beneficiaries =>
      dispensed.map((e) => e.redemption.studentId).toSet().length;

  /// إجمالي المبلغ المستحق للصراف حسب تسعيرة الجوائز المُدخلة.
  double get dispensedMoney =>
      dispensed.fold<double>(0, (sum, e) => sum + e.money);

  /// هل أُدخل سعر لجائزة واحدة على الأقل ضمن هذه الفترة؟
  bool get hasPricing => dispensed.any((e) => e.unitPrice != null);

  /// جوائز سُلّمت ولم يُدخل لها سعر بعد (تُظهرها الواجهة كتنبيه).
  List<LedgerGroup> get unpricedRewards =>
      byReward.where((g) => !g.hasPrice).toList();

  static String fmtInt(num value) => _intFmt.format(value);
  static String fmtMoney(num value) => _moneyFmt.format(value);

  String get _moneySuffix =>
      currency.trim().isEmpty ? '' : ' ${currency.trim()}';

  String moneyText(num value) => '${fmtMoney(value)}$_moneySuffix';

  // ===========================================================
  // كشف نصي جاهز للإرسال عبر أي تطبيق مراسلة
  // ===========================================================
  String toPlainText({bool includeDetails = true}) {
    final b = StringBuffer()
      ..writeln('📋 السجل الكامل لصرف الجوائز')
      ..writeln('──────────────')
      ..writeln('الجامع: $mosqueLabel')
      ..writeln('الفترة: ${period.label}')
      ..writeln('الصراف: $cashierLabel')
      ..writeln('تاريخ إصدار الكشف: ${dateTimeFmt.format(generatedAt)}')
      ..writeln('')
      ..writeln('▪️ الملخص')
      ..writeln('عدد الجوائز المسلّمة: ${fmtInt(dispensedCount)}')
      ..writeln('عدد الطلاب المستفيدين: ${fmtInt(beneficiaries)}')
      ..writeln('إجمالي النقاط المسحوبة: ${fmtInt(dispensedPoints)} نقطة');
    if (hasPricing) {
      b.writeln('المبلغ المستحق للصراف: ${moneyText(dispensedMoney)}');
    }
    if (pendingCount > 0) {
      b.writeln('قسائم قيد الانتظار: ${fmtInt(pendingCount)}'
          ' (${fmtInt(pendingPoints)} نقطة)');
    }

    b
      ..writeln('')
      ..writeln('▪️ التفصيل حسب الجائزة (أساس المحاسبة)');
    for (final g in byReward) {
      final money = g.hasPrice ? ' = ${moneyText(g.money)}' : '';
      b.writeln('• ${g.label}: ${fmtInt(g.count)} قطعة'
          ' — ${fmtInt(g.points)} نقطة$money');
    }
    if (byReward.isEmpty) {
      b.writeln('• لا توجد جوائز مسلّمة ضمن هذه الفترة.');
    }
    if (hasPricing) {
      b.writeln('الإجمالي بالمال: ${moneyText(dispensedMoney)}');
      final unpriced = unpricedRewards;
      if (unpriced.isNotEmpty) {
        b.writeln(
            '(جوائز بلا تسعيرة: ${unpriced.map((g) => g.label).join('، ')})');
      }
    }

    if (byHalaqa.isNotEmpty) {
      b
        ..writeln('')
        ..writeln('▪️ التفصيل حسب الحلقة');
      for (final g in byHalaqa) {
        b.writeln('• ${g.label}: ${fmtInt(g.count)} جائزة'
            ' — ${fmtInt(g.points)} نقطة');
      }
    }

    if (includeDetails && entries.isNotEmpty) {
      b
        ..writeln('')
        ..writeln('▪️ تفصيل العمليات (${fmtInt(entries.length)})');
      var i = 1;
      for (final e in entries) {
        final r = e.redemption;
        final status = e.isDispensed ? 'تم التسليم' : 'قيد الانتظار';
        b
          ..writeln('$i) ${dateTimeFmt.format(e.date)}')
          ..writeln('   الطالب: ${r.studentName} (${e.studentCode})'
              ' - ${e.halaqaName}')
          ..writeln('   الجائزة: ${r.rewardTitle}'
              ' — ${fmtInt(r.pointsSpent)} نقطة'
              '${e.isDispensed && e.unitPrice != null ? ' — ${moneyText(e.unitPrice!)}' : ''}')
          ..writeln('   الحالة: $status | القسيمة: ${r.redemptionCode}'
              '${r.cashierName != null ? ' | الصراف: ${r.cashierName}' : ''}');
        i++;
      }
    }

    b
      ..writeln('')
      ..writeln('──────────────')
      ..writeln('كشف صادر عن بوابة الصراف المعتمد عبر منصة محراب.');

    return b.toString();
  }

  // ===========================================================
  // ملف CSV يفتح مباشرة في Excel
  // ===========================================================
  String toCsv() {
    String cell(Object? value) {
      final text = (value ?? '').toString().replaceAll('"', '""');
      return '"$text"';
    }

    final moneyHeader =
        'المبلغ${currency.trim().isEmpty ? '' : ' (${currency.trim()})'}';

    final rows = <String>[
      // BOM يضمن ظهور العربية بشكل صحيح في Excel
      '﻿${[
        cell('م'),
        cell('التاريخ'),
        cell('الحالة'),
        cell('الطالب'),
        cell('كود الطالب'),
        cell('الحلقة'),
        cell('الجامع'),
        cell('الجائزة'),
        cell('النقاط'),
        cell(moneyHeader),
        cell('رمز القسيمة'),
        cell('الصراف'),
      ].join(',')}',
    ];

    var i = 1;
    for (final e in entries) {
      final r = e.redemption;
      rows.add([
        cell(i),
        cell(dateTimeFmt.format(e.date)),
        cell(e.isDispensed ? 'تم التسليم' : 'قيد الانتظار'),
        cell(r.studentName),
        cell(e.studentCode),
        cell(e.halaqaName),
        cell(r.mosqueName),
        cell(r.rewardTitle),
        cell(r.pointsSpent),
        cell(e.isDispensed && e.unitPrice != null
            ? fmtMoney(e.unitPrice!)
            : ''),
        cell(r.redemptionCode),
        cell(r.cashierName ?? ''),
      ].join(','));
      i++;
    }

    rows
      ..add('')
      ..add(cell('الملخص'))
      ..add([cell('الجامع'), cell(mosqueLabel)].join(','))
      ..add([cell('الفترة'), cell(period.label)].join(','))
      ..add([cell('الصراف'), cell(cashierLabel)].join(','))
      ..add([cell('جوائز مسلّمة'), cell(dispensedCount)].join(','))
      ..add([cell('طلاب مستفيدون'), cell(beneficiaries)].join(','))
      ..add([cell('إجمالي النقاط'), cell(dispensedPoints)].join(','));
    if (hasPricing) {
      rows.add(
          [cell('إجمالي المبلغ'), cell(fmtMoney(dispensedMoney))].join(','));
    }
    if (pendingCount > 0) {
      rows.add([
        cell('قيد الانتظار'),
        cell(pendingCount),
        cell(pendingPoints),
      ].join(','));
    }

    rows
      ..add('')
      ..add([
        cell('التفصيل حسب الجائزة'),
        cell('العدد'),
        cell('النقاط'),
        cell(moneyHeader),
      ].join(','));
    for (final g in byReward) {
      rows.add([
        cell(g.label),
        cell(g.count),
        cell(g.points),
        cell(g.hasPrice ? fmtMoney(g.money) : ''),
      ].join(','));
    }

    return rows.join('\r\n');
  }

  /// اسم ملف آمن للتصدير.
  String fileNamePrefix() {
    String safe(String value) =>
        value.replaceAll(RegExp(r'[\\/:*?"<>|\s]+'), '_');
    return 'سجل_الصرف_${safe(mosqueLabel)}_${safe(period.label)}';
  }
}
