#!/usr/bin/env python3
# -*- coding: utf-8 -*-
import subprocess, os, sys
sys.path.insert(0, "/tmp/sprix_py")
import build_sprix as B

OUT = B.OUT
TMP = f"{OUT}/_tmp.html"
FINAL_HTML = f"{OUT}/SPRIX-Financial-Literacy-Subject7.html"
FINAL_PDF = f"{OUT}/SPRIX-Financial-Literacy-Subject7.pdf"


def render(html, pdf):
    open(TMP, "w", encoding="utf-8").write(html)
    subprocess.run(["google-chrome", "--headless=new", "--disable-gpu", "--no-sandbox",
                    "--no-pdf-header-footer", f"--print-to-pdf={pdf}", f"file://{TMP}"],
                   check=True, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL,
                   timeout=600)


def pages_of(pdf):
    txt = subprocess.run(["pdftotext", "-layout", pdf, "-"], capture_output=True, text=True).stdout
    pages = txt.split("\f")
    if pages and pages[-1].strip() == "":
        pages = pages[:-1]
    return pages


def measure(pdf):
    pages = pages_of(pdf)
    res = {}
    for anchor, marker in B.anchors():
        occ = [i + 1 for i, pg in enumerate(pages) if marker in pg]
        res[anchor] = max(occ) if occ else None
    return res, len(pages)


def main():
    html = B.build_html({a: "—" for a, _ in B.anchors()}, "—")
    render(html, "/tmp/sprix_py/_p1.pdf")
    pages, total = measure("/tmp/sprix_py/_p1.pdf")
    print("pass1 pages:", total)
    html = B.build_html(pages, total)
    render(html, "/tmp/sprix_py/_p2.pdf")
    pages2, total2 = measure("/tmp/sprix_py/_p2.pdf")
    print("pass2 pages:", total2, "stable:", pages2 == pages)
    if pages2 != pages or total2 != total:
        pages, total = pages2, total2
        html = B.build_html(pages, total)
    open(FINAL_HTML, "w", encoding="utf-8").write(html)
    render(html, FINAL_PDF)
    _, t3 = measure(FINAL_PDF)
    print("FINAL pages:", t3)
    if os.path.exists(TMP):
        os.remove(TMP)


if __name__ == "__main__":
    main()
