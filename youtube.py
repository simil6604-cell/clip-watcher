"""YouTube-Upload über die offizielle YouTube Data API v3 (ohne Zusatzpakete).
Braucht YT_CLIENT_ID, YT_CLIENT_SECRET (config.env) und eine Anmeldung mit ./yt_auth.py.
Im Testmodus der Google-App läuft die Anmeldung nach 7 Tagen ab: remind() erinnert per Telegram."""
import json, os, time, urllib.error, urllib.parse, urllib.request
import tokens

def configured():
    return bool(os.environ.get("YT_CLIENT_ID") and os.environ.get("YT_CLIENT_SECRET")
                and tokens.get("YT_REFRESH_TOKEN"))

def remind(send):
    """Ab Tag 6 nach der Anmeldung einmal täglich per Telegram erinnern (nur im Testmodus)."""
    if os.environ.get("YT_TESTING", "1") == "0" or not tokens.get("YT_REFRESH_TOKEN"):
        return
    auth_at = float(tokens.get("YT_AUTH_AT") or 0)
    last = float(tokens.get("YT_REMINDED_AT") or 0)
    if auth_at and time.time() - auth_at > 6 * 86400 and time.time() - last > 20 * 3600:
        days = (time.time() - auth_at) / 86400
        send(f"⏰ YouTube-Anmeldung ist {int(days)} Tage alt und läuft nach 7 Tagen ab.\n"
             "Bitte in Termius ausführen:\ncd ~/clip-watcher && ./yt_auth.py")
        tokens.put(YT_REMINDED_AT=str(time.time()))

def _token():
    data = urllib.parse.urlencode({"client_id": os.environ["YT_CLIENT_ID"],
                                   "client_secret": os.environ["YT_CLIENT_SECRET"],
                                   "refresh_token": tokens.get("YT_REFRESH_TOKEN"),
                                   "grant_type": "refresh_token"}).encode()
    try:
        with urllib.request.urlopen("https://oauth2.googleapis.com/token", data, timeout=30) as r:
            return json.load(r)["access_token"]
    except urllib.error.HTTPError as e:
        if "invalid_grant" in e.read().decode(errors="replace"):
            raise RuntimeError("Anmeldung abgelaufen. In Termius: cd ~/clip-watcher && ./yt_auth.py")
        raise

def upload(video, title, description, tags):
    tok = _token()
    meta = {"snippet": {"title": title[:100], "description": description[:5000], "tags": tags,
                        "categoryId": "20"},  # 20 = Gaming
            "status": {"privacyStatus": os.environ.get("YT_PRIVACY", "public"),
                       "selfDeclaredMadeForKids": False}}
    req = urllib.request.Request(
        "https://www.googleapis.com/upload/youtube/v3/videos?uploadType=resumable&part=snippet,status",
        data=json.dumps(meta).encode(), method="POST",
        headers={"Authorization": f"Bearer {tok}", "Content-Type": "application/json; charset=UTF-8",
                 "X-Upload-Content-Type": "video/mp4",
                 "X-Upload-Content-Length": str(os.path.getsize(video))})
    with urllib.request.urlopen(req, timeout=60) as r:
        location = r.headers["Location"]
    with open(video, "rb") as f:
        put = urllib.request.Request(location, data=f.read(), method="PUT",
                                     headers={"Authorization": f"Bearer {tok}", "Content-Type": "video/mp4"})
    with urllib.request.urlopen(put, timeout=600) as r:
        vid = json.load(r)["id"]
    return f"https://youtube.com/shorts/{vid}"
