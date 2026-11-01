-- ======================================================
-- التوسّع إلى مستوى الدولة: مزامنة بالنطاق والتزايد + أرقام الإشراف العام
-- ======================================================
-- لماذا؟ كل جهاز كان يجلب الجداول كلها لكل المساجد كل 15 ثانية، وهذا يتضاعف
-- بعدد الأجهزة وبحجم البيانات معاً (340 ألف طلب في اليوم لمسجدين فقط).
-- بعد هذا الملف يطلب الجهاز ما يخص مساجده وحدها، وما تغيّر منذ آخر مزامنة وحدها،
-- وبطلب واحد صغير حين لا يتغير شيء.
--
-- إضافي بالكامل: لا عمود يُحذف، لا سياسة (RLS) تتغيّر، ولا مفتاح يُمَسّ. نسخ التطبيق
-- القديمة تكمل عملها كما هي (تجلب الجداول كاملة)، والجديدة تستعمل الدوال أدناه
-- وترجع تلقائياً إلى الطريقة القديمة إن لم تكن هذه الترقية مطبَّقة.
--
-- ملاحظة تشغيل: ADD COLUMN بقيمة افتراضية متغيّرة يعيد كتابة الجدول. الجداول
-- صغيرة اليوم فيمرّ في جزء من الثانية؛ لو أُجّلت هذه الترقية حتى تكبر البيانات
-- فسيحتاج كل جدول قفلاً أطول. طبّقها قبل التعميم لا بعده.

-- ------------------------------------------------------
-- 1. mosque_id للجداول التي تفتقده (كان الوصول إليه عبر الطالب أو الحلقة أو الدرس)
-- ------------------------------------------------------
alter table public.attendance                 add column if not exists mosque_id text;
alter table public.memorization_records       add column if not exists mosque_id text;
alter table public.messages                   add column if not exists mosque_id text;
alter table public.points_logs                add column if not exists mosque_id text;
alter table public.subject_recitation_records add column if not exists mosque_id text;
alter table public.event_questions            add column if not exists mosque_id text;

update public.attendance t set mosque_id = s.mosque_id
  from public.students s where s.id = t.student_id and t.mosque_id is null;
update public.memorization_records t set mosque_id = s.mosque_id
  from public.students s where s.id = t.student_id and t.mosque_id is null;
update public.points_logs t set mosque_id = s.mosque_id
  from public.students s where s.id = t.student_id and t.mosque_id is null;
update public.subject_recitation_records t set mosque_id = s.mosque_id
  from public.students s where s.id = t.student_id and t.mosque_id is null;
update public.messages t set mosque_id = coalesce(
    (select s.mosque_id from public.students s where s.id = t.student_id),
    (select h.mosque_id from public.halaqat h where h.id = t.halaqa_id))
  where t.mosque_id is null;
update public.event_questions t set mosque_id = e.mosque_id
  from public.community_events e where e.id = t.event_id and t.mosque_id is null;

-- النسخ القديمة لا ترسل mosque_id: يُشتقّ هنا عند الإدراج فلا يبقى صف بلا مسجد.
create or replace function public.sync_fill_mosque_id() returns trigger
language plpgsql set search_path = public as $$
begin
  if new.mosque_id is null then
    if tg_table_name = 'event_questions' then
      select e.mosque_id into new.mosque_id
        from public.community_events e where e.id = new.event_id;
    else
      if new.student_id is not null then
        select s.mosque_id into new.mosque_id
          from public.students s where s.id = new.student_id;
      end if;
      -- متداخلة عمداً: plpgsql لا يقطع `and` مبكراً، فالإشارة إلى halaqa_id في جدول
      -- بلا هذا العمود (points_logs) كانت ستفشل الإدراج.
      if new.mosque_id is null then
        if tg_table_name = 'messages' then
          select h.mosque_id into new.mosque_id
            from public.halaqat h where h.id = new.halaqa_id;
        end if;
      end if;
    end if;
  end if;
  return new;
end $$;

