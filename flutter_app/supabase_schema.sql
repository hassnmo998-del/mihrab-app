-- ================================================================
-- نظام إدارة المسجد وحلقات تحفيظ القرآن الكريم
-- الهيكلية الشاملة لقاعدة بيانات Supabase المتوافقة مع التطبيق 100%
-- ================================================================

-- 1. جدول المساجد
create table if not exists mosques (
  id text primary key,
  name text not null,
  city text default 'دمشق',
  address text,
  phone text,
  gender text default 'male',
  access_code text unique not null,
  -- رمز تسليم أحادي الاستخدام (WMV-) لإنشاء الفرع النسائي؛ ليس كود دخول
  women_access_code text,
  -- معرّف الفرع النسائي المنشأ من هذا المسجد
  women_branch_id text,
  -- للفرع النسائي: مسجد الرجال الذي أصدر رمز التسليم
  parent_mosque_id text,
  -- كود صراف مستقل غير مشتق من كود المسجد
  cashier_access_code text,
  latitude double precision default 33.5138,
  longitude double precision default 36.2765,
  donation_image_url text,
  donation_account_name text,
  donation_account_number text,
  donation_description text,
  is_donation_enabled boolean default true,
  is_active boolean default true,
  created_at timestamptz default now(),
  updated_at timestamptz default now()
);

-- 2. جدول المشايخ والمعلمات
create table if not exists sheikhs (
  id text primary key,
  mosque_id text not null references mosques(id) on delete cascade,
  full_name text not null,
  phone text,
  code text unique not null,
  profile_image_url text,
  default_attendance_points int default 5,
  is_active boolean default true,
  created_at timestamptz default now()
);

-- 3. جدول الحلقات القرآنية
create table if not exists halaqat (
  id text primary key,
  mosque_id text not null references mosques(id) on delete cascade,
  sheikh_id text references sheikhs(id) on delete set null,
  co_sheikh_ids jsonb default '[]'::jsonb,
  name text not null,
  description text,
  age_group_min int default 6,
  age_group_max int default 18,
  schedule text default 'السبت - الإثنين - الأربعاء (عصراً)',
  days_of_week jsonb default '[]'::jsonb,
  timing_type text,
  prayer_name text,
  prayer_relation text,
  custom_time text,
  is_active boolean default true,
  created_at timestamptz default now()
);

-- 4. جدول الطلاب
create table if not exists students (
  id text primary key,
  mosque_id text not null references mosques(id) on delete cascade,
  halaqa_id text references halaqat(id) on delete set null,
  sheikh_id text references sheikhs(id) on delete set null,
  full_name text not null,
  birth_date text,
  gender text default 'male',
  phone text,
  notes text,
  total_points int default 50,
  code text unique not null,
  profile_image_url text,
  is_active boolean default true,
  enrolled_at timestamptz default now(),
  created_at timestamptz default now(),
  updated_at timestamptz default now()
);

-- 5. جدول الفعاليات ومجالس العلم
create table if not exists community_events (
  id text primary key,
  mosque_id text not null references mosques(id) on delete cascade,
  sheikh_id text references sheikhs(id) on delete set null,
  title text not null,
  description text,
  event_type text default 'lesson',
  custom_type_name text,
  timing_type text default 'prayer_linked',
  prayer_name text,
  prayer_relation text default 'after',
  target_audience text default 'general',
  event_datetime timestamptz default now(),
  duration_minutes int default 60,
  organizer_type text default 'mosque_admin',
  organizer_name text,
  attendance_count int default 0,
  latitude double precision default 33.5138,
  longitude double precision default 36.2765,
  is_active boolean default true,
  is_recurring boolean default false,
  is_qa_enabled boolean default false,
  max_questions int default 10,
  audio_record_url text,
  video_record_url text,
  event_status text default 'upcoming',
  recurring_days text,
  created_at timestamptz default now(),
  updated_at timestamptz default now()
);

