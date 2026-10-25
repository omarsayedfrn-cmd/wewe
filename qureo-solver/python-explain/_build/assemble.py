#!/usr/bin/env python3
import json, re, os, glob

BASE = "/tmp/qureo_py"

def clean(s):
    if not s:
        return ""
    s = re.sub(r"\[\[bdi\]\]", "", s)
    s = re.sub(r"\[\[/bdi\]\]", "", s)
    s = re.sub(r"\[\[bold\]\]", "", s)
    s = re.sub(r"\[\[/bold\]\]", "", s)
    s = re.sub(r"\[\[copy\]\]", "", s)
    s = re.sub(r"\[\[/copy\]\]", "", s)
    s = re.sub(r"\[\[/?[a-zA-Z]+\]\]", "", s)
    return s.strip()

section = json.load(open(f"{BASE}/section106.json", encoding="utf-8"))
chapters = section["chapters"]

out = []
for ch in chapters:
    cid = str(ch["id"])
    cj = json.load(open(f"{BASE}/chap/{cid}.json", encoding="utf-8"))
    lecs = []
    for lmeta in cj.get("lectures", []):
        lid = str(lmeta["id"])
        lj = json.load(open(f"{BASE}/lec/{lid}.json", encoding="utf-8"))
        summaries = [{"text": clean(s.get("text")), "check": clean(s.get("check_text"))}
                     for s in lj.get("summaries", [])]
        tries, supplements = [], []
        for t in lj.get("talks", []):
            ty = t.get("type", "")
            b = t.get("body", {})
            if ty.startswith("try"):
                codes = b.get("codes", [])
                model = ""
                lang = "python"
                if codes:
                    model = codes[0].get("model_answer") or codes[0].get("code") or ""
                    lang = codes[0].get("lang", "python")
                q = b.get("question", {})
                tries.append({
                    "title": clean(q.get("text", "")) if isinstance(q, dict) else "",
                    "guide": clean(b.get("guide", "")),
                    "hints": [clean(h) for h in b.get("hints", [])],
                    "model_answer": model,
                    "lang": lang,
                })
            elif ty == "supplement":
                supplements.append({"title": clean(b.get("title", "")),
                                    "filename": b.get("filename", ""),
                                    "alt": clean(b.get("alt", ""))})
        lecs.append({
            "id": lid,
            "title": lj.get("lecture", {}).get("title") or lmeta.get("title"),
            "summaries": summaries,
            "tries": tries,
            "supplements": supplements,
            "talk_types": sorted(set(t.get("type", "") for t in lj.get("talks", []))),
        })
    out.append({
        "id": ch["id"],
        "seq": ch["seq"],
        "name": ch["name"],
        "description": clean(ch.get("description", "")),
        "test_range": ch.get("test_range", ""),
        "test_type": ch.get("test_type", ""),
        "question_count": ch.get("question_count", 0),
        "lectures": lecs,
    })

json.dump(out, open(f"{BASE}/course.json", "w", encoding="utf-8"), ensure_ascii=False, indent=2)

# summary stats
tot_s = sum(len(l["summaries"]) for c in out for l in c["lectures"])
tot_t = sum(len(l["tries"]) for c in out for l in c["lectures"])
print(f"chapters={len(out)} lectures={sum(len(c['lectures']) for c in out)} summaries={tot_s} tries={tot_t}")
print("chapters with 0 tries:", [c["seq"] for c in out if sum(len(l["tries"]) for l in c["lectures"]) == 0])
print("chapters with 0 summaries:", [c["seq"] for c in out if sum(len(l["summaries"]) for l in c["lectures"]) == 0])
