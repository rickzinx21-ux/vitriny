-- Vitriny / Supabase PostgreSQL
-- Execute no SQL Editor de um projeto Supabase novo.
create extension if not exists pgcrypto;

create type public.store_status as enum ('pending','approved','rejected','blocked');
create type public.favorite_target as enum ('store','product');

create table public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  full_name text,
  phone text,
  is_blocked boolean not null default false,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table public.categories (
  id uuid primary key default gen_random_uuid(),
  name text not null unique,
  slug text not null unique,
  kind text not null default 'store' check (kind in ('store','product','both')),
  is_active boolean not null default true,
  created_at timestamptz not null default now()
);

create table public.stores (
  id uuid primary key default gen_random_uuid(),
  owner_id uuid not null references auth.users(id) on delete cascade,
  name text not null,
  slug text unique,
  category_id uuid references public.categories(id),
  category text,
  description text,
  logo_url text,
  cover_url text,
  address text,
  neighborhood text,
  city text,
  state text,
  postal_code text,
  phone text,
  whatsapp text,
  opening_hours jsonb not null default '{}'::jsonb,
  latitude double precision,
  longitude double precision,
  instagram text,
  facebook text,
  website text,
  status public.store_status not null default 'pending',
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint store_coordinates_pair check ((latitude is null and longitude is null) or (latitude between -90 and 90 and longitude between -180 and 180))
);
create index stores_owner_idx on public.stores(owner_id);
create index stores_status_city_idx on public.stores(status, city);

