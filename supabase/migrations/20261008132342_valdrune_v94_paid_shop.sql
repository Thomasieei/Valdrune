grant all on public.valdrune_profiles, public.valdrune_cloud_saves, public.valdrune_chat to service_role;
create policy valdrune_profiles_public_ranking on public.valdrune_profiles for select to authenticated using (true);
create table public.valdrune_catalog (
  id text primary key, name text not null,
  kind text not null check (kind in ('cash','crowns')),
  amount_cents integer not null default 0, currency text not null default 'eur' check (currency = 'eur'),
  crowns_reward integer not null default 0, crowns_price integer not null default 0,
  active boolean not null default true,
  check ((kind = 'cash' and amount_cents > 0 and crowns_reward > 0 and crowns_price = 0)
    or (kind = 'crowns' and crowns_price > 0 and amount_cents = 0 and crowns_reward = 0))
);
create table public.valdrune_wallets (
  user_id uuid primary key references auth.users(id) on delete cascade,
  crowns integer not null default 0, -- may be negative after refund of already-spent crowns
  premium_until bigint not null default 0,
  starter_purchased boolean not null default false,
  revision bigint not null default 0,
  updated_at timestamptz not null default now()
);
create table public.valdrune_orders (
  id uuid primary key, user_id uuid not null references auth.users(id) on delete cascade,
  offer_id text not null references public.valdrune_catalog(id),
  amount_cents integer not null check (amount_cents > 0), currency text not null check (currency = 'eur'),
  crowns_reward integer not null check (crowns_reward > 0), crowns_refunded integer not null default 0,
  status text not null default 'created' check (status in ('created','checkout_open','paid','expired','failed','refunded')),
  stripe_session_id text unique, stripe_payment_intent_id text unique, checkout_url text,
  livemode boolean not null,
  fulfilled_at timestamptz, delivery_claimed_at timestamptz,
  created_at timestamptz not null default now(), updated_at timestamptz not null default now()
);
create unique index valdrune_starter_once_idx on public.valdrune_orders(user_id)
  where offer_id = 'pack_debut' and status in ('created','checkout_open','paid','refunded');
create index valdrune_orders_owner_idx on public.valdrune_orders(user_id, created_at desc);
create table public.valdrune_spends (
  id uuid primary key, user_id uuid not null references auth.users(id) on delete cascade,
  offer_id text not null references public.valdrune_catalog(id),
  free_part integer not null check (free_part >= 0), paid_part integer not null check (paid_part > 0),
  status text not null default 'pending' check (status in ('pending','applied','cancelled')),
  created_at timestamptz not null default now(), updated_at timestamptz not null default now()
);
create index valdrune_spends_owner_idx on public.valdrune_spends(user_id, status);
alter table public.valdrune_catalog enable row level security;
alter table public.valdrune_wallets enable row level security;
alter table public.valdrune_orders enable row level security;
alter table public.valdrune_spends enable row level security;
create policy valdrune_catalog_read on public.valdrune_catalog for select to authenticated using (active);
create policy valdrune_wallet_read on public.valdrune_wallets for select to authenticated using ((select auth.uid()) = user_id);
create policy valdrune_orders_read on public.valdrune_orders for select to authenticated using ((select auth.uid()) = user_id);
create policy valdrune_spends_read on public.valdrune_spends for select to authenticated using ((select auth.uid()) = user_id);
revoke all on public.valdrune_catalog, public.valdrune_wallets, public.valdrune_orders, public.valdrune_spends from anon, authenticated;
grant select on public.valdrune_catalog, public.valdrune_wallets, public.valdrune_orders, public.valdrune_spends to authenticated;
grant all on public.valdrune_catalog, public.valdrune_wallets, public.valdrune_orders, public.valdrune_spends to service_role;

