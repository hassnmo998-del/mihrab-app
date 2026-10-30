-- ======================================================
-- التواصل مع المطوّر: محادثة نصية صغيرة بين المستخدم وصاحب المشروع
-- ======================================================
-- القواعد:
--   - المستخدم يرسل ٣ رسائل، ويزيد له رسالة مع كل ردّ منك: محادثة حقيقية بلا سبام.
--   - الجدول في المخطط private فلا تصله واجهة الـ API (المفتاح العام يقدر على الجداول العادية):
--     المستخدم يكتب ويقرأ محادثة جهازه وحدها عبر dev_msg_send / dev_msg_thread / dev_msg_unread.
--   - صندوقك والرد والحذف بكلمة السر نفسها لشاشة أرقام التطبيق (private.app_stats_secret)،
--     وتتوقف عشر دقائق بعد عشرين محاولة خاطئة (جدول المحاولات نفسه).
--   - الخادم يفرض الحدّ والطول (٦٠٠ حرف) والسقف اليومي العام (٣٠٠ رسالة): التطبيق لا يُوثق به.
--   - ما يُحفظ مع الرسالة: معرّف الجهاز نفسه المستعمل في عدّ الأجهزة، المنصة، ورقم الإصدار.
-- يُطبَّق مرة من SQL Editor (أو apply_migration). لا يمسّ أي جدول موجود.

create table if not exists private.dev_messages (
  id          bigint generated always as identity primary key,
  install_id  text not null check (install_id ~ '^[0-9a-f]{32}$'),
  from_dev    boolean not null default false,
  body        text not null check (char_length(body) between 1 and 1000),
  platform    text not null default '',
  app_version text not null default '' check (char_length(app_version) <= 20),
  created_at  timestamptz not null default now(),
  read_by_dev boolean not null default false
);

create index if not exists dev_messages_install_idx on private.dev_messages (install_id, id);
create index if not exists dev_messages_created_idx on private.dev_messages (created_at);

alter table private.dev_messages enable row level security;

-- ------------------------------------------------------
-- فحص كلمة سر المطوّر (نفس منطق app_install_stats)
-- ------------------------------------------------------
create or replace function private.dev_check_secret(p_secret text)
returns text
language plpgsql
volatile
security definer
set search_path = ''
as $$
declare
  v_hash text;
begin
  if (select count(*) from private.app_stats_failures where at > now() - interval '10 minutes') >= 20 then
    return 'too_many_attempts';
  end if;

  select secret_hash into v_hash from private.app_stats_secret where id = 1;
  if v_hash is null or coalesce(p_secret, '') = '' or extensions.crypt(p_secret, v_hash) <> v_hash then
    insert into private.app_stats_failures default values;
    delete from private.app_stats_failures where at < now() - interval '1 day';
    return 'wrong_secret';
  end if;
  return 'ok';
end;
$$;

revoke all on function private.dev_check_secret(text) from public;

-- ------------------------------------------------------
-- المستخدم: إرسال رسالة
-- ------------------------------------------------------
create or replace function public.dev_msg_send(
  p_install_id text,
  p_body       text,
  p_platform   text default '',
  p_version    text default ''
)
returns jsonb
language plpgsql
volatile
security definer
set search_path = ''
as $$
declare
  v_body     text := btrim(coalesce(p_body, ''));
  v_platform text := case when p_platform in ('android', 'windows', 'ios', 'web', 'macos', 'linux') then p_platform else 'web' end;
  v_used     int;
  v_replies  int;
  v_allow    int;
