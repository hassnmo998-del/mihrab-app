import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:intl/intl.dart' show NumberFormat;

import '../../../core/theme/app_theme.dart';
import '../../../core/utils/arabic_time.dart';
import '../../../models/install_stats.dart';

/// «الأجهزة التي عليها التطبيق» في لوحة المشرف العام.
///
/// الرقم الكبير: أجهزة ظهرت خلال آخر 30 يوماً. تحته: ما فُتح عليه التطبيق اليوم وخلال
/// الأسبوع وما انضم هذا الأسبوع، ثم التوزيع على المنصات، ومنحنى الفتح اليومي، والإصدارات.
class InstallStatsCard extends StatefulWidget {
  final Future<InstallStats> Function() load;

  /// إعادة دخول المشرف العام حين انتهت جلسته في Supabase. يعيد true إن نجح.
  final Future<bool> Function()? onSignIn;

  /// ساعة «حُدّث الساعة ...» (الاختبارات تثبّتها).
  final DateTime Function() clock;

  const InstallStatsCard({super.key, required this.load, this.onSignIn, this.clock = DateTime.now});

  @override
  State<InstallStatsCard> createState() => InstallStatsCardState();
}

class InstallStatsCardState extends State<InstallStatsCard> {
  static final NumberFormat _fmt = NumberFormat('#,##0', 'en');

  InstallStats? _stats;
  InstallStatsError? _error;
  bool _loading = true;
  DateTime? _loadedAt;

  @override
  void initState() {
    super.initState();
    reload();
  }

