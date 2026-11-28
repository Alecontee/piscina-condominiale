-- Piscina condominiale: turni dei bagnini e area riservata agli amministratori.
-- BOZZA DA RIVEDERE: non è ancora stata eseguita su Supabase.
-- Quando il sito userà le nuove sezioni, si esegue una volta nel SQL Editor del progetto,
-- dopo schema.sql. Ripeterla non fa danni.
--
-- Cosa protegge davvero i dati: queste regole (RLS), non la grafica.
-- Nascondere un pulsante o una sezione nel sito non basta: chi ha la chiave pubblica
-- potrebbe chiedere i dati direttamente al database. Con le regole qui sotto il database
-- risponde solo a chi ha il ruolo giusto.
--
--   turni     operatori e amministratori leggono, solo gli amministratori scrivono
--   mansioni  solo amministratori (lettura e scrittura)
--   acquisti  solo amministratori (lettura e scrittura)
--
-- La vecchia tabella "interventi" (manutenzione straordinaria) resta com'è con i suoi dati:
-- il sito semplicemente non la usa più.

-- ---------------------------------------------------------------------------
-- Tabelle, stesso formato delle altre (id + dati JSON)
-- ---------------------------------------------------------------------------
do $$
declare t text;
begin
  foreach t in array array['turni', 'mansioni', 'acquisti'] loop
    execute format('create table if not exists public.%I (
      id         text primary key,
      dati       jsonb not null default ''{}''::jsonb,
      aggiornato timestamptz not null default now()
    )', t);
    execute format('alter table public.%I enable row level security', t);
    execute format('drop trigger if exists aggiornato on public.%I', t);
    execute format('create trigger aggiornato before update on public.%I for each row execute function public.tocca_aggiornato()', t);
  end loop;
end $$;

create index if not exists turni_data on public.turni ((dati ->> 'data'));

-- ---------------------------------------------------------------------------
-- Regole di accesso
-- ---------------------------------------------------------------------------
do $$
declare p record;
begin
  for p in select policyname, tablename from pg_policies
    where schemaname = 'public' and tablename in ('turni', 'mansioni', 'acquisti') loop
    execute format('drop policy %I on public.%I', p.policyname, p.tablename);
  end loop;
end $$;

create policy "staff legge"  on public.turni for select using (public.is_staff());
create policy "admin scrive" on public.turni for all    using (public.is_admin()) with check (public.is_admin());

create policy "solo admin" on public.mansioni for all using (public.is_admin()) with check (public.is_admin());
create policy "solo admin" on public.acquisti for all using (public.is_admin()) with check (public.is_admin());

grant select, insert, update, delete on public.turni, public.mansioni, public.acquisti to authenticated;
revoke all on public.turni, public.mansioni, public.acquisti from anon;

-- ---------------------------------------------------------------------------
-- Aggiornamenti in tempo reale (rispettano le stesse regole)
-- ---------------------------------------------------------------------------
do $$
declare t text;
begin
  foreach t in array array['turni', 'mansioni', 'acquisti'] loop
    begin
      execute format('alter publication supabase_realtime add table public.%I', t);
    exception when duplicate_object then null;
    end;
  end loop;
end $$;

-- ---------------------------------------------------------------------------
-- FACOLTATIVO, da decidere: bacheca degli operatori
-- Oggi gli operatori possono cambiare tutta la tabella "pubblico" (orari, regolamento,
-- informazioni). Nell'anteprima orari, regolamento e informazioni li cambiano solo gli
-- amministratori. Per farlo rispettare anche dal database, togliere i commenti qui sotto.
-- Gli operatori conservano "bacheca" (serve all'SOS guasti per chiudere la piscina)
-- e "presenze" (il contatore degli ingressi): su quella riga potrebbero ancora
-- cambiare gli orari passando dal database, a meno di separare lo stato aperta/chiusa
-- in una riga a parte.
-- ---------------------------------------------------------------------------
-- drop policy if exists "staff scrive" on public.pubblico;
-- create policy "admin scrive" on public.pubblico for all
--   using (public.is_admin()) with check (public.is_admin());
-- create policy "operatori: stato e presenze" on public.pubblico for all
--   using (public.is_staff() and id in ('bacheca', 'presenze'))
--   with check (public.is_staff() and id in ('bacheca', 'presenze'));
