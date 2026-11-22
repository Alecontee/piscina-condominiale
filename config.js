// Collegamento all'archivio Supabase.
// Questi due valori sono pubblici per natura: i dati sono protetti dalle regole di accesso in supabase/schema.sql.
window.PISCINA_CONFIG = {
  url: 'INSERISCI_PROJECT_URL',        // es. https://abcdxyz.supabase.co
  anonKey: 'INSERISCI_CHIAVE_PUBBLICA' // la chiave "anon public" o "publishable"
};