create function public.valdrune_wallet_sync(p_user_id uuid) returns jsonb
language plpgsql security invoker set search_path = '' as $$
declare w public.valdrune_wallets; deliveries jsonb;
begin
  insert into public.valdrune_wallets(user_id) values (p_user_id) on conflict do nothing;
  select * into w from public.valdrune_wallets where user_id = p_user_id;
  select coalesce(jsonb_agg(d), '[]'::jsonb) into deliveries from (
    select jsonb_build_object('id',id,'kind','starter','offer_id',offer_id) as d
      from public.valdrune_orders where user_id=p_user_id and status='paid' and offer_id='pack_debut' and delivery_claimed_at is null
    union all
    select jsonb_build_object('id',id,'kind','spend','offer_id',offer_id,'free_part',free_part,'paid_part',paid_part) as d
      from public.valdrune_spends where user_id=p_user_id and status='pending'
  ) q;
  return jsonb_build_object('wallet',to_jsonb(w)-'user_id','deliveries',deliveries,'orders',
    (select coalesce(jsonb_agg(to_jsonb(q)),'[]'::jsonb) from
      (select id,offer_id,status from public.valdrune_orders where user_id=p_user_id order by created_at desc limit 30) q));
end $$;

create function public.valdrune_reserve_spend(p_user_id uuid,p_request_id uuid,p_offer_id text,p_free_part integer) returns jsonb
language plpgsql security invoker set search_path = '' as $$
declare w public.valdrune_wallets; s public.valdrune_spends; price integer; paid integer;
begin
  insert into public.valdrune_wallets(user_id) values (p_user_id) on conflict do nothing;
  select * into w from public.valdrune_wallets where user_id=p_user_id for update;
  select * into s from public.valdrune_spends where id=p_request_id;
  if found then
    if s.user_id<>p_user_id or s.offer_id<>p_offer_id or s.free_part<>p_free_part then raise exception 'Request conflict'; end if;
    return public.valdrune_wallet_sync(p_user_id);
  end if;
  select crowns_price into price from public.valdrune_catalog where id=p_offer_id and active and kind='crowns';
  if price is null or p_free_part is null or p_free_part<0 or p_free_part>=price then raise exception 'Invalid offer or contribution'; end if;
  paid=price-p_free_part;
  if w.crowns<paid then raise exception 'Insufficient paid crowns'; end if;
  if exists (select 1 from public.valdrune_spends where user_id=p_user_id and status='pending') then raise exception 'Delivery pending'; end if;
  update public.valdrune_wallets set crowns=crowns-paid,revision=revision+1,updated_at=now() where user_id=p_user_id;
  insert into public.valdrune_spends(id,user_id,offer_id,free_part,paid_part) values(p_request_id,p_user_id,p_offer_id,p_free_part,paid);
  return public.valdrune_wallet_sync(p_user_id);
end $$;

create function public.valdrune_finish_delivery(p_user_id uuid,p_receipt_id uuid,p_state jsonb,p_cancel boolean default false) returns jsonb
language plpgsql security invoker set search_path = '' as $$
declare s public.valdrune_spends; o public.valdrune_orders;
begin
  -- One lock order (wallet, then receipt) across debit, delivery and refund.
  perform 1 from public.valdrune_wallets where user_id=p_user_id for update;
  select * into s from public.valdrune_spends where id=p_receipt_id and user_id=p_user_id for update;
  if s.id is null then
    select * into o from public.valdrune_orders where id=p_receipt_id and user_id=p_user_id for update;
    if o.id is null or o.status<>'paid' or o.offer_id<>'pack_debut' or p_cancel then raise exception 'Unknown delivery'; end if;
    if o.delivery_claimed_at is not null then return public.valdrune_wallet_sync(p_user_id); end if;
  elsif s.status<>'pending' then return public.valdrune_wallet_sync(p_user_id);
  end if;
  if p_cancel then
    update public.valdrune_wallets set crowns=crowns+s.paid_part,revision=revision+1,updated_at=now() where user_id=p_user_id;
    update public.valdrune_spends set status='cancelled',updated_at=now() where id=s.id;
  else
    if p_state is null or jsonb_typeof(p_state)<>'object' or p_state->>'v'<>'2'
      or not coalesce((p_state->'_commerce_receipts') ? p_receipt_id::text,false)
      or p_state->>'_commerce_uid' is distinct from p_user_id::text then raise exception 'Invalid delivery save'; end if;
    insert into public.valdrune_cloud_saves(user_id,state,client_updated_at,version)
      values(p_user_id,p_state,(extract(epoch from now())*1000)::bigint,'9.4')
      on conflict(user_id) do update set state=excluded.state,client_updated_at=excluded.client_updated_at,version=excluded.version;
    if s.id is not null then update public.valdrune_spends set status='applied',updated_at=now() where id=s.id;
    else update public.valdrune_orders set delivery_claimed_at=now(),updated_at=now() where id=o.id; end if;
  end if;
  return public.valdrune_wallet_sync(p_user_id);
