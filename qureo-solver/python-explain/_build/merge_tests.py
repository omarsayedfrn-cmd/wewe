#!/usr/bin/env python3
import json, re, os

BASE = "/tmp/qureo_py"

def clean(s):
    if not s:
        return ""
    for tag in ("bdi", "bold", "copy"):
        s = s.replace(f"[[{tag}]]", "").replace(f"[[/{tag}]]", "")
    s = re.sub(r"\[\[/?[a-zA-Z]+\]\]", "", s)
    return s.strip()

course = json.load(open(f"{BASE}/course.json", encoding="utf-8"))

for ch in course:
    cid = str(ch["id"])
    path = f"{BASE}/test/{cid}.json"
    questions = []
    if os.path.exists(path):
        data = json.load(open(path, encoding="utf-8"))
        if isinstance(data, list):
            for item in data:
                q = item.get("question", {})
                choices = item.get("choices") or []
                descs = item.get("descriptions") or []
                questions.append({
                    "seq": q.get("seq"),
                    "type": q.get("type"),
                    "content": clean(q.get("content", "")),
                    "hints": [clean(h) for h in (q.get("hints") or [])],
                    "choices": [{"id": c["id"], "content": clean(c["content"])} for c in choices],
                    "description": {
                        "code": (descs[0].get("code", "") if descs else ""),
                        "lang": (descs[0].get("lang", "python") if descs else "python"),
                        "placeholders": (descs[0].get("placeholders", []) if descs else []),
                    } if descs else None,
                })
    ch["test_questions"] = questions

json.dump(course, open(f"{BASE}/course.json", "w", encoding="utf-8"), ensure_ascii=False, indent=2)

nq = sum(len(c["test_questions"]) for c in course)
nchoice = sum(1 for c in course for q in c["test_questions"] if q["type"] == "choice")
ndesc = sum(1 for c in course for q in c["test_questions"] if q["type"] == "description")
print(f"total test questions={nq}  choice={nchoice}  description={ndesc}")
