-- Segundo tipo de evento: sorteio de uma lista por número de registro.
alter table roleta.events add column if not exists event_type text not null default 'roulette' check (event_type in ('roulette','list_draw'));

create table if not exists roleta.list_entries (
  id uuid primary key default gen_random_uuid(),
  event_id uuid not null references roleta.events(id) on delete cascade,
  registration_number text not null,
  display_name text not null,
  whatsapp text, instagram text, email text,
  source_row integer not null,
  raw_data jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  unique(event_id, registration_number)
);
create table if not exists roleta.list_draws (
  id uuid primary key default gen_random_uuid(),
  event_id uuid not null unique references roleta.events(id) on delete cascade,
  entry_id uuid not null unique references roleta.list_entries(id),
  registration_number text not null,
  random_value double precision not null check(random_value >= 0 and random_value < 1),
  drawn_by uuid not null references auth.users(id),
  drawn_at timestamptz not null default now()
);
create index if not exists list_entries_event_number_idx on roleta.list_entries(event_id, registration_number);
alter table roleta.list_entries enable row level security;
alter table roleta.list_draws enable row level security;
revoke all on roleta.list_entries, roleta.list_draws from public, anon, authenticated;

-- O valor aleatório vem da Edge Function usando Web Crypto; a função só converte
-- esse valor em um registro e mantém a auditoria do resultado.
create or replace function public.roleta_draw_list_event(p_event_id uuid, p_random_value double precision)
returns table(registration_number text, display_name text, whatsapp text, instagram text, email text, drawn_at timestamptz)
language plpgsql security definer set search_path = roleta, public as $$
declare v_entry roleta.list_entries; v_count integer; v_offset integer;
begin
  if auth.uid() is null then raise exception 'AUTH_REQUIRED'; end if;
  if p_random_value < 0 or p_random_value >= 1 then raise exception 'INVALID_RANDOM_VALUE'; end if;
  if not exists(select 1 from roleta.events where id=p_event_id and owner_id=auth.uid() and event_type='list_draw' and status='active') then raise exception 'EVENT_NOT_AVAILABLE'; end if;
  if exists(select 1 from roleta.list_draws where event_id=p_event_id) then raise exception 'EVENT_ALREADY_DRAWN'; end if;
  select count(*) into v_count from roleta.list_entries where event_id=p_event_id;
  if v_count=0 then raise exception 'EMPTY_LIST'; end if;
  v_offset:=floor(p_random_value*v_count);
  select * into v_entry from roleta.list_entries where event_id=p_event_id order by registration_number, id offset v_offset limit 1 for update;
  insert into roleta.list_draws(event_id,entry_id,registration_number,random_value,drawn_by) values(p_event_id,v_entry.id,v_entry.registration_number,p_random_value,auth.uid());
  update roleta.events set status='closed' where id=p_event_id;
  return query select v_entry.registration_number,v_entry.display_name,v_entry.whatsapp,v_entry.instagram,v_entry.email,now();
end $$;
revoke all on function public.roleta_draw_list_event(uuid,double precision) from public, anon;
grant execute on function public.roleta_draw_list_event(uuid,double precision) to authenticated;
