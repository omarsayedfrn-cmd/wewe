#!/usr/bin/env python3
"""
Upload the answer bank to the private `solver_answers` table.

The answers are NO LONGER shipped inside the APK. They live server-side and are
served one engine at a time by the `solver-answers` Edge Function, only after
the caller's JWT, approval status, bound account, and entitlement are verified.

Usage:
    export SUPABASE_URL="https://<project>.supabase.co"
    export SUPABASE_SERVICE_ROLE_KEY="<service-role-key>"
    python3 solver-platform/supabase/scripts/upload_answers.py

Optional:
    ANSWERS_DIR=/path/to/Engines   # defaults to <repo>/Engines
"""

import json
import os
import sys
import urllib.error
import urllib.request
from datetime import datetime, timezone
from pathlib import Path

# <repo>/solver-platform/supabase/scripts/upload_answers.py -> <repo>
REPO_ROOT = Path(__file__).resolve().parents[3]
ANSWERS_DIR = Path(os.environ.get("ANSWERS_DIR", REPO_ROOT / "Engines"))

# engine_code -> (sub-directory, type)
SOURCES = {
    "qureo":       ("qureo-solver",       "qureo"),
    "qureo_js_en": ("qureo-js-en-solver", "qureo"),
    "qureo2":      ("qureo2-solver",      "qureo"),
    "qureo2_en":   ("qureo2-en-solver",   "qureo"),
    "sprix":       ("sprix-solver",       "sprix"),
    "sprix_en":    ("sprix-en-solver",    "sprix"),
}


def load_payload(engine_code: str) -> dict:
    folder, kind = SOURCES[engine_code]
    path = ANSWERS_DIR / folder / "answers.json"
    if not path.exists():
        raise FileNotFoundError(f"Missing answer file: {path}")

    with path.open("r", encoding="utf-8") as fh:
        data = json.load(fh)

    if kind == "sprix":
        chapters = data.get("chapters", {})
        # Preserve curriculum order; JSON object key order is not reliable
        # after storage, so store it explicitly for trial slicing.
        data["chapter_order"] = list(chapters.keys())

    return data


def main() -> int:
    url = os.environ.get("SUPABASE_URL", "").rstrip("/")
    key = os.environ.get("SUPABASE_SERVICE_ROLE_KEY", "")
    if not url or not key:
        print("ERROR: set SUPABASE_URL and SUPABASE_SERVICE_ROLE_KEY", file=sys.stderr)
        return 1

    now = datetime.now(timezone.utc).isoformat()
    rows = []
    for engine_code in SOURCES:
        try:
            payload = load_payload(engine_code)
        except FileNotFoundError as exc:
            print(f"ERROR: {exc}", file=sys.stderr)
            return 1
        rows.append({
            "engine_code": engine_code,
            "payload": payload,
            "updated_at": now,
        })
        print(f"Loaded {engine_code} ({len(payload)} top-level keys)")

    body = json.dumps(rows).encode("utf-8")
    request = urllib.request.Request(
        f"{url}/rest/v1/solver_answers?on_conflict=engine_code",
        data=body,
        method="POST",
        headers={
            "apikey": key,
            "Authorization": f"Bearer {key}",
            "Content-Type": "application/json",
            "Prefer": "resolution=merge-duplicates,return=minimal",
        },
    )

    try:
        with urllib.request.urlopen(request, timeout=60) as response:
            print(f"Uploaded {len(rows)} engine bundles (HTTP {response.status}).")
    except urllib.error.HTTPError as exc:
        print(f"Upload failed: HTTP {exc.code}\n{exc.read().decode(errors='replace')}",
              file=sys.stderr)
        return 1
    except urllib.error.URLError as exc:
        print(f"Upload failed: {exc}", file=sys.stderr)
        return 1

    return 0


if __name__ == "__main__":
    raise SystemExit(main())