  /// يجلب الأرقام من جديد. الأرقام السابقة تبقى ظاهرة أثناء الجلب.
  Future<void> reload() async {
    if (mounted) setState(() => _loading = true);
    try {
      final stats = await widget.load();
      if (!mounted) return;
      setState(() {
        _stats = stats;
        _error = null;
        _loadedAt = widget.clock();
      });
    } on InstallStatsException catch (e) {
      if (mounted) setState(() => _error = e.error);
    } catch (_) {
      if (mounted) setState(() => _error = InstallStatsError.unavailable);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _signIn() async {
    final ok = await widget.onSignIn?.call() ?? false;
    if (ok) await reload();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final stats = _stats;

    return Container(
      key: const ValueKey('installStatsCard'),
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.emeraldPrimary.withValues(alpha: 0.25), width: 1.5),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 8, offset: const Offset(0, 2))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _header(isDark),
          const SizedBox(height: 10),
          if (stats != null) ...[
            if (_error != null) _staleNote(isDark),
            _body(stats, isDark),
          ] else if (_error != null)
            _errorView(_error!, isDark)
          else
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 28),
              child: Center(child: CircularProgressIndicator(strokeWidth: 2.5)),
            ),
        ],
      ),
    );
  }

  Widget _header(bool isDark) {
    final loadedAt = _loadedAt;
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(color: AppColors.emeraldPrimary.withValues(alpha: 0.12), shape: BoxShape.circle),
          child: Icon(Icons.devices_rounded, size: 20, color: AppColors.emeraldPrimary),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('الأجهزة التي عليها التطبيق', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              if (loadedAt != null)
                Text('حُدّث ${ArabicTime.clock(loadedAt)}', style: TextStyle(fontSize: 11, color: _muted(isDark))),
            ],
          ),
        ),
        if (_loading && _stats != null)
          const Padding(
            padding: EdgeInsets.all(12),
            child: SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)),
          )
        else
          IconButton(
            key: const ValueKey('installStatsRefresh'),
            tooltip: 'تحديث الأرقام',
            icon: const Icon(Icons.refresh_rounded),
            onPressed: _loading ? null : reload,
          ),
      ],
    );
  }

  Widget _body(InstallStats s, bool isDark) {
    if (s.total == 0) {
      return _message(
        isDark,
        icon: Icons.hourglass_empty_rounded,
        text:
            'لم يُعدّ أي جهاز بعد. العدّ يبدأ حين يفتح الناس الإصدار الذي يحمله، '
            'ويصل كل جهاز يتحدّث تباعاً.',
      );
    }

    final days = _chartDays(s);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // الرقم الذي تقوم عليه اللوحة
        Text(
          _fmt.format(s.installed),
          key: const ValueKey('installStatsInstalled'),
          style: TextStyle(
            fontSize: 48,
            height: 1.1,
            fontWeight: FontWeight.w700,
            color: isDark ? Colors.white : AppColors.obsidianEspresso,
          ),
        ),
        Text('ظهر عليها التطبيق خلال آخر 30 يوماً', style: TextStyle(fontSize: 13, color: _muted(isDark))),
        const SizedBox(height: 14),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: _tile('فُتح عليها اليوم', s.openedToday, isDark)),
            const SizedBox(width: 8),
            Expanded(child: _tile('فُتح عليها خلال 7 أيام', s.opened7d, isDark)),
            const SizedBox(width: 8),
            Expanded(child: _tile('جديدة هذا الأسبوع', s.new7d, isDark)),
          ],
        ),
        if (s.byPlatform.isNotEmpty) ...[
          _sectionTitle('حسب المنصة', isDark),
          for (final p in s.byPlatform) _shareRow(InstallStats.platformLabel(p.key), p.count, s.installed, isDark),
        ],
        if (days.length >= 2) ...[
          _sectionTitle('أجهزة فُتح عليها التطبيق، يوماً بيوم', isDark),
          _DailyColumns(days: days, isDark: isDark),
        ],
        if (s.byVersion.isNotEmpty) ...[
          _sectionTitle('حسب الإصدار', isDark),
          for (final v in _versions(s.byVersion)) _shareRow(v.key, v.count, s.installed, isDark),
        ],
        const SizedBox(height: 12),
        _footnote(s, isDark),
      ],
    );
  }

  /// أيام المنحنى منذ بدأ العدّ: ما قبله أصفار لا تعني شيئاً.
  List<InstallDay> _chartDays(InstallStats s) {
    final since = s.countingSince;
    if (since == null) return s.daily;
    final first = DateTime(since.year, since.month, since.day).subtract(const Duration(days: 1));
    return s.daily.where((d) => d.day.isAfter(first)).toList();
  }

  /// حتى خمسة أسطر: إن زادت الإصدارات تبقى أكثر أربعة ويُجمع الباقي في «أخرى».
  List<InstallCount> _versions(List<InstallCount> all) {
    final named = [for (final v in all) InstallCount(v.key.isEmpty ? 'غير معروف' : 'v${v.key}', v.count)];
    if (named.length <= 5) return named;
    final rest = named.skip(4).fold<int>(0, (sum, v) => sum + v.count);
    return [...named.take(4), InstallCount('أخرى', rest)];
  }

  Widget _tile(String label, int value, bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.black.withValues(alpha: 0.035),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              _fmt.format(value),
              maxLines: 1,
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 11, height: 1.25, color: _muted(isDark)),
          ),
        ],
      ),
    );
  }

  Widget _sectionTitle(String text, bool isDark) => Padding(
    padding: const EdgeInsets.only(top: 18, bottom: 8),
    child: Text(
      text,
      style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: isDark ? Colors.white70 : Colors.black87),
    ),
  );

  /// اسم، عدد ونسبته، وشريط بلون واحد: الطول وحده يحمل المقدار.
  Widget _shareRow(String label, int count, int whole, bool isDark) {
    final share = whole <= 0 ? 0.0 : (count / whole).clamp(0.0, 1.0);
    final percent = (share * 100).round();
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  label,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                ),
              ),
              Text(
                '${_fmt.format(count)}  ·  $percent%',
                textDirection: TextDirection.ltr,
                style: TextStyle(
                  fontSize: 12,
                  color: _muted(isDark),
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: share,
              minHeight: 8,
              backgroundColor: AppColors.emeraldPrimary.withValues(alpha: isDark ? 0.18 : 0.12),
              valueColor: AlwaysStoppedAnimation(AppColors.emeraldPrimary),
            ),
          ),
        ],
      ),
    );
  }

  Widget _footnote(InstallStats s, bool isDark) {
    final since = s.countingSince;
    final lines = [
      if (since != null) 'بدأ العدّ في ${ArabicTime.date(since)}، والأجهزة التي لم تتحدّث بعد تُعدّ حين تتحدّث.',
      'الجهاز الذي حُذف منه التطبيق يخرج من العدد بعد 30 يوماً من آخر ظهور له. '
          'على أندرويد يُعدّ الجهاز ولو لم يُفتح التطبيق.',
      'كل الأجهزة منذ بدء العدّ: ${_fmt.format(s.total)}.',
    ];
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withValues(alpha: 0.03) : Colors.black.withValues(alpha: 0.03),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info_outline_rounded, size: 16, color: _muted(isDark)),
          const SizedBox(width: 6),
          Expanded(
            child: Text(lines.join('\n'), style: TextStyle(fontSize: 11, height: 1.5, color: _muted(isDark))),
          ),
        ],
      ),
    );
  }

  Widget _staleNote(bool isDark) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Text(
      _error == InstallStatsError.unavailable
          ? 'تعذّر التحديث الآن، هذه آخر أرقام وصلت.'
          : 'انتهت جلسة الدخول، هذه آخر أرقام وصلت.',
      style: TextStyle(fontSize: 11, color: Colors.orange.shade800),
    ),
  );

  Widget _errorView(InstallStatsError error, bool isDark) {
    return switch (error) {
      InstallStatsError.notSignedIn => _message(
        isDark,
        icon: Icons.lock_clock_outlined,
        text: 'انتهت جلسة دخول المشرف العام على هذا الجهاز. ادخل من جديد لعرض الأرقام.',
        action: widget.onSignIn == null
            ? null
            : FilledButton.icon(
                onPressed: _signIn,
                icon: const Icon(Icons.login_rounded, size: 18),
                label: const Text('الدخول من جديد'),
              ),
      ),
      InstallStatsError.notAuthorized => _message(
        isDark,
        icon: Icons.block_rounded,
        text: 'هذا الحساب لا يملك صلاحية عرض الأرقام.',
      ),
      InstallStatsError.unavailable => _message(
        isDark,
        icon: Icons.cloud_off_rounded,
        text: 'تعذّر الوصول إلى الخادم. تحقق من الإنترنت ثم أعد المحاولة.',
        action: OutlinedButton.icon(
          onPressed: _loading ? null : reload,
          icon: const Icon(Icons.refresh_rounded, size: 18),
          label: const Text('إعادة المحاولة'),
        ),
      ),
    };
  }

  Widget _message(bool isDark, {required IconData icon, required String text, Widget? action}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Column(
        children: [
          Icon(icon, size: 32, color: _muted(isDark)),
          const SizedBox(height: 8),
          Text(text, textAlign: TextAlign.center, style: const TextStyle(fontSize: 13, height: 1.5)),
          if (action != null) ...[const SizedBox(height: 10), action],
        ],
      ),
    );
  }

  static Color _muted(bool isDark) => isDark ? Colors.white60 : Colors.black54;
}

