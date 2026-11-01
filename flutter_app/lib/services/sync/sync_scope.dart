import '../../models/models.dart';

/// المساجد التي يحتاجها هذا الجهاز من السحابة.
///
/// كل جهاز كان يجلب بيانات كل المساجد؛ على مستوى دولة هذا يعني أن هاتف طالب
/// يحمّل بيانات مئات الآلاف. هنا يُحدَّد النطاق من الجلسات المحفوظة على الجهاز:
/// - [dataMosqueIds]: مساجد تُجلب بياناتها كاملة (جلسة إدارة أو شيخ أو طالب أو صراف).
/// - [rowOnlyMosqueIds]: مساجد يكفي صفّ المسجد نفسه (الفرع النسائي أو الأب)، فلا تصل
///   بيانات القسم الآخر إلى الجهاز.
class SyncScope {
  /// أكبر عدد مساجد في نطاق واحد (حدّ دالة `sync_changes` في الخادم).
  static const int maxDataMosques = 100;

  /// المنصة «صغيرة» حتى هذا العدد من المساجد: يحمّل كل جهاز بياناتها كلها كما كان قبل
  /// المزامنة بالنطاق، فتبقى شاشات تقارن أو تسرد مساجد كثيرة (المنافسة، التبرع، اكتشف)
  /// كاملة. فوقه ينتقل كل جهاز إلى مساجده وحدها. **هذا الحدّ هو الفاصل**: قبل أن
  /// تتجاوزه المنصة يجب أن تكون هذه الشاشات قد انتقلت إلى ترتيب وبحث يحسبهما الخادم.
  static const int smallPlatformMosques = 40;

  /// عند الانتقال من «صغيرة» إلى «كبيرة» نشترط هذا العدد (لا الحدّ نفسه) كي لا يتذبذب
  /// الجهاز بين الوضعين حول الحدّ، فكل انتقال يمسح بيانات ويعيد جلب أخرى.
  static const int smallPlatformKeepMosques = 50;

  /// مساجد تُجلب بياناتها (الجداول كلها).
  final Set<String> dataMosqueIds;

  /// مساجد **هذا الجهاز** (جلساته): وحدها يصل صفّها كاملاً بأكوادها. بقية [dataMosqueIds]
  /// يصل صفّها بأعمدة البطاقة العامة بلا أي كود دخول.
  final Set<String> ownMosqueIds;

  /// مساجد يكفي صفّها (الفرع النسائي أو الأب) بأعمدة البطاقة العامة.
  final Set<String> rowOnlyMosqueIds;

  /// النطاق كل المنصة (المنصة صغيرة): لا حاجة لبحث الخادم، كل شيء في الجهاز.
  final bool wholePlatform;

  const SyncScope({
    this.dataMosqueIds = const {},
    Set<String>? ownMosqueIds,
    this.rowOnlyMosqueIds = const {},
    this.wholePlatform = false,
  }) : ownMosqueIds = ownMosqueIds ?? dataMosqueIds;

  bool get isEmpty => dataMosqueIds.isEmpty;

  /// كل المساجد التي يلزم صفّها (بياناتها كاملة أو صفّها فقط).
  Set<String> get allMosqueRowIds => {...dataMosqueIds, ...rowOnlyMosqueIds};

  /// مساجد يصل صفّها بأعمدة البطاقة (لا مساجد الجهاز نفسه).
  Set<String> get cardMosqueIds =>
      {...dataMosqueIds, ...rowOnlyMosqueIds}.difference(ownMosqueIds);

  /// مفتاح ثابت للنطاق: تغيّره (دخول مسجد جديد، خروج، اتساع أو ضيق) يفرض جلباً أساسياً.
  String get key {
    final data = dataMosqueIds.toList()..sort();
    if (ownMosqueIds.length == dataMosqueIds.length &&
        ownMosqueIds.containsAll(dataMosqueIds)) {
      return data.join(',');
    }
    final own = ownMosqueIds.toList()..sort();
    return '${data.join(',')}|${own.join(',')}';
  }

