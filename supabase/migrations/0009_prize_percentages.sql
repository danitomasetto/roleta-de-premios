-- Prêmios da roleta são percentuais inteiros e devem fechar 100%.
drop function if exists public.roleta_create_event(text,text,text,text,text,text);

create function public.roleta_create_event(
  p_title text,
  p_slug text,
  p_layout text default 'slots',
  p_primary_color text default '#681D30',
  p_secondary_color text default '#C79339',
  p_event_type text default 'roulette',
  p_prizes jsonb default null
)
returns uuid language plpgsql security definer set search_path = roleta, public as $$
declare v_id uuid; v_total integer; v_count integer;
begin
  if auth.uid() is null then raise exception 'AUTH_REQUIRED'; end if;
  if coalesce(trim(p_title),'')='' or p_slug !~ '^[a-z0-9-]{3,80}$' then raise exception 'INVALID_EVENT'; end if;
  if p_layout not in ('slots','wheel') or p_event_type not in ('roulette','list_draw') then raise exception 'INVALID_EVENT_TYPE'; end if;

  if p_event_type='roulette' then
    if p_prizes is null then
      p_prizes:='[{"title":"Chocolate","kind":"gift","weight":30},{"title":"Gire novamente","kind":"spin_again","weight":10},{"title":"Cupom 10% OFF","kind":"coupon","weight":40},{"title":"Cupom 20% OFF","kind":"coupon","weight":20}]'::jsonb;
    end if;
    if jsonb_typeof(p_prizes)<>'array' or jsonb_array_length(p_prizes)=0 then raise exception 'INVALID_PRIZES'; end if;
    if exists(select 1 from jsonb_array_elements(p_prizes) item where coalesce(trim(item->>'title'),'')='' or item->>'kind' not in ('gift','coupon','spin_again') or coalesce(item->>'weight','') !~ '^(100|[1-9][0-9]?)$') then raise exception 'INVALID_PRIZES'; end if;
    select count(*),sum((item->>'weight')::integer) into v_count,v_total from jsonb_array_elements(p_prizes) item;
    if v_count=0 or v_total<>100 then raise exception 'PRIZE_PERCENTAGES_MUST_TOTAL_100'; end if;
  end if;

  insert into roleta.events(owner_id,title,slug,layout,event_type,status,primary_color,secondary_color)
  values(auth.uid(),trim(p_title),p_slug,p_layout,p_event_type,case when p_event_type='roulette' then 'active' else 'draft' end,p_primary_color,p_secondary_color)
  returning id into v_id;

  if p_event_type='roulette' then
    insert into roleta.prizes(event_id,title,symbol,weight,kind,coupon_prefix)
    select v_id,trim(item->>'title'),case item->>'kind' when 'gift' then '🎁' when 'coupon' then '🎟️' else '✦' end,(item->>'weight')::integer,item->>'kind',
      case when item->>'kind'='coupon' then upper(left(regexp_replace(item->>'title','[^A-Za-z0-9]','','g'),12)) else null end
    from jsonb_array_elements(p_prizes) item;
  end if;
  return v_id;
end $$;

revoke all on function public.roleta_create_event(text,text,text,text,text,text,jsonb) from public, anon;
grant execute on function public.roleta_create_event(text,text,text,text,text,text,jsonb) to authenticated;
