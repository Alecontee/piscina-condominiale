-- Piscina condominiale: cancellazione automatica del registro ingressi dopo 12 mesi.
-- NON ancora applicato. Si esegue una volta in Supabase > SQL Editor, dopo l'approvazione
-- dell'amministratore. Ripeterlo non fa danni: il lavoro programmato viene sostituito.
--
-- Cosa fa: ogni notte alle 03:30 (ora UTC) cancella le righe della tabella "accessi"
-- (una riga per giorno, con id nel formato AAAA-MM-GG) più vecchie di 12 mesi.
-- Il registro contiene anche gli ospiti e gli ingressi negati, che quindi spariscono insieme.

-- 1) Attiva il programmatore di Supabase (Database > Extensions > pg_cron)
create extension if not exists pg_cron;

-- 2) La funzione di pulizia, richiamabile anche a mano: select public.pulisci_registro_ingressi();
create or replace function public.pulisci_registro_ingressi() returns integer
language plpgsql security definer set search_path = public as $$
declare n integer;
begin
  delete from public.accessi
  where id ~ '^\d{4}-\d{2}-\d{2}$'
    and id::date < (current_date - interval '12 months');
  get diagnostics n = row_count;
  return n;
end $$;

-- Solo il programmatore la usa: nessuno dal sito può richiamarla.
revoke execute on function public.pulisci_registro_ingressi() from public, anon, authenticated;

-- 3) Programma la pulizia ogni notte
select cron.unschedule(jobid) from cron.job where jobname = 'pulizia-registro-ingressi';
select cron.schedule('pulizia-registro-ingressi', '30 3 * * *', $$select public.pulisci_registro_ingressi()$$);

-- Verifica: elenco dei lavori programmati e ultime esecuzioni
-- select jobname, schedule, active from cron.job;
-- select status, return_message, start_time from cron.job_run_details order by start_time desc limit 5;

-- ---------------------------------------------------------------------------
-- FACOLTATIVO, da attivare solo se approvato insieme all'informativa (punto 6):
-- cancella gli account di accesso delle persone rimosse dall'elenco invitati
-- da più di 30 giorni. Togli i due trattini all'inizio di ogni riga per attivarlo.
-- ---------------------------------------------------------------------------
-- create or replace function public.pulisci_account_rimossi() returns integer
-- language plpgsql security definer set search_path = public, auth as $$
-- declare n integer;
-- begin
--   delete from auth.users u
--   where not exists (select 1 from public.utenti t where t.email = lower(u.email))
--     and coalesce(u.last_sign_in_at, u.created_at) < now() - interval '30 days';
--   get diagnostics n = row_count;
--   return n;
-- end $$;
-- revoke execute on function public.pulisci_account_rimossi() from public, anon, authenticated;
-- select cron.unschedule(jobid) from cron.job where jobname = 'pulizia-account-rimossi';
-- select cron.schedule('pulizia-account-rimossi', '45 3 * * *', $$select public.pulisci_account_rimossi()$$);
