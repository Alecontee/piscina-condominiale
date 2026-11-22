"""Aggiornamento mattutino del meteo: legge gli orari dalla Bacheca e, se oggi la piscina è aperta,
scrive le previsioni in pubblico/meteo. Lo esegue GitHub Actions (.github/workflows/meteo.yml).
Variabili: SUPABASE_URL, SUPABASE_SERVICE_KEY (segreti del repository)."""
import json, os, subprocess, sys, tempfile, urllib.request

URL = os.environ["SUPABASE_URL"].rstrip("/")
KEY = os.environ["SUPABASE_SERVICE_KEY"]
LAT = os.environ.get("METEO_LAT", "45.4770")
LON = os.environ.get("METEO_LON", "9.0790")
LUOGO = os.environ.get("METEO_LUOGO", "Seguro, Settimo Milanese")

HEAD = {"apikey": KEY, "Content-Type": "application/json"}
if not KEY.startswith("sb_"):
    HEAD["Authorization"] = f"Bearer {KEY}"

def chiama(metodo, percorso, corpo=None, extra=None):
    req = urllib.request.Request(URL + percorso, method=metodo, headers={**HEAD, **(extra or {})},
                                 data=None if corpo is None else json.dumps(corpo).encode())
    with urllib.request.urlopen(req, timeout=30) as r:
        return r.read().decode() or "null"

righe = json.loads(chiama("GET", "/rest/v1/pubblico?id=eq.bacheca&select=dati"))
bacheca = righe[0]["dati"] if righe else {}
with tempfile.NamedTemporaryFile("w", suffix=".json", delete=False, encoding="utf-8") as f:
    json.dump(bacheca, f)

esito = subprocess.run([sys.executable, "-I", os.path.join(os.path.dirname(os.path.abspath(__file__)), "meteo.py"), f.name, LAT, LON, LUOGO],
                       capture_output=True, text=True)
if esito.returncode == 3:
    print("Oggi nessun aggiornamento:", esito.stderr.strip())
    sys.exit(0)
if esito.returncode != 0:
    print(esito.stderr.strip(), file=sys.stderr)
    sys.exit(1)

dati = json.loads(esito.stdout)
chiama("POST", "/rest/v1/pubblico", [{"id": "meteo", "dati": dati}], {"Prefer": "resolution=merge-duplicates"})
r = dati["riepilogo"]
print(f"Meteo pubblicato: apertura {dati['apertura']['da']}-{dati['apertura']['a']}, minima {r['min']}°, massima {r['max']}°")
