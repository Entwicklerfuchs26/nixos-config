#!/usr/bin/env python3
"""AniO - AniList Metadaten + Jellyfin-Struktur"""

import re
import sys
import time
import shutil
import argparse
import requests
from pathlib import Path
from xml.etree import ElementTree as ET
from xml.dom import minidom

ANILIST_API = "https://graphql.anilist.co"
ANILIST_HEADERS = {
    "Content-Type": "application/json",
    "Accept": "application/json",
    "User-Agent": "Mozilla/5.0 (X11; Linux x86_64; rv:124.0) Gecko/20100101 Firefox/124.0",
}
VIDEO_EXTS = {".mkv", ".mp4", ".avi", ".mov", ".m4v", ".webm", ".ts"}

ELTERN_RELATIONEN = {"PARENT", "SIDE_STORY"}
TV_FORMATE = {"TV", "TV_SHORT", "ONA"}

SERIES_QUERY = """
query ($search: String) {
  Media(search: $search, type: ANIME) {
    id
    format
    title { romaji english native }
    startDate { year }
    description(asHtml: false)
    genres
    averageScore
    episodes
    status
    coverImage { extraLarge large }
    bannerImage
    studios(isMain: true) { nodes { name } }
    relations {
      edges {
        relationType
        node {
          id
          format
          title { english romaji }
          startDate { year }
        }
      }
    }
  }
}
"""


def query_anilist(title: str):
    for versuch in range(3):
        try:
            resp = requests.post(
                ANILIST_API,
                json={"query": SERIES_QUERY, "variables": {"search": title}},
                headers=ANILIST_HEADERS,
                timeout=10,
            )
            if resp.status_code == 429:
                wait = 60 * (versuch + 1)
                print(f"      Rate-Limit (429) — warte {wait}s...")
                time.sleep(wait)
                continue
            if resp.status_code == 404:
                wait = 30 * (versuch + 1)
                print(f"      HTTP 404 — warte {wait}s...")
                time.sleep(wait)
                continue
            resp.raise_for_status()
            data = resp.json()
            if "errors" in data:
                return None
            return data.get("data", {}).get("Media")
        except Exception:
            if versuch < 2:
                time.sleep(3 * (versuch + 1))
            else:
                raise
    raise Exception("AniList nicht erreichbar nach 3 Versuchen")


def titles_similar(search: str, result_title: str) -> bool:
    """Prüft ob Suchbegriff und Ergebnis sinnvoll übereinstimmen."""
    stop = {"the", "a", "an", "of", "in", "and", "to", "is", "no", "ga", "wa", "de", "na"}
    sw = {w for w in re.findall(r'\w+', search.lower()) if w not in stop and len(w) > 2}
    rw = {w for w in re.findall(r'\w+', result_title.lower()) if w not in stop and len(w) > 2}
    if not sw:
        return True
    return bool(sw & rw)


def download_image(url: str, path: Path) -> bool:
    try:
        resp = requests.get(url, timeout=20, stream=True)
        if resp.status_code == 200:
            with open(path, "wb") as f:
                for chunk in resp.iter_content(8192):
                    f.write(chunk)
            return True
    except Exception as e:
        print(f"    Bild-Fehler: {e}")
    return False


def clean_html(text: str) -> str:
    if not text:
        return ""
    text = re.sub(r"<[^>]+>", "", text)
    text = re.sub(r"\n{3,}", "\n\n", text)
    return text.strip()


def translate_de(text: str) -> str:
    if not text:
        return ""
    try:
        resp = requests.get(
            "https://translate.googleapis.com/translate_a/single",
            params={"client": "gtx", "sl": "en", "tl": "de", "dt": "t", "q": text},
            timeout=10,
        )
        resp.raise_for_status()
        data = resp.json()
        return "".join(chunk[0] for chunk in data[0] if chunk[0])
    except Exception:
        return text


def safe_name(s: str) -> str:
    return re.sub(r'[<>:"/\\|?*\x00-\x1f]', "", s).strip()


def is_movie(info: dict) -> bool:
    return info.get("format") == "MOVIE"


def nfo_plot(info: dict) -> str:
    return translate_de(clean_html(info.get("description", "")))


def find_parent_series(info: dict, anime_dir: Path):
    """Sucht die Elternserie eines Films im Anime-Verzeichnis."""
    for edge in info.get("relations", {}).get("edges", []):
        if edge.get("relationType") not in ELTERN_RELATIONEN:
            continue
        node = edge.get("node", {})
        if node.get("format") not in TV_FORMATE:
            continue

        title_en = node["title"].get("english") or node["title"].get("romaji", "")
        year = node.get("startDate", {}).get("year", "")
        folder = safe_name(f"{title_en} ({year})" if year else title_en)

        candidate = anime_dir / folder
        if candidate.is_dir():
            return candidate, node

    return None, None