create table public.products (
  id uuid primary key default gen_random_uuid(),
  store_id uuid not null references public.stores(id) on delete cascade,
  category_id uuid references public.categories(id),
  name text not null,
  description text,
  price numeric(12,2) not null check (price >= 0),
  promo_price numeric(12,2) check (promo_price is null or (promo_price >= 0 and promo_price < price)),
  stock integer check (stock is null or stock >= 0),
  image_url text,
  images jsonb not null default '[]'::jsonb,
  is_active boolean not null default true,
  is_featured boolean not null default false,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create index products_store_idx on public.products(store_id);
create index products_active_idx on public.products(is_active);

create table public.favorites (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  target_type public.favorite_target not null,
  target_id uuid not null,
  created_at timestamptz not null default now(),
  unique(user_id,target_type,target_id)
);

create table public.plans (
  id uuid primary key default gen_random_uuid(),
  code text not null unique check (code in ('basic','professional','premium')),
  name text not null,
  description text,
  price numeric(12,2),
  product_limit integer,
  features jsonb not null default '{}'::jsonb,
  is_active boolean not null default true,
  created_at timestamptz not null default now()
);
insert into public.plans(code,name,description,price,product_limit) values
('basic','Básico','Plano gratuito com limite configurável.',0,20),
('professional','Profissional','Plano pago. Valor a definir pelo proprietário.',null, null),
('premium','Premium','Plano pago. Valor a definir pelo proprietário.',null, null)
on conflict(code) do nothing;

create table public.subscriptions (
  id uuid primary key default gen_random_uuid(),
  store_id uuid not null references public.stores(id) on delete cascade,
  plan_id uuid not null references public.plans(id),
  status text not null default 'trialing' check(status in ('trialing','active','past_due','canceled','expired')),
  provider text,
  provider_subscription_id text,
  current_period_start timestamptz,
  current_period_end timestamptz,
  created_at timestamptz not null default now()
);

create table public.payments (
  id uuid primary key default gen_random_uuid(),
  subscription_id uuid references public.subscriptions(id),
  store_id uuid not null references public.stores(id),
  amount numeric(12,2) not null check(amount >= 0),
  currency text not null default 'BRL',
  status text not null check(status in ('pending','paid','failed','refunded')),
  provider text,
  provider_payment_id text,
  paid_at timestamptz,
  created_at timestamptz not null default now()
);

create table public.store_views (
  id uuid primary key default gen_random_uuid(),
  store_id uuid not null references public.stores(id) on delete cascade,
  viewer_id uuid references auth.users(id) on delete set null,
  viewed_at timestamptz not null default now()
);
create table public.product_views (
  id uuid primary key default gen_random_uuid(),
  product_id uuid not null references public.products(id) on delete cascade,
  viewer_id uuid references auth.users(id) on delete set null,
  viewed_at timestamptz not null default now()
);

create table public.banners (
  id uuid primary key default gen_random_uuid(),
  title text not null,
  image_url text not null,
  target_url text,
  starts_at timestamptz,
  ends_at timestamptz,
  is_active boolean not null default true,
  created_at timestamptz not null default now()
);

create table public.admin_users (
  user_id uuid primary key references auth.users(id) on delete cascade,
  role text not null default 'owner' check(role in ('owner','admin','moderator')),
  created_at timestamptz not null default now()
);

-- Profile creation from Auth signup metadata.
create or replace function public.handle_new_user()
returns trigger language plpgsql security definer set search_path = '' as $$
begin
  insert into public.profiles(id,full_name)
  values(new.id, new.raw_user_meta_data ->> 'full_name')
  on conflict(id) do nothing;
  return new;
end;
$$;
drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created after insert on auth.users
for each row execute procedure public.handle_new_user();

create or replace function public.is_admin()
returns boolean language sql stable security definer set search_path = '' as $$
  select exists(select 1 from public.admin_users where user_id = auth.uid());
$$;

create or replace function public.owns_store(store_uuid uuid)
returns boolean language sql stable security definer set search_path = '' as $$
  select exists(select 1 from public.stores where id = store_uuid and owner_id = auth.uid());
$$;

-- Impede que o lojista aprove/desbloqueie a própria loja alterando colunas protegidas.
create or replace function public.guard_store_moderation_fields()
returns trigger language plpgsql security definer set search_path = '' as $$
begin
  if old.owner_id = auth.uid() and not public.is_admin() then
    if new.status is distinct from old.status or new.is_active is distinct from old.is_active or new.owner_id is distinct from old.owner_id then
      raise exception 'Somente a administração pode alterar aprovação, bloqueio ou proprietário da loja.';
    end if;
  end if;
  return new;
end;
$$;
drop trigger if exists protect_store_moderation_fields on public.stores;
create trigger protect_store_moderation_fields before update on public.stores
for each row execute function public.guard_store_moderation_fields();

alter table public.profiles enable row level security;
alter table public.categories enable row level security;
alter table public.stores enable row level security;
alter table public.products enable row level security;
alter table public.favorites enable row level security;
alter table public.plans enable row level security;
alter table public.subscriptions enable row level security;
alter table public.payments enable row level security;
alter table public.store_views enable row level security;
alter table public.product_views enable row level security;
alter table public.banners enable row level security;
alter table public.admin_users enable row level security;

create policy "profiles select self or admin" on public.profiles for select using(id=auth.uid() or public.is_admin());
create policy "profiles update self or admin" on public.profiles for update using(id=auth.uid() or public.is_admin()) with check(id=auth.uid() or public.is_admin());

create policy "active categories public read" on public.categories for select using(is_active or public.is_admin());
create policy "admin manages categories" on public.categories for all using(public.is_admin()) with check(public.is_admin());

create policy "approved stores public read" on public.stores for select using((status='approved' and is_active) or owner_id=auth.uid() or public.is_admin());
create policy "owner creates own store" on public.stores for insert with check(owner_id=auth.uid() and status='pending');
create policy "owner updates own store" on public.stores for update using(owner_id=auth.uid() or public.is_admin()) with check(owner_id=auth.uid() or public.is_admin());
create policy "admin deletes stores" on public.stores for delete using(public.is_admin());

create policy "active products public read" on public.products for select using(
  (is_active and exists(select 1 from public.stores s where s.id=store_id and s.status='approved' and s.is_active))
  or public.owns_store(store_id) or public.is_admin()
);
create policy "owner manages own products" on public.products for all using(public.owns_store(store_id) or public.is_admin()) with check(public.owns_store(store_id) or public.is_admin());

create policy "favorites private" on public.favorites for select using(user_id=auth.uid() or public.is_admin());
create policy "users manage own favorites" on public.favorites for all using(user_id=auth.uid()) with check(user_id=auth.uid());

create policy "plans public read" on public.plans for select using(is_active or public.is_admin());
create policy "admin manages plans" on public.plans for all using(public.is_admin()) with check(public.is_admin());
create policy "store owner reads subscriptions" on public.subscriptions for select using(public.owns_store(store_id) or public.is_admin());
create policy "admin manages subscriptions" on public.subscriptions for all using(public.is_admin()) with check(public.is_admin());
create policy "store owner reads payments" on public.payments for select using(public.owns_store(store_id) or public.is_admin());
create policy "admin manages payments" on public.payments for all using(public.is_admin()) with check(public.is_admin());

create policy "views public insert" on public.store_views for insert with check(true);
create policy "views owner or admin read" on public.store_views for select using(public.owns_store(store_id) or public.is_admin());
create policy "product views public insert" on public.product_views for insert with check(true);
create policy "product views owner or admin read" on public.product_views for select using(
  exists(select 1 from public.products p where p.id=product_id and public.owns_store(p.store_id)) or public.is_admin()
);
create policy "active banners public read" on public.banners for select using(is_active or public.is_admin());
create policy "admin manages banners" on public.banners for all using(public.is_admin()) with check(public.is_admin());
create policy "admins read admin list" on public.admin_users for select using(user_id=auth.uid() or public.is_admin());
create policy "only admin manages admin list" on public.admin_users for all using(public.is_admin()) with check(public.is_admin());

-- Storage: bucket de imagens público para leitura, escrita restrita ao dono da pasta.
insert into storage.buckets(id,name,public,file_size_limit,allowed_mime_types)
values('vitriny-media','vitriny-media',true,5242880,array['image/jpeg','image/png','image/webp'])
on conflict(id) do nothing;

create policy "public reads vitriny media" on storage.objects for select using(bucket_id='vitriny-media');
create policy "authenticated uploads own folder" on storage.objects for insert to authenticated
with check(bucket_id='vitriny-media' and (storage.foldername(name))[1]=auth.uid()::text);
create policy "owner updates own media" on storage.objects for update to authenticated
using(bucket_id='vitriny-media' and (storage.foldername(name))[1]=auth.uid()::text)
with check(bucket_id='vitriny-media' and (storage.foldername(name))[1]=auth.uid()::text);
create policy "owner deletes own media" on storage.objects for delete to authenticated
using(bucket_id='vitriny-media' and (storage.foldername(name))[1]=auth.uid()::text);

-- IMPORTANT: depois de criar a conta do proprietário, execute no SQL Editor:
-- insert into public.admin_users(user_id,role)
-- select id,'owner' from auth.users where email='SEU_EMAIL_DE_LOGIN';
-- Não habilite cadastro público de admin. Nunca exponha service_role no frontend.
