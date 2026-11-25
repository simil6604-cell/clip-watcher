#!/usr/bin/env bash
# Assistent: fragt nacheinander alle Schlüssel ab, schreibt config.env und verbindet die Plattformen.
# Usage: ./configure.sh [telegram|youtube|tiktok|claude]   (Enter ohne Eingabe = Wert behalten)
set -uo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
CFG="$HERE/config.env"
PY="$HERE/venv/bin/python"; [ -x "$PY" ] || PY=python3
[ -f "$CFG" ] || cp "$HERE/config.env.example" "$CFG"
chmod 600 "$CFG"

get() { grep -E "^$1=" "$CFG" | tail -1 | cut -d= -f2-; }
set_key() {  # set_key NAME WERT  (Wert kommt über die Umgebung, nicht über die Kommandozeile)
  NAME="$1" VAL="$2" "$PY" - "$CFG" <<'PY'
import os, sys
p, k, v = sys.argv[1], os.environ["NAME"], os.environ["VAL"]
lines = open(p).read().splitlines()
for i, l in enumerate(lines):
    if l.startswith(k + "="):
        lines[i] = f"{k}={v}"; break
else:
    lines.append(f"{k}={v}")
open(p, "w").write("\n".join(lines) + "\n")
PY
}
ask() {  # ask NAME "Frage" [geheim]
  local cur val; cur="$(get "$1")"
  local hint=""; [ -n "$cur" ] && hint=" (schon gesetzt, Enter = behalten)"
  if [ "${3:-}" = geheim ]; then
    read -r -s -p "$2$hint: " val; echo
  else
    read -r -p "$2$hint: " val
  fi
  val="$(echo -n "$val" | tr -d '[:space:]')"
  if [ -n "$val" ]; then set_key "$1" "$val"; echo "   ✔ gespeichert (${#val} Zeichen)"
  else echo "   (nichts eingegeben)"; fi
}

PART="${1:-alle}"
if [ "$PART" = alle ] || [ "$PART" = telegram ]; then
echo "== Telegram"
ask TELEGRAM_TOKEN "Telegram-Bot-Token (von @BotFather) einfügen" geheim
TOK="$(get TELEGRAM_TOKEN)"
if [ -z "$TOK" ]; then
  read -r -p "Kein Token erkannt. Bitte nochmal einfügen: " TOK; TOK="$(echo -n "$TOK" | tr -d '[:space:]')"
  [ -n "$TOK" ] && set_key TELEGRAM_TOKEN "$TOK" && echo "   ✔ gespeichert (${#TOK} Zeichen)"
fi
if [ -n "$TOK" ]; then
  echo "Jetzt in Telegram deinem Bot 'hi' schreiben. Danach hier NUR Enter drücken."
  read -r extra; extra="$(echo -n "$extra" | tr -d '[:space:]')"
  if [[ "$extra" == *:* ]]; then set_key TELEGRAM_TOKEN "$extra"; TOK="$extra"; echo "   ✔ Token übernommen"; fi
  CID="$(curl -s "https://api.telegram.org/bot$TOK/getUpdates" | "$PY" -c '
import json, sys
d = json.load(sys.stdin)
ids = [u.get("message", {}).get("chat", {}).get("id") for u in d.get("result", [])]
ids = [i for i in ids if i]
print(ids[-1] if ids else "")' 2>/dev/null)"
  if [ -n "$CID" ]; then set_key TELEGRAM_CHAT_ID "$CID"; echo "Chat-ID gefunden."
  else echo "Keine Nachricht gefunden. Token prüfen, dem Bot schreiben und ./configure.sh nochmal starten."; fi
fi
if [ -n "$TOK" ]; then
  ME="$(curl -s "https://api.telegram.org/bot$TOK/getMe")"
  if ! echo "$ME" | grep -q '"ok":true'; then
    echo "❌ Telegram kennt diesen Token nicht. Bei @BotFather mit /mybots -> Bot -> API Token neu kopieren."
  elif [ -n "$(get TELEGRAM_CHAT_ID)" ]; then
    R="$(curl -s "https://api.telegram.org/bot$TOK/sendMessage" \
      --data-urlencode "chat_id=$(get TELEGRAM_CHAT_ID)" --data-urlencode "text=✅ clip-watcher ist mit Telegram verbunden")"
    if echo "$R" | grep -q '"ok":true'; then echo "✅ Testnachricht an Telegram geschickt."
    else echo "❌ Senden fehlgeschlagen: $R"; fi
  fi
fi

fi
if [ "$PART" = alle ] || [ "$PART" = youtube ]; then
echo; echo "== YouTube"
ask YT_CLIENT_ID "YouTube Client-ID einfügen"
ask YT_CLIENT_SECRET "YouTube Client-Secret einfügen" geheim

fi
if [ "$PART" = alle ] || [ "$PART" = tiktok ]; then
echo; echo "== TikTok"
ask TIKTOK_CLIENT_KEY "TikTok Client key einfügen"
ask TIKTOK_CLIENT_SECRET "TikTok Client secret einfügen" geheim
[ -z "$(get REDIRECT_URI)" ] && set_key REDIRECT_URI "https://www.tiktok.com/"

fi
if [ "$PART" = alle ] || [ "$PART" = claude ]; then
echo; echo "== Claude (optional, bessere Hooks)"
ask ANTHROPIC_API_KEY "Claude-API-Schlüssel (Enter = überspringen)" geheim

fi
echo; echo "Gespeichert in config.env."
if { [ "$PART" = alle ] || [ "$PART" = youtube ]; } && [ -n "$(get YT_CLIENT_ID)" ]; then
  read -r -p "Jetzt bei YouTube anmelden? (j/n): " a
  [ "$a" = j ] && "$PY" "$HERE/yt_auth.py"
fi
if { [ "$PART" = alle ] || [ "$PART" = tiktok ]; } && [ -n "$(get TIKTOK_CLIENT_KEY)" ]; then
  read -r -p "Jetzt bei TikTok anmelden? (j/n): " a
  [ "$a" = j ] && "$PY" "$HERE/auth.py" tiktok
fi
echo; echo "Fertig. Starten mit: systemctl restart clip-watcher"