-- 6. سجلات التسميع القرآني
create table if not exists memorization_records (
  id text primary key,
  student_id text not null references students(id) on delete cascade,
  halaqa_id text references halaqat(id) on delete set null,
  sheikh_id text references sheikhs(id) on delete set null,
  course_id text,
  surah_name text not null,
  from_ayah int not null,
  to_ayah int not null,
  juz_number int not null default 1,
  session_type text default 'new_memorization',
  quality_rating text default 'excellent',
  points_earned int default 0,
  notes text,
  counts_towards_statistics boolean default true,
  recorded_at timestamptz default now()
);

-- 7. جدول الحضور والغياب
create table if not exists attendance (
  id text primary key,
  student_id text not null references students(id) on delete cascade,
  halaqa_id text references halaqat(id) on delete cascade,
  session_date text not null,
  status text not null default 'present',
  points_earned int default 0,
  notes text,
  recorded_at timestamptz default now()
);

-- 8. سجل النقاط العام
create table if not exists points_logs (
  id text primary key,
  student_id text not null references students(id) on delete cascade,
  points int not null default 0,
  reason text not null,
  category text default 'memorization',
  competition_id text,
  created_at timestamptz default now()
);

-- View للتوافق مع التسميات المفردة والجمع
-- security_invoker: يُقيَّم RLS بصلاحيات المستعلِم لا منشئ المنظر
create or replace view points_log with (security_invoker = true) as select * from points_logs;

-- 9. جدول الرسائل والتواصل
create table if not exists messages (
  id text primary key,
  student_id text not null references students(id) on delete cascade,
  halaqa_id text references halaqat(id) on delete cascade,
  sender_type text not null default 'parent',
  sender_name text not null,
  content text not null,
  message_type text default 'general',
  is_read boolean default false,
  created_at timestamptz default now()
);

-- 10. جدول المسابقات
create table if not exists competitions (
  id text primary key,
  mosque_id text references mosques(id) on delete cascade,
  title text not null,
  description text,
  start_date timestamptz default now(),
  end_date timestamptz default (now() + interval '30 days'),
  count_quran boolean default true,
  count_hadith boolean default true,
  count_attendance boolean default true,
  bonus_points int default 0,
  gender_branch text default 'male',
  is_active boolean default true,
  created_at timestamptz default now()
);

-- 11. جدول الدورات الاستثنائية المكثفة
create table if not exists intensive_courses (
  id text primary key,
  mosque_id text references mosques(id) on delete cascade,
  name text not null,
  description text,
  start_date timestamptz default now(),
  end_date timestamptz default (now() + interval '30 days'),
  sheikh_ids jsonb default '[]'::jsonb,
  halaqa_ids jsonb default '[]'::jsonb,
  student_ids jsonb default '[]'::jsonb,
  days_of_week jsonb default '[]'::jsonb,
  start_time text,
  end_time text,
  counts_towards_quran_progress boolean default true,
  created_at timestamptz default now()
);

-- 12. جدول الرحلات والأنشطة
create table if not exists trips (
  id text primary key,
  mosque_id text references mosques(id) on delete cascade,
  title text not null,
  destination text not null,
  trip_date timestamptz not null,
  meeting_time text,
  deadline_date timestamptz,
  description text,
  required_items jsonb default '[]'::jsonb,
  target_halaqa_ids jsonb default '[]'::jsonb,
  target_student_ids jsonb default '[]'::jsonb,
  cost_points int default 0,
  status text default 'active',
  created_at timestamptz default now()
);

-- 13. جدول الجوائز (متجر الجوائز)
create table if not exists rewards (
  id text primary key,
  mosque_id text references mosques(id) on delete cascade,
  title text not null,
  description text,
  points_cost int default 100,
  is_active boolean default true,
  created_at timestamptz default now()
);

-- 14. جدول طلبات استبدال الجوائز (الصراف)
create table if not exists reward_redemptions (
  id text primary key,
  student_id text not null references students(id) on delete cascade,
  student_name text,
  mosque_id text not null references mosques(id) on delete cascade,
  mosque_name text,
  reward_id text not null references rewards(id) on delete cascade,
  reward_title text,
  points_spent int default 0,
  redemption_code text,
  status text default 'pending',
  redeemed_at timestamptz default now(),
  dispensed_at timestamptz,
  cashier_name text
);

