-- Dados visuais mínimos para a tela pública; não expõe participantes ou cupons.
create or replace function public.roleta_get_public_event(p_slug text)
returns table(title text, layout text, primary_color text, secondary_color text)
language sql security definer set search_path = roleta, public as $$
  select e.title,e.layout,e.primary_color,e.secondary_color
  from roleta.events e where e.slug=p_slug and e.event_type='roulette' and e.status='active'
  limit 1;
$$;
revoke all on function public.roleta_get_public_event(text) from public;
grant execute on function public.roleta_get_public_event(text) to anon, authenticated;
