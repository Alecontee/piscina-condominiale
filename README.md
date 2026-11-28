# Piscina Condominiale

Il sito della piscina del condominio: qualità dell'acqua, orari, meteo, avvisi, manutenzione, elenco condomini, tessere con QR e controllo degli ingressi.

- **Sito**: pagina statica (`index.html`) pubblicata con GitHub Pages.
- **Archivio e accessi**: Supabase (database Postgres con regole di accesso, login via email).
- **Meteo**: il sito legge le previsioni dal vivo da Open-Meteo (gratuito, senza chiavi), ogni volta che viene aperto e poi ogni 30 minuti.

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
   - *URL Configuration*: Site URL = indirizzo del sito (`https://alecontee.github.io/piscina-condominiale/`), e lo stesso indirizzo in *Redirect URLs*.
   - *Emails → Templates*: per **Magic Link** e **Confirm signup** usa il testo di `supabase/email-accesso.html` (oggetto: «Il tuo codice per la piscina»). Il sito chiede il codice, non usa il link.
   - *Emails → SMTP Settings*: configura un servizio di invio (es. Brevo o Resend). Senza, Supabase manda email solo ai membri del progetto.
3. **Configurazione del sito**: in `config.js` inserisci Project URL e chiave pubblica (anon / publishable).
4. **GitHub Pages**: *Settings → Pages → Deploy from a branch → main / (root)*.

## File

- `index.html` – il sito
- `config.js` – collegamento a Supabase
- `supabase/schema.sql` – tabelle, regole di accesso, funzioni
- `supabase/email-accesso.html` – testo dell'email di accesso
- `informativa.html` – bozza dell'informativa privacy
- `logo.svg` – logo (palazzina con piscina); `icon.svg`, `icon-scura.svg` e `icon-notte.svg` – icona chiara, scura e notturna (finestre gialle); `icon-180.png`, `icon-512.png` – icone per iPhone e Android