def next_s00_episode(series_dir: Path) -> int:
    """Findet die nächste freie Episodennummer in Season 00."""
    season00 = series_dir / "Season 00"
    if not season00.exists():
        return 1
    used = set()
    for f in season00.iterdir():
        m = re.search(r"S00E(\d+)", f.name)
        if m:
            used.add(int(m.group(1)))
    n = 1
    while n in used:
        n += 1
    return n


def make_tvshow_nfo(info: dict) -> str:
    root = ET.Element("tvshow")

    def add(tag, text):
        if text is not None and str(text).strip():
            ET.SubElement(root, tag).text = str(text)

    title_en = info["title"].get("english") or info["title"].get("romaji", "")
    add("title", title_en)
    add("originaltitle", info["title"].get("romaji", ""))
    add("year", info.get("startDate", {}).get("year"))
    add("plot", nfo_plot(info))

    score = info.get("averageScore")
    if score:
        add("rating", f"{score / 10:.1f}")

    for genre in info.get("genres", []):
        add("genre", genre)

    studios = info.get("studios", {}).get("nodes", [])
    if studios:
        add("studio", studios[0]["name"])

    add("status", info.get("status", ""))

    uid = ET.SubElement(root, "uniqueid")
    uid.set("type", "anilist")
    uid.set("default", "true")
    uid.text = str(info.get("id", ""))

    xml = ET.tostring(root, encoding="unicode")
    return minidom.parseString(xml).toprettyxml(indent="  ", encoding=None)


def make_movie_nfo(info: dict) -> str:
    root = ET.Element("movie")

    def add(tag, text):
        if text is not None and str(text).strip():
            ET.SubElement(root, tag).text = str(text)

    title_en = info["title"].get("english") or info["title"].get("romaji", "")
    add("title", title_en)
    add("originaltitle", info["title"].get("romaji", ""))
    add("year", info.get("startDate", {}).get("year"))
    add("plot", nfo_plot(info))

    score = info.get("averageScore")
    if score:
        add("rating", f"{score / 10:.1f}")

    for genre in info.get("genres", []):
        add("genre", genre)

    studios = info.get("studios", {}).get("nodes", [])
    if studios:
        add("studio", studios[0]["name"])

    uid = ET.SubElement(root, "uniqueid")
    uid.set("type", "anilist")
    uid.set("default", "true")
    uid.text = str(info.get("id", ""))

    xml = ET.tostring(root, encoding="unicode")
    return minidom.parseString(xml).toprettyxml(indent="  ", encoding=None)


def make_episode_nfo(show_title: str, season: int, episode: int, title: str = None) -> str:
    root = ET.Element("episodedetails")
    ET.SubElement(root, "title").text = title or f"Folge {episode}"
    ET.SubElement(root, "showtitle").text = show_title
    ET.SubElement(root, "season").text = str(season)
    ET.SubElement(root, "episode").text = str(episode)
    xml = ET.tostring(root, encoding="unicode")
    return minidom.parseString(xml).toprettyxml(indent="  ", encoding=None)


def extract_se(filename: str):
    stem = Path(filename).stem

    # S01E01 / s01e01
    m = re.search(r"[Ss](\d+)[Ee](\d+)", stem)
    if m:
        return int(m.group(1)), int(m.group(2))

    # Staffel 2 Folge 10 / Staffel_2_Folge_10 / Staffel_1_Floge_2 (Deutsch)
    m = re.search(r"[Ss]taffel[_ ]?(\d+)[^a-zA-Z0-9]+[Ff](?:olge|loge)[_ ]?(\d+)", stem)
    if m:
        return int(m.group(1)), int(m.group(2))

    # DVD-Specials → Season 00
    m = re.search(r"[Dd][Vv][Dd][_ ]?(\d+)", stem)
    if m:
        return 0, int(m.group(1))

    # Folge 10 / Floge 10 ohne Staffel (nimmt Season 1 an)
    m = re.search(r"[Ff](?:olge|loge)[_ ]?(\d+)", stem)
    if m:
        return 1, int(m.group(1))

    # trailing number
    m = re.search(r"(?:[-_ ])(\d{1,3})$", stem)
    if m:
        return 1, int(m.group(1))

    return None, None


