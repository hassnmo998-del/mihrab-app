-- ======================================================
-- التراجع عن scale_sync.sql — لا يُطبَّق إلا للتراجع عنه
-- ======================================================
-- يعيد القاعدة إلى ما كانت عليه قبل الترقية بالضبط: يحذف المشغّلات والدوال وجدول شواهد
-- الحذف والفهارس والأعمدة التي أضافتها. لا يمسّ أي صف من بيانات المساجد (الأعمدة
-- المحذوفة مشتقّة كلها: mosque_id من الطالب أو الدرس، وupdated_at ختم زمني).
--
-- بعده تتجه نسخ التطبيق تلقائياً إلى الجلب الكامل القديم (دالة sync_changes
-- تختفي فتُقرأ «غير مدعومة»)، ولوحة المشرف العام تعرض قائمتها المحلية القديمة.
--
-- الأعمدة updated_at في mosques وstudents وcommunity_events كانت موجودة قبل الترقية
-- فلا تُحذف هنا.

do $$
declare t text;
begin
  foreach t in array array['mosques','sheikhs','halaqat','students','community_events',
      'memorization_records','attendance','messages','competitions','intensive_courses',
      'trips','rewards','reward_redemptions','recitation_tracks',
      'subject_recitation_records','points_logs','event_questions'] loop
    execute format('drop trigger if exists sync_touch on public.%I', t);
    execute format('drop trigger if exists sync_log_delete on public.%I', t);
  end loop;
  foreach t in array array['attendance','memorization_records','messages',
                           'points_logs','subject_recitation_records','event_questions'] loop
    execute format('drop trigger if exists sync_fill_mosque_id on public.%I', t);
  end loop;
end $$;

drop function if exists public.sync_changes(text[], timestamptz);
drop function if exists public.ministry_overview();
drop function if exists public.ministry_mosques(text, text, int, int);
drop function if exists private.require_super_admin();
drop function if exists public.sync_fill_mosque_id();
drop function if exists public.sync_touch();
drop function if exists public.sync_log_delete();

drop table if exists public.sync_tombstones;

do $$
declare t text;
begin
  foreach t in array array['sheikhs','halaqat','students','community_events',
      'memorization_records','attendance','messages','competitions','intensive_courses',
      'trips','rewards','reward_redemptions','recitation_tracks',
      'subject_recitation_records','points_logs','event_questions'] loop
    execute format('drop index if exists public.%I', t || '_sync_idx');
  end loop;
end $$;

drop index if exists public.mosques_sync_idx;
drop index if exists public.attendance_student_idx;
drop index if exists public.attendance_halaqa_idx;
drop index if exists public.memorization_student_idx;
drop index if exists public.messages_student_idx;
drop index if exists public.messages_halaqa_idx;
drop index if exists public.points_logs_student_idx;
drop index if exists public.subject_recitation_student_idx;
drop index if exists public.subject_recitation_track_idx;
drop index if exists public.reward_redemptions_student_idx;
drop index if exists public.reward_redemptions_reward_idx;
drop index if exists public.event_questions_event_idx;
drop index if exists public.students_halaqa_idx;
drop index if exists public.students_sheikh_idx;
drop index if exists public.halaqat_sheikh_idx;
drop index if exists public.attendance_session_date_idx;
drop index if exists public.attendance_updated_idx;
drop index if exists public.community_events_geo_idx;

-- أعمدة أضافتها الترقية (mosque_id للجداول الستة، وupdated_at للجداول التي لم تكن تملكه)
alter table public.attendance                 drop column if exists mosque_id;
alter table public.memorization_records       drop column if exists mosque_id;
alter table public.messages                   drop column if exists mosque_id;
alter table public.points_logs                drop column if exists mosque_id;
alter table public.subject_recitation_records drop column if exists mosque_id;
alter table public.event_questions            drop column if exists mosque_id;

do $$
declare t text;
begin
  foreach t in array array['sheikhs','halaqat','memorization_records','attendance','messages',
      'competitions','intensive_courses','trips','rewards','reward_redemptions',
      'recitation_tracks','subject_recitation_records','points_logs','event_questions'] loop
    execute format('alter table public.%I drop column if exists updated_at', t);
  end loop;
end $$;

notify pgrst, 'reload schema';
