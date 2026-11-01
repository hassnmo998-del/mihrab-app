import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_theme.dart';
import '../../data/datasources/ministry_remote.dart';
import '../../services/data_service.dart';
import 'ministry_mosque_card.dart';
import 'ministry_overview_card.dart';

/// قسم المساجد في لوحة المشرف العام.
///
/// يعمل على مستوى الدولة: الأرقام والقائمة يحسبهما الخادم بصفحات وبحث وتصفية بالمدينة،
/// فلا يحمّل الجهاز بيانات المنصة كلها. إن لم تكن ترقية الخادم مطبَّقة (`scale_sync.sql`)
/// يعرض القائمة القديمة المبنية من النسخة المحلية كما كانت.
class MinistryMosquesSection extends StatefulWidget {
  /// سجل أكواد التسجيل المستعملة (لإظهار تاريخ التسجيل والكود على بطاقة الجامع).
  final List<Map<String, dynamic>> history;

  /// يُشعَر عند السحب للتحديث في الشاشة الأم.
  final Listenable? refresh;

  /// للاختبار.
  final MinistryRemote? remote;

  const MinistryMosquesSection({
    super.key,
    required this.history,
    this.refresh,
    this.remote,
  });

  @override
  State<MinistryMosquesSection> createState() => _MinistryMosquesSectionState();
}

enum _Mode { loading, server, legacy, unauthorized, failed }

class _MinistryMosquesSectionState extends State<MinistryMosquesSection> {
  static const int _pageSize = 40;

  late final MinistryRemote _remote;
  final TextEditingController _search = TextEditingController();
  Timer? _debounce;

  _Mode _mode = _Mode.loading;
  MinistryOverview? _overview;
  List<MinistryMosqueRow> _rows = [];
  int _total = 0;
  String? _city;
  bool _loadingMore = false;

  /// رقم الطلب الأحدث: ردّ متأخر لطلب قديم (بحث سبقه آخر) لا يكتب فوق الأحدث.
  int _generation = 0;

  @override
  void initState() {
    super.initState();
    _remote = widget.remote ??
        MinistryRemote(context.read<DataService>().remoteDataSource);
    widget.refresh?.addListener(_reload);
    _reload();
  }

  @override
  void dispose() {
    widget.refresh?.removeListener(_reload);
    _debounce?.cancel();
    _search.dispose();
    super.dispose();
  }

  Future<void> _reload() async {
    final gen = ++_generation;
    if (_rows.isEmpty) setState(() => _mode = _Mode.loading);

    final results = await Future.wait([
      _remote.overview(),
      _remote.mosques(search: _search.text, city: _city, limit: _pageSize),
    ]);
    if (!mounted || gen != _generation) return;

    final ov = results[0] as MinistryResult<MinistryOverview>;
    final page = results[1] as MinistryResult<MinistryPage>;

    if (ov.status == MinistryStatus.unsupported || page.status == MinistryStatus.unsupported) {
      setState(() => _mode = _Mode.legacy);
      return;
    }
    if (ov.status == MinistryStatus.unauthorized || page.status == MinistryStatus.unauthorized) {
      setState(() => _mode = _Mode.unauthorized);
      return;
    }
    if (!ov.ok || !page.ok) {
      setState(() => _mode = _Mode.failed);
      return;
    }
    setState(() {
      _overview = ov.data;
      _rows = List.of(page.data!.rows);
      _total = page.data!.total;
      _mode = _Mode.server;
    });
  }

  /// بحث أو تصفية جديدة: الصفحة الأولى من جديد (الملخص لا يتغير بالبحث).
  Future<void> _requery() async {
    final gen = ++_generation;
    final page = await _remote.mosques(search: _search.text, city: _city, limit: _pageSize);
    if (!mounted || gen != _generation) return;
    if (!page.ok) {
      setState(() => _mode = page.status == MinistryStatus.unauthorized
          ? _Mode.unauthorized
          : _Mode.failed);
      return;
    }
    setState(() {
      _rows = List.of(page.data!.rows);
      _total = page.data!.total;
      _mode = _Mode.server;
    });
  }