def find_videos(path: Path):
    return sorted(
        p for p in path.rglob("*")
        if p.is_file() and p.suffix.lower() in VIDEO_EXTS
        and not p.name.startswith("._")  # macOS metadata-Dateien ignorieren
    )


def execute_film(show_dir: Path, info: dict, anime_dir: Path, dry_run: bool):
    title_en = info["title"].get("english") or info["title"].get("romaji", show_dir.name)
    year = info.get("startDate", {}).get("year", "")
    folder = safe_name(f"{title_en} ({year})" if year else title_en)
    target = anime_dir / folder
    videos = find_videos(show_dir)
    video = max(videos, key=lambda v: v.stat().st_size)
    ext = video.suffix.lower()

    # Elternserie suchen
    parent_dir, parent_node = find_parent_series(info, anime_dir)

    if parent_dir:
        parent_title = parent_node["title"].get("english") or parent_node["title"].get("romaji", "")
        ep_num = next_s00_episode(parent_dir)
        new_name = safe_name(f"{parent_title} - S00E{ep_num:02d} - {title_en}{ext}")

        print(f"\n  {title_en} ({year})  [Film → Season 00 von '{parent_dir.name}']")

        if dry_run:
            print(f"    [Vorschau] → {parent_dir.name}/Season 00/{new_name}")
            return

        season00 = parent_dir / "Season 00"
        season00.mkdir(exist_ok=True)

        dest = season00 / new_name
        if not dest.exists():
            shutil.move(str(video), str(dest))
            print(f"    Verschoben: Season 00/{new_name}")
        elif show_dir != parent_dir and video.exists():
            video.unlink()
            print(f"    Duplikat entfernt: {video.name}")

        ep_nfo = season00 / new_name.replace(ext, ".nfo")
        if not ep_nfo.exists():
            ep_nfo.write_text(
                make_episode_nfo(parent_title, 0, ep_num, title_en),
                encoding="utf-8",
            )
            print("    episode.nfo erstellt")

        if show_dir != parent_dir and show_dir.exists():
            leftover = [f for f in show_dir.rglob("*") if f.is_file() and f.suffix.lower() in VIDEO_EXTS and not f.name.startswith("._")]
            if not leftover:
                shutil.rmtree(show_dir)
                print(f"    Alter Ordner entfernt: {show_dir.name}/")
        return

    # Kein Elternserie → eigenständiger Film
    print(f"\n  {title_en} ({year})  [Film]")

    if dry_run:
        new_name = safe_name(f"{folder}{ext}")
        print(f"    [Vorschau] → {folder}/{new_name}")
        return

    target.mkdir(exist_ok=True)

    nfo_path = target / f"{folder}.nfo"
    nfo_path.write_text(make_movie_nfo(info), encoding="utf-8")
    print("    movie.nfo erstellt")

    old_nfo = target / "tvshow.nfo"
    if old_nfo.exists():
        old_nfo.unlink()
        print("    Alte tvshow.nfo entfernt")

    poster = target / "poster.jpg"
    if not poster.exists():
        cover = info.get("coverImage", {})
        url = cover.get("extraLarge") or cover.get("large")
        if url and download_image(url, poster):
            print("    poster.jpg heruntergeladen")

    fanart = target / "fanart.jpg"
    if not fanart.exists() and info.get("bannerImage"):
        if download_image(info["bannerImage"], fanart):
            print("    fanart.jpg heruntergeladen")

    new_name = safe_name(f"{folder}{ext}")
    dest = target / new_name
    if not dest.exists():
        shutil.move(str(video), str(dest))
        print(f"    Verschoben: {new_name}")
    elif show_dir != target and video.exists():
        video.unlink()
        print(f"    Duplikat entfernt: {video.name}")

    # Extras/-Unterordner in Zielordner übernehmen (Jellyfin-kompatibel)
    if show_dir != target:
        extras_src = show_dir / "Extras"
        if extras_src.is_dir():
            extras_dst = target / "Extras"
            extras_dst.mkdir(exist_ok=True)
            for ef in sorted(extras_src.iterdir()):
                if ef.is_file() and not ef.name.startswith("._"):
                    dst = extras_dst / ef.name
                    if not dst.exists():
                        shutil.move(str(ef), str(dst))
                        print(f"    Extra verschoben: {ef.name}")

    for d in sorted(target.iterdir()):
        if d.is_dir() and re.match(r"Season \d+", d.name):
            leftover = [f for f in d.rglob("*") if f.is_file() and f.suffix.lower() in VIDEO_EXTS]
            if not leftover:
                shutil.rmtree(d)
                print(f"    Season-Ordner entfernt: {d.name}/")

    if show_dir != target and show_dir.exists():
        leftover = [f for f in show_dir.rglob("*") if f.is_file() and f.suffix.lower() in VIDEO_EXTS and not f.name.startswith("._")]
        if not leftover:
            shutil.rmtree(show_dir)
            print(f"    Alter Ordner entfernt: {show_dir.name}/")


