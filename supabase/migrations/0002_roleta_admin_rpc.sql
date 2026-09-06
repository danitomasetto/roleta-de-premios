-- Operações administrativas da Roleta. Todas conferem o usuário autenticado.
create or replace function public.roleta_list_my_events()
returns table(id uuid, title text, slug text, status text, layout text, primary_color text, secondary_color text, created_at timestamptz)
language sql security definer set search_path = roleta, public as $$
  select e.id,e.title,e.slug,e.status,e.layout,e.primary_color,e.secondary_color,e.created_at
  from roleta.events e where e.owner_id=(select auth.uid()) order by e.created_at desc;
$$;

create or replace function public.roleta_create_event(p_title text, p_slug text, p_layout text default 'slots', p_primary_color text default '#681D30', p_secondary_color text default '#C79339')
returns uuid language plpgsql security definer set search_path = roleta, public as $$
declare v_id uuid;
begin
  if auth.uid() is null then raise exception 'AUTH_REQUIRED'; end if;
  if coalesce(trim(p_title),'')='' or p_slug !~ '^[a-z0-9-]{3,80}$' then raise exception 'INVALID_EVENT'; end if;
  if p_layout not in ('slots','wheel') then raise exception 'INVALID_LAYOUT'; end if;
  insert into roleta.events(owner_id,title,slug,layout,primary_color,secondary_color)
  values(auth.uid(),trim(p_title),p_slug,p_layout,p_primary_color,p_secondary_color) returning id into v_id;
  return v_id;
end $$;

revoke all on function public.roleta_list_my_events() from public, anon;
revoke all on function public.roleta_create_event(text,text,text,text,text) from public, anon;
grant execute on function public.roleta_list_my_events() to authenticated;
grant execute on function public.roleta_create_event(text,text,text,text,text) to authenticated;
