#!/usr/bin/env python3
"""Venue corroboration for theme demand (0008 research).

Two instruments, both with the artist axis as the built-in control (0007 proved
artist-name demand; the ratio of theme phrasing to artist phrasing in the same
venue is the base rate the skill requires):

1. Google autocomplete — does the query exist, and how do people phrase it?
   (subject "paintings of X" vs movement "impressionist paintings" vs medium
   "oil painting" vs artist "van gogh paintings"). Completions prove existence,
   not volume.
2. Reddit archive search (pullpush.io + arctic-shift) across the five art
   subreddits 0007 used — theme-seeking ask-threads and their term frequency.
   Both archives rate-limited 0007 mid-run; failures are recorded, not hidden.

Output: user-research/data/0008-venues.json
"""
import json, time, urllib.parse, urllib.request

UA = {"User-Agent": "TondoResearch/0.1 (dhanesh.n.m19@gmail.com)"}

AUTOCOMPLETE_PREFIXES = {
    # movement axis
    "impressionist pain": "movement", "impressionism art": "movement",
    "baroque paint": "movement", "renaissance paint": "movement",
    "romanticism pain": "movement", "abstract expression": "movement",
    "surrealist pain": "movement", "art nouveau p": "movement",
    # subject/genre axis
    "portrait paint": "genre", "landscape paint": "genre",
    "still life paint": "genre", "paintings of": "genre",
    "famous paintings of": "genre", "religious paint": "genre",
    "ukiyo-e": "genre", "mughal paint": "genre", "japanese paint": "genre",
    # medium axis
    "oil paint": "medium", "watercolor paint": "medium",
    "acrylic paint": "medium", "ink wash": "medium", "tempera": "medium",
    # artist axis (CONTROL — 0007 established this demand)
    "van gogh paint": "artist-control", "monet paint": "artist-control",
    "vermeer paint": "artist-control", "paintings by": "artist-control",
}

SUBREDDITS = ["Art", "painting", "ArtHistory", "museum", "ArtPorn"]

REDDIT_TERMS = {
    # theme-seeking phrasings
    "impressionist paintings": "movement", "baroque paintings": "movement",
    "renaissance paintings": "movement", "romanticism": "movement",
    "portrait paintings": "genre", "landscape paintings": "genre",
    "still life": "genre", "ukiyo-e": "genre", "mughal": "genre",
    "oil painting": "medium", "watercolor": "medium", "ink wash": "medium",
    # artist controls (0007's top pool-reachable names)
    "van gogh": "artist-control", "monet": "artist-control",
    "vermeer": "artist-control",
}


def get(url, timeout=25):
    try:
        with urllib.request.urlopen(urllib.request.Request(url, headers=UA), timeout=timeout) as r:
            return json.load(r), None
    except Exception as e:
        return None, f"{type(e).__name__}: {e}"


def autocomplete():
    out, failures = {}, []
    for prefix, axis in AUTOCOMPLETE_PREFIXES.items():
        url = ("https://suggestqueries.google.com/complete/search?client=firefox&q="
               + urllib.parse.quote(prefix))
        d, err = get(url)
        if d is None:
            failures.append({"prefix": prefix, "error": err})
        else:
            out[prefix] = {"axis": axis, "completions": d[1][:10]}
        time.sleep(0.4)
    return out, failures


def reddit_counts():
    """Comment/submission counts per term per archive. arctic-shift first
    (pullpush was the flakier of the two in 0007), pullpush as fallback."""
    out, failures = {}, []
    subs = ",".join(SUBREDDITS)
    for term, axis in REDDIT_TERMS.items():
        rec = {"axis": axis, "arctic_shift_submissions": None, "pullpush_comments": None}
        url = ("https://arctic-shift.photon-reddit.com/api/posts/search?"
               + urllib.parse.urlencode({"subreddit": subs, "query": term, "limit": "100"}))
        d, err = get(url, timeout=40)
        if d is not None and "data" in d:
            rec["arctic_shift_submissions"] = len(d["data"])
            rec["sample_titles"] = [p.get("title", "")[:110] for p in d["data"][:6]]
        else:
            failures.append({"term": term, "api": "arctic-shift", "error": err})
        url = ("https://api.pullpush.io/reddit/search/comment/?"
               + urllib.parse.urlencode({"subreddit": subs, "q": term, "size": "100"}))
        d, err = get(url, timeout=40)
        if d is not None and "data" in d:
            rec["pullpush_comments"] = len(d["data"])
        else:
            failures.append({"term": term, "api": "pullpush", "error": err})
        out[term] = rec
        time.sleep(1.2)
    return out, failures


def main():
    ac, ac_fail = autocomplete()
    print(f"autocomplete: {len(ac)} prefixes ok, {len(ac_fail)} failed")
    rd, rd_fail = reddit_counts()
    ok = sum(1 for v in rd.values()
             if v["arctic_shift_submissions"] is not None or v["pullpush_comments"] is not None)
    print(f"reddit: {ok}/{len(rd)} terms returned data, {len(rd_fail)} call failures")
    with open("user-research/data/0008-venues.json", "w") as f:
        json.dump({"generated_on": "2026-08-20",
                   "autocomplete": ac, "autocomplete_failures": ac_fail,
                   "reddit": rd, "reddit_failures": rd_fail,
                   "subreddits": SUBREDDITS}, f, indent=1)
    print("wrote user-research/data/0008-venues.json")


if __name__ == "__main__":
    main()
