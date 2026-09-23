-- ======================================================
-- مصادقة المشرف العام عبر Supabase Auth
-- ======================================================
-- يحل محل app_config_supabase.sql (الذي كان يخزّن كلمة السر نصاً صريحاً
-- ويسمح بقراءتها لأي حامل للمفتاح العام). هذا الملف مطبَّق فعلاً على
-- المشروع mltxsmonudbtnrloqawf.
--
-- كلمة السر لم تعد موجودة في قاعدة البيانات ولا في التطبيق إطلاقاً:
-- يخزّنها Supabase Auth كتجزئة مُملّحة (bcrypt) في auth.users.

-- 19. جدول صلاحية المشرف العام
-- صف واحد لكل مشرف عام. لا توجد سياسة كتابة إطلاقاً، فلا يمكن منح الصلاحية
-- عبر الـ API — فقط من SQL Editor أو لوحة Supabase.
create table if not exists public.super_admins (
  user_id uuid primary key references auth.users(id) on delete cascade,
  email text,
  created_at timestamptz default now()
);

alter table public.super_admins enable row level security;

-- القراءة للمستخدم المسجَّل دخوله وصفه هو فقط
drop policy if exists "Super admin reads own row" on public.super_admins;
create policy "Super admin reads own row" on public.super_admins
  for select to authenticated using (auth.uid() = user_id);

-- ------------------------------------------------------
-- منح الصلاحية بعد إنشاء الحساب من Authentication > Users
-- ------------------------------------------------------
insert into public.super_admins (user_id, email)
select id, email from auth.users where email = 'admin@masjed.app'
on conflict (user_id) do nothing;
