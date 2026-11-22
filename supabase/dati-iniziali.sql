-- Dati portati dal sito precedente: impostazioni, orari della Bacheca e regolamento.
-- Si esegue una volta, dopo schema.sql.
insert into public.impostazioni (id, dati) values ('piscina', '{"capienza": 50, "ccMax": 0.4, "clMax": 1.5, "clMin": 0.5, "etaAccomp": 14, "immagine": {"id": null, "url": "img/piscina.jpg", "pos": "center"}, "maxOspiti": 1, "nome": "Piscina condominiale", "oreMax": 12, "phMax": 7.8, "phMin": 7.2, "taMax": 31, "taMin": 27}'::jsonb)
  on conflict (id) do update set dati = excluded.dati;
insert into public.pubblico (id, dati) values
  ('bacheca', '{"aggiornato": "2026-11-22T20:18:29.078Z", "fer": {"a": "20:00", "da": "11:00"}, "festivi": true, "motivo": "", "riposo": "", "s1": "2027-06-07", "s2": "2027-09-05", "stato": "aperta", "we": {"a": "20:00", "da": "10:00"}}'::jsonb),
  ('regolamento', '{"aggiornato": "2026-11-22T19:39:00.975Z", "testo": "Doccia obbligatoria prima di entrare in vasca.\nCuffia obbligatoria in acqua.\nVietato portare oggetti di vetro e consumare cibo a bordo vasca.\nVietato correre sul bordo e tuffarsi.\nI minori di 14 anni entrano solo accompagnati da un adulto.\nOgni famiglia può portare al massimo 1 ospite al giorno, da registrare all''ingresso.\nRispettare gli orari di apertura e le indicazioni degli operatori."}'::jsonb)
  on conflict (id) do update set dati = excluded.dati;