/// أعمدة الفتح اليومي: لون واحد، خط قاعدة رفيع، قيمة الذروة فوق عمودها، والتفاصيل
/// في تلميح كل عمود. الأقدم في بداية السطر واليوم في نهايته.
class _DailyColumns extends StatelessWidget {
  final List<InstallDay> days;
  final bool isDark;

  const _DailyColumns({required this.days, required this.isDark});

  static const double _chartHeight = 92;
  static const double _labelHeight = 16;

  @override
  Widget build(BuildContext context) {
    final fmt = NumberFormat('#,##0', 'en');
    final peak = days.map((d) => d.opened).fold<int>(0, math.max);
    final peakIndex = days.lastIndexWhere((d) => d.opened == peak);
    final muted = isDark ? Colors.white60 : Colors.black54;
    final first = days.first.day;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          height: _chartHeight + _labelHeight,
          child: LayoutBuilder(
            builder: (context, box) {
              final slot = box.maxWidth / days.length;
              final barWidth = math.max(2.0, math.min(24.0, slot - 2));
              return Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  for (var i = 0; i < days.length; i++)
                    SizedBox(
                      width: slot,
                      child: Tooltip(
                        message:
                            '${ArabicTime.weekday(days[i].day)} ${ArabicTime.date(days[i].day)}\n'
                            'فُتح عليها التطبيق: ${fmt.format(days[i].opened)}  ·  ظهرت: ${fmt.format(days[i].seen)}',
                        triggerMode: TooltipTriggerMode.tap,
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            if (i == peakIndex && peak > 0)
                              SizedBox(
                                height: _labelHeight,
                                child: OverflowBox(
                                  maxWidth: 60,
                                  child: Text(
                                    fmt.format(peak),
                                    key: const ValueKey('installStatsPeak'),
                                    textDirection: TextDirection.ltr,
                                    style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: muted),
                                  ),
                                ),
                              ),
                            Container(
                              width: barWidth,
                              height: peak == 0 ? 0 : _chartHeight * days[i].opened / peak,
                              decoration: BoxDecoration(
                                color: AppColors.emeraldPrimary,
                                borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              );
            },
          ),
        ),
        // خط القاعدة: شعرة واحدة خافتة
        Container(height: 1, color: isDark ? Colors.white24 : Colors.black12),
        const SizedBox(height: 4),
        Row(
          children: [
            Text(ArabicTime.date(first), style: TextStyle(fontSize: 10, color: muted)),
            const Spacer(),
            Text('اليوم', style: TextStyle(fontSize: 10, color: muted)),
          ],
        ),
      ],
    );
  }
}
