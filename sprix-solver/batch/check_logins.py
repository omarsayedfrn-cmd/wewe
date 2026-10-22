#!/usr/bin/env python3
"""فحص دخول طلاب SPRIX بشكل متوازي آمن (ضد الباند).

Usage:
  python3 check_logins.py [students.json] [--workers 3] [--outdir .]

- يشيّك login فقط (POST /auth/login + GET /auth/me) بدون أي حل.
- التوازي الافتراضي 3 + jitter عشوائي + stagger بين الثريدز.
- المخرجات في outdir:
    valid_students.json    <- دخولهم سليم (نفس سكيما الدخل)
    wrong_passwords.json   <- باسورد/كود غلط (نفس السكيما + حقل error)
    check_report.json      <- ملخص + حالة كل طالب
"""
import json, os, sys, time, random, threading
from concurrent.futures import ThreadPoolExecutor, as_completed

import requests

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

_lock = threading.Lock()
_done = 0


def check_one(stu, worker_idx):
    """Returns (status, detail). status in: valid / wrong_password / rate_limited / network_error."""
    global _done
    # stagger عند البداية: كل worker يستنى دوره + jitter
    time.sleep(worker_idx * 2.0 + random.uniform(1.0, 2.5))
    s = requests.Session()
    s.headers.update(HEADERS)
    code = stu["code"]
    for attempt in (1, 2):
        try:
            r = s.post(f"{BASE}/api/v1/auth/login",
                       json={"login_id": code, "password": stu["password"]},
                       timeout=25)
            if r.status_code == 200:
                try:
                    body = r.json()
                except Exception:
                    return ("network_error", "non-JSON success body")
                if body.get("success"):
                    time.sleep(random.uniform(0.5, 1.0))
                    me = s.get(f"{BASE}/api/v1/auth/me", timeout=25)
                    if me.status_code == 200:
                        return ("valid", "ok")
                    return ("network_error", f"me http={me.status_code}")
                return ("wrong_password", "success=false")
            if r.status_code == 401:
                return ("wrong_password", "invalid_credentials")
            if r.status_code == 429 and attempt == 1:
                time.sleep(15 + random.uniform(0, 5))  # backoff ثم إعادة واحدة
                continue
            if r.status_code == 429:
                return ("rate_limited", "http 429 twice")
            return ("network_error", f"login http={r.status_code} body={r.text[:120]}")
        except requests.RequestException as e:
            if attempt == 1:
                time.sleep(8 + random.uniform(0, 4))
                continue
            return ("network_error", f"{type(e).__name__}: {e}")
    return ("network_error", "unreachable")


def main():
    students_path = sys.argv[1] if len(sys.argv) > 1 and not sys.argv[1].startswith("--") else None
    if students_path is None:
        # default: ملف الطلاب جنب مجلد الـ batch
        here = os.path.dirname(os.path.abspath(__file__))
        students_path = os.path.join(os.path.dirname(here), "..", "students_boys.json")
        students_path = os.path.normpath(students_path)
        if not os.path.exists(students_path):
            students_path = "/home/omsa/Projects/solver-project/students_boys.json"
    workers = 3
    outdir = os.path.dirname(os.path.abspath(__file__))
    for i, a in enumerate(sys.argv):
        if a == "--workers" and i + 1 < len(sys.argv):
            workers = int(sys.argv[i + 1])
        if a == "--outdir" and i + 1 < len(sys.argv):
            outdir = sys.argv[i + 1]
    os.makedirs(outdir, exist_ok=True)

    students = json.load(open(students_path, encoding="utf-8"))
    total = len(students)
    print(f"فحص {total} طالب | workers={workers} | outdir={outdir}", flush=True)

    results = {}  # code -> (status, detail, stu)

    def task(idx, stu):
        global _done
        status, detail = check_one(stu, idx % workers)
        with _lock:
            _done += 1
            print(f"[{_done}/{total}] {stu['code']} {stu['name'][:30]} -> {status} ({detail})",
                  flush=True)
        # فاصل إنساني قبل الطالب التالي على نفس الثريد
        time.sleep(random.uniform(1.0, 2.0))
        return stu["code"], status, detail, stu

    with ThreadPoolExecutor(max_workers=workers) as ex:
        futs = [ex.submit(task, i, stu) for i, stu in enumerate(students)]
        for f in as_completed(futs):
            code, status, detail, stu = f.result()
            results[code] = (status, detail, stu)

    valid, wrong, other = [], [], []
    report_details = []
    for stu in students:  # بنفس ترتيب الملف الأصلي
        status, detail, _s = results[stu["code"]]
        report_details.append({"name": stu["name"], "code": stu["code"],
                               "status": status, "detail": detail})
        if status == "valid":
            valid.append(stu)
        elif status == "wrong_password":
            wrong.append({**stu, "error": detail})
        else:
            other.append({"name": stu["name"], "code": stu["code"],
                          "password": stu["password"], "error": f"{status}: {detail}"})

    json.dump(valid, open(os.path.join(outdir, "valid_students.json"), "w", encoding="utf-8"),
              ensure_ascii=False, indent=2)
    json.dump(wrong, open(os.path.join(outdir, "wrong_passwords.json"), "w", encoding="utf-8"),
              ensure_ascii=False, indent=2)
    if other:
        json.dump(other, open(os.path.join(outdir, "retry_later.json"), "w", encoding="utf-8"),
                  ensure_ascii=False, indent=2)
    json.dump({"total": total, "valid": len(valid), "wrong_password": len(wrong),
               "other": len(other), "details": report_details},
              open(os.path.join(outdir, "check_report.json"), "w", encoding="utf-8"),
              ensure_ascii=False, indent=2)
    print(f"\nالنتيجة: valid={len(valid)} wrong={len(wrong)} other={len(other)}", flush=True)
    if other:
        print("ملحوظة: other (ممكن rate-limit) في retry_later.json — أعد فحصهم لاحقا.", flush=True)


if __name__ == "__main__":
    main()
