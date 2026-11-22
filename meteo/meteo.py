"""Previsioni del giorno per la piscina, solo se oggi è aperta secondo la Bacheca.
Uso: python3 -I meteo.py BACHECA.json LAT LON "Località" > meteo.json
Esce con codice 3 (senza stampare nulla) se oggi la piscina è chiusa o gli orari non sono pubblicati."""
import json, sys, urllib.request
from collections import Counter, defaultdict
from datetime import datetime, timezone, date, timedelta
from zoneinfo import ZoneInfo

bach_path, lat, lon, luogo = sys.argv[1], float(sys.argv[2]), float(sys.argv[3]), sys.argv[4]
tz = ZoneInfo("Europe/Rome")
oggi = datetime.now(tz).date()

try:
    b = json.load(open(bach_path, encoding="utf-8"))
    b = b.get("data", b) if isinstance(b, dict) else {}
except Exception:
    b = {}

def pasqua(y):
    a, bb, c = y % 19, y // 100, y % 100
    d, e, f = bb // 4, bb % 4, (bb + 8) // 25
    g = (bb - f + 1) // 3
    h = (19 * a + bb - d - g + 15) % 30
    i, k = c // 4, c % 4
    l = (32 + 2 * e + 2 * i - h - k) % 7
    m = (a + 11 * h + 22 * l) // 451
    n = h + l - 7 * m + 114
    return date(y, n // 31, n % 31 + 1)

def festivo(d):
    if d.strftime("%m-%d") in {"01-01", "01-06", "04-25", "05-01", "06-02", "08-15", "11-01", "12-08", "12-25", "12-26"}:
        return True
    return d == pasqua(d.year) + timedelta(days=1)

def chiusa(motivo):
    print(f"CHIUSA: {motivo}", file=sys.stderr)
    sys.exit(3)

if b.get("stato") == "chiusa": chiusa("chiusa fino a nuovo avviso")
if b.get("s1") and oggi.isoformat() < b["s1"]: chiusa("fuori stagione")
if b.get("s2") and oggi.isoformat() > b["s2"]: chiusa("stagione conclusa")
if str(b.get("riposo", "")) != "" and int(b["riposo"]) == (oggi.isoweekday() % 7): chiusa("giorno di riposo")
weekend = oggi.weekday() >= 5 or (b.get("festivi", True) is not False and festivo(oggi))
gr = (b.get("we") if weekend else b.get("fer")) or {}
da, a = gr.get("da"), gr.get("a")
if not da or not a: chiusa("orari di oggi non pubblicati")

url = f"https://api.met.no/weatherapi/locationforecast/2.0/compact?lat={lat:.4f}&lon={lon:.4f}"
req = urllib.request.Request(url, headers={"User-Agent": "piscina-condominiale/1.0 (uso privato)"})
with urllib.request.urlopen(req, timeout=30) as r:
    ts = json.load(r)["properties"]["timeseries"]

def sym(d, *keys):
    for k in keys:
        s = d.get(k, {}).get("summary", {}).get("symbol_code")
        if s: return s
    return ""

h_da = int(da[:2]); h_a = int(a[:2]) + (1 if a[3:5] != "00" else 0)
ore = []
for t in ts:
    when = datetime.fromisoformat(t["time"].replace("Z", "+00:00")).astimezone(tz)
    if when.date() == oggi and h_da <= when.hour < h_a and "next_1_hours" in t["data"]:
        d = t["data"]
        ore.append({"t": t["time"], "temp": round(d["instant"]["details"]["air_temperature"], 1),
                    "simbolo": sym(d, "next_1_hours"), "pioggia": d["next_1_hours"]["details"].get("precipitation_amount", 0),
                    "vento": round(d["instant"]["details"].get("wind_speed", 0) * 3.6)})
if not ore:
    print("Nessuna previsione oraria per gli orari di oggi", file=sys.stderr); sys.exit(4)

base = Counter(o["simbolo"].split("_")[0] for o in ore).most_common(1)[0][0]
simbolo = next(o["simbolo"] for o in ore if o["simbolo"].split("_")[0] == base)
riepilogo = {"min": round(min(o["temp"] for o in ore)), "max": round(max(o["temp"] for o in ore)),
             "pioggia": round(sum(o["pioggia"] for o in ore), 1), "ventoMax": max(o["vento"] for o in ore), "simbolo": simbolo}

giorni = defaultdict(lambda: {"temps": [], "pioggia": 0.0, "simbolo": "", "best": 99})
for t in ts:
    when = datetime.fromisoformat(t["time"].replace("Z", "+00:00")).astimezone(tz)
    g = giorni[when.date().isoformat()]
    g["temps"].append(t["data"]["instant"]["details"]["air_temperature"])
    d6 = t["data"].get("next_6_hours", {}).get("details", {})
    if when.hour in (0, 6, 12, 18) and "air_temperature_max" in d6:
        g["temps"] += [d6["air_temperature_max"], d6["air_temperature_min"]]
    if "next_1_hours" in t["data"]:
        g["pioggia"] += t["data"]["next_1_hours"]["details"].get("precipitation_amount", 0)
    elif "next_6_hours" in t["data"] and when.hour in (0, 6, 12, 18):
        g["pioggia"] += d6.get("precipitation_amount", 0)
    s = sym(t["data"], "next_6_hours", "next_1_hours")
    if s and abs(when.hour - 12) < g["best"]:
        g["best"], g["simbolo"] = abs(when.hour - 12), s
prossimi = [{"data": k, "min": round(min(v["temps"])), "max": round(max(v["temps"])), "simbolo": v["simbolo"], "pioggia": round(v["pioggia"], 1)}
            for k, v in sorted(giorni.items()) if k > oggi.isoformat() and len(v["temps"]) >= 3][:5]

print(json.dumps({"luogo": luogo, "fonte": "MET Norway", "data": oggi.isoformat(), "apertura": {"da": da, "a": a},
                  "aggiornato": datetime.now(timezone.utc).isoformat(timespec="seconds").replace("+00:00", "Z"),
                  "riepilogo": riepilogo, "ore": ore, "giorni": prossimi}, ensure_ascii=False))
