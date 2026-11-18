# Clip Watcher: Schritt für Schritt einrichten

Dauer insgesamt: ca. 2 Stunden. Kosten: nur der Server (ca. 7–10 € im Monat).
Menü-Namen auf den Websites können leicht anders heißen als hier beschrieben.
**Zugangsdaten nie in einen Chat schreiben**, nur in `config.env` auf dem Server.

---

## Schritt 1: GitHub-Repo anlegen (2 Min.)
1. github.com/new öffnen.
2. Name: `clip-watcher`, **Private** auswählen.
3. **Nichts** ankreuzen (kein README, keine .gitignore, keine Lizenz).
4. „Create repository“. Claude den Namen sagen, Claude schiebt den Code hinein.
5. Token für den Server: GitHub → Settings → Developer settings → Personal access tokens →
   Fine-grained tokens → Generate. Nur Repo `clip-watcher`, Berechtigung „Contents: Read“.
   Token sicher notieren (wird in Schritt 3 als Passwort gebraucht).

## Schritt 2: Server mieten (10 Min.)
1. Bei einem Cloud-Anbieter registrieren, z.B. Hetzner Cloud (hetzner.com/cloud).
2. Neuen Server erstellen:
   - Image: **Ubuntu 24.04**
   - Typ: **4 vCPU, 8 GB RAM, mind. 80 GB** (für Untertitel und Aufnahmen)
   - Standort: egal (z.B. Deutschland)
   - Zugang: Root-Passwort per E-Mail oder SSH-Key
3. Die **IP-Adresse** des Servers notieren.

Verbinden:
- Windows: PowerShell öffnen → `ssh root@DEINE-IP`
- Mac: Terminal → `ssh root@DEINE-IP`
- Handy: App „Termius“

## Schritt 3: Programm installieren (15 Min., läuft von selbst)
Auf dem Server eingeben:
```bash
apt update && apt install -y git
git clone https://github.com/simil6604-cell/clip-watcher
cd clip-watcher
sudo ./setup.sh
```
Bei `git clone`: Benutzername = dein GitHub-Name, Passwort = Token aus Schritt 1.

`config.env` bearbeiten (brauchst du in den nächsten Schritten):
```bash
nano ~/clip-watcher/config.env
```
Speichern: `Strg+O`, `Enter`. Schließen: `Strg+X`.

## Schritt 4: Telegram (5 Min.)
1. In Telegram **@BotFather** öffnen (blauer Haken!) → `/newbot`.
2. Namen eingeben, dann einen Benutzernamen, der auf `bot` endet.
3. Den **Token** in `config.env` bei `TELEGRAM_TOKEN=` eintragen.
4. Deinem neuen Bot irgendeine Nachricht schicken („hi“).
5. Im Browser öffnen: `https://api.telegram.org/botDEIN-TOKEN/getUpdates`
   Dort steht `"chat":{"id":123456789` → die Zahl bei `TELEGRAM_CHAT_ID=` eintragen.

## Schritt 5: YouTube (25 Min.)
1. Mit dem Google-Konto, das den YouTube-Kanal hat, console.cloud.google.com öffnen.
2. Neues Projekt `clip-watcher` erstellen.
3. „APIs & Dienste“ → „Bibliothek“ → **YouTube Data API v3** → „Aktivieren“.
4. „OAuth-Zustimmungsbildschirm“ / „Google Auth Platform“:
   - Nutzertyp **Extern**, App-Name `clip-watcher`, deine E-Mail.
   - Unter „Zielgruppe“ → „Testnutzer“ die Gmail-Adresse des Kanals eintragen.
   - Optional: „App veröffentlichen“ (In Produktion), dann läuft die Anmeldung nicht nach 7 Tagen ab
     und in config.env `YT_TESTING=0` setzen. Kein Logo hochladen.
5. „Clients“ / „Anmeldedaten“ → „Erstellen“ → **OAuth-Client-ID** → Typ **Desktop-App**.
   Client-ID und Client-Secret in `config.env` bei `YT_CLIENT_ID` und `YT_CLIENT_SECRET` eintragen.
6. Anmelden (geht auch vom iPad aus, in Termius):
   ```bash
   cd ~/clip-watcher && ./yt_auth.py
   ```
   Den angezeigten Link im Browser öffnen, Kanal-Konto wählen,
   bei „App nicht überprüft“ → „Erweitert“ → „Weiter zu clip-watcher“ → zulassen.
   Der Browser zeigt danach „Seite nicht erreichbar“. Das ist richtig so: die komplette Adresse
   aus der Adresszeile kopieren und in Termius einfügen. Fertig, der Zugang wird automatisch gespeichert.
   Solange die Google-App im Testmodus ist, läuft die Anmeldung nach 7 Tagen ab.
   Der Telegram-Bot erinnert dich ab Tag 6, dann einfach `./yt_auth.py` nochmal ausführen.
