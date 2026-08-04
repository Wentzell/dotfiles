#!/usr/bin/env python3
"""s2lit -- Semantic Scholar + arXiv literature helper (search | expand | fetch).

Rate-limit aware. Reads an S2 API key from $S2_API_KEY (optional; without it the
Semantic Scholar API is heavily 429-throttled -- use the /semantic-scholar
command's WebSearch fallback for discovery instead). curl is unavailable in this
environment, so everything here uses urllib. The key is never printed.
"""
import argparse, json, os, re, sys, time
import urllib.request, urllib.parse, urllib.error
import xml.etree.ElementTree as ET

S2_BASE = "https://api.semanticscholar.org/graph/v1/paper"
ARXIV_API = "http://export.arxiv.org/api/query"
ARXIV_PDF = "https://arxiv.org/pdf/"
FIELDS = "title,year,citationCount,externalIds,authors,venue"
STOP = {"the", "a", "an", "of", "for", "in", "and", "with", "using", "to", "on"}


def headers(email):
    h = {"User-Agent": f"s2lit/1.0 (mailto:{email})"}
    key = (os.environ.get("S2_API_KEY") or "").strip()
    if key:
        h["x-api-key"] = key
    return h


def s2_get(url, hdrs, retries=5):
    """GET the S2 API with exponential backoff on 429 (the 1 req/s limit)."""
    delay = 5
    for _ in range(retries):
        try:
            with urllib.request.urlopen(urllib.request.Request(url, headers=hdrs), timeout=60) as r:
                return json.load(r)
        except urllib.error.HTTPError as e:
            if e.code == 429:
                sys.stderr.write(f"  429 -> backoff {delay}s\n"); time.sleep(delay); delay *= 2; continue
            if e.code == 403:
                sys.stderr.write("  403 Forbidden: S2 key missing/truncated/not-yet-active; "
                                 "use WebSearch discovery instead.\n"); return None
            sys.stderr.write(f"  HTTP {e.code}\n"); return None
        except Exception as e:
            sys.stderr.write(f"  ERR {e}\n"); time.sleep(delay); delay *= 2
    return None


def slug(s, n=6):
    words = re.sub(r"[^a-zA-Z0-9 ]", " ", s or "").split()
    return "-".join([w for w in words if w.lower() not in STOP][:n]).lower() or "paper"


def arxiv_meta(ids, hdrs):
    """Batch-validate arXiv IDs; return {id: {title, year, authors}}. One API call."""
    out = {}
    if not ids:
        return out
    url = ARXIV_API + "?" + urllib.parse.urlencode({"id_list": ",".join(ids), "max_results": len(ids)})
    try:
        with urllib.request.urlopen(urllib.request.Request(url, headers=hdrs), timeout=60) as r:
            root = ET.fromstring(r.read().decode("utf-8"))
    except Exception as e:
        sys.stderr.write(f"arxiv meta error: {e}\n"); return out
    ns = {"a": "http://www.w3.org/2005/Atom"}
    for e in root.findall("a:entry", ns):
        idel = e.find("a:id", ns)
        if idel is None or not idel.text:
            continue
        sid = idel.text.rsplit("/abs/", 1)[-1].split("v")[0]
        tel, pel = e.find("a:title", ns), e.find("a:published", ns)
        out[sid] = {
            "title": " ".join((tel.text if tel is not None and tel.text else "").split()),
            "year": (pel.text[:4] if pel is not None and pel.text else "----"),
            "authors": [a.find("a:name", ns).text for a in e.findall("a:author", ns)
                        if a.find("a:name", ns) is not None],
        }
    return out


def load_manifest(path):
    try:
        with open(path) as f:
            return json.load(f)
    except FileNotFoundError:
        return []