  bool contains(String? mosqueId) =>
      mosqueId != null && dataMosqueIds.contains(mosqueId);

  /// نطاق الجهاز بحسب حجم المنصة: كل المساجد إن كانت صغيرة، وإلا [own] كما هو.
  ///
  /// [platformIds] معرّفات المساجد (يكفي أن تضمّ [smallPlatformKeepMosques] + 1).
  /// [wasWholePlatform]: هل كان الجهاز على كل المنصة؟ فيبقى عليها حتى يتجاوز العدد
  /// [smallPlatformKeepMosques] (لا الحدّ نفسه)، كي لا يتذبذب بين الوضعين.
  static SyncScope forPlatform({
    required SyncScope own,
    required List<String> platformIds,
    required bool wasWholePlatform,
  }) {
    final limit = wasWholePlatform ? smallPlatformKeepMosques : smallPlatformMosques;
    // مساجد الجهاز تُضمّ ولو لم تظهر في القائمة (مسجد أُنشئ بلا إنترنت ولم يُرفع بعد)
    final all = {...platformIds, ...own.dataMosqueIds};
    if (platformIds.length > limit || all.length > maxDataMosques) return own;
    return SyncScope(
      dataMosqueIds: all,
      ownMosqueIds: own.dataMosqueIds,
      wholePlatform: true,
    );
  }

  /// يحسب النطاق من الجلسات المحفوظة، أو يعيد `null` إذا تعذّر الجزم.
  ///
  /// `null` يعني «ارجع إلى المزامنة الكاملة هذه المرة»: جلسة لا نعرف مسجدها، أو نطاق
  /// أكبر من الحدّ. الخطأ هنا لو حدث يعني حذف بيانات المستخدم من جهازه، فنفضّل
  /// دائماً الطريقة القديمة الثقيلة على تخمين نطاق ناقص.
  ///
  /// جلسات المشرف العام والزائر لا تحتاج بيانات مسجد (للمشرف العام دوال مجمَّعة).
  static SyncScope? fromSessions({
    required Iterable<ActiveSession> sessions,
    required Iterable<Student> students,
    required Iterable<Sheikh> sheikhs,
    required Iterable<Mosque> mosques,
  }) {
    final data = <String>{};

    for (final s in sessions) {
      if (s.role == 'super_admin' || s.role == 'visitor') continue;

      var mosqueId = (s.mosqueId ?? '').trim();
      if (mosqueId.isEmpty) {
        mosqueId = _resolveMosqueId(s, students, sheikhs) ?? '';
      }
      if (mosqueId.isEmpty) return null; // جلسة لا نعرف مسجدها: لا نخمّن
      data.add(mosqueId);
    }

    if (data.length > maxDataMosques) return null;

    final rowOnly = <String>{};
    for (final m in mosques) {
      if (!data.contains(m.id)) continue;
      for (final linked in [m.parentMosqueId, m.womenBranchId]) {
        if (linked != null && linked.isNotEmpty && !data.contains(linked)) {
          rowOnly.add(linked);
        }
      }
    }

    return SyncScope(dataMosqueIds: data, rowOnlyMosqueIds: rowOnly);
  }

  static String? _resolveMosqueId(
    ActiveSession s,
    Iterable<Student> students,
    Iterable<Sheikh> sheikhs,
  ) {
    if (s.role == 'student') {
      for (final st in students) {
        if ((s.studentId != null && st.id == s.studentId) || st.code == s.code) {
          return st.mosqueId;
        }
      }
    } else if (s.role == 'sheikh') {
      for (final sh in sheikhs) {
        if ((s.sheikhId != null && sh.id == s.sheikhId) || sh.code == s.code) {
          return sh.mosqueId;
        }
      }
    }
    return null;
  }
}
