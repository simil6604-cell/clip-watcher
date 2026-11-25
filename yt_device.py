#!/usr/bin/env python3
"""YouTube-Anmeldung ohne Adresse kopieren (Google "Fernseher"-Anmeldung).
Usage: cd ~/clip-watcher && venv/bin/python yt_device.py
Braucht einen Google-OAuth-Client vom Typ "Fernseher und Geräte mit begrenzter Eingabe".
Fragt Client-ID und Secret ab, zeigt einen kurzen Code (auch per Telegram),
den du auf google.com/device eintippst. Danach ist alles gespeichert."""
import getpass, json, os, sys, time, urllib.error, urllib.parse, urllib.request
HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import tokens

CFG = os.path.join(HERE, "config.env")

def read_cfg():
    d = {}
    if os.path.exists(CFG):
        for l in open(CFG):
            if "=" in l and not l.lstrip().startswith("#"):
                k, v = l.rstrip("\n").split("=", 1); d[k] = v
    return d

def set_cfg(k, v):
    lines = open(CFG).read().splitlines() if os.path.exists(CFG) else []
    lines = [l for l in lines if not l.startswith(k + "=")] + [f"{k}={v}"]
    open(CFG, "w").write("\n".join(lines) + "\n"); os.chmod(CFG, 0o600)

def post(url, fields):
    req = urllib.request.Request(url, urllib.parse.urlencode(fields).encode())
    try:
        return json.load(urllib.request.urlopen(req, timeout=30))
    except urllib.error.HTTPError as e:
        return json.loads(e.read().decode() or "{}")

def telegram(text):
    c = read_cfg()
    if c.get("TELEGRAM_TOKEN") and c.get("TELEGRAM_CHAT_ID"):
        try:
            post(f"https://api.telegram.org/bot{c['TELEGRAM_TOKEN']}/sendMessage",
                 {"chat_id": c["TELEGRAM_CHAT_ID"], "text": text})
        except Exception:
            pass

cid = input("Client-ID vom Fernseher-Client einfügen: ").strip()
sec = getpass.getpass("Clientschlüssel einfügen (man sieht nichts): ").strip()
if not cid or not sec:
    sys.exit("Client-ID oder Schlüssel fehlt.")
print(f"   ✔ Client-ID ({len(cid)} Zeichen) und Schlüssel ({len(sec)} Zeichen) erhalten")

r = post("https://oauth2.googleapis.com/device/code",
         {"client_id": cid, "scope": "https://www.googleapis.com/auth/youtube"})
if "user_code" not in r:
    sys.exit(f"❌ Google lehnt ab: {r.get('error_description') or r.get('error') or r}\n"
             "   Ist der Client vom Typ 'Fernseher und Geräte mit begrenzter Eingabe'?")
url, code = r.get("verification_url", "https://www.google.com/device"), r["user_code"]
print(f"\n👉 Öffne {url} und gib diesen Code ein:\n\n      {code}\n")
print("   Mit dem Kanal-Konto anmelden, 'Weiter' / 'Zulassen' tippen. Ich warte hier ...")
telegram(f"YouTube verbinden:\n1) {url} öffnen\n2) Code eingeben: {code}\n3) Kanal-Konto wählen, zulassen")

wait, deadline = int(r.get("interval", 5)), time.time() + int(r.get("expires_in", 1800))
while time.time() < deadline:
    time.sleep(wait)
    t = post("https://oauth2.googleapis.com/token", {"client_id": cid, "client_secret": sec,
             "device_code": r["device_code"], "grant_type": "urn:ietf:params:oauth:grant-type:device_code"})
    if "refresh_token" in t:
        set_cfg("YT_CLIENT_ID", cid); set_cfg("YT_CLIENT_SECRET", sec)
        tokens.put(YT_REFRESH_TOKEN=t["refresh_token"], YT_AUTH_AT=str(time.time()), YT_REMINDED_AT="0")
        print("\n✅ YouTube ist verbunden. Alles gespeichert.")
        telegram("✅ YouTube ist verbunden")
        sys.exit(0)
    err = t.get("error")
    if err == "slow_down":
        wait += 5
    elif err != "authorization_pending":
        sys.exit(f"❌ Abgebrochen: {t.get('error_description') or err}")
sys.exit("❌ Zeit abgelaufen. Einfach nochmal starten.")
