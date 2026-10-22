#!/usr/bin/env python3
"""حل منهج SPRIX (وحدات 19-24) لمجموعة طلاب بشكل متوازي آمن.

Usage:
  nohup python3 run_batch.py [--workers 3] [--start 1] [--only CODE1,CODE2] &

- الدخل: valid_students.json (نفس المجلد) — سكيما {name, code, password}
- لكل طالب: يتخطى لو خلصان 100% أصلا، وإلا يشغّل solve.sh (START=1) ويلوج في logs/<code>.log
- ضد الباند: workers=3 + stagger عشوائي 2-6s قبل كل طالب + فاصل بعد كل طالب + solve.sh نفسه فيه sleeps
- retry: فشل الشبكة (non-JSON/كيرل) → إعادة واحدة بعد 30s. فشل إجابة (WRONG) → لا إعادة (محتاج تحديث answers).
- المخرجات: summary.json + logs/ + batch_progress.log
"""
import json, os, sys, time, random, threading, subprocess
from concurrent.futures import ThreadPoolExecutor, as_completed

import requests

HERE = os.path.dirname(os.path.abspath(__file__))
SOLVER_DIR = os.path.normpath(os.path.join(HERE, ".."))
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
TARGET_UNITS = [19, 20, 21, 22, 23, 24]

_lock = threading.Lock()
_done = 0
_progress_fh = None


def log_progress(msg):
    with _lock:
        line = f"[{time.strftime('%H:%M:%S')}] {msg}"
        print(line, flush=True)
        if _progress_fh:
            _progress_fh.write(line + "\n")
            _progress_fh.flush()


def already_done(stu):
    """True لو الوحدات 19-24 كلها 100% (يوفر ساعات). None لو تعذر الفحص."""
    try:
        s = requests.Session()
        s.headers.update(HEADERS)
        r = s.post(f"{BASE}/api/v1/auth/login",
                   json={"login_id": stu["code"], "password": stu["password"]},
                   timeout=25)
        if r.status_code != 200:
            return None
        time.sleep(random.uniform(0.5, 1.0))
        u = s.get(f"{BASE}/api/v1/subjects/7/units", timeout=25).json()
        prog = {row["id"]: row for row in u["data"] if row["id"] in TARGET_UNITS}
        if len(prog) < len(TARGET_UNITS):
            return None
        return all(float(row.get("progress_pct") or 0) >= 100 for row in prog.values())
    except Exception:
        return None


def run_solve(stu, start):
    logdir = os.path.join(HERE, "logs")
    os.makedirs(logdir, exist_ok=True)
    logpath = os.path.join(logdir, f"{stu['code']}.log")
    env = dict(os.environ, LOGIN_ID=stu["code"], PASSWORD=stu["password"],
               START=str(start),
               SLEEP_SCALE=os.environ.get("SLEEP_SCALE", "1"))
    with open(logpath, "a", encoding="utf-8") as fh:
        fh.write(f"\n===== run at {time.strftime('%Y-%m-%d %H:%M:%S')} START={start} =====\n")
        fh.flush()
        p = subprocess.run(["bash", os.path.join(SOLVER_DIR, "solve.sh")],
                           cwd=SOLVER_DIR, env=env,
                           stdout=fh, stderr=subprocess.STDOUT, timeout=2400)
    return p.returncode, logpath


def worker(idx, stu, start, total):
    global _done
    code = stu["code"]
    # stagger ضد thundering herd
    time.sleep(random.uniform(2.0, 6.0))
    log_progress(f"start {code} ({stu['name'][:25]})")
    t0 = time.time()
    try:
        done = already_done(stu)
    except Exception as e:
        done = None
    if done is True:
        with _lock:
            _done += 1
        log_progress(f"[{_done}/{total}] {code} already 100% -> skipped")
        return {"code": code, "name": stu["name"], "status": "already_done",
                "duration_s": round(time.time() - t0)}
    if done is None:
        log_progress(f"{code}: progress check inconclusive -> solving anyway")
    time.sleep(random.uniform(1.0, 3.0))  # فاصل إنساني قبل الحل

    status, detail, rc = "failed", "", -1
    for attempt in (1, 2):
        rc, logpath = run_solve(stu, start)
        tail = ""
        try:
            with open(logpath, encoding="utf-8") as fh:
                content = fh.read()
            tail = content[-1500:]
        except Exception:
            pass
        if rc == 0 and "DONE." in tail:
            status, detail = "done", f"log={logpath}"
            break
        # فشل إجابة (محتوى) لا يُعاد — فشل شبكة يُعاد مرة
        if "WRONG (retry with correct id)" in tail or "missing from answers" in tail:
            status, detail = "failed_answers", f"rc={rc} log={logpath}"
            break
        if attempt == 1:
            log_progress(f"{code}: network-ish fail rc={rc} -> backoff 30s + retry")
            time.sleep(30 + random.uniform(0, 10))
            continue
        status, detail = "failed", f"rc={rc} log={logpath}"
    dur = round(time.time() - t0)
    with _lock:
        _done += 1
    log_progress(f"[{_done}/{total}] {code} -> {status} ({dur}s)")
    time.sleep(random.uniform(2.0, 4.0))  # فاصل بعد كل طالب
    return {"code": code, "name": stu["name"], "status": status,
            "detail": detail, "duration_s": dur}


def main():
    global _progress_fh, _done
    workers, start, only = 3, "1", None
    for i, a in enumerate(sys.argv):
        if a == "--workers" and i + 1 < len(sys.argv):
            workers = int(sys.argv[i + 1])
        if a == "--start" and i + 1 < len(sys.argv):
            start = sys.argv[i + 1]
        if a == "--only" and i + 1 < len(sys.argv):
            only = set(sys.argv[i + 1].split(","))
    students = json.load(open(os.path.join(HERE, "valid_students.json"), encoding="utf-8"))
    if only:
        students = [s for s in students if s["code"] in only]
    # resume: تخطي اللي خلصوا في تشغيل سابق (done/already_done في summary.json)
    results = []
    try:
        prev = json.load(open(os.path.join(HERE, "summary.json"), encoding="utf-8"))
        done_codes = {r["code"] for r in prev
                      if r.get("status") in ("done", "already_done")}
        results = [r for r in prev if r.get("code") in done_codes]
        if done_codes:
            students = [s for s in students if s["code"] not in done_codes]
            print(f"resume: skip {len(done_codes)} already finished", flush=True)
    except (FileNotFoundError, json.JSONDecodeError):
        pass
    total = len(students) + len(results)
    _done = len(results)
    _progress_fh = open(os.path.join(HERE, "batch_progress.log"), "a", encoding="utf-8")
    log_progress(f"batch start: {len(students)} students workers={workers} START={start} "
                 f"SLEEP_SCALE={os.environ.get('SLEEP_SCALE','1')} (+{len(results)} resumed)")
    if not students:
        log_progress(f"batch end: all resumed")
        _progress_fh.close()
        return
    try:
        with ThreadPoolExecutor(max_workers=workers) as ex:
            futs = [ex.submit(worker, i, stu, start, total) for i, stu in enumerate(students)]
            for f in as_completed(futs):
                results.append(f.result())
                json.dump(results, open(os.path.join(HERE, "summary.json"), "w",
                                       encoding="utf-8"), ensure_ascii=False, indent=2)
    finally:
        counts = {}
        for r in results:
            counts[r["status"]] = counts.get(r["status"], 0) + 1
        log_progress(f"batch end: {counts}")
        _progress_fh.close()


if __name__ == "__main__":
    main()