do $$
declare t text;
begin
  foreach t in array array['attendance','memorization_records','messages',
                           'points_logs','subject_recitation_records','event_questions'] loop
    execute format('drop trigger if exists sync_fill_mosque_id on public.%I', t);
    execute format('create trigger sync_fill_mosque_id before insert on public.%I
                    for each row execute function public.sync_fill_mosque_id()', t);
  end loop;
end $$;

-- ------------------------------------------------------
-- 2. updated_at بتوقيت الخادم على كل جدول يُزامَن (ساعة الجهاز لا يُعتمد عليها)
-- ------------------------------------------------------
create or replace function public.sync_touch() returns trigger
language plpgsql as $$
begin
  new.updated_at := clock_timestamp();
  return new;
end $$;

do $$
declare t text;
begin
  foreach t in array array['mosques','sheikhs','halaqat','students','community_events',
      'memorization_records','attendance','messages','competitions','intensive_courses',
      'trips','rewards','reward_redemptions','recitation_tracks',
      'subject_recitation_records','points_logs','event_questions'] loop
    execute format('alter table public.%I add column if not exists updated_at
                    timestamptz not null default clock_timestamp()', t);
    execute format('drop trigger if exists sync_touch on public.%I', t);
    execute format('create trigger sync_touch before insert or update on public.%I
                    for each row execute function public.sync_touch()', t);
  end loop;
end $$;

-- ------------------------------------------------------
-- 3. شواهد الحذف: الاستعلام بـ updated_at لا يرى ما حُذف، والحذف المتسلسل
--    (مسجد ← طلابه ← سجلاتهم) يمرّ من هنا أيضاً.
-- ------------------------------------------------------
create table if not exists public.sync_tombstones (
  id         bigint generated always as identity primary key,
  table_name text not null,
  row_id     text not null,
  mosque_id  text,
  deleted_at timestamptz not null default clock_timestamp()
);
create index if not exists sync_tombstones_scope_idx
  on public.sync_tombstones (mosque_id, deleted_at);
create index if not exists sync_tombstones_at_idx
  on public.sync_tombstones (deleted_at);

alter table public.sync_tombstones enable row level security;
-- قراءة فقط: معرّفات محذوفة لا بيانات فيها. الكتابة للمشغّلات (SECURITY DEFINER) وحدها.
drop policy if exists "sync_tombstones read" on public.sync_tombstones;
create policy "sync_tombstones read" on public.sync_tombstones for select using (true);

create or replace function public.sync_log_delete() returns trigger
language plpgsql security definer set search_path = public as $$
begin
  insert into public.sync_tombstones (table_name, row_id, mosque_id)
  values (
    tg_table_name,
    old.id,
    case when tg_table_name = 'mosques' then old.id
         else to_jsonb(old) ->> 'mosque_id' end
  );
  return old;
end $$;

do $$
declare t text;
begin
  foreach t in array array['mosques','sheikhs','halaqat','students','community_events',
      'memorization_records','attendance','messages','competitions','intensive_courses',
      'trips','rewards','reward_redemptions','recitation_tracks',
      'subject_recitation_records','points_logs','event_questions'] loop
    execute format('drop trigger if exists sync_log_delete on public.%I', t);
    execute format('create trigger sync_log_delete after delete on public.%I
                    for each row execute function public.sync_log_delete()', t);
  end loop;
end $$;

-- ------------------------------------------------------
-- 4. الفهارس. لم يكن في القاعدة غير المفاتيح الأساسية: كل تصفية بالمسجد، وكل حذف
--    متسلسل من طالب أو مسجد، كان يمسح الجدول كاملاً.
-- ------------------------------------------------------
do $$
declare t text;
begin
  foreach t in array array['sheikhs','halaqat','students','community_events',
      'memorization_records','attendance','messages','competitions','intensive_courses',
      'trips','rewards','reward_redemptions','recitation_tracks',
      'subject_recitation_records','points_logs','event_questions'] loop
    execute format('create index if not exists %I on public.%I (mosque_id, updated_at, id)',
                   t || '_sync_idx', t);
  end loop;
end $$;

create index if not exists mosques_sync_idx on public.mosques (updated_at, id);

-- مفاتيح أجنبية بلا فهارس (حذف طالب كان يفحص كل جدول فرعي كاملاً)
create index if not exists attendance_student_idx        on public.attendance (student_id);
create index if not exists attendance_halaqa_idx         on public.attendance (halaqa_id);
create index if not exists memorization_student_idx      on public.memorization_records (student_id);
create index if not exists messages_student_idx          on public.messages (student_id);
create index if not exists messages_halaqa_idx           on public.messages (halaqa_id);
create index if not exists points_logs_student_idx       on public.points_logs (student_id);
create index if not exists subject_recitation_student_idx on public.subject_recitation_records (student_id);
create index if not exists subject_recitation_track_idx  on public.subject_recitation_records (track_id);
create index if not exists reward_redemptions_student_idx on public.reward_redemptions (student_id);
create index if not exists reward_redemptions_reward_idx on public.reward_redemptions (reward_id);
create index if not exists event_questions_event_idx     on public.event_questions (event_id);
create index if not exists students_halaqa_idx           on public.students (halaqa_id);
create index if not exists students_sheikh_idx           on public.students (sheikh_id);
create index if not exists halaqat_sheikh_idx            on public.halaqat (sheikh_id);

-- أرقام الإشراف العام (اليوم، والنشاط خلال أسبوع)، وجلب دروس اكتشف بالموقع
create index if not exists attendance_session_date_idx   on public.attendance (session_date);
create index if not exists attendance_updated_idx        on public.attendance (updated_at);
create index if not exists community_events_geo_idx      on public.community_events (latitude, longitude);

-- ------------------------------------------------------
-- 5. دالة المزامنة: ما الذي تغيّر في هذه المساجد منذ آخر مرة؟ (طلب واحد بدل 17)
-- ------------------------------------------------------
-- تعيد أي الجداول فيها جديد، والمحذوف، وساعة الخادم لتكون هي المؤشر التالي (لا ساعة
-- الجهاز). نافذة تداخل دقيقتان تغطي معاملات تُثبَّت متأخرة. الجهاز يجلب الجداول
-- المتغيّرة وحدها بالصفحات، فيصير الطلب الخامل طلباً واحداً بحجم بضع مئات بايت.
-- INVOKER: تحترم سياسات الأمان إذا شُدّدت لاحقاً، ولا تتجاوزها.
create or replace function public.sync_changes(
  p_mosque_ids text[],
  p_since timestamptz default null
) returns jsonb
language plpgsql security invoker set search_path = public as $$
declare
  v_now     timestamptz := clock_timestamp();
  v_since   timestamptz;
  v_changed jsonb := '{}'::jsonb;
  v_t       text;
  v_has     boolean;
  v_tombs   jsonb := '[]'::jsonb;
  v_n       int := 0;
  c_tomb_limit constant int := 2000;
begin
  if p_mosque_ids is null or cardinality(p_mosque_ids) = 0 then
    return jsonb_build_object('server_now', v_now, 'changed', v_changed,
                              'tombstones', v_tombs, 'tombstones_more', false);
  end if;
  if cardinality(p_mosque_ids) > 100 then
    raise exception 'too many mosques in one sync scope' using errcode = '22023';
  end if;

  v_since := case when p_since is null then null else p_since - interval '2 minutes' end;

  select exists (select 1 from public.mosques m
                  where m.id = any (p_mosque_ids)
                    and (v_since is null or m.updated_at >= v_since)) into v_has;
  v_changed := v_changed || jsonb_build_object('mosques', v_has);

  foreach v_t in array array['sheikhs','halaqat','students','community_events',
      'memorization_records','attendance','messages','competitions','intensive_courses',
      'trips','rewards','reward_redemptions','recitation_tracks',
      'subject_recitation_records','points_logs','event_questions'] loop
    execute format('select exists (select 1 from public.%I
                     where mosque_id = any ($1) and ($2 is null or updated_at >= $2))', v_t)
      into v_has using p_mosque_ids, v_since;
    v_changed := v_changed || jsonb_build_object(v_t, v_has);
  end loop;

  if v_since is not null then
    select coalesce(jsonb_agg(jsonb_build_object('t', x.table_name, 'id', x.row_id)), '[]'::jsonb),
           count(*)
      into v_tombs, v_n
      from (select s.table_name, s.row_id
              from public.sync_tombstones s
             where s.mosque_id = any (p_mosque_ids) and s.deleted_at >= v_since
             order by s.deleted_at
             limit c_tomb_limit) x;
  end if;

  return jsonb_build_object('server_now', v_now, 'changed', v_changed,
                            'tombstones', v_tombs, 'tombstones_more', v_n >= c_tomb_limit);
end $$;

-- ------------------------------------------------------
-- 6. الإشراف العام: أرقام مجمَّعة وقائمة مساجد بصفحات، من الخادم
-- ------------------------------------------------------
-- اللوحة كانت تبني بطاقة لكل مسجد وتعدّ من نسخة محلية فيها كل بيانات المنصة. هنا
-- يحسب الخادم ما يخصّ الصفحة المعروضة فقط، ويفحص كل استدعاء أن المستدعي مشرف عام
-- مسجَّل (جدول super_admins، الدخول بـ Supabase Auth).
create schema if not exists private;

create or replace function private.require_super_admin() returns void
language plpgsql security definer set search_path = public as $$
begin
  if auth.uid() is null
     or not exists (select 1 from public.super_admins where user_id = auth.uid()) then
    raise exception 'super admin only' using errcode = '42501';
  end if;
end $$;

create or replace function public.ministry_overview() returns jsonb
language plpgsql security definer set search_path = public as $$
declare
  v_today text := ((now() at time zone 'Asia/Damascus')::date)::text;
begin
  perform private.require_super_admin();
  return jsonb_build_object(
    'mosques_men',      (select count(*) from public.mosques where coalesce(gender, 'male') <> 'female'),
    'mosques_women',    (select count(*) from public.mosques where gender = 'female'),
    'sheikhs',          (select count(*) from public.sheikhs),
    'halaqat',          (select count(*) from public.halaqat),
    'students',         (select count(*) from public.students),
    'attendance_today', (select count(*) from public.attendance where session_date = v_today),
    'active_mosques_7d',(select count(distinct mosque_id) from public.attendance
                          where updated_at > now() - interval '7 days'),
    'new_mosques_30d',  (select count(*) from public.mosques
                          where created_at > now() - interval '30 days'),
    'cities', (select coalesce(jsonb_agg(jsonb_build_object('city', c.city, 'mosques', c.n)
                                         order by c.n desc, c.city), '[]'::jsonb)
                 from (select coalesce(nullif(trim(city), ''), 'غير محدد') as city, count(*) as n
                         from public.mosques
                        where coalesce(gender, 'male') <> 'female'
                        group by 1 order by n desc, city limit 60) c)
  );
end $$;

create or replace function public.ministry_mosques(
  p_search text default null,
  p_city   text default null,
  p_limit  int  default 40,
  p_offset int  default 0
) returns jsonb
language plpgsql security definer set search_path = public as $$
declare
  v_limit  int := least(greatest(coalesce(p_limit, 40), 1), 100);
  v_offset int := greatest(coalesce(p_offset, 0), 0);
  v_q      text := lower(trim(coalesce(p_search, '')));
  v_city   text := trim(coalesce(p_city, ''));
  v_total  bigint;
  v_rows   jsonb;
begin
  perform private.require_super_admin();

  select count(*) into v_total
    from public.mosques m
   where (v_q = '' or position(v_q in lower(m.name)) > 0
                   or position(v_q in lower(coalesce(m.city, ''))) > 0
                   or position(v_q in lower(coalesce(m.address, ''))) > 0)
     and (v_city = '' or coalesce(nullif(trim(m.city), ''), 'غير محدد') = v_city);

  select coalesce(jsonb_agg(to_jsonb(p) order by p.created_at desc nulls last, p.id), '[]'::jsonb)
    into v_rows
    from (
      select m.id, m.name, m.city, m.address, m.gender, m.parent_mosque_id, m.created_at,
             -- أكواد القسم النسائي تبقى عند إدارته وحدها (كما في اللوحة السابقة)
             case when m.gender = 'female' then null else m.access_code end as access_code,
             (select count(*) from public.halaqat h where h.mosque_id = m.id) as halaqat_count,
             (select count(*) from public.sheikhs s where s.mosque_id = m.id) as sheikhs_count,
             (select count(*) from public.students st where st.mosque_id = m.id) as students_count,
             (select max(a.updated_at) from public.attendance a where a.mosque_id = m.id) as last_activity
        from public.mosques m
       where (v_q = '' or position(v_q in lower(m.name)) > 0
                       or position(v_q in lower(coalesce(m.city, ''))) > 0
                       or position(v_q in lower(coalesce(m.address, ''))) > 0)
         and (v_city = '' or coalesce(nullif(trim(m.city), ''), 'غير محدد') = v_city)
       order by m.created_at desc nulls last, m.id
       limit v_limit offset v_offset
    ) p;

  return jsonb_build_object('total', v_total, 'rows', v_rows);
end $$;

revoke execute on function public.ministry_overview() from public, anon;
revoke execute on function public.ministry_mosques(text, text, int, int) from public, anon;
revoke execute on function private.require_super_admin() from public, anon, authenticated;
grant  execute on function public.ministry_overview() to authenticated;
grant  execute on function public.ministry_mosques(text, text, int, int) to authenticated;

notify pgrst, 'reload schema';

-- ------------------------------------------------------
-- اختياري بعد التطبيق: تنظيف شواهد الحذف الأقدم من 45 يوماً. الجهاز الذي غاب أكثر
-- من أسبوعين يعيد جلب مساجده كاملة (لا يعتمد على الشواهد)، فالتنظيف آمن.
-- يتطلب تفعيل pg_cron من لوحة Supabase ثم:
--   select cron.schedule('purge-sync-tombstones', '17 3 * * *',
--     $$ delete from public.sync_tombstones where deleted_at < now() - interval '45 days' $$);
-- ------------------------------------------------------