# ---------- search ----------
def cmd_search(a):
    hdrs = headers(a.email)
    keyed = bool(os.environ.get("S2_API_KEY"))
    papers = {}
    for i, q in enumerate(a.query):
        sys.stderr.write(f"[{i + 1}/{len(a.query)}] {q}\n")
        url = S2_BASE + "/search?" + urllib.parse.urlencode({"query": q, "limit": a.limit, "fields": FIELDS})
        data = s2_get(url, hdrs)
        for p in (data or {}).get("data", []):
            pid = p.get("paperId")
            if pid and pid not in papers:
                papers[pid] = p
        time.sleep(1.0 if keyed else 2.0)
    ranked = sorted(papers.values(), key=lambda p: (p.get("citationCount") or -1), reverse=True)
    out = [{"title": p.get("title"), "year": p.get("year"), "citations": p.get("citationCount"),
            "arxiv": (p.get("externalIds") or {}).get("ArXiv"),
            "doi": (p.get("externalIds") or {}).get("DOI"), "venue": p.get("venue"),
            "authors": [x.get("name") for x in (p.get("authors") or [])][:4]} for p in ranked]
    with open(a.out, "w") as f:
        json.dump(out, f, indent=2)
    sys.stderr.write(f"\n{len(out)} unique papers -> {a.out} ({'keyed' if keyed else 'anonymous'})\n")
    for p in out[:30]:
        print(f"{str(p['citations']):>6} {str(p['year']):>4}  {str(p['arxiv']):<14} {(p['title'] or '')[:70]}")


# ---------- expand ----------
def paged(sid, kind, inner, hdrs, cap_pages):
    for page in range(cap_pages):
        url = f"{S2_BASE}/ARXIV:{sid}/{kind}?" + urllib.parse.urlencode(
            {"fields": FIELDS, "limit": 1000, "offset": page * 1000})
        data = s2_get(url, hdrs)
        time.sleep(2.5)
        if not data or not data.get("data"):
            break
        for row in data["data"]:
            if row.get(inner):
                yield row[inner]
        if len(data["data"]) < 1000:
            break


def cmd_expand(a):
    hdrs = headers(a.email)
    manifest = load_manifest(a.manifest)
    have = {e["arxiv"] for e in manifest}
    seeds = a.ids or [e["arxiv"] for e in manifest]
    if not seeds:
        sys.stderr.write("no seeds (pass arXiv IDs, or build a manifest first)\n"); return
    cand = {}

    def snapshot():
        rows = []
        for r in cand.values():
            nb, nf = len(r["b"]), len(r["f"])
            rows.append({"arxiv": r["arxiv"], "title": r["title"], "year": r["year"],
                         "citations": r["citations"], "authors": r["authors"],
                         "n_backward": nb, "n_forward": nf, "seed_degree": nb + nf})
        rows.sort(key=lambda r: (r["seed_degree"], r["citations"] or -1), reverse=True)
        return rows

    for i, sid in enumerate(seeds):
        sys.stderr.write(f"[{i + 1}/{len(seeds)}] seed {sid}\n")
        for direction, kind, inner in [("b", "references", "citedPaper"), ("f", "citations", "citingPaper")]:
            for p in paged(sid, kind, inner, hdrs, a.cap_pages):
                ax = (p.get("externalIds") or {}).get("ArXiv")
                if not ax or ax in have:
                    continue
                rec = cand.setdefault(ax, {"arxiv": ax, "title": p.get("title"), "year": p.get("year"),
                                           "citations": p.get("citationCount"),
                                           "authors": [x.get("name") for x in (p.get("authors") or [])][:3],
                                           "b": set(), "f": set()})
                rec[direction].add(sid)
        with open(a.out, "w") as f:  # checkpoint after every seed
            json.dump(snapshot(), f, indent=2)
    ranked = snapshot()
    sys.stderr.write(f"\n{len(ranked)} new candidates -> {a.out}\n")
    for r in ranked[:30]:
        print(f"{r['seed_degree']:>2} {r['n_backward']}/{r['n_forward']:<3} {str(r['citations']):>6} "
              f"{str(r['year']):>4}  {r['arxiv']:<14} {(r['title'] or '')[:60]}")


