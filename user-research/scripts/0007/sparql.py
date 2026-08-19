#!/usr/bin/env python3
"""Thin, polite Wikidata SPARQL client with retry+backoff. Used by all 0007 dictionary steps."""
import json, sys, time, urllib.parse, urllib.request, urllib.error

ENDPOINT = "https://query.wikidata.org/sparql"
UA = "Tondo/1.0 (daily-art app research; dhanesh.n.m19@gmail.com)"

def run(query, tries=5, timeout=180, pause=1.0):
    """POST a SPARQL query. Returns list of binding dicts. Retries with exponential backoff."""
    data = urllib.parse.urlencode({"query": query}).encode()
    last = None
    for attempt in range(tries):
        req = urllib.request.Request(ENDPOINT, data=data, headers={
            "User-Agent": UA,
            "Accept": "application/sparql-results+json",
            "Content-Type": "application/x-www-form-urlencoded",
        })
        try:
            with urllib.request.urlopen(req, timeout=timeout) as r:
                body = r.read()
            time.sleep(pause)
            return json.loads(body)["results"]["bindings"]
        except Exception as e:
            last = e
            detail = ""
            if isinstance(e, urllib.error.HTTPError):
                try: detail = e.read()[:300].decode("utf-8", "replace")
                except Exception: pass
            wait = 5 * (2 ** attempt)
            print(f"  ! attempt {attempt+1}/{tries} failed: {type(e).__name__} {e} {detail}", file=sys.stderr)
            if attempt < tries - 1:
                print(f"    backing off {wait}s", file=sys.stderr)
                time.sleep(wait)
    raise RuntimeError(f"SPARQL failed after {tries} attempts: {last}")

def val(b, k, default=None):
    return b[k]["value"] if k in b else default
