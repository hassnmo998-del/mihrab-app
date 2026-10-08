/// أوقات التطبيق (موعد الدرس، تاريخ الرحلة، لحظة حركة النقاط...) تُكتب وقتاً محلياً بلا
/// منطقة زمنية: `2026-10-07T18:00:00.000`.
///
/// عمود Supabase من نوع `timestamptz` والخادم على UTC، فيحفظها «18:00 UTC» ويعيدها
/// `2026-10-07T18:00:00+00:00`. `DateTime.parse` يقرأ ذلك لحظةً بتوقيت غرينتش، أي التاسعة
/// مساءً في سوريا: الرقم المعروض يبقى 6:00 لكن كل مقارنة بالساعة (انتهى الدرس؟ أُغلقت
/// الأسئلة؟ في أي شهر هذه النقاط؟) تتأخر ثلاث ساعات على كل جهاز وصله السجل من السحابة.
///
/// [parseWallClock] يقرأ القيمة كما قصدها كاتبها: الساعة المكتوبة نفسها بالتوقيت المحلي.
/// لا تغيّر صيغة الكتابة إلى UTC: النسخ الأقدم من التطبيق تعرض الحقول كما هي، فتعرض موعداً
/// مختلفاً لكل درس يُكتب بالصيغة الجديدة.
library;

/// يقرأ وقتاً مخزّناً على أنه الساعة المكتوبة نفسها بالتوقيت المحلي. قيمة فارغة أو غير
/// مقروءة تعيد [fallback] (أو الآن).
DateTime parseWallClock(Object? raw, {DateTime? fallback}) =>
    tryParseWallClock(raw) ?? fallback ?? DateTime.now();

/// مثل [parseWallClock] لكن يعيد `null` لقيمة فارغة أو غير مقروءة.
DateTime? tryParseWallClock(Object? raw) {
  if (raw == null) return null;
  final text = raw.toString().trim();
  if (text.isEmpty) return null;
  final parsed = DateTime.tryParse(text);
  if (parsed == null) return null;
  return parsed.isUtc ? asLocalWallClock(parsed) : parsed;
}

/// الحقول نفسها (السنة... الميكروثانية) كوقت محلي.
DateTime asLocalWallClock(DateTime t) => t.isUtc
    ? DateTime(t.year, t.month, t.day, t.hour, t.minute, t.second, t.millisecond, t.microsecond)
    : t;

/// صيغة الكتابة: الساعة المحلية بلا منطقة زمنية، كما كتبتها كل نسخ التطبيق.
String wallClockJson(DateTime t) => asLocalWallClock(t).toIso8601String();
