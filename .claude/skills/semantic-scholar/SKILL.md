---
name: semantic-scholar
description: Research literature on a topic via Semantic Scholar + arXiv — discover, download PDFs, and synthesize a themed overview
argument-hint: <topic or keywords> [quick|survey|expand <ids>|deep-dive <sub-topic>]
effort: high
allowed-tools: Bash, Read, Write, Edit, Glob, Grep, WebSearch, WebFetch
disable-model-invocation: true
---

Run a reproducible literature-research pass — discover papers, download PDFs, and synthesize a themed overview — for the topic in the argument. Operate in the **current working directory**: build `papers/`, `papers/manifest.json`, and `overview.md` under CWD. Re-running is additive (dedupe by arXiv id).

## Argument

`$ARGUMENTS` = the topic/keywords, optionally followed by a mode word and directives:
- no mode word, or `survey` → full pass (default).
- `quick` → discovery only, ranked candidate list, **no downloads**.
- `expand <ids>` → citation-graph expansion from the given arXiv IDs (or, if none given, the current manifest).
- `deep-dive <sub-topic>` → targeted discovery + a focused `<sub-topic>_deep_dive.md`.

If no argument is given, ask what topic to research before proceeding.

## Operating knowledge (do not re-derive)

- **The tool:** `${CLAUDE_SKILL_DIR}/scripts/s2lit.py` (bundled with this skill — run it in place, never copy it into the working directory).
- **API key:** `~/.secrets/s2_api_key` (chmod 600, on NFS home — not Dropbox). Consume it **inline** and never echo it: `S2_API_KEY="$(cat ~/.secrets/s2_api_key)" python3 ${CLAUDE_SKILL_DIR}/scripts/s2lit.py …`. Do not print, cat, or paste the key; do not put it in a committed file or in shell history.
- **No key / HTTP 403:** discovery falls back to **WebSearch scoped to `semanticscholar.org` and `arxiv.org`** — fully functional, no key needed. `403` = key missing / truncated (a good key is 44 chars, a truncated one 40) / not-yet-activated. `429` = rate limit.
- **Rate limit:** 1 request/second cumulative across all S2 endpoints. `s2lit.py` already spaces calls ≥1.5–2.5 s, does exponential backoff on 429, and checkpoints after every seed/paper so a timeout never loses progress. Do not wrap it in tight loops.
- **`curl` is blocked** by the permission mode. Use `s2lit.py` (urllib) or `wget` only.
- **arXiv:** IDs are batch-validated (`id_list` API) before download; the `%PDF` header is verified; old-style IDs like `physics/9803008` are sanitized to `physics-9803008` in filenames. The User-Agent carries the email.

## Setup

1. `mkdir -p papers`.
2. Detect the key once: `test -s ~/.secrets/s2_api_key && echo keyed || echo anonymous`. If anonymous, note that Phase 1 will use the WebSearch fallback and skip the `s2lit.py search`/`expand` calls (they would just 429).
3. If `papers/manifest.json` already exists, read it — this is an additive re-run; everything dedupes against it.

## Phase 1 — Discover

Decompose the topic into 4–8 sub-angles (core method, application domains, adjacent techniques, key author lines, reviews). Then:

- **Always:** WebSearch each sub-angle, scoped with `site:arxiv.org` / `semanticscholar.org` and method keywords. Collect arXiv IDs, titles, years.
- **If keyed and depth warrants:** also run `S2_API_KEY="$(cat ~/.secrets/s2_api_key)" python3 ${CLAUDE_SKILL_DIR}/scripts/s2lit.py search "<q1>" "<q2>" … --out s2results.json` for citation-ranked hits.

Produce a **deduped, ranked candidate list** (by relevance and citation count). For `quick` mode, stop here and report the list.

## Phase 2 — Curate & fetch

1. Dedupe candidates against `papers/manifest.json` (skip IDs already collected).
2. Assign each keeper a short `theme` tag (a lowercase word grouping the collection, e.g. `foundations`, `lattice`, `application`, `review`).
3. **Batch-size gate:** for ≲25 new papers, download directly. For larger batches, present the curated list with a suggested count and **confirm scope with the user** (AskUserQuestion) before downloading.
4. Download with `S2_API_KEY="$(cat ~/.secrets/s2_api_key)" python3 ${CLAUDE_SKILL_DIR}/scripts/s2lit.py fetch <id:theme> … --dir papers --manifest papers/manifest.json`, or `--from <file>` for a curated list (lines `id[,theme[,note]]` or a JSON array). The key isn't required for arXiv PDF downloads, but passing it inline is harmless and keeps one pattern.

For `expand` mode: `python3 ${CLAUDE_SKILL_DIR}/scripts/s2lit.py expand <ids> --out expand_candidates.json` (or no ids → seeds from the manifest), review the seed-degree-ranked candidates, curate, then fetch as above.

## Phase 3 — Synthesize

Create or update `overview.md`, scaled to collection size, with:
- title + a one-paragraph **"idea in brief"**;
- the **key mechanisms** at play;
- **literature grouped by theme**, each entry `[arXiv](https://arxiv.org/abs/ID)` + a one-line annotation;
- a **recommended reading path**;
- an honest **"what works vs. open problems"** section;
- a **"connections to your work"** section (quantum many-body / TRIQS / DMFT context where relevant);
- a **collection table** (theme → count) + pointer to `manifest.json`;
- a short **provenance/methodology** note (how many passes, discovery method, date).

For `deep-dive`, write a focused `<sub-topic>_deep_dive.md` with the same shape narrowed to the one sub-thread, and add a pointer from `overview.md`.

## Modes summary

| mode | phases | output |
|-|-|-|
| `quick` | 1 | ranked candidate list, no files beyond `s2results.json` |
| `survey` (default) | 1–3 | `papers/*.pdf`, `manifest.json`, `overview.md` |
| `expand <ids>` | 1(expand)–3 | `expand_candidates.json`, new PDFs, updated `overview.md` |
| `deep-dive <sub-topic>` | 1–3 | targeted PDFs, `<sub-topic>_deep_dive.md` |

## Report

End with: papers added (counts by theme), files written/updated, the key mode used (keyed vs anonymous fallback), and any clusters deliberately held back (with counts) so the user can ask to pull them in.