# ---------- fetch ----------
def parse_items(a):
    items = []
    if a.from_file:
        with open(a.from_file) as f:
            txt = f.read().strip()
        if txt.startswith("["):
            for e in json.loads(txt):
                items.append((e["arxiv"], e.get("theme", a.theme), e.get("title", "")))
        else:
            for line in txt.splitlines():
                line = line.strip()
                if not line or line.startswith("#"):
                    continue
                parts = [x.strip() for x in line.split(",")]
                items.append((parts[0], parts[1] if len(parts) > 1 else a.theme,
                              parts[2] if len(parts) > 2 else ""))
    for tok in a.ids:
        aid, theme = (tok.split(":", 1) if ":" in tok else (tok, a.theme))
        items.append((aid, theme, ""))
    return items


def cmd_fetch(a):
    hdrs = headers(a.email)
    os.makedirs(a.dir, exist_ok=True)
    manifest = load_manifest(a.manifest)
    have = {e["arxiv"] for e in manifest}
    items = parse_items(a)
    meta = arxiv_meta([aid for aid, _, _ in items], hdrs)
    added, missing = 0, []
    for aid, theme, note in items:
        if aid in have:
            sys.stderr.write(f"skip (have) {aid}\n"); continue
        m = meta.get(aid)
        if not m:
            missing.append(aid); sys.stderr.write(f"NO METADATA {aid}\n"); continue
        authors = m["authors"]
        a0 = re.sub(r"[^A-Za-z]", "", authors[0].split()[-1]) if authors else "unknown"
        fname = f"{m['year']}_{a0}_{slug(m['title'] or note)}_{aid.replace('/', '-')}.pdf"
        path = os.path.join(a.dir, fname)
        entry = {"arxiv": aid, "theme": theme, "title": m["title"], "year": m["year"],
                 "authors": authors, "file": fname, "url": f"https://arxiv.org/abs/{aid}"}
        try:
            with urllib.request.urlopen(urllib.request.Request(ARXIV_PDF + aid, headers=hdrs), timeout=90) as r:
                data = r.read()
            if data[:4] != b"%PDF":
                entry["status"] = "not-pdf"; sys.stderr.write(f"FAIL {aid} not PDF\n")
            else:
                with open(path, "wb") as fh:
                    fh.write(data)
                entry["status"] = "ok"; entry["bytes"] = len(data); added += 1
                sys.stderr.write(f"OK   {fname} ({len(data) // 1024} KB)\n")
        except Exception as ex:
            entry["status"] = f"error:{ex}"; sys.stderr.write(f"ERR  {aid}: {ex}\n")
        manifest.append(entry); have.add(aid)
        with open(a.manifest, "w") as f:  # checkpoint after every paper
            json.dump(manifest, f, indent=2)
        time.sleep(1.5)
    sys.stderr.write(f"\nAdded {added}. Manifest now {len(manifest)} entries."
                     + (f" Missing: {missing}\n" if missing else "\n"))


def main():
    EMAIL = "nwentzell@flatironinstitute.org"
    p = argparse.ArgumentParser(description="Semantic Scholar + arXiv literature helper")
    sub = p.add_subparsers(dest="cmd", required=True)

    s = sub.add_parser("search", help="ranked keyword search")
    s.add_argument("query", nargs="+")
    s.add_argument("--out", default="s2results.json")
    s.add_argument("--limit", type=int, default=25)
    s.add_argument("--email", default=EMAIL)
    s.set_defaults(func=cmd_search)

    e = sub.add_parser("expand", help="citation-graph expansion from seeds/manifest")
    e.add_argument("ids", nargs="*")
    e.add_argument("--out", default="expand_candidates.json")
    e.add_argument("--manifest", default="papers/manifest.json")
    e.add_argument("--cap-pages", type=int, default=1, dest="cap_pages")
    e.add_argument("--email", default=EMAIL)
    e.set_defaults(func=cmd_expand)

    f = sub.add_parser("fetch", help="validate + download PDFs + update manifest")
    f.add_argument("ids", nargs="*", help="arXiv IDs, optionally id:theme")
    f.add_argument("--from", dest="from_file", help="file of id[,theme[,note]] lines or a JSON list")
    f.add_argument("--dir", default="papers")
    f.add_argument("--manifest", default="papers/manifest.json")
    f.add_argument("--theme", default="misc")
    f.add_argument("--email", default=EMAIL)
    f.set_defaults(func=cmd_fetch)

    a = p.parse_args()
    a.func(a)


if __name__ == "__main__":
    main()
