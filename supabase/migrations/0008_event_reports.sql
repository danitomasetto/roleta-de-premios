-- Relatório completo, acessível somente pelo dono de cada evento.
create or replace function public.roleta_get_event_report(p_event_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = roleta, public
as $$
declare
  v_event roleta.events;
begin
  if auth.uid() is null then raise exception 'AUTH_REQUIRED'; end if;
  select * into v_event from roleta.events where id=p_event_id and owner_id=auth.uid();
  if not found then raise exception 'EVENT_NOT_FOUND'; end if;

  if v_event.event_type='list_draw' then
    return jsonb_build_object(
      'event', jsonb_build_object('id',v_event.id,'title',v_event.title,'type',v_event.event_type,'status',v_event.status,'created_at',v_event.created_at),
      'summary', jsonb_build_object('entries',(select count(*) from roleta.list_entries where event_id=v_event.id),'draws',(select count(*) from roleta.list_draws where event_id=v_event.id)),
      'entries', coalesce((select jsonb_agg(to_jsonb(x) order by x.registration_number) from (
        select registration_number,display_name as name,whatsapp,instagram,email,created_at from roleta.list_entries where event_id=v_event.id
      ) x),'[]'::jsonb),
      'winner', coalesce((select jsonb_build_object('registration_number',d.registration_number,'name',e.display_name,'whatsapp',e.whatsapp,'instagram',e.instagram,'email',e.email,'drawn_at',d.drawn_at)
        from roleta.list_draws d join roleta.list_entries e on e.id=d.entry_id where d.event_id=v_event.id),'null'::jsonb)
    );
  end if;

  return jsonb_build_object(
    'event', jsonb_build_object('id',v_event.id,'title',v_event.title,'type',v_event.event_type,'status',v_event.status,'created_at',v_event.created_at),
    'summary', jsonb_build_object(
      'participants',(select count(*) from roleta.participants where event_id=v_event.id),
      'spins',(select count(*) from roleta.spins where event_id=v_event.id),
      'coupons',(select count(*) from roleta.coupons c join roleta.spins s on s.id=c.spin_id where s.event_id=v_event.id)
    ),
    'prizes', coalesce((select jsonb_agg(to_jsonb(x) order by x.title) from (
      select p.title,p.symbol,p.kind,count(s.id) as awarded
      from roleta.prizes p left join roleta.spins s on s.prize_id=p.id
      where p.event_id=v_event.id group by p.id,p.title,p.symbol,p.kind
    ) x),'[]'::jsonb),
    'participants', coalesce((select jsonb_agg(to_jsonb(x) order by x.last_spin desc nulls last,x.name) from (
      select p.full_name as name,p.whatsapp,p.instagram,p.email,count(s.id) as spins,
        coalesce(string_agg(c.code,', ' order by c.created_at) filter (where c.code is not null),'') as coupons,max(s.created_at) as last_spin
      from roleta.participants p left join roleta.spins s on s.participant_id=p.id left join roleta.coupons c on c.spin_id=s.id
      where p.event_id=v_event.id group by p.id,p.full_name,p.whatsapp,p.instagram,p.email
    ) x),'[]'::jsonb),
    'spins', coalesce((select jsonb_agg(to_jsonb(x) order by x.created_at desc) from (
      select s.created_at,p.full_name as name,p.whatsapp,pr.title as prize,pr.symbol,c.code as coupon
      from roleta.spins s join roleta.participants p on p.id=s.participant_id join roleta.prizes pr on pr.id=s.prize_id left join roleta.coupons c on c.spin_id=s.id
      where s.event_id=v_event.id
    ) x),'[]'::jsonb)
  );
end;
$$;

revoke all on function public.roleta_get_event_report(uuid) from public, anon;
grant execute on function public.roleta_get_event_report(uuid) to authenticated;
