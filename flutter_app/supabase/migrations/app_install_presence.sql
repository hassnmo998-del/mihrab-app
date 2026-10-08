-- ======================================================
-- عدّ الأجهزة التي عليها التطبيق (لوحة المشرف العام)
-- ======================================================
-- لا يُحفظ أي بيان عن صاحب الجهاز: معرّف لا يدل على أحد، المنصة، رقم الإصدار،
-- ومتى ظهر الجهاز. الجدولان في المخطط private فلا تصلهما واجهة الـ API أصلاً:
--   - التطبيق يكتب عبر app_install_ping وحدها.
--   - الأرقام المجمَّعة (لا قائمة الأجهزة) عبر app_install_stats، وقد صارت بكلمة سر:
--     انظر app_install_stats_secret.sql.
-- الأيام بتوقيت دمشق في الدالتين: «اليوم» في اللوحة هو يوم المساجد.

create table if not exists private.app_installs (
  install_id  text primary key check (install_id ~ '^[0-9a-f]{32}$'),
  platform    text not null check (platform in ('android', 'windows', 'ios', 'web', 'macos', 'linux')),
  app_version text not null default '' check (char_length(app_version) <= 20),
  first_seen  timestamptz not null default now(),
  last_seen   timestamptz not null default now(),
  -- آخر مرة فُتح فيها التطبيق (إشارات الخلفية على أندرويد لا تغيّره)
  last_opened timestamptz
);

create index if not exists app_installs_last_seen_idx on private.app_installs (last_seen);

-- سطر لكل جهاز في كل يوم ظهر فيه: منه منحنى الأيام. يُبقى 60 يوماً فقط.
create table if not exists private.app_install_days (
  day        date not null,
  install_id text not null references private.app_installs (install_id) on delete cascade,
  opened     boolean not null default false,
  primary key (day, install_id)
);

alter table private.app_installs enable row level security;
alter table private.app_install_days enable row level security;

-- ------------------------------------------------------
-- «هذا الجهاز موجود»: سطر الجهاز + سطر يومه. تعيد اليوم والثواني الباقية منه
-- كي لا يرسل الجهاز ثانية قبل يوم جديد (ساعة الجهاز نفسها قد تكون مخطئة).
-- ------------------------------------------------------
create or replace function public.app_install_ping(
  p_install_id text,
  p_platform   text,
  p_version    text,
  p_opened     boolean default true
)
returns jsonb
language plpgsql
volatile
security definer
set search_path = ''
as $$
declare
  v_local   timestamp := now() at time zone 'Asia/Damascus';
  v_today   date := v_local::date;
  v_opened  boolean := coalesce(p_opened, false);
  v_version text := coalesce(p_version, '');
begin
  if p_install_id is null or p_install_id !~ '^[0-9a-f]{32}$' then
    raise exception 'invalid install id' using errcode = '22023';
  end if;
  if p_platform is null or p_platform not in ('android', 'windows', 'ios', 'web', 'macos', 'linux') then
    raise exception 'invalid platform' using errcode = '22023';
  end if;
  if v_version !~ '^[0-9A-Za-z.+-]{0,20}$' then
    v_version := '';
  end if;

  insert into private.app_installs as i (install_id, platform, app_version, last_opened)
  values (p_install_id, p_platform, v_version, case when v_opened then now() end)
  on conflict (install_id) do update set
    platform    = excluded.platform,
    app_version = excluded.app_version,
    last_seen   = now(),
    last_opened = coalesce(excluded.last_opened, i.last_opened);

  insert into private.app_install_days as d (day, install_id, opened)
  values (v_today, p_install_id, v_opened)
  on conflict (day, install_id) do update set opened = d.opened or excluded.opened;

  -- تنظيف نادر لما تجاوز 60 يوماً (المفتاح يبدأ باليوم فالحذف مدى قصير)
  if random() < 0.01 then
    delete from private.app_install_days where day < v_today - 60;
  end if;

  return jsonb_build_object(
    'day', v_today,
    'seconds_left', ceil(extract(epoch from ((v_today + 1)::timestamp - v_local)))::int
  );
end;
$$;

-- ------------------------------------------------------
-- الأرقام المجمَّعة للمشرف العام وحده.
-- «عليها التطبيق» = ظهرت خلال آخر 30 يوماً: الجهاز الذي حُذف منه التطبيق
-- لا يرسل شيئاً، فيخرج من العدد بعد 30 يوماً من آخر ظهور.
-- ------------------------------------------------------
create or replace function public.app_install_stats()
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_today date := (now() at time zone 'Asia/Damascus')::date;
  v_since timestamptz := now() - interval '30 days';
  v_result jsonb;
begin
  if not exists (select 1 from public.super_admins where user_id = auth.uid()) then
    raise exception 'not a super admin' using errcode = '42501';
  end if;

  select jsonb_build_object(
    'today', v_today,
    'counting_since', (select min(first_seen) from private.app_installs),
    'installed', (select count(*) from private.app_installs where last_seen >= v_since),
    'total', (select count(*) from private.app_installs),
    'opened_today', (select count(*) from private.app_install_days where day = v_today and opened),
    'opened_7d', (select count(distinct install_id) from private.app_install_days
                  where day > v_today - 7 and opened),
    'new_7d', (select count(*) from private.app_installs
               where (first_seen at time zone 'Asia/Damascus')::date > v_today - 7),
    'by_platform', (
      select coalesce(jsonb_agg(jsonb_build_object('key', platform, 'count', n) order by n desc, platform), '[]'::jsonb)
      from (select platform, count(*) as n from private.app_installs
            where last_seen >= v_since group by platform) p
    ),
    'by_version', (
      select coalesce(jsonb_agg(jsonb_build_object('key', app_version, 'count', n) order by n desc, app_version desc), '[]'::jsonb)
      from (select app_version, count(*) as n from private.app_installs
            where last_seen >= v_since group by app_version) v
    ),
    'daily', (
      select jsonb_agg(jsonb_build_object(
               'day', g.day::date,
               'seen', coalesce(s.seen, 0),
               'opened', coalesce(s.opened, 0)) order by g.day)
      from generate_series((v_today - 29)::timestamp, v_today::timestamp, interval '1 day') as g(day)
      left join (
        select day, count(*) as seen, count(*) filter (where opened) as opened
        from private.app_install_days
        where day > v_today - 30
        group by day
      ) s on s.day = g.day::date
    )
  ) into v_result;

  return v_result;
end;
$$;

revoke all on function public.app_install_ping(text, text, text, boolean) from public;
revoke all on function public.app_install_stats() from public;
grant execute on function public.app_install_ping(text, text, text, boolean) to anon, authenticated;
revoke execute on function public.app_install_stats() from anon;
grant execute on function public.app_install_stats() to authenticated;
