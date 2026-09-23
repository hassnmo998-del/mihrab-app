-- Public lessons can be given by one sheikh (single) or several (group).
-- sheikh_id stays the primary/creating sheikh for backward compatibility;
-- sheikh_ids lists every sheikh taking part in a group lesson.
-- Applied to the live project on 2026-09-23 (migration: group_lessons_multi_sheikh).
alter table public.community_events
  add column if not exists lesson_format text not null default 'single',
  add column if not exists sheikh_ids text[] not null default '{}';

do $$
begin
  if not exists (
    select 1 from pg_constraint
    where conname = 'community_events_lesson_format_check'
      and conrelid = 'public.community_events'::regclass
  ) then
    alter table public.community_events
      add constraint community_events_lesson_format_check
      check (lesson_format in ('single', 'group'));
  end if;
end $$;
