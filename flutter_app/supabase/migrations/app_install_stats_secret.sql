-- ======================================================
-- أرقام الأجهزة لصاحب المشروع وحده: بكلمة سر، لا بحساب المشرف العام
-- ======================================================
-- للمنصة أكثر من مشرف عام، والأرقام لصاحبها فقط. الدالة تفحص كلمة سر محفوظة
-- تجزئتها (bcrypt) في private.app_stats_secret، ولا تشترط أي دخول.
--
-- كلمة السر لا تُكتب هنا ولا في التطبيق. تُضبط أو تُغيَّر من SQL Editor:
--   insert into private.app_stats_secret (id, secret_hash)
--   values (1, extensions.crypt('<كلمة السر>', extensions.gen_salt('bf', 10)))
--   on conflict (id) do update set secret_hash = excluded.secret_hash;
-- التطبيق يرسلها بأحرف صغيرة بلا مسافات ولا شرطات، فتُحفظ بالصيغة نفسها.

create table if not exists private.app_stats_secret (
  id          int primary key default 1 check (id = 1),
  secret_hash text not null
);

-- محاولات خاطئة: تُحسب كي يتوقف الفحص حين تكثر
create table if not exists private.app_stats_failures (
  at timestamptz not null default now()
);
create index if not exists app_stats_failures_at_idx on private.app_stats_failures (at);

alter table private.app_stats_secret enable row level security;
alter table private.app_stats_failures enable row level security;

-- النسخة السابقة كانت لأي مشرف عام
drop function if exists public.app_install_stats();

create or replace function public.app_install_stats(p_secret text)
returns jsonb
language plpgsql
volatile
security definer
set search_path = ''
as $$
declare
  v_hash   text;
  v_today  date := (now() at time zone 'Asia/Damascus')::date;
  v_since  timestamptz := now() - interval '30 days';
  v_result jsonb;
begin
  -- عشرون محاولة خاطئة (من أي جهاز) في عشر دقائق توقف الفحص: لا تخمين ولا إنهاك للخادم
  if (select count(*) from private.app_stats_failures where at > now() - interval '10 minutes') >= 20 then
    return jsonb_build_object('error', 'too_many_attempts');
  end if;

  select secret_hash into v_hash from private.app_stats_secret where id = 1;
  if v_hash is null or coalesce(p_secret, '') = '' or extensions.crypt(p_secret, v_hash) <> v_hash then
    insert into private.app_stats_failures default values;
    delete from private.app_stats_failures where at < now() - interval '1 day';
    -- خطأ في الردّ لا استثناء: الاستثناء كان سيلغي تسجيل المحاولة
    return jsonb_build_object('error', 'wrong_secret');
  end if;

  -- «عليها التطبيق» = ظهرت خلال آخر 30 يوماً؛ الأيام بتوقيت دمشق
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

revoke all on function public.app_install_stats(text) from public;
grant execute on function public.app_install_stats(text) to anon, authenticated;