end $$;

-- This RPC is called ONLY by the signature-verified Stripe webhook.
create function public.valdrune_stripe_event(p_type text,p_object jsonb) returns jsonb
language plpgsql security invoker set search_path = '' as $$
declare o public.valdrune_orders; owner_id uuid; returned integer; delta integer; pi text;
begin
  if p_type='charge.refunded' then
    pi=p_object->>'payment_intent';
    select user_id into owner_id from public.valdrune_orders where stripe_payment_intent_id=pi;
    if owner_id is null then return jsonb_build_object('ignored',true); end if;
    perform 1 from public.valdrune_wallets where user_id=owner_id for update;
    select * into o from public.valdrune_orders where stripe_payment_intent_id=pi for update;
    if o.fulfilled_at is null then return jsonb_build_object('ignored',true); end if;
    if (p_object->>'amount')::integer<>o.amount_cents or lower(p_object->>'currency')<>o.currency
      or (p_object->>'livemode')::boolean<>o.livemode then raise exception 'Refund mismatch'; end if;
    returned=least(o.crowns_reward,ceil(o.crowns_reward::numeric*(p_object->>'amount_refunded')::integer/o.amount_cents)::integer);
    delta=greatest(0,returned-o.crowns_refunded);
    update public.valdrune_wallets set crowns=crowns-delta,
      premium_until=case when o.offer_id='pack_debut' and returned=o.crowns_reward then 0 else premium_until end,
      revision=revision+1,updated_at=now() where user_id=o.user_id;
    update public.valdrune_orders set crowns_refunded=greatest(crowns_refunded,returned),
      status=case when returned=crowns_reward then 'refunded' else status end,updated_at=now() where id=o.id;
    return jsonb_build_object('ok',true);
  end if;
  if p_object->'metadata'->>'app' is distinct from 'valdrune' then return jsonb_build_object('ignored',true); end if;
  select user_id into owner_id from public.valdrune_orders where id=(p_object->'metadata'->>'order_id')::uuid;
  if owner_id is null then raise exception 'Unknown Valdrune order'; end if;
  perform 1 from public.valdrune_wallets where user_id=owner_id for update;
  select * into o from public.valdrune_orders where id=(p_object->'metadata'->>'order_id')::uuid for update;
  if p_object->'metadata'->>'user_id' is distinct from o.user_id::text
    or p_object->'metadata'->>'offer_id' is distinct from o.offer_id
    or (p_object->>'livemode')::boolean is distinct from o.livemode
    or (o.stripe_session_id is not null and o.stripe_session_id<>p_object->>'id') then raise exception 'Order mismatch'; end if;
  if p_type in ('checkout.session.completed','checkout.session.async_payment_succeeded') then
    if p_object->>'payment_status' is distinct from 'paid' then return jsonb_build_object('pending',true); end if;
    if (p_object->>'amount_total')::integer is distinct from o.amount_cents
      or lower(p_object->>'currency') is distinct from o.currency then raise exception 'Amount mismatch'; end if;
    if o.fulfilled_at is not null or o.status='refunded' then return jsonb_build_object('duplicate',true); end if;
    update public.valdrune_wallets set crowns=crowns+o.crowns_reward,
      premium_until=case when o.offer_id='pack_debut' then greatest(premium_until,(extract(epoch from now()))::bigint,
        coalesce((select (state->>'premium_until')::bigint from public.valdrune_cloud_saves where user_id=o.user_id),0))+259200 else premium_until end,
      starter_purchased=starter_purchased or o.offer_id='pack_debut',revision=revision+1,updated_at=now() where user_id=o.user_id;
    update public.valdrune_orders set status='paid',stripe_session_id=p_object->>'id',
      stripe_payment_intent_id=p_object->>'payment_intent',fulfilled_at=now(),updated_at=now() where id=o.id;
  elsif p_type in ('checkout.session.expired','checkout.session.async_payment_failed') and o.fulfilled_at is null then
    update public.valdrune_orders set status=case when p_type='checkout.session.expired' then 'expired' else 'failed' end,updated_at=now() where id=o.id;
  end if;
  return jsonb_build_object('ok',true);
