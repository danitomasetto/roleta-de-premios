-- O número de registro é interno: 1, 2, 3... na ordem importada.
alter table roleta.list_entries alter column registration_number type bigint using nullif(registration_number,'')::bigint;

drop function if exists public.roleta_create_event(text,text,text,text,text);
create or replace function public.roleta_create_event(p_title text, p_slug text, p_layout text default 'slots', p_primary_color text default '#681D30', p_secondary_color text default '#C79339', p_event_type text default 'roulette')
returns uuid language plpgsql security definer set search_path = roleta, public as $$
declare v_id uuid;
begin
  if auth.uid() is null then raise exception 'AUTH_REQUIRED'; end if;
  if coalesce(trim(p_title),'')='' or p_slug !~ '^[a-z0-9-]{3,80}$' then raise exception 'INVALID_EVENT'; end if;
  if p_layout not in ('slots','wheel') or p_event_type not in ('roulette','list_draw') then raise exception 'INVALID_EVENT_TYPE'; end if;
  insert into roleta.events(owner_id,title,slug,layout,event_type,primary_color,secondary_color)
  values(auth.uid(),trim(p_title),p_slug,p_layout,p_event_type,p_primary_color,p_secondary_color) returning id into v_id;
  return v_id;
end $$;
revoke all on function public.roleta_create_event(text,text,text,text,text,text) from public, anon;
grant execute on function public.roleta_create_event(text,text,text,text,text,text) to authenticated;

create or replace function public.roleta_import_list(p_event_id uuid, p_entries jsonb)
returns integer language plpgsql security definer set search_path = roleta, public as $$
declare v_count integer;
begin
  if auth.uid() is null then raise exception 'AUTH_REQUIRED'; end if;
  if not exists(select 1 from roleta.events where id=p_event_id and owner_id=auth.uid() and event_type='list_draw' and status='draft') then raise exception 'EVENT_NOT_EDITABLE'; end if;
  if jsonb_typeof(p_entries) <> 'array' then raise exception 'INVALID_FILE'; end if;
  delete from roleta.list_entries where event_id=p_event_id;
  insert into roleta.list_entries(event_id,registration_number,display_name,whatsapp,instagram,email,source_row,raw_data)
  select p_event_id, ordinality::bigint, trim(item->>'name'), nullif(trim(item->>'whatsapp'),''), nullif(trim(item->>'instagram'),''), nullif(trim(item->>'email'),''), ordinality::integer, item
  from jsonb_array_elements(p_entries) with ordinality as x(item,ordinality)
  where coalesce(trim(item->>'name'),'')<>'';
  get diagnostics v_count = row_count;
  if v_count=0 then raise exception 'EMPTY_LIST'; end if;
  update roleta.events set status='active' where id=p_event_id;
  return v_count;
end $$;
revoke all on function public.roleta_import_list(uuid,jsonb) from public, anon;
grant execute on function public.roleta_import_list(uuid,jsonb) to authenticated;
