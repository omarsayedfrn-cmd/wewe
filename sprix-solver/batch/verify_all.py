#!/usr/bin/env python3
"""تحقق مستقل من إتمام طلاب SPRIX + إنتاج ملف المكتملين.

Usage:
  python3 verify_all.py [--workers 5] [--out completed_students.json]

- لكل طالب في valid_students.json: login + GET /subjects/7/units
- المكتمل = الوحدات 19-24 كلها progress_pct >= 100
- المخرجات: completed_students.json [{name, code, password}] + needs_work.json + verify_report.json
"""
import json, os, sys, time, random, threading
from concurrent.futures import ThreadPoolExecutor, as_completed

import requests

HERE = os.path.dirname(os.path.abspath(__file__))
BASE = "https://egy.app.spx-learning-square.com"
UA = ("Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 "
      "(KHTML, like Gecko) Chrome/153.0.0.0 Safari/537.36")
HEADERS = {
    "User-Agent": UA,
    "Accept": "application/json, text/plain, */*",
    "Content-Type": "application/json",
    "Referer": f"{BASE}/subjects/7/curriculum",
    "Accept-Language": "en-US,en;q=0.9",
}
TARGET = [19, 20, 21, 22, 23, 24]

_lock = threading.Lock()
_done = 0


def verify_one(stu, idx, total):
    global _done
    time.sleep((idx % 5) * 1.0 + random.uniform(0.5, 1.5))
    out = {"name": stu["name"], "code": stu["code"], "units": {},
           "complete": False, "error": ""}
    try:
        s = requests.Session()
        s.headers.update(HEADERS)
        r = s.post(f"{BASE}/api/v1/auth/login",
                   json={"login_id": stu["code"], "password": stu["password"]},
                   timeout=25)
        if r.status_code != 200:
            out["error"] = f"login http={r.status_code}"
        else:
            time.sleep(random.uniform(0.3, 0.8))
            u = s.get(f"{BASE}/api/v1/subjects/7/units", timeout=25).json()
            for row in u["data"]:
                if row["id"] in TARGET:
                    out["units"][str(row["id"])] = row.get("progress_pct")
            vals = [float(out["units"].get(str(i)) or 0) for i in TARGET]
            out["complete"] = len(out["units"]) == 6 and all(v >= 100 for v in vals)
    except Exception as e:
        out["error"] = f"{type(e).__name__}: {e}"
    with _lock:
        _done += 1
        print(f"[{_done}/{total}] {stu['code']} complete={out['complete']} "
              f"units={out['units']} {out['error']}", flush=True)
    time.sleep(random.uniform(0.5, 1.0))
    return out


def main():
    workers, out_name = 5, "completed_students.json"
    for i, a in enumerate(sys.argv):
        if a == "--workers" and i + 1 < len(sys.argv):
            workers = int(sys.argv[i + 1])
        if a == "--out" and i + 1 < len(sys.argv):
            out_name = sys.argv[i + 1]
    students = json.load(open(os.path.join(HERE, "valid_students.json"), encoding="utf-8"))
    total = len(students)
    print(f"verify {total} students workers={workers}", flush=True)
    details = []
    with ThreadPoolExecutor(max_workers=workers) as ex:
        futs = [ex.submit(verify_one, stu, i, total) for i, stu in enumerate(students)]
        for f in as_completed(futs):
            details.append(f.result())
    by_code = {d["code"]: d for d in details}
    completed, needs = [], []
    for stu in students:
        d = by_code[stu["code"]]
        if d["complete"]:
            completed.append({k: stu[k] for k in ("name", "code", "password")})
        else:
            needs.append({"name": stu["name"], "code": stu["code"],
                          "password": stu["password"], "units": d["units"],
                          "error": d["error"]})
    json.dump(completed, open(os.path.join(HERE, out_name), "w", encoding="utf-8"),
              ensure_ascii=False, indent=2)
    json.dump(needs, open(os.path.join(HERE, "needs_work.json"), "w", encoding="utf-8"),
              ensure_ascii=False, indent=2)
    json.dump({"total": total, "completed": len(completed),
               "needs_work": len(needs), "details": details},
              open(os.path.join(HERE, "verify_report.json"), "w", encoding="utf-8"),
              ensure_ascii=False, indent=2)
    print(f"completed={len(completed)} needs_work={len(needs)} -> {out_name}", flush=True)


if __name__ == "__main__":
    main()
