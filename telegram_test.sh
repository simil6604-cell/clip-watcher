#!/usr/bin/env bash
# Prüft die Telegram-Verbindung und sagt in einem Satz, was los ist.
HERE="$(cd "$(dirname "$0")" && pwd)"; CFG="$HERE/config.env"
PY="$HERE/venv/bin/python"; [ -x "$PY" ] || PY=python3
get() { grep -E "^$1=" "$CFG" | tail -1 | cut -d= -f2-; }
TOK="$(get TELEGRAM_TOKEN)"; CID="$(get TELEGRAM_CHAT_ID)"
echo "== Telegram-Test"
if [ -z "$TOK" ]; then echo "❌ Es ist KEIN Token gespeichert. Lösung: ./configure.sh telegram"; exit 1; fi
ME="$(curl -s "https://api.telegram.org/bot$TOK/getMe")"
if ! echo "$ME" | grep -q '"ok":true'; then
  echo "❌ Der gespeicherte Token ist FALSCH (${#TOK} Zeichen, richtig sind ca. 46)."
  echo "   Lösung: bei BotFather /mybots -> Bot -> API Token kopieren, dann ./configure.sh telegram"; exit 1; fi
NAME="$(echo "$ME" | "$PY" -c 'import json,sys; r=json.load(sys.stdin)["result"]; print(r["first_name"], "(@"+r["username"]+")")')"
echo "✔ Token ist richtig. Er gehört zu deinem Bot: $NAME"
UPD="$(curl -s "https://api.telegram.org/bot$TOK/getUpdates")"
FOUND="$(echo "$UPD" | "$PY" -c '
import json,sys
ids=[u.get("message",{}).get("chat",{}).get("id") for u in json.load(sys.stdin).get("result",[])]
ids=[i for i in ids if i]; print(ids[-1] if ids else "")')"
if [ -n "$FOUND" ]; then
  P="$CFG" VAL="$FOUND" "$PY" -c '
import os
p, v = os.environ["P"], os.environ["VAL"]
L = [l for l in open(p).read().splitlines() if not l.startswith("TELEGRAM_CHAT_ID=")] + ["TELEGRAM_CHAT_ID=" + v]
open(p, "w").write("\n".join(L) + "\n")'
  CID="$FOUND"; echo "✔ Deine Nachricht an den Bot ist angekommen, Chat-ID gespeichert."
elif [ -z "$CID" ]; then
  echo "❌ Der Bot hat noch KEINE Nachricht von dir bekommen."
  echo "   Lösung: In Telegram oben nach $NAME suchen, öffnen, auf START tippen, 'hi' schicken."
  echo "   Dann diesen Test nochmal starten: ./telegram_test.sh"; exit 1
fi
R="$(curl -s "https://api.telegram.org/bot$TOK/sendMessage" --data-urlencode "chat_id=$CID" \
     --data-urlencode "text=✅ clip-watcher ist mit Telegram verbunden")"
if echo "$R" | grep -q '"ok":true'; then echo "✅ FERTIG: Schau jetzt in Telegram in den Chat mit $NAME."
else echo "❌ Senden ging nicht: $R"; fi
