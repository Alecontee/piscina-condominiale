-- Piscina condominiale: archivio, regole di accesso e funzioni.
-- Si esegue una volta nel progetto Supabase (SQL Editor). Ripeterlo non fa danni.

-- ---------------------------------------------------------------------------
-- Persone invitate e ruoli
-- ---------------------------------------------------------------------------
create table if not exists public.utenti (
  email       text primary key check (email = lower(email)),
  nome        text not null default '',
  ruolo       text not null check (ruolo in ('condomino', 'operatore', 'admin')),
  famiglia_id text,
  creato      timestamptz not null default now()
);

-- Ruolo di chi sta usando il sito (null = non invitato)
create or replace function public.mio_ruolo() returns text
language sql stable security definer set search_path = public as $$
  select ruolo from public.utenti where email = lower(coalesce(auth.jwt() ->> 'email', ''))
$$;
create or replace function public.is_invitato() returns boolean language sql stable as $$ select public.mio_ruolo() is not null $$;
create or replace function public.is_staff()    returns boolean language sql stable as $$ select coalesce(public.mio_ruolo() in ('operatore', 'admin'), false) $$;
create or replace function public.is_admin()    returns boolean language sql stable as $$ select coalesce(public.mio_ruolo() = 'admin', false) $$;

-- ---------------------------------------------------------------------------
-- Dati del sito: ogni tabella contiene documenti JSON (id + dati)
-- ---------------------------------------------------------------------------
do $$
declare t text;
begin
  foreach t in array array['impostazioni', 'pubblico', 'avvisi', 'letture', 'interventi', 'famiglie', 'accessi'] loop
    execute format('create table if not exists public.%I (
      id         text primary key,
      dati       jsonb not null default ''{}''::jsonb,
      aggiornato timestamptz not null default now()
    )', t);
    execute format('alter table public.%I enable row level security', t);
  end loop;
end $$;

create index if not exists letture_ts on public.letture ((dati ->> 'ts') desc);

create or replace function public.tocca_aggiornato() returns trigger language plpgsql as $$
begin new.aggiornato := now(); return new; end $$;
do $$
declare t text;
begin
  foreach t in array array['impostazioni', 'pubblico', 'avvisi', 'letture', 'interventi', 'famiglie', 'accessi'] loop
    execute format('drop trigger if exists aggiornato on public.%I', t);
    execute format('create trigger aggiornato before update on public.%I for each row execute function public.tocca_aggiornato()', t);
  end loop;
end $$;

-- ---------------------------------------------------------------------------
-- Regole di accesso
--   condomini invitati: leggono Home (impostazioni, pubblico, avvisi, letture)
--   operatori: in più manutenzione, ingressi, bacheca; leggono le famiglie
--   amministratore: tutto, compresi famiglie, impostazioni e invitati
-- ---------------------------------------------------------------------------
alter table public.utenti enable row level security;

do $$
declare r record;
begin
  for r in select policyname, tablename from pg_policies where schemaname = 'public'
    and tablename in ('utenti', 'impostazioni', 'pubblico', 'avvisi', 'letture', 'interventi', 'famiglie', 'accessi') loop
    execute format('drop policy %I on public.%I', r.policyname, r.tablename);
  end loop;
end $$;

create policy "io e admin leggono" on public.utenti for select using (email = lower(coalesce(auth.jwt() ->> 'email', '')) or public.is_admin());
create policy "admin gestisce"     on public.utenti for all    using (public.is_admin()) with check (public.is_admin());

create policy "invitati leggono" on public.impostazioni for select using (public.is_invitato());
create policy "admin scrive"     on public.impostazioni for all    using (public.is_admin()) with check (public.is_admin());

create policy "invitati leggono" on public.pubblico for select using (public.is_invitato());
create policy "staff scrive"     on public.pubblico for all    using (public.is_staff()) with check (public.is_staff());

create policy "invitati leggono" on public.avvisi for select using (public.is_invitato());
create policy "staff scrive"     on public.avvisi for all    using (public.is_staff()) with check (public.is_staff());

create policy "invitati leggono" on public.letture for select using (public.is_invitato());
create policy "staff scrive"     on public.letture for all    using (public.is_staff()) with check (public.is_staff());

create policy "staff legge e scrive" on public.interventi for all using (public.is_staff()) with check (public.is_staff());
create policy "staff legge e scrive" on public.accessi    for all using (public.is_staff()) with check (public.is_staff());

create policy "staff legge"  on public.famiglie for select using (public.is_staff());
create policy "admin scrive" on public.famiglie for all    using (public.is_admin()) with check (public.is_admin());

-- La famiglia del condomino collegato (per mostrargli le sue tessere)
create or replace function public.mia_famiglia() returns jsonb
language sql stable security definer set search_path = public as $$
  select jsonb_build_object('id', f.id) || f.dati
  from public.famiglie f join public.utenti u on u.famiglia_id = f.id
  where u.email = lower(coalesce(auth.jwt() ->> 'email', ''))
$$;

-- ---------------------------------------------------------------------------
-- Aggiornamenti in tempo reale
-- ---------------------------------------------------------------------------
do $$
declare t text;
begin
  foreach t in array array['impostazioni', 'pubblico', 'avvisi', 'letture', 'interventi', 'famiglie', 'accessi', 'utenti'] loop
    begin
      execute format('alter publication supabase_realtime add table public.%I', t);
    exception when duplicate_object then null;
    end;
  end loop;
end $$;

-- ---------------------------------------------------------------------------
-- Immagine della Home (archivio file pubblico, solo l'amministratore carica)
-- ---------------------------------------------------------------------------
insert into storage.buckets (id, name, public) values ('immagini', 'immagini', true)
on conflict (id) do update set public = true;

drop policy if exists "admin carica immagini" on storage.objects;
drop policy if exists "admin modifica immagini" on storage.objects;
drop policy if exists "admin elimina immagini" on storage.objects;
create policy "admin carica immagini"   on storage.objects for insert with check (bucket_id = 'immagini' and public.is_admin());
create policy "admin modifica immagini" on storage.objects for update using (bucket_id = 'immagini' and public.is_admin());
create policy "admin elimina immagini"  on storage.objects for delete using (bucket_id = 'immagini' and public.is_admin());
