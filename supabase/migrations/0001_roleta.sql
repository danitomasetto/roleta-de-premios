-- Schema isolado da Roleta de Prêmios. Não altera tabelas da Horoteca.
create schema if not exists roleta;
revoke all on schema roleta from public;
grant usage on schema roleta to service_role;

create table if not exists roleta.events (
  id uuid primary key default gen_random_uuid(), owner_id uuid not null references auth.users(id),
  title text not null, slug text not null unique, status text not null default 'draft' check (status in ('draft','active','closed')),
  layout text not null default 'slots' check (layout in ('slots','wheel')),
  logo_url text, primary_color text not null default '#681D30', secondary_color text not null default '#C79339',
  created_at timestamptz not null default now(), starts_at timestamptz, ends_at timestamptz
);
create table if not exists roleta.prizes (
  id uuid primary key default gen_random_uuid(), event_id uuid not null references roleta.events(id) on delete cascade,
  title text not null, symbol text not null default '✦', weight integer not null check (weight > 0),
  kind text not null default 'coupon' check (kind in ('coupon','gift','spin_again')),
  coupon_prefix text, active boolean not null default true, created_at timestamptz not null default now()
);
create table if not exists roleta.participants (
  id uuid primary key default gen_random_uuid(), event_id uuid not null references roleta.events(id) on delete cascade,
  full_name text not null, whatsapp text not null, whatsapp_normalized text not null, instagram text, email text, privacy_accepted_at timestamptz not null,
  created_at timestamptz not null default now(), unique(event_id, whatsapp_normalized)
);
create table if not exists roleta.spins (
  id uuid primary key default gen_random_uuid(), event_id uuid not null references roleta.events(id), participant_id uuid not null references roleta.participants(id),
  prize_id uuid not null references roleta.prizes(id), created_at timestamptz not null default now()
);
create table if not exists roleta.coupons (
  id uuid primary key default gen_random_uuid(), spin_id uuid not null unique references roleta.spins(id) on delete cascade,
  code text not null unique, status text not null default 'generated' check(status in ('generated','redeemed','cancelled')),
  redeemed_at timestamptz, redeemed_by uuid references auth.users(id), created_at timestamptz not null default now()
);
create index if not exists participants_event_whatsapp_idx on roleta.participants(event_id, whatsapp_normalized);
create index if not exists spins_event_created_idx on roleta.spins(event_id, created_at desc);
alter table roleta.events enable row level security; alter table roleta.prizes enable row level security; alter table roleta.participants enable row level security; alter table roleta.spins enable row level security; alter table roleta.coupons enable row level security;
revoke all on all tables in schema roleta from public, anon, authenticated;

-- A função fica em public apenas para a Edge Function conseguir chamá-la via API.
-- Ela não é executável por navegador: somente service_role recebe EXECUTE.
create or replace function public.roleta_spin_event(p_slug text, p_name text, p_whatsapp text, p_instagram text default null, p_email text default null)
returns table(prize_title text, prize_symbol text, prize_kind text, coupon_code text)
language plpgsql security definer set search_path = roleta, public as $$
declare v_event roleta.events; v_participant uuid; v_prize roleta.prizes; v_total integer; v_pick numeric; v_coupon text; v_spin uuid;
begin
  select * into v_event from roleta.events where slug=p_slug and status='active' and (starts_at is null or starts_at<=now()) and (ends_at is null or ends_at>=now()) for update;
  if not found then raise exception 'EVENT_NOT_AVAILABLE'; end if;
  if coalesce(trim(p_name),'')='' or coalesce(trim(p_whatsapp),'')='' then raise exception 'PARTICIPANT_REQUIRED'; end if;
  insert into roleta.participants(event_id,full_name,whatsapp,whatsapp_normalized,instagram,email,privacy_accepted_at) values(v_event.id,trim(p_name),trim(p_whatsapp),regexp_replace(trim(p_whatsapp),'\\D','','g'),nullif(trim(p_instagram),''),nullif(trim(p_email),''),now())
  on conflict(event_id,whatsapp_normalized) do update set full_name=excluded.full_name, whatsapp=excluded.whatsapp, instagram=coalesce(excluded.instagram,roleta.participants.instagram), email=coalesce(excluded.email,roleta.participants.email) returning id into v_participant;
  select coalesce(sum(weight),0) into v_total from roleta.prizes where event_id=v_event.id and active;
  if v_total=0 then raise exception 'NO_PRIZES'; end if;
  v_pick:=random()*v_total;
  select * into v_prize from roleta.prizes where event_id=v_event.id and active order by id limit 1;
  for v_prize in select * from roleta.prizes where event_id=v_event.id and active order by created_at loop v_pick:=v_pick-v_prize.weight; if v_pick<=0 then exit; end if; end loop;
  insert into roleta.spins(event_id,participant_id,prize_id) values(v_event.id,v_participant,v_prize.id) returning id into v_spin;
  if v_prize.kind='coupon' then v_coupon:=coalesce(v_prize.coupon_prefix,'PREMIO')||'-'||to_char(current_date,'MMDD')||'-'||upper(substr(md5(random()::text),1,4)); insert into roleta.coupons(spin_id,code) values(v_spin,v_coupon); end if;
  return query select v_prize.title,v_prize.symbol,v_prize.kind,v_coupon;
end $$;
revoke all on function public.roleta_spin_event(text,text,text,text,text) from public, anon, authenticated;
grant execute on function public.roleta_spin_event(text,text,text,text,text) to service_role;