7. **Wichtig:** Google lädt Videos aus ungeprüften Projekten nur **privat** hoch.
   Damit sie öffentlich werden, die Prüfung beantragen: Google-Formular
   „YouTube API Services – Audit and Quota Extension Form“ (in der Google-Hilfe suchen).
   Bis dahin: Videos landen privat auf deinem Kanal.

## Schritt 6: TikTok (25 Min. + Wartezeit)
1. developers.tiktok.com → mit deinem TikTok-Konto registrieren.
2. „Manage apps“ → **App erstellen**: Name, Icon, Beschreibung, Kategorie.
   Links zu Nutzungsbedingungen und Datenschutz sind Pflicht (z.B. eine einfache Seite).
3. Produkte hinzufügen: **Login Kit** und **Content Posting API** (Direct Post einschalten).
4. Berechtigungen: `user.info.basic` und `video.publish`.
5. Bei Login Kit eine **Redirect-URI** (https) eintragen, z.B. deine GitHub-Repo-Adresse.
   Dieselbe Adresse in `config.env` bei `REDIRECT_URI=` eintragen.
6. Client Key und Secret bei `TIKTOK_CLIENT_KEY` und `TIKTOK_CLIENT_SECRET` eintragen.
7. Anmelden:
   ```bash
   cd ~/clip-watcher && set -a && . ./config.env && set +a && venv/bin/python auth.py tiktok
   ```
   Link im Browser öffnen, einloggen, zulassen. Du landest auf der Redirect-Seite:
   die **komplette Adresse aus der Adresszeile** kopieren und im Terminal einfügen.
   `TIKTOK_REFRESH_TOKEN=...` in `config.env` eintragen.
8. App zur Prüfung einreichen („Submit for review“). Bis zur Freigabe sind Posts **nur privat**
   (`TIKTOK_PRIVACY=SELF_ONLY`). Nach der Freigabe `TIKTOK_PRIVACY=PUBLIC_TO_EVERYONE`.

## Schritt 7: Instagram (25 Min.)
1. Instagram-App → Einstellungen → „Kontotyp und Tools“ → **Zu professionellem Konto wechseln**
   → „Creator“.
2. developers.facebook.com → „Meine Apps“ → **App erstellen** → Anwendungsfall
   „Instagram API“ / „Inhalte auf Instagram verwalten“.
3. In der App: Instagram → „API-Einrichtung mit Instagram-Login“:
   - Berechtigungen `instagram_business_basic` und `instagram_business_content_publish`.
   - Bei „Business-Login-Einstellungen“ dieselbe **Redirect-URI** wie bei TikTok eintragen.
   - Unter „App-Rollen“ deinen Instagram-Account als **Tester** hinzufügen und die Einladung
     auf instagram.com → Einstellungen → „Apps und Websites“ → „Tester-Einladungen“ annehmen.
4. **Instagram-App-ID** und **Secret** bei `IG_APP_ID` und `IG_APP_SECRET` eintragen.
5. Anmelden:
   ```bash
   cd ~/clip-watcher && set -a && . ./config.env && set +a && venv/bin/python auth.py instagram
   ```
   Wie bei TikTok: Link öffnen, zulassen, Adresse zurückkopieren.
   `IG_USER_ID=` und `IG_ACCESS_TOKEN=` in `config.env` eintragen. Das Token erneuert sich selbst.

## Schritt 7b: Bessere Hooks mit Claude (optional, ca. 1 Cent pro Clip)
1. console.anthropic.com öffnen, anmelden, unter „Billing“ Guthaben aufladen (z.B. 5 €).
2. „API Keys“ → „Create Key“ → Namen `clip-watcher` → Schlüssel kopieren.
3. In `config.env` bei `ANTHROPIC_API_KEY=` eintragen.
Ohne Schlüssel nimmt das Programm einfach die häufigste Chat-Reaktion als Hook.

## Schritt 8: Testlauf (ohne zu posten)
In `config.env` muss `DRY_RUN=1` stehen. Dann:
```bash
systemctl start clip-watcher
tail -f ~/clip-watcher/runs/*.log
```
Sobald Kai oder Speed live sind, kommen fertige Clips per Telegram, gepostet wird noch nichts.
Streamer ändern: `nano ~/clip-watcher/streamers.txt`, danach `systemctl restart clip-watcher`.

## Schritt 9: Echt posten
Wenn dir die Clips gefallen: in `config.env` `DRY_RUN=0` setzen, dann
```bash
systemctl restart clip-watcher
```
Ab jetzt läuft alles automatisch, auch nach einem Neustart des Servers.

## Wartung
- Status: `systemctl status clip-watcher`
- Speicher prüfen: `df -h`. Alte Aufnahmen löschen: `rm -rf ~/clip-watcher/runs/*-2026*` (Beispiel)
- Update holen: `cd ~/clip-watcher && git pull && systemctl restart clip-watcher`
- Fehler? Log-Ausschnitt an Claude schicken (**ohne** `config.env`).
