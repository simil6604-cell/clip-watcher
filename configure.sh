#!/usr/bin/env bash
# Assistent: fragt nacheinander alle Schlüssel ab, schreibt config.env und verbindet die Plattformen.
# Usage: ./configure.sh      (Enter ohne Eingabe = Wert behalten / überspringen)
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
  [ -n "$val" ] && set_key "$1" "$val"
}

echo "== Telegram"
ask TELEGRAM_TOKEN "Telegram-Bot-Token (von @BotFather) einfügen" geheim
TOK="$(get TELEGRAM_TOKEN)"
if [ -n "$TOK" ] && [ -z "$(get TELEGRAM_CHAT_ID)" ]; then
  echo "Schreib deinem Bot jetzt in Telegram eine Nachricht (z.B. 'hi'), dann Enter drücken."
  read -r _
  CID="$(curl -s "https://api.telegram.org/bot$TOK/getUpdates" | "$PY" -c '
import json, sys
d = json.load(sys.stdin)
ids = [u.get("message", {}).get("chat", {}).get("id") for u in d.get("result", [])]
ids = [i for i in ids if i]
print(ids[-1] if ids else "")' 2>/dev/null)"
  if [ -n "$CID" ]; then set_key TELEGRAM_CHAT_ID "$CID"; echo "Chat-ID gefunden."
  else echo "Keine Nachricht gefunden. Token prüfen, dem Bot schreiben und ./configure.sh nochmal starten."; fi
fi
if [ -n "$(get TELEGRAM_CHAT_ID)" ]; then
  curl -s -o /dev/null "https://api.telegram.org/bot$TOK/sendMessage" \
    --data-urlencode "chat_id=$(get TELEGRAM_CHAT_ID)" --data-urlencode "text=✅ clip-watcher ist mit Telegram verbunden" \
    && echo "Testnachricht an Telegram geschickt."
fi

echo; echo "== YouTube"
ask YT_CLIENT_ID "YouTube Client-ID einfügen"
ask YT_CLIENT_SECRET "YouTube Client-Secret einfügen" geheim

echo; echo "== TikTok"
ask TIKTOK_CLIENT_KEY "TikTok Client key einfügen"
ask TIKTOK_CLIENT_SECRET "TikTok Client secret einfügen" geheim
[ -z "$(get REDIRECT_URI)" ] && set_key REDIRECT_URI "https://www.tiktok.com/"

echo; echo "== Claude (optional, bessere Hooks)"
ask ANTHROPIC_API_KEY "Claude-API-Schlüssel (Enter = überspringen)" geheim

echo; echo "Gespeichert in config.env."
if [ -n "$(get YT_CLIENT_ID)" ]; then
  read -r -p "Jetzt bei YouTube anmelden? (j/n): " a
  [ "$a" = j ] && "$PY" "$HERE/yt_auth.py"
fi
if [ -n "$(get TIKTOK_CLIENT_KEY)" ]; then
  read -r -p "Jetzt bei TikTok anmelden? (j/n): " a
  [ "$a" = j ] && "$PY" "$HERE/auth.py" tiktok
fi
echo; echo "Fertig. Starten mit: systemctl restart clip-watcher"