begin
  if p_install_id is null or p_install_id !~ '^[0-9a-f]{32}$' then
    raise exception 'invalid install id' using errcode = '22023';
  end if;
  if v_body = '' then
    return jsonb_build_object('error', 'empty');
  end if;
  if char_length(v_body) > 600 then
    return jsonb_build_object('error', 'too_long');
  end if;

  -- سقف يومي عام: لا يغرق صندوقك أحد ولو بدّل معرّف جهازه
  if (select count(*) from private.dev_messages where not from_dev and created_at > now() - interval '1 day') >= 300 then
    return jsonb_build_object('error', 'busy');
  end if;

  select count(*) filter (where not from_dev), count(*) filter (where from_dev)
    into v_used, v_replies
    from private.dev_messages
   where install_id = p_install_id;

  v_allow := 3 + v_replies;
  if v_used >= v_allow then
    return jsonb_build_object('error', 'limit', 'remaining', 0);
  end if;

  insert into private.dev_messages (install_id, from_dev, body, platform, app_version)
  values (p_install_id, false, v_body, v_platform, left(coalesce(p_version, ''), 20));

  -- محادثات قديمة جداً تُنظَّف
  delete from private.dev_messages where created_at < now() - interval '365 days';

  return jsonb_build_object('ok', true, 'remaining', v_allow - v_used - 1);
end;
$$;

-- ------------------------------------------------------
-- المستخدم: محادثة جهازه وما بقي له من رسائل
-- ------------------------------------------------------
create or replace function public.dev_msg_thread(p_install_id text)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_used    int;
  v_replies int;
begin
  if p_install_id is null or p_install_id !~ '^[0-9a-f]{32}$' then
    raise exception 'invalid install id' using errcode = '22023';
  end if;

  select count(*) filter (where not from_dev), count(*) filter (where from_dev)
    into v_used, v_replies
    from private.dev_messages
   where install_id = p_install_id;

  return jsonb_build_object(
    'remaining', greatest(0, 3 + v_replies - v_used),
    'messages', coalesce((
      select jsonb_agg(jsonb_build_object('id', m.id, 'from_dev', m.from_dev, 'body', m.body, 'at', m.created_at) order by m.id)
        from (select * from private.dev_messages where install_id = p_install_id order by id desc limit 80) m
    ), '[]'::jsonb)
  );
end;
$$;

-- ------------------------------------------------------
-- المستخدم: كم ردّاً جديداً بعد آخر ردّ قرأه (لوميض زر «؟»)
-- ------------------------------------------------------
create or replace function public.dev_msg_unread(p_install_id text, p_after bigint default 0)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
begin
  if p_install_id is null or p_install_id !~ '^[0-9a-f]{32}$' then
    raise exception 'invalid install id' using errcode = '22023';
  end if;
  return jsonb_build_object('count', (
    select count(*) from private.dev_messages
     where install_id = p_install_id and from_dev and id > coalesce(p_after, 0)
  ));
end;
$$;

-- ------------------------------------------------------
-- المطوّر: صندوق الوارد (سطر لكل جهاز، الأحدث أولاً)
-- ------------------------------------------------------
create or replace function public.dev_msg_admin_inbox(p_secret text)
returns jsonb
language plpgsql
volatile
security definer
set search_path = ''
as $$
declare
  v_ok text := private.dev_check_secret(p_secret);
begin
  if v_ok <> 'ok' then
    return jsonb_build_object('error', v_ok);
  end if;

  return jsonb_build_object('threads', coalesce((
    select jsonb_agg(x.t order by x.t ->> 'last_at' desc)
      from (
        select jsonb_build_object(
                 'install_id', g.install_id,
                 'platform', coalesce(g.platform, ''),
                 'version', coalesce(g.version, ''),
                 'last_body', l.body,
                 'last_from_dev', l.from_dev,
                 'last_at', l.created_at,
                 'unread', g.unread,
                 'total', g.total
               ) as t
          from (
            select install_id,
                   max(id) as last_id,
                   count(*) as total,
                   count(*) filter (where not from_dev and not read_by_dev) as unread,
                   (array_agg(platform order by id desc) filter (where not from_dev))[1] as platform,
                   (array_agg(app_version order by id desc) filter (where not from_dev))[1] as version
              from private.dev_messages
             group by install_id
          ) g
          join private.dev_messages l on l.id = g.last_id
         limit 200
      ) x
  ), '[]'::jsonb));