  Future<void> _loadMore() async {
    if (_loadingMore || _rows.length >= _total) return;
    setState(() => _loadingMore = true);
    final gen = _generation;
    final page = await _remote.mosques(
      search: _search.text,
      city: _city,
      limit: _pageSize,
      offset: _rows.length,
    );
    if (!mounted || gen != _generation) return;
    setState(() {
      _loadingMore = false;
      if (page.ok) {
        final known = {for (final r in _rows) r.id};
        _rows.addAll(page.data!.rows.where((r) => !known.contains(r.id)));
        _total = page.data!.total;
      }
    });
  }

  void _onSearchChanged(String _) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), () {
      if (_mode == _Mode.legacy) {
        setState(() {});
      } else {
        _requery();
      }
    });
  }

  void _setCity(String? city) {
    setState(() => _city = city);
    if (_mode != _Mode.legacy) _requery();
  }

  ({String? date, String token}) _regInfo(MinistryMosqueRow r) {
    for (final h in widget.history) {
      final code = (h['mosqueAccessCode'] ?? '').toString().trim().toUpperCase();
      final name = (h['mosqueName'] ?? '').toString().trim();
      final mine = (r.accessCode ?? '').trim().toUpperCase();
      if ((code.isNotEmpty && code == mine) || (name.isNotEmpty && name == r.name.trim())) {
        final raw = (h['timestamp'] ?? '').toString().trim();
        final date = raw.isEmpty ? null : (raw.contains('T') ? raw.split('T')[0] : raw);
        return (date: date, token: (h['token'] ?? '').toString().trim());
      }
    }
    return (date: null, token: '');
  }

  Widget _card(MinistryMosqueRow r, {VoidCallback? onDeleted}) {
    final reg = _regInfo(r);
    return MinistryMosqueCard(
      key: ValueKey(r.id),
      row: r,
      regDate: reg.date,
      usedToken: reg.token,
      onDeleted: onDeleted,
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return switch (_mode) {
      _Mode.loading => const Padding(
          padding: EdgeInsets.symmetric(vertical: 40),
          child: Center(child: CircularProgressIndicator()),
        ),
      _Mode.unauthorized => _message(
          Icons.lock_outline,
          'هذا الحساب غير مسجَّل كمشرف عام على الخادم، فلا تُعرض أرقام المنصة.',
          isDark,
        ),
      // تعذّر الخادم (لا إنترنت مثلاً): تبقى النسخة المحلية ظاهرة كما كانت قبل هذه
      // اللوحة، مع شريط يعيد المحاولة، بدل أن تختفي القائمة كلها.
      _Mode.failed => _legacy(context, isDark, offline: true),
      _Mode.legacy => _legacy(context, isDark),
      _Mode.server => _server(context, isDark),
    };
  }

  Widget _message(IconData icon, String text, bool isDark, {bool retry = false}) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withValues(alpha: 0.03) : Colors.grey[100],
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          Icon(icon, size: 32, color: Colors.grey),
          const SizedBox(height: 8),
          Text(text, textAlign: TextAlign.center),
          if (retry) ...[
            const SizedBox(height: 8),
            TextButton.icon(
              onPressed: _reload,
              icon: const Icon(Icons.refresh),
              label: const Text('إعادة المحاولة'),
            ),
          ],
        ],
      ),
    );
  }

  Widget _searchField(bool isDark) {
    return TextField(
      controller: _search,
      onChanged: _onSearchChanged,
      textInputAction: TextInputAction.search,
      decoration: InputDecoration(
        hintText: 'ابحث باسم الجامع أو المدينة أو العنوان',
        prefixIcon: const Icon(Icons.search),
        suffixIcon: _search.text.isEmpty
            ? null
            : IconButton(
                icon: const Icon(Icons.clear),
                onPressed: () {
                  _search.clear();
                  _onSearchChanged('');
                },
              ),
        filled: true,
        fillColor: isDark ? Colors.white10 : Colors.grey[100],
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
        contentPadding: const EdgeInsets.symmetric(vertical: 12),
      ),
    );
  }

  Widget _server(BuildContext context, bool isDark) {
    final remaining = _total - _rows.length;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (_overview != null)
          MinistryOverviewCard(overview: _overview!, selectedCity: _city, onCity: _setCity),
        const SizedBox(height: 20),
        Row(
          children: [
            Icon(Icons.mosque_rounded, color: AppColors.emeraldPrimary),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'المساجد المسجلة في المنصة ($_total)',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
            ),
            if (_city != null)
              ActionChip(
                label: Text('المدينة: $_city ✕', style: const TextStyle(fontSize: 11)),
                onPressed: () => _setCity(null),
              ),
          ],
        ),
        const SizedBox(height: 12),
        _searchField(isDark),
        const SizedBox(height: 12),
        if (_rows.isEmpty)
          _message(Icons.search_off, 'لا توجد مساجد مطابقة.', isDark)
        else
          for (final r in _rows) ...[
            _card(r, onDeleted: () {
              setState(() {
                _rows.removeWhere((x) => x.id == r.id);
                _total = (_total - 1).clamp(0, 1 << 31);
              });
              _reload();
            }),
            const SizedBox(height: 14),
          ],
        if (remaining > 0)
          Center(
            child: OutlinedButton.icon(
              onPressed: _loadingMore ? null : _loadMore,
              icon: _loadingMore
                  ? const SizedBox(
                      width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.expand_more),
              label: Text('تحميل المزيد ($remaining متبقٍ)'),
            ),
          ),
      ],
    );
  }

  // ---------- الوضع القديم: لا ترقية في الخادم، القائمة من النسخة المحلية ----------

  Widget _legacy(BuildContext context, bool isDark, {bool offline = false}) {
    final data = context.read<DataService>();
    return AnimatedBuilder(
      animation: data,
      builder: (context, _) {
        final q = _search.text.trim().toLowerCase();
        final all = data.getMosques();
        final mosques = all.where((m) {
          if (q.isNotEmpty &&
              !(m.name.toLowerCase().contains(q) ||
                  m.city.toLowerCase().contains(q) ||
                  (m.address ?? '').toLowerCase().contains(q))) {
            return false;
          }
          return _city == null || m.city == _city;
        }).toList();

        final rows = [
          for (final m in mosques)
            MinistryMosqueRow(
              id: m.id,
              name: m.name,
              city: m.city,
              address: m.address,
              gender: m.gender,
              parentMosqueId: m.parentMosqueId,
              accessCode: m.isWomenSection ? null : m.accessCode,
              halaqatCount: data.getHalaqat(mosqueId: m.id).length,
              sheikhsCount: data.getSheikhs(mosqueId: m.id).length,
              studentsCount: data.getStudents(mosqueId: m.id).length,
            ),
        ];

        final orphans = widget.history.where((h) {
          final hCode = (h['mosqueAccessCode'] ?? '').toString().trim().toUpperCase();
          final hName = (h['mosqueName'] ?? '').toString().trim();
          return !all.any((m) =>
              (hCode.isNotEmpty && m.accessCode.trim().toUpperCase() == hCode) ||
              (hName.isNotEmpty && m.name.trim() == hName));
        }).toList();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (offline) ...[
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.orange.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.cloud_off_outlined, size: 18, color: Colors.orange),
                    const SizedBox(width: 8),
                    const Expanded(
                      child: Text(
                        'تعذّر جلب أرقام المنصة من الخادم الآن؛ تُعرض النسخة المحفوظة على هذا الجهاز.',
                        style: TextStyle(fontSize: 12),
                      ),
                    ),
                    TextButton(onPressed: _reload, child: const Text('أعد المحاولة')),
                  ],
                ),
              ),
              const SizedBox(height: 12),
            ],
            Row(
              children: [
                Icon(Icons.mosque_rounded, color: AppColors.emeraldPrimary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'المساجد المسجلة في المنصة (${all.length})',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _searchField(isDark),
            const SizedBox(height: 12),
            if (rows.isEmpty)
              _message(Icons.search_off, 'لا توجد مساجد مسجلة في المنصة حالياً', isDark)
            else
              for (final r in rows) ...[
                _card(r),
                const SizedBox(height: 14),
              ],
            if (orphans.isNotEmpty) ...[
              const SizedBox(height: 22),
              Text(
                'سجلات تسجيل سابقة أخرى (${orphans.length})',
                style: const TextStyle(
                    fontWeight: FontWeight.bold, fontSize: 14, color: Colors.grey),
              ),
              const SizedBox(height: 10),
              for (final h in orphans.reversed) ...[
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: isDark ? Colors.white.withValues(alpha: 0.03) : Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.grey.withValues(alpha: 0.2)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text((h['mosqueName'] ?? 'مسجد سابق').toString(),
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                      if ((h['token'] ?? '').toString().isNotEmpty)
                        Text('الكود المستخدم: ${h['token']}',
                            style: const TextStyle(fontSize: 11, color: Colors.grey)),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
              ],
            ],
          ],
        );
      },
    );
  }
}