end $$;

revoke all on function public.valdrune_wallet_sync(uuid),public.valdrune_reserve_spend(uuid,uuid,text,integer),
  public.valdrune_finish_delivery(uuid,uuid,jsonb,boolean),public.valdrune_stripe_event(text,jsonb) from public,anon,authenticated;
grant execute on function public.valdrune_wallet_sync(uuid),public.valdrune_reserve_spend(uuid,uuid,text,integer),
  public.valdrune_finish_delivery(uuid,uuid,jsonb,boolean),public.valdrune_stripe_event(text,jsonb) to service_role;
notify pgrst, 'reload schema';

insert into public.valdrune_catalog(id,name,kind,amount_cents,currency,crowns_reward,crowns_price) values
('pack_debut','Pack du débutant','cash',99,'eur',300,0),
('c1','Poignée de couronnes','cash',99,'eur',120,0),
('c2','Bourse de couronnes','cash',499,'eur',650,0),
('c3','Coffret de couronnes','cash',999,'eur',1400,0),
('c4','Coffre de couronnes','cash',1999,'eur',3000,0),
('c5','Trésor du roi','cash',4999,'eur',8000,0),
('premium30','Premium · 30 jours','crowns',0,'eur',0,450),
('premium7','Premium · 7 jours','crowns',0,'eur',0,150),
('pierre_eveil','Pierre d''Éveil','crowns',0,'eur',0,60),
('pierre_eveil3','Pierres d''Éveil ×3','crowns',0,'eur',0,150),
('billets','Billets d''arène ×5','crowns',0,'eur',0,25),
('boost1','Boost d''expérience · 1 h','crowns',0,'eur',0,40),
('boost24','Boost d''expérience · 24 h','crowns',0,'eur',0,250),
('maitrise','Parchemin de guerre','crowns',0,'eur',0,180),
('metier','Parchemin d''artisan','crowns',0,'eur',0,150),
('enchant','Parchemin d''enchantement','crowns',0,'eur',0,220),
('auto','Écuyer automatique','crowns',0,'eur',0,600),
('sac','Sac agrandi','crowns',0,'eur',0,120),
('potions','Caisse de potions','crowns',0,'eur',0,30),
('leg','Coffre légendaire','crowns',0,'eur',0,350),
('garde','Garde d''élite','crowns',0,'eur',0,400),
('pegase','Pégase d''Azur','crowns',0,'eur',0,4000),
('m_roi_cerf','Roi-Cerf doré','crowns',0,'eur',0,2600),
('m_taureau','Taureau cuirassé','crowns',0,'eur',0,2200),
('m_loup','Loup de guerre','crowns',0,'eur',0,900),
('m_cheval','Cheval de selle','crowns',0,'eur',0,150),
('classe_dompteur','Classe DOMPTEUR','crowns',0,'eur',0,800),
('lame','Lame de l''Aube +5','crowns',0,'eur',0,2400),
('fendeuse','Fendeuse du Néant +5','crowns',0,'eur',0,2400),
('sceptre','Sceptre Astral +5','crowns',0,'eur',0,2400),
('titan','Rempart du Titan +5','crowns',0,'eur',0,1600),
('set_plate','Plates du Dragon +5','crowns',0,'eur',0,2000),
('set_cuir','Cuir de l''Ombre +5','crowns',0,'eur',0,2000),
('set_tissu','Robe Céleste +5','crowns',0,'eur',0,2000),
('bottes','Bottes de Vent +5','crowns',0,'eur',0,1300),
('art_rage','Idole de rage +3','crowns',0,'eur',0,1500),
('art_vie','Calice de vie +3','crowns',0,'eur',0,1500),
('art_fortune','Anneau de fortune +3','crowns',0,'eur',0,1500),
('res2','Pack d''apprenti T2','crowns',0,'eur',0,60),
('res3','Pack d''artisan T3','crowns',0,'eur',0,200),
('res4','Pack de maître T4','crowns',0,'eur',0,700),
('res5','Pack légendaire T5','crowns',0,'eur',0,2000),
('or1','Bourse d''argent','crowns',0,'eur',0,80),
('or2','Coffre d''argent','crowns',0,'eur',0,600),
('or3','Trésor royal','crowns',0,'eur',0,6000);
