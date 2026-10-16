#!/usr/bin/env python3
"""Synced lyrics for one track from lrclib.net, cached.

    lyrics.py <cache dir> <artist> <title> <duration seconds>

Prints the LRC text, or nothing when the track has no synced lyrics. A miss is
cached too, so the same unknown track is not asked about again.
"""
import hashlib
import json
import os
import sys
import urllib.parse
import urllib.request

API = "https://lrclib.net/api"
UA = "tetoOS (https://github.com/quickshell-mirror/quickshell)"


def ask(path, params):
    url = f"{API}/{path}?{urllib.parse.urlencode(params)}"
    req = urllib.request.Request(url, headers={"User-Agent": UA})
    try:
        with urllib.request.urlopen(req, timeout=8) as r:
            return json.load(r)
    except Exception:
        return None


def main():
    cache, artist, title, duration = sys.argv[1], sys.argv[2], sys.argv[3], sys.argv[4]
    os.makedirs(cache, exist_ok=True)
    key = hashlib.sha1(f"{artist}\0{title}".encode()).hexdigest()[:24]
    path = os.path.join(cache, key + ".lrc")
    if os.path.exists(path):
        with open(path) as f:
            text = f.read()
        print("" if text.startswith("#none") else text)
        return
    found = ""
    d = ask("get", {"artist_name": artist, "track_name": title, "duration": duration})
    if isinstance(d, dict) and d.get("syncedLyrics"):
        found = d["syncedLyrics"]
    else:
        d = ask("search", {"artist_name": artist, "track_name": title})
        if isinstance(d, list):
            found = next((x["syncedLyrics"] for x in d if x.get("syncedLyrics")), "")
    with open(path, "w") as f:
        f.write(found or "#none\n")
    print(found)


if __name__ == "__main__":
    main()
