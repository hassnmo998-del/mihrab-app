-- ======================================================
-- جدول أكواد تسجيل المساجد المشترك بين أجهزة المشرف العام
-- شغّل هذا الملف في Supabase Dashboard > SQL Editor
-- ======================================================

-- 18. جدول أكواد تسجيل المساجد (يولّدها المشرف العام)
-- مشترك سحابياً: أي جهاز مسجَّل كمشرف عام يرى نفس الأكواد ونفس سجل التسجيل
create table if not exists registration_tokens (
  id text primary key,              -- الكود نفسه مثل REG-1234567-3
  is_used boolean default false,    -- false = كود نشط، true = تم استخدامه ويظهر في السجل
  mosque_name text,
  mosque_address text,
  mosque_access_code text,
  used_at timestamptz,
  created_at timestamptz default now()
);

alter table registration_tokens enable row level security;
create policy "Allow all operations for anon" on registration_tokens for all using (true) with check (true);

-- تفعيل البث اللحظي (Realtime) ليظهر الكود على بقية الأجهزة فوراً
do $$
begin
  alter publication supabase_realtime add table registration_tokens;
exception
  when duplicate_object then null;
  when undefined_object then null;
end $$;