end;
$$;

-- ------------------------------------------------------
-- المطوّر: محادثة جهاز (وتُعلَّم رسائله مقروءة)
-- ------------------------------------------------------
create or replace function public.dev_msg_admin_thread(p_secret text, p_install_id text)
returns jsonb
language plpgsql
volatile
security definer
set search_path = ''
as $$
declare
  v_ok text := private.dev_check_secret(p_secret);
begin
  if v_ok <> 'ok' then
    return jsonb_build_object('error', v_ok);
  end if;
  if p_install_id is null or p_install_id !~ '^[0-9a-f]{32}$' then
    return jsonb_build_object('messages', '[]'::jsonb, 'remaining', 0);
  end if;

  update private.dev_messages set read_by_dev = true
   where install_id = p_install_id and not from_dev and not read_by_dev;

  return jsonb_build_object(
    'remaining', 0,
    'messages', coalesce((
      select jsonb_agg(jsonb_build_object('id', m.id, 'from_dev', m.from_dev, 'body', m.body, 'at', m.created_at) order by m.id)
        from (select * from private.dev_messages where install_id = p_install_id order by id desc limit 200) m
    ), '[]'::jsonb)
  );
end;
$$;

-- ------------------------------------------------------
-- المطوّر: ردّ (يمنح المستخدم رسالة إضافية تلقائياً)
-- ------------------------------------------------------
create or replace function public.dev_msg_admin_reply(p_secret text, p_install_id text, p_body text)
returns jsonb
language plpgsql
volatile
security definer
set search_path = ''
as $$
declare
  v_ok   text := private.dev_check_secret(p_secret);
  v_body text := btrim(coalesce(p_body, ''));
begin
  if v_ok <> 'ok' then
    return jsonb_build_object('error', v_ok);
  end if;
  if p_install_id is null or p_install_id !~ '^[0-9a-f]{32}$' or v_body = '' then
    return jsonb_build_object('error', 'empty');
  end if;
  if char_length(v_body) > 1000 then
    return jsonb_build_object('error', 'too_long');
  end if;

  insert into private.dev_messages (install_id, from_dev, body, read_by_dev)
  values (p_install_id, true, v_body, true);
  return jsonb_build_object('ok', true);
end;
$$;

-- ------------------------------------------------------
-- المطوّر: حذف محادثة (سبام مثلاً)
-- ------------------------------------------------------
create or replace function public.dev_msg_admin_delete(p_secret text, p_install_id text)
returns jsonb
language plpgsql
volatile
security definer
set search_path = ''
as $$
declare
  v_ok text := private.dev_check_secret(p_secret);
begin
  if v_ok <> 'ok' then
    return jsonb_build_object('error', v_ok);
  end if;
  delete from private.dev_messages where install_id = p_install_id;
  return jsonb_build_object('ok', true);
end;
$$;

revoke all on function public.dev_msg_send(text, text, text, text) from public;
revoke all on function public.dev_msg_thread(text) from public;
revoke all on function public.dev_msg_unread(text, bigint) from public;
revoke all on function public.dev_msg_admin_inbox(text) from public;
revoke all on function public.dev_msg_admin_thread(text, text) from public;
revoke all on function public.dev_msg_admin_reply(text, text, text) from public;
revoke all on function public.dev_msg_admin_delete(text, text) from public;

grant execute on function public.dev_msg_send(text, text, text, text) to anon, authenticated;
grant execute on function public.dev_msg_thread(text) to anon, authenticated;
grant execute on function public.dev_msg_unread(text, bigint) to anon, authenticated;
grant execute on function public.dev_msg_admin_inbox(text) to anon, authenticated;
grant execute on function public.dev_msg_admin_thread(text, text) to anon, authenticated;
grant execute on function public.dev_msg_admin_reply(text, text, text) to anon, authenticated;
grant execute on function public.dev_msg_admin_delete(text, text) to anon, authenticated;