def execute_serie(show_dir: Path, info: dict, anime_dir: Path, dry_run: bool):
    title_en = info["title"].get("english") or info["title"].get("romaji", show_dir.name)
    year = info.get("startDate", {}).get("year", "")
    folder = safe_name(f"{title_en} ({year})" if year else title_en)
    target = anime_dir / folder
    videos = find_videos(show_dir)

    print(f"\n  {title_en} ({year})  [Serie]")

    if dry_run:
        for v in videos:
            s, e = extract_se(v.name)
            if s is None:
                print(f"    [Vorschau] Staffel/Folge unbekannt: {v.name}")
                continue
            new = safe_name(f"{title_en} - S{s:02d}E{e:02d}{v.suffix.lower()}")
            print(f"    [Vorschau] → {folder}/Season {s:02d}/{new}")
        return

    target.mkdir(exist_ok=True)

    nfo_path = target / "tvshow.nfo"
    if not nfo_path.exists():
        nfo_path.write_text(make_tvshow_nfo(info), encoding="utf-8")
        print("    tvshow.nfo erstellt")

    poster = target / "poster.jpg"
    if not poster.exists():
        cover = info.get("coverImage", {})
        url = cover.get("extraLarge") or cover.get("large")
        if url and download_image(url, poster):
            print("    poster.jpg heruntergeladen")

    fanart = target / "fanart.jpg"
    if not fanart.exists() and info.get("bannerImage"):
        if download_image(info["bannerImage"], fanart):
            print("    fanart.jpg heruntergeladen")

    moved = 0
    for v in videos:
        s, e = extract_se(v.name)
        if s is None:
            print(f"    WARNUNG: Staffel/Folge nicht erkannt bei {v.name}")
            continue

        ext = v.suffix.lower()
        new_name = safe_name(f"{title_en} - S{s:02d}E{e:02d}{ext}")
        season_dir = target / f"Season {s:02d}"
        season_dir.mkdir(exist_ok=True)

        sp = season_dir / f"season{s:02d}-poster.jpg"
        if not sp.exists():
            cover = info.get("coverImage", {})
            url = cover.get("extraLarge") or cover.get("large")
            if url:
                download_image(url, sp)

        dest = season_dir / new_name
        if not dest.exists():
            shutil.move(str(v), str(dest))
            moved += 1
        elif show_dir != target and v.exists():
            # Gleiche Episode bereits im Zielordner vorhanden — Duplikat entfernen
            v.unlink()
            print(f"    Duplikat entfernt: {v.name}")

        ep_nfo = season_dir / new_name.replace(ext, ".nfo")
        if not ep_nfo.exists():
            ep_nfo.write_text(make_episode_nfo(title_en, s, e), encoding="utf-8")

    print(f"    {moved} Datei(en) verschoben")

    if show_dir != target and show_dir.exists():
        leftover = [f for f in show_dir.rglob("*") if f.is_file() and f.suffix.lower() in VIDEO_EXTS and not f.name.startswith("._")]
        if not leftover:
            shutil.rmtree(show_dir)
            print(f"    Alter Ordner entfernt: {show_dir.name}/")


def execute(show_dir: Path, info: dict, anime_dir: Path, dry_run: bool = False):
    if is_movie(info):
        execute_film(show_dir, info, anime_dir, dry_run)
    else:
        execute_serie(show_dir, info, anime_dir, dry_run)


