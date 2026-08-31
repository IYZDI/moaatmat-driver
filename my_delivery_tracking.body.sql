
declare v_uid uuid := auth.uid();
begin
  if v_uid is null then return; end if;

  return query
  select od.id, od.status, od.eta,
         case when od.assigned_driver is null then null
              else coalesce(nullif(btrim(d.name), ''), 'مندوب التوصيل') end,
         coalesce(d.phone, od.driver_phone),
         d.last_lat, d.last_lng, d.last_loc_at,
         coalesce(ao.lat, asu.lat, od.dest_lat, od.lat),
         coalesce(ao.lng, asu.lng, od.dest_lng, od.lng),
         -- 0367: النافذةُ المتعاقَد عليها بجانب الوقت المتوقَّع — فيقارن
         --   العميلُ ما يراه بما وُعد به، لا بما يتذكّره.
         s.delivery_slot_label
    from public.order_deliveries od
    left join public.drivers d            on d.id  = od.assigned_driver
    left join public.orders  o            on o.id  = od.order_id
    left join public.app_users uo         on uo.id = o.user_id
    left join public.addresses ao         on ao.id = o.address_id
    left join public.subscription_days sd on sd.id = od.subscription_day_id
    left join public.subscriptions s      on s.id  = sd.subscription_id
    left join public.app_users us         on us.id = s.user_id
    left join public.addresses asu        on asu.id = coalesce(sd.address_id, s.address_id)
   where od.id = p_delivery
     and (uo.auth_user_id = v_uid or us.auth_user_id = v_uid)
     -- 0336: النافذةُ الوحيدة. قبلَها لا مندوبَ في الطريق، وبعدَها موقعُه
     --       يخصّ زبونًا آخر.
     and od.status = 'out_for_delivery';
end
