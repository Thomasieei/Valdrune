-- Valdrune : tables du serveur (à coller dans Supabase > SQL Editor > Run)
-- Avant : Authentication > Sign In / Providers > activer « Allow anonymous sign-ins ».

create table if not exists public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  name text not null default 'Voyageur' check (char_length(name) between 1 and 24),
  power int not null default 0,
  map int not null default 1,
  updated_at timestamptz not null default now()
);

create table if not exists public.saves (
  user_id uuid primary key references auth.users(id) on delete cascade,
  data jsonb not null,
  version text,
  updated_at timestamptz not null default now()
);

create table if not exists public.chat (
  id bigint generated always as identity primary key,
  user_id uuid not null default auth.uid() references auth.users(id) on delete cascade,
  name text not null check (char_length(name) between 1 and 24),
  channel text not null default 'monde' check (channel in ('monde', 'commerce')),
  msg text not null check (char_length(msg) between 1 and 200),
  created_at timestamptz not null default now()
);
create index if not exists chat_id_idx on public.chat (id);

alter table public.profiles enable row level security;
alter table public.saves enable row level security;
alter table public.chat enable row level security;

-- Profils : tout le monde (connecté) peut lire ; chacun ne modifie que le sien
drop policy if exists "profils lisibles" on public.profiles;
create policy "profils lisibles" on public.profiles for select to authenticated using (true);
drop policy if exists "profil perso insert" on public.profiles;
create policy "profil perso insert" on public.profiles for insert to authenticated with check (auth.uid() = id);
drop policy if exists "profil perso update" on public.profiles;
create policy "profil perso update" on public.profiles for update to authenticated using (auth.uid() = id) with check (auth.uid() = id);

-- Sauvegardes : chacun ne voit et n'écrit QUE la sienne
drop policy if exists "sauvegarde perso select" on public.saves;
create policy "sauvegarde perso select" on public.saves for select to authenticated using (auth.uid() = user_id);
drop policy if exists "sauvegarde perso insert" on public.saves;
create policy "sauvegarde perso insert" on public.saves for insert to authenticated with check (auth.uid() = user_id);
drop policy if exists "sauvegarde perso update" on public.saves;
create policy "sauvegarde perso update" on public.saves for update to authenticated using (auth.uid() = user_id) with check (auth.uid() = user_id);

-- Chat : tout le monde lit ; on n'écrit qu'en son propre nom
drop policy if exists "chat lisible" on public.chat;
create policy "chat lisible" on public.chat for select to authenticated using (true);
drop policy if exists "chat ecrire" on public.chat;
create policy "chat ecrire" on public.chat for insert to authenticated with check (auth.uid() = user_id);
