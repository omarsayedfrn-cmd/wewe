#!/usr/bin/env python3
# -*- coding: utf-8 -*-
import json, os, glob, html

BASE = "/tmp/sprix_py"
ANSWERS = json.load(open("/home/omsa/Projects/solver-project/sprix-solver/answers.json", encoding="utf-8"))
curriculum = json.load(open(f"{BASE}/curriculum.json", encoding="utf-8"))["data"]


def unesc(s):
    return html.unescape(s) if s else s


out_units = []
for unit in curriculum:
    items = []
    for it in unit["items"]:
        t = it["item_type"]
        if t == "chapter":
            path = f"{BASE}/blocks/{it['id']}.json"
            if not os.path.exists(path):
                continue
            bj = json.load(open(path, encoding="utf-8"))
            blocks = bj["data"]["blocks"]
            # correct option per block from answers.json
            corr = {}
            for pair in ANSWERS["chapters"].get(str(it["id"]), []):
                corr[str(pair[0])] = pair[1]
            lines, questions = [], []
            for b in blocks:
                if b["type"] == "dialogue":
                    name = (b.get("character") or {}).get("name") or ""
                    lines.append({"who": name, "text": unesc(b.get("content") or "")})
                elif b["type"] == "image":
                    lines.append({"who": "", "image": b.get("image") or b.get("content") or ""})
                elif b["type"] == "question":
                    q = b.get("question") or {}
                    coid = corr.get(str(b["id"]))
                    opts = [{"id": o["id"], "text": unesc(o.get("text") or "")} for o in (b.get("options") or [])]
                    questions.append({
                        "qid": q.get("id"),
                        "text": unesc(q.get("question_text") or ""),
                        "hint": unesc(q.get("hint1") or ""),
                        "explanation": unesc(q.get("explanation") or ""),
                        "options": opts,
                        "correct": coid,
                    })
            items.append({"type": "chapter", "id": it["id"], "title": it["title"],
                          "lines": lines, "questions": questions})
        elif t == "review":
            items.append({"type": "review", "id": it["id"], "title": it["title"]})
        elif t == "test":
            path = f"{BASE}/tests/{it['id']}.json"
            if not os.path.exists(path):
                continue
            tj = json.load(open(path, encoding="utf-8"))
            d = tj.get("data") or {}
            qs = d.get("questions") or {}
            opts = d.get("options") or {}
            corr = {}
            for pair in ANSWERS["tests"].get(str(it["id"]), []):
                corr[str(pair[0])] = pair[1]
            questions = []
            for qid, q in qs.items():
                questions.append({
                    "qid": q.get("id"),
                    "text": unesc(q.get("question_text") or ""),
                    "hint": unesc(q.get("hint1") or ""),
                    "options": [{"id": o["id"], "text": unesc(o.get("text") or "")} for o in opts.get(qid, [])],
                    "correct": corr.get(str(qid)),
                })
            questions.sort(key=lambda x: x["qid"])
            items.append({"type": "test", "id": it["id"], "title": it["title"], "questions": questions})
    out_units.append({"id": unit["id"], "title": unit["title"], "items": items})

json.dump(out_units, open(f"{BASE}/subject7.json", "w", encoding="utf-8"), ensure_ascii=False, indent=1)

nch = sum(1 for u in out_units for i in u["items"] if i["type"] == "chapter")
nts = sum(1 for u in out_units for i in u["items"] if i["type"] == "test")
nq = sum(len(i["questions"]) for u in out_units for i in u["items"] if i["type"] in ("chapter", "test"))
nl = sum(len(i["lines"]) for u in out_units for i in u["items"] if i["type"] == "chapter")
miss = [f"ch{i['id']}:{q['qid']}" for u in out_units for i in u["items"] if i["type"] == "chapter" for q in i["questions"] if not q["correct"]]
misst = [f"test{i['id']}:{q['qid']}" for u in out_units for i in u["items"] if i["type"] == "test" for q in i["questions"] if not q["correct"]]
print(f"units={len(out_units)} chapters={nch} tests={nts} questions={nq} dialogue_lines={nl}")
print("chapter q without answer:", len(miss), miss[:8])
print("test q without answer:", len(misst), misst[:8])