def plan_phase(shows: list, auto: bool, anime_dir: Path) -> list:
    plans = []

    print("=" * 60)
    print("  SCHRITT 1 — Einträge prüfen")
    print("=" * 60)

    for show_dir in shows:
        videos = find_videos(show_dir)
        if not videos:
            continue

        raw_name = show_dir.name
        search = re.sub(r"\s*\(\d{4}\)\s*$", "", raw_name)
        search = re.sub(r"[_]", " ", search)

        print(f"\n  [{len(plans) + 1}] {raw_name}  ({len(videos)} Datei(en))")

        try:
            info = query_anilist(search)
        except Exception as e:
            print(f"      AniList-Fehler: {e}")
            if not auto:
                alt = input("      Alternativen Suchbegriff eingeben (leer = überspringen): ").strip()
                if alt:
                    try:
                        info = query_anilist(alt)
                    except Exception as e2:
                        print(f"      Fehler: {e2}")
                        plans.append((show_dir, None))
                        continue
                else:
                    plans.append((show_dir, None))
                    continue
            else:
                plans.append((show_dir, None))
                continue

        if not info:
            print("      Nicht auf AniList gefunden — übersprungen")
            plans.append((show_dir, None))
            continue

        title_en = info["title"].get("english") or info["title"].get("romaji", raw_name)
        title_romaji = info["title"].get("romaji", "")
        year = info.get("startDate", {}).get("year", "")
        typ = "Film" if is_movie(info) else "Serie"

        print(f"      Gefunden : {title_en} ({year})  [{typ}]")
        if title_romaji and title_romaji != title_en:
            print(f"      Romaji   : {title_romaji}")
        print(f"      AniList  : https://anilist.co/anime/{info['id']}")

        if is_movie(info):
            parent_dir, parent_node = find_parent_series(info, anime_dir)
            if parent_dir:
                parent_title = parent_node["title"].get("english") or parent_node["title"].get("romaji", "")
                print(f"      Elternserie: {parent_dir.name}  → Season 00")

        if auto:
            if not titles_similar(search, title_en):
                print(f"      WARNUNG: Kein Titelübereinstimmung — übersprungen (manuell prüfen!)")
                plans.append((show_dir, None))
            else:
                plans.append((show_dir, info))
            time.sleep(1.0)
            continue

        ans = input("      Korrekt? [J/n/m=manuell/ü=überspringen]: ").strip().lower()
        if ans == "ü":
            plans.append((show_dir, None))
        elif ans in ("n", "m"):
            term = input("      Suchbegriff: ").strip()
            try:
                info2 = query_anilist(term)
            except Exception as e:
                print(f"      Fehler: {e}")
                plans.append((show_dir, None))
                continue
            if not info2:
                print("      Nicht gefunden — übersprungen")
                plans.append((show_dir, None))
            else:
                title2 = info2["title"].get("english") or info2["title"].get("romaji", "")
                year2 = info2.get("startDate", {}).get("year", "")
                typ2 = "Film" if is_movie(info2) else "Serie"
                print(f"      Neuer Treffer: {title2} ({year2})  [{typ2}]")
                plans.append((show_dir, info2))
        else:
            plans.append((show_dir, info))

        time.sleep(1.0)

    return plans


def main():
    ap = argparse.ArgumentParser(
        description="AniO — AniList Metadaten + Jellyfin-Struktur",
        usage="AniO [Pfad] [Optionen]",
    )
    ap.add_argument("path",      nargs="?", default=".", help="Anime-Verzeichnis (Standard: aktueller Ordner)")
    ap.add_argument("--dry-run", action="store_true",    help="Nur anzeigen, nichts verschieben")
    ap.add_argument("--auto",    action="store_true",    help="Alle AniList-Treffer automatisch bestätigen")
    ap.add_argument("--show",    metavar="NAME",          help="Nur diesen Unterordner verarbeiten")
    args = ap.parse_args()

    anime_dir = Path(args.path).resolve()
    if not anime_dir.is_dir():
        sys.exit(f"Verzeichnis nicht gefunden: {anime_dir}")

    print(f"AniO — {anime_dir}")
    if args.dry_run:
        print("Vorschau-Modus — keine Dateien werden verändert\n")

    if args.show:
        d = anime_dir / args.show
        if not d.is_dir():
            sys.exit(f"Ordner nicht gefunden: {d}")
        shows = [d]
    else:
        shows = sorted(d for d in anime_dir.iterdir() if d.is_dir())

    plans = plan_phase(shows, auto=args.auto, anime_dir=anime_dir)

    confirmed = [(d, info) for d, info in plans if info is not None]
    skipped   = len(plans) - len(confirmed)

    if not confirmed:
        print("\nNichts zu tun.")
        return

    filme  = sum(1 for _, i in confirmed if is_movie(i))
    serien = len(confirmed) - filme

    print(f"\n{'=' * 60}")
    print(f"  SCHRITT 2 — Verarbeitung startet  ({serien} Serie(n), {filme} Film(e), {skipped} übersprungen)")
    print(f"{'=' * 60}")

    for show_dir, info in confirmed:
        execute(show_dir, info, anime_dir, dry_run=args.dry_run)

    print("\nFertig.")


if __name__ == "__main__":
    main()
