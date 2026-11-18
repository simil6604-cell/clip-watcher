#!/usr/bin/env python3
"""YouTube-Anmeldung (einmalig, im Testmodus alle 7 Tage neu). Läuft auf dem Server, geht vom iPad aus.
Usage:  cd ~/clip-watcher && ./yt_auth.py
1. Den angezeigten Link im Browser (iPad) öffnen, mit dem Kanal-Konto anmelden, zulassen.
2. Danach zeigt der Browser "Seite nicht erreichbar" (localhost). Das ist richtig so!
3. Die komplette Adresse aus der Adresszeile kopieren und hier einfügen.
Der Zugang wird automatisch gespeichert (runs/tokens.json), config.env muss nicht geändert werden."""
import json, os, sys, time, urllib.parse, urllib.request
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import tokens

def load_config():
    p = os.path.join(os.path.dirname(os.path.abspath(__file__)), "config.env")
    if os.path.exists(p):
        for line in open(p):
            if "=" in line and not line.lstrip().startswith("#"):
                k, v = line.strip().split("=", 1)
                os.environ.setdefault(k, v)

load_config()
CID, SECRET = os.environ.get("YT_CLIENT_ID"), os.environ.get("YT_CLIENT_SECRET")
if not CID or not SECRET:
    sys.exit("Zuerst YT_CLIENT_ID und YT_CLIENT_SECRET in config.env eintragen.")
REDIRECT = "http://localhost:8765"
url = "https://accounts.google.com/o/oauth2/v2/auth?" + urllib.parse.urlencode({
    "client_id": CID, "redirect_uri": REDIRECT, "response_type": "code",
    "scope": "https://www.googleapis.com/auth/youtube.upload",
    "access_type": "offline", "prompt": "consent"})

print("\n1) Diesen Link im Browser öffnen und mit dem Kanal-Konto anmelden:\n\n" + url)
print("\n   Bei 'App nicht überprüft': 'Erweitert' -> 'Weiter zu clip-watcher' -> zulassen.")
print("\n2) Der Browser zeigt danach 'Seite nicht erreichbar'. Das ist richtig so.")
back = input("\n3) Die komplette Adresse aus der Adresszeile hier einfügen:\n> ").strip()
code = urllib.parse.parse_qs(urllib.parse.urlparse(back).query).get("code", [""])[0]
if not code:
    sys.exit("In der Adresse wurde kein code= gefunden. Bitte nochmal versuchen.")
data = urllib.parse.urlencode({"code": code, "client_id": CID, "client_secret": SECRET,
                               "redirect_uri": REDIRECT, "grant_type": "authorization_code"}).encode()
try:
    tok = json.load(urllib.request.urlopen("https://oauth2.googleapis.com/token", data, timeout=30))
except urllib.error.HTTPError as e:
    sys.exit("Google hat abgelehnt: " + e.read().decode(errors="replace")[:300])
tokens.put(YT_REFRESH_TOKEN=tok["refresh_token"], YT_AUTH_AT=str(time.time()), YT_REMINDED_AT="0")
print("\n✅ YouTube ist verbunden. Der Zugang ist gespeichert.")
