-- ================================================================
-- عزل القسم النسائي — ترقية قاعدة البيانات
-- ================================================================
-- طُبِّقت على مشروع mltxsmonudbtnrloqawf بتاريخ 2026-09-23 باسم
-- `women_branch_isolation`. الملف مطابق لما طُبّق حرفياً، وآمن لإعادة
-- التشغيل على مشروع جديد (كل الأوامر idempotent).
-- ================================================================


-- ----------------------------------------------------------------
-- 0) إصلاح انحراف البنية: أعمدة التبرع
-- ----------------------------------------------------------------
-- معرَّفة في supabase_schema.sql ويرسلها التطبيق في كل حفظ لمسجد، لكنها لم
-- تُطبَّق على الجدول الحي (create table if not exists لا يضيف أعمدة لجدول
-- موجود)، فكان كل حفظ لمسجد يُرفض، ويحجز طابور المزامنة خلفه حتى 15 محاولة.
alter table mosques add column if not exists donation_image_url text;
alter table mosques add column if not exists donation_account_name text;
alter table mosques add column if not exists donation_account_number text;
alter table mosques add column if not exists donation_description text;
alter table mosques add column if not exists is_donation_enabled boolean default true;


-- ----------------------------------------------------------------
-- 1) أعمدة الفرع النسائي
-- ----------------------------------------------------------------
alter table mosques add column if not exists women_branch_id text;
alter table mosques add column if not exists parent_mosque_id text;
alter table mosques add column if not exists cashier_access_code text;

comment on column mosques.women_access_code is
  'Single-use handover token (WMV-) issued by the men''s administration to create the women''s branch. Not a login credential; cleared once redeemed.';
comment on column mosques.women_branch_id is
  'Id of the women''s branch provisioned from this mosque, if any.';
comment on column mosques.parent_mosque_id is
  'For a women''s branch: the men''s mosque that issued the handover token.';
comment on column mosques.cashier_access_code is
  'Independent cashier code. Legacy codes were derived from the mosque code (CSH-<same suffix>), so either one revealed the other.';


-- ----------------------------------------------------------------
-- 2) إبطال الرموز النسائية القديمة القابلة للاستنتاج
-- ----------------------------------------------------------------
-- WM-<لاحقة كود المسجد>: من يعرف MSQ-1234 يعرف WM-1234 والعكس.
-- التطبيق يرفض هذه الصيغة أصلاً، وهذا يمسحها من المصدر (أُبطل صف واحد).
update mosques
   set women_access_code = null
 where women_access_code like 'WM-%';


-- ----------------------------------------------------------------
-- 3) فهارس البحث بالأكواد (وتمنع تكرار كود بين مسجدين)
-- ----------------------------------------------------------------
create unique index if not exists mosques_access_code_upper_key
  on mosques (upper(access_code))
  where access_code is not null and access_code <> '';

create unique index if not exists mosques_women_access_code_key
  on mosques (upper(women_access_code))
  where women_access_code is not null and women_access_code <> '';

create unique index if not exists mosques_cashier_access_code_key
  on mosques (upper(cashier_access_code))
  where cashier_access_code is not null and cashier_access_code <> '';

create index if not exists mosques_parent_mosque_id_idx
  on mosques (parent_mosque_id);


-- ================================================================
-- لم يُطبَّق عمداً: إخفاء الأكواد عن المزامنة (منظر + دالة بحث)
-- ================================================================
-- المسودة السابقة (mosques_public + resolve_mosque_code) سُحبت قبل التطبيق
-- لعيبين في تصميمها:
--
--   1. الدالة كانت تُرجع صف المسجد كاملاً عند أي مطابقة، فحامل رمز تسليم
--      القسم النسائي أو كود الصراف كان سيستلم كود إدارة الرجال نفسه.
--   2. المزامنة عبر منظر بلا عمود women_access_code تُسقط رمز التسليم المعلّق
--      من جهاز المدير، فيصدر رمزاً جديداً يُبطل الرمز الذي تحمله المديرة.
--
-- الحل الصحيح جزء من البند العاشر (عزل حقيقي على السيرفر) ويتطلب هوية لكل
-- جهاز عبر Supabase Auth، لأن مفتاح anon الواحد لا يميّز بين حامليه.
