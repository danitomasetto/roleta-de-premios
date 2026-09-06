drop function if exists public.roleta_list_my_events();
create or replace function public.roleta_list_my_events()
returns table(id uuid, title text, slug text, status text, event_type text, layout text, primary_color text, secondary_color text, created_at timestamptz)
language sql security definer set search_path = roleta, public as $$
  select e.id,e.title,e.slug,e.status,e.event_type,e.layout,e.primary_color,e.secondary_color,e.created_at
  from roleta.events e where e.owner_id=(select auth.uid()) order by e.created_at desc;
$$;
revoke all on function public.roleta_list_my_events() from public, anon;
grant execute on function public.roleta_list_my_events() to authenticated;
