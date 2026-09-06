-- Eventos de roleta já nascem prontos para teste com os prêmios padrão.
create or replace function public.roleta_create_event(
  p_title text,
  p_slug text,
  p_layout text default 'slots',
  p_primary_color text default '#681D30',
  p_secondary_color text default '#C79339',
  p_event_type text default 'roulette'
)
returns uuid language plpgsql security definer set search_path = roleta, public as $$
declare v_id uuid;
begin
  if auth.uid() is null then raise exception 'AUTH_REQUIRED'; end if;
  if coalesce(trim(p_title),'')='' or p_slug !~ '^[a-z0-9-]{3,80}$' then raise exception 'INVALID_EVENT'; end if;
  if p_layout not in ('slots','wheel') or p_event_type not in ('roulette','list_draw') then raise exception 'INVALID_EVENT_TYPE'; end if;

  insert into roleta.events(owner_id,title,slug,layout,event_type,status,primary_color,secondary_color)
  values(auth.uid(),trim(p_title),p_slug,p_layout,p_event_type,case when p_event_type='roulette' then 'active' else 'draft' end,p_primary_color,p_secondary_color)
  returning id into v_id;

  if p_event_type='roulette' then
    insert into roleta.prizes(event_id,title,symbol,weight,kind,coupon_prefix) values
      (v_id,'Chocolate','🍫',30,'gift',null),
      (v_id,'Gire novamente','✦',10,'spin_again',null),
      (v_id,'Cupom 10% OFF','🎟️',40,'coupon','TOM10'),
      (v_id,'Cupom 20% OFF','🏷️',20,'coupon','TOM20');
  end if;
  return v_id;
end $$;
revoke all on function public.roleta_create_event(text,text,text,text,text,text) from public, anon;
grant execute on function public.roleta_create_event(text,text,text,text,text,text) to authenticated;
