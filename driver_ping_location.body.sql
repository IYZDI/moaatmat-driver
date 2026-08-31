
declare v_driver uuid;
begin
  v_driver := public._driver_id_by_token(p_token);
  if v_driver is null then raise exception 'جلسة غير صالحة'; end if;
  if p_lat is null or p_lng is null then return; end if;
  update public.drivers
     set last_lat = p_lat, last_lng = p_lng, last_loc_at = now(),
         last_seen_at = now(),
         token_expires_at = now() + interval '90 days'
   where id = v_driver;
end;
