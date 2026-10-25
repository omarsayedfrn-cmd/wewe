#!/usr/bin/env python3
"""حل لعبة SPHINX (Global Finance Quest — subject 8) لمجموعة طلاب بشكل متوازٍ آمن.

Usage:
  nohup python3 run_batch.py [--workers 3] [--only CODE1,CODE2] [--students FILE] [--lock 710000] &
  # إلزامي التشغيل بـ setsid عشان أي tool timeout ما يقتلش الـ process group:
  setsid nohup python3 run_batch.py --workers 3 > batch.out 2>&1 < /dev/null & disown

- الدخل: ملف الطلاب (افتراضي ../../docs/data/students_boys.json) سكيما [{name, code, password}].
- لكل طالب: يستدعي ../solve.sh (نفس المحرك المُتحقق) ويلوج في logs/<code>.log.
- ضد الباند: workers=3 + stagger عشوائي + solve.sh نفسه فيه sleeps.
- المخرجات: summary.json + logs/ + batch_progress.log
"""
import json, os, sys, time, random, argparse, subprocess
from concurrent.futures import ThreadPoolExecutor, as_completed

HERE = os.path.dirname(os.path.abspath(__file__))
SOLVER = os.path.normpath(os.path.join(HERE, "..", "solve.sh"))
DEFAULT_STUDENTS = os.path.normpath(os.path.join(HERE, "..", "..", "docs", "data", "students_boys.json"))
LOGS = os.path.join(HERE, "logs")
LOCK = False

def log(msg):
    line = f"[{time.strftime('%H:%M:%S')}] {msg}"
    print(line, flush=True)
    with open(os.path.join(HERE, "batch_progress.log"), "a", encoding="utf-8") as f:
        f.write(line + "\n")

def parse_result(text):
    res = {}
    for line in reversed(text.splitlines()):
        if line.startswith("totalScore="):
            for tok in line.split():
                if "=" in tok:
                    k, v = tok.split("=", 1)
                    res[k] = v
            break
    return res

def run_student(stu, lock, sleep_scale):
    code = str(stu.get("code") or stu.get("login_id"))
    pw = stu.get("password", "")
    logf = os.path.join(LOGS, f"{code}.log")
    env = dict(os.environ, SLEEP_SCALE=str(sleep_scale), LOCK_ASSETS=str(lock))
    time.sleep(random.uniform(1.0, 4.0))
    with open(logf, "w", encoding="utf-8") as fh:
        try:
            p = subprocess.run(["bash", SOLVER, code, pw], stdout=fh, stderr=subprocess.STDOUT,
                               env=env, timeout=1500)
            rc = p.returncode
        except subprocess.TimeoutExpired:
            rc = -1
        except Exception as e:
            fh.write(f"RUN ERROR: {e}\n")
            rc = -2
    text = open(logf, encoding="utf-8").read()
    res = parse_result(text)
    return {"name": stu.get("name"), "code": code,
            "grade": res.get("grade"), "totalScore": res.get("totalScore"),
            "finalAssets": res.get("finalAssets"), "profit": res.get("profit"),
            "passed": res.get("passed"), "rc": rc}

def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--workers", type=int, default=3)
    ap.add_argument("--only", default="")
    ap.add_argument("--students", default=DEFAULT_STUDENTS)
    ap.add_argument("--lock", type=int, default=700000)
    ap.add_argument("--sleep-scale", type=float, default=0.05)
    a = ap.parse_args()

    os.makedirs(LOGS, exist_ok=True)
    students = json.load(open(a.students, encoding="utf-8"))
    if a.only:
        want = {c.strip() for c in a.only.split(",") if c.strip()}
        students = [s for s in students if str(s.get("code")) in want]
    log(f"batch start: {len(students)} students, workers={a.workers}, lock={a.lock}")

    results = []
    with ThreadPoolExecutor(max_workers=a.workers) as ex:
        futs = {ex.submit(run_student, s, a.lock, a.sleep_scale): s for s in students}
        for fut in as_completed(futs):
            r = fut.result()
            results.append(r)
            log(f"{r['name']} ({r['code']}): grade={r['grade']} total={r['totalScore']} assets={r['finalAssets']} rc={r['rc']}")
            json.dump(results, open(os.path.join(HERE, "summary.json"), "w", encoding="utf-8"),
                      ensure_ascii=False, indent=1)

    results.sort(key=lambda r: str(r.get("code")))
    ss = sum(1 for r in results if r.get("grade") == "SS")
    log(f"batch done: {ss}/{len(results)} = SS")
    json.dump(results, open(os.path.join(HERE, "summary.json"), "w", encoding="utf-8"),
              ensure_ascii=False, indent=1)

if __name__ == "__main__":
    main()
