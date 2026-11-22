# Piscina Condominiale

Il sito della piscina del condominio: qualità dell'acqua, orari, meteo, avvisi, manutenzione, elenco condomini, tessere con QR e controllo degli ingressi.

- **Sito**: pagina statica (`index.html`) pubblicata con GitHub Pages.
- **Archivio e accessi**: Supabase (database Postgres con regole di accesso, login via email).
- **Meteo**: ogni mattina della stagione, GitHub Actions legge le previsioni di MET Norway e le salva nell'archivio.

## Chi vede cosa

| Ruolo | Accesso |
|---|---|
| Condomino | Solo la Home, più le tessere della propria famiglia |
| Operatore | Bacheca, Manutenzione, Ingressi, consultazione dei condomini |
| Amministratore | Tutto, compresi elenco condomini, impostazioni e persone invitate |

Entra solo chi è nell'elenco **Impostazioni → Persone invitate**. L'accesso avviene con un link o un codice ricevuto via email, senza password.

## Installazione

1. **Supabase**: crea un progetto (regione Central EU). In *SQL Editor* esegui `supabase/schema.sql`, poi aggiungi il primo amministratore:
   Poi esegui `supabase/dati-iniziali.sql` (orari, regolamento e impostazioni già decisi) e aggiungi il primo amministratore:
   ```sql
   insert into public.utenti (email, nome, ruolo) values ('tua@email.it', 'Il tuo nome', 'admin');
   ```
2. **Accesso via email** (*Authentication*):
   - *URL Configuration*: Site URL = indirizzo del sito (es. `https://utente.github.io/piscina-condominiale/`), e lo stesso indirizzo in *Redirect URLs*.
   - *Emails → Templates*: per **Magic Link** e **Confirm signup** usa il testo di `supabase/email-accesso.html` (oggetto: «Accesso al sito della piscina»).
   - *Emails → SMTP Settings*: configura un servizio di invio (es. Brevo o Resend). Senza, Supabase manda email solo ai membri del progetto.
3. **Configurazione del sito**: in `config.js` inserisci Project URL e chiave pubblica (anon / publishable).
4. **GitHub Pages**: *Settings → Pages → Deploy from a branch → main / (root)*.
5. **Meteo**: *Settings → Secrets and variables → Actions*, aggiungi `SUPABASE_URL` e `SUPABASE_SERVICE_KEY` (chiave *service_role* o *secret*). Il lavoro `Meteo del giorno` parte da giugno a settembre; si può avviare a mano da *Actions*.

## File

- `index.html` – il sito
- `config.js` – collegamento a Supabase
- `supabase/schema.sql` – tabelle, regole di accesso, funzioni
- `supabase/email-accesso.html` – testo dell'email di accesso
- `meteo/` – lettura delle previsioni e aggiornamento dell'archivio
- `informativa.html` – bozza dell'informativa privacy
