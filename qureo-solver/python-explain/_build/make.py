#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""Render -> measure chapter pages -> rebuild with page numbers -> final PDF."""
import subprocess, os, sys
sys.path.insert(0, "/tmp/qureo_py")
import build_book as B

OUT = B.OUT
TMP_HTML = f"{OUT}/_tmp.html"
FINAL_HTML = f"{OUT}/QUREO-Python-25chapters.html"
FINAL_PDF = f"{OUT}/QUREO-Python-25chapters.pdf"


def render(html, pdf):
    open(TMP_HTML, "w", encoding="utf-8").write(html)
    subprocess.run(["google-chrome", "--headless=new", "--disable-gpu", "--no-sandbox",
                    "--no-pdf-header-footer", f"--print-to-pdf={pdf}",
                    f"file://{TMP_HTML}"], check=True,
                   stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)


def pages_of(pdf):
    txt = subprocess.run(["pdftotext", "-layout", pdf, "-"],
                         capture_output=True, text=True).stdout
    pages = txt.split("\f")
    if pages and pages[-1].strip() == "":
        pages = pages[:-1]
    return pages


def measure(pdf):
    pages = pages_of(pdf)
    result = {}
    for i, ch in enumerate(B.COURSE, start=1):
        cid = str(ch["id"])
        occ = [p + 1 for p, pg in enumerate(pages) if cid in pg]
        result[i] = max(occ) if occ else None
    return result, len(pages)


def main():
    # pass 1: placeholder
    html = B.build_html({i: "—" for i in range(1, B.TOTAL_CH + 1)}, "—")
    render(html, "/tmp/qureo_py/_p1.pdf")
    pages, total = measure("/tmp/qureo_py/_p1.pdf")
    print("pass1 total pages:", total)
    print("pass1 chapter pages:", pages)
    # pass 2: real numbers
    html = B.build_html(pages, total)
    render(html, "/tmp/qureo_py/_p2.pdf")
    pages2, total2 = measure("/tmp/qureo_py/_p2.pdf")
    print("pass2 total pages:", total2, "same chapter pages:", pages2 == pages)
    # finalize with pass2 numbers if changed
    if total2 != total or pages2 != pages:
        pages, total = pages2, total2
        html = B.build_html(pages, total)
    open(FINAL_HTML, "w", encoding="utf-8").write(html)
    render(html, FINAL_PDF)
    _, total3 = measure(FINAL_PDF)
    print("FINAL:", FINAL_PDF, "pages:", total3)
    if os.path.exists(TMP_HTML):
        os.remove(TMP_HTML)


if __name__ == "__main__":
    main()