-- 15. مسارات التسميع المخصصة (أحاديث، متون، إلخ)
create table if not exists recitation_tracks (
  id text primary key,
  mosque_id text not null references mosques(id) on delete cascade,
  name text not null,
  category text default 'custom',
  unit_label text default 'حديث',
  total_units int default 40,
  points_per_unit int default 2,
  is_active boolean default true,
  is_default_quran boolean default false,
  target_halaqa_ids jsonb default '[]'::jsonb,
  sheikh_id text references sheikhs(id) on delete set null,
  created_at timestamptz default now()
);

-- 16. سجلات تسميع المواد المخصصة
create table if not exists subject_recitation_records (
  id text primary key,
  student_id text not null references students(id) on delete cascade,
  halaqa_id text references halaqat(id) on delete set null,
  sheikh_id text references sheikhs(id) on delete set null,
  track_id text not null references recitation_tracks(id) on delete cascade,
  track_name text,
  from_unit int default 1,
  to_unit int default 1,
  units_count int default 1,
  points_earned int default 0,
  course_id text,
  notes text,
  counts_towards_statistics boolean default true,
  recorded_at timestamptz default now()
);

-- ================================================================
-- فهارس البحث بالأكواد (تمنع التكرار وتسرّع الدخول بالمسح)
create unique index if not exists mosques_women_access_code_key
  on mosques (upper(women_access_code))
  where women_access_code is not null and women_access_code <> '';

create unique index if not exists mosques_cashier_access_code_key
  on mosques (upper(cashier_access_code))
  where cashier_access_code is not null and cashier_access_code <> '';

create index if not exists mosques_parent_mosque_id_idx
  on mosques (parent_mosque_id);

-- ================================================================
-- سياسات الأمان والحماية (Row Level Security - RLS)
-- ================================================================
alter table mosques enable row level security;
alter table sheikhs enable row level security;
alter table halaqat enable row level security;
alter table students enable row level security;
alter table community_events enable row level security;
alter table memorization_records enable row level security;
alter table attendance enable row level security;
alter table points_logs enable row level security;
alter table messages enable row level security;
alter table competitions enable row level security;
alter table intensive_courses enable row level security;
alter table trips enable row level security;
alter table rewards enable row level security;
alter table reward_redemptions enable row level security;
alter table recitation_tracks enable row level security;
alter table subject_recitation_records enable row level security;

-- السماح بالقراءة والكتابة الكاملة للمفتاح العمومي (Anon Key)
create policy "Allow all operations for anon" on mosques for all using (true) with check (true);
create policy "Allow all operations for anon" on sheikhs for all using (true) with check (true);
create policy "Allow all operations for anon" on halaqat for all using (true) with check (true);
create policy "Allow all operations for anon" on students for all using (true) with check (true);
create policy "Allow all operations for anon" on community_events for all using (true) with check (true);
create policy "Allow all operations for anon" on memorization_records for all using (true) with check (true);
create policy "Allow all operations for anon" on attendance for all using (true) with check (true);
create policy "Allow all operations for anon" on points_logs for all using (true) with check (true);
create policy "Allow all operations for anon" on messages for all using (true) with check (true);
create policy "Allow all operations for anon" on competitions for all using (true) with check (true);
create policy "Allow all operations for anon" on intensive_courses for all using (true) with check (true);
create policy "Allow all operations for anon" on trips for all using (true) with check (true);
create policy "Allow all operations for anon" on rewards for all using (true) with check (true);
create policy "Allow all operations for anon" on reward_redemptions for all using (true) with check (true);
create policy "Allow all operations for anon" on recitation_tracks for all using (true) with check (true);
create policy "Allow all operations for anon" on subject_recitation_records for all using (true) with check (true);

-- 17. جدول أسئلة الدروس العامة والمحاضرات (الأسئلة الحية المجهولة)
create table if not exists event_questions (
  id text primary key,
  event_id text not null references community_events(id) on delete cascade,
  content text not null,
  created_at timestamptz default now(),
  is_answered boolean default false
);

alter table community_events add column if not exists recurring_days text;

alter table event_questions enable row level security;
create policy "Allow all operations for anon" on event_questions for all using (true) with check (true);


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
