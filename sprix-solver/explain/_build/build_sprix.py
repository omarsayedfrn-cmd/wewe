#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""Build the SPRIX subject 7 (الثقافة المالية) self-study book — authored style."""
import json, html as ihtml, os, sys
sys.path.insert(0, "/tmp/sprix_py")
from content_sprix import C as CONTENT

BASE = "/tmp/sprix_py"
OUT = "/home/omsa/Projects/solver-project/sprix-solver/explain"
CSS = open(f"{OUT}/_style.css", encoding="utf-8").read()
CSS += """
/* ملحق الثقافة المالية — بلا إيموجي، تنسيق مضغوط متّصل */
body{font-size:12pt;line-height:1.9}
.card{margin:8px 0}
.idea{margin:10px 0}
.sum{margin-top:8px;font-weight:700;color:var(--navy)}
.card li.ok{font-weight:700;color:var(--navy)}
.card li.ok .ok-tag{font-weight:400;font-size:.85em;color:var(--muted)}
.pt{padding-right:20px;padding-left:0;margin:4px 0}
.pt li{margin:8px 0}
.unitband{background:var(--navy);color:#fff;padding:6px 16px;margin:22px 0 6px;font-size:15pt;font-weight:700;break-before:page;break-after:avoid}
.unitband:first-of-type{break-before:auto}
@media print{.chap{border-top:0;break-before:auto}}
"""
DATA = json.load(open(f"{BASE}/subject7.json", encoding="utf-8"))


def esc(s):
    return ihtml.escape(s or "")


def render_questions(questions, label="س"):
    if not questions:
        return "<div class='card'>لا توجد أسئلة في هذا الفصل (فصل محاكاة تفاعلية).</div>"
    cards = ""
    for n, q in enumerate(questions, start=1):
        ids = [o["id"] for o in q["options"]]
        opts = ""
        for o in q["options"]:
            if q["correct"] and o["id"] == q["correct"]:
                opts += f"<li class='ok'>{esc(o['text'])} <span class='ok-tag'>(الإجابة الصحيحة)</span></li>"
            else:
                opts += f"<li>{esc(o['text'])}</li>"
        broken = "<div class='warn'><b>ملاحظة:</b> هذا السؤال معروف على المنصة بعدم وجود خيار صحيح مقبول فيه، فتجاوزه ولا تتعطل عنده.</div>" if (not q["correct"] or q["correct"] not in ids) else ""
        hint = f"<div class='tip'><b>تلميح:</b> {esc(q['hint'])}</div>" if q.get("hint") else ""
        cards += f"<div class='card'><b>{label}{n}:</b> {esc(q['text'])}<ul>{opts}</ul>{broken}{hint}</div>\n"
    return cards


def chapter_sec(ch, idx, unit):
    con = CONTENT.get(ch["id"], {})
    anchor = f"c{ch['id']}"
    pts = "".join(f"<li>{esc(p)}</li>" for p in con.get("points", []))
    ex = f"<div class='tip'><b>مثال:</b> {esc(con['example'])}</div>" if con.get("example") else ""
    note = f"<div class='warn'><b>تنبيه:</b> {esc(con['note'])}</div>" if con.get("note") else ""
    summ = f"<div class='sum'>الخلاصة: {esc(con.get('summary',''))}</div>" if con.get("summary") else ""
    return f"""<section class='chap' id='{anchor}'><div class='backtop'><a href='#top'>العودة للفهرس</a> — الفصل {idx}</div><div class="wrap">
<div class="head"><span class="pill">{esc(unit['title'])}</span> <span class="pill g">الفصل {idx}</span> <span class="pill t">درس</span>
<h1>{idx}. {esc(ch['title'])}</h1>
<div><span class="pill g">ID {ch['id']}</span></div></div>
<h2 class="s">1. الفكرة في جملة واحدة</h2>
<div class="idea">{esc(con.get('idea', ch['title']))}</div>
<h2 class="s">2. الشرح خطوة بخطوة</h2>
<div class="card"><ul class="pt">{pts}</ul>{ex}{note}{summ}</div>
<h2 class="s">3. أسئلة الفصل مع الحل</h2>
{render_questions(ch['questions'])}
</div><div class='backtop'><a href='#top'>العودة للفهرس</a></div></section>"""


def test_sec(t, unit):
    anchor = f"t{t['id']}"
    return f"""<section class='chap' id='{anchor}'><div class='backtop'><a href='#top'>العودة للفهرس</a> — اختبار</div><div class="wrap">
<div class="head"><span class="pill">{esc(unit['title'])}</span> <span class="pill g">اختبار الوحدة</span> <span class="pill t">اختبار</span>
<h1>اختبار: {esc(t['title'])}</h1>
<div><span class="pill g">ID {t['id']}</span> <span class="pill">عدد الأسئلة: {len(t['questions'])}</span></div></div>
<h2 class="s">أسئلة الاختبار مع الحل</h2>
{render_questions(t['questions'])}
</div><div class='backtop'><a href='#top'>العودة للفهرس</a></div></section>"""


def toc(units, pages):
    rows = ""
    chidx = 0
    for unit in units:
        rows += f"<tr><td colspan='3' style='text-align:right;background:#F5F3EE;font-weight:700'>الوحدة {unit['id']} — {esc(unit['title'])}</td></tr>"
        for it in unit["items"]:
            if it["type"] == "review":
                continue
            if it["type"] == "chapter":
                chidx += 1
                anchor = f"c{it['id']}"
                label = f"<b>{chidx}. {esc(it['title'])}</b>"
            else:
                anchor = f"t{it['id']}"
                label = f"<b>اختبار: {esc(it['title'])}</b>"
            p = pages.get(anchor, "—")
            rows += (f"<tr><td style='width:44px'><a href='#{anchor}'>&#9656;</a></td>"
                     f"<td>{label}<br><span style='color:#5E5E5E;font-size:9.5pt'>ID {it['id']} • "
                     f"أسئلة: {len(it.get('questions', []))}</span></td>"
                     f"<td style='width:80px;text-align:center'><b>{p}</b></td></tr>")
    return rows


def build_html(pages, total_pages):
    nch = sum(1 for u in DATA for i in u["items"] if i["type"] == "chapter")
    nts = sum(1 for u in DATA for i in u["items"] if i["type"] == "test")
    front = f"""<div class='toc'>
<div class="cover">
<span class="pill">SPRIX • الثقافة المالية</span> <span class="pill g">{nch} فصلًا + {nts} اختبارًا</span>
<h1>الثقافة المالية — من الصفر إلى اتخاذ القرار</h1>
<h2>شرح مبسّط بأسلوب واضح لكل فصل + أسئلة الفصول والاختبارات مع الحل (للدراسة الذاتية)</h2>
<div><span class="pill">عدد الصفحات الكلي: {total_pages}</span> <span class="pill g">Subject 7 • الوحدات 19 – 24</span></div>
</div>
<div class="how"><b>كيف تستخدم هذا الملف؟ (دراسة ذاتية)</b><ol>
<li>ابدأ من الوحدة الأولى وتقدّم بالترتيب — كل فصل يبني على ما قبله.</li>
<li>اقرأ «الفكرة في جملة واحدة» ثم «الشرح خطوة بخطوة» والخلاصة في نهايته.</li>
<li>حُلّ «أسئلة الفصل مع الحل» بنفسك، ثم راجع «اختبار الوحدة» في نهايتها.</li>
<li>الخيار الصحيح معلَّم بنص «(الإجابة الصحيحة)» لتصحيح ذاتي فوري.</li>
</ol></div>
<h2 class="s">الفهرس — اضغط السهم في النسخة الإلكترونية</h2>
<table><tr><th style="width:44px">#</th><th>المحتوى</th><th style="width:80px;text-align:center">صفحة</th></tr>{toc(DATA, pages)}</table>
</div>"""
    body = front
    chidx = 0
    for unit in DATA:
        body += f"\n<div class='unitband'>الوحدة {unit['id']} — {esc(unit['title'])}</div>"
        for it in unit["items"]:
            if it["type"] == "chapter":
                chidx += 1
                body += "\n" + chapter_sec(it, chidx, unit)
            elif it["type"] == "test":
                body += "\n" + test_sec(it, unit)
    return ("<!DOCTYPE html><html lang=\"ar\" dir=\"rtl\"><head><meta charset=\"utf-8\">"
            "<meta name=\"viewport\" content=\"width=device-width, initial-scale=1\">"
            "<title>SPRIX الثقافة المالية — Subject 7</title><style>" + CSS +
            "</style></head><body id=\"top\">" + body + "</body></html>")


def anchors():
    res = []
    for unit in DATA:
        for it in unit["items"]:
            if it["type"] == "chapter":
                res.append((f"c{it['id']}", f"ID {it['id']}"))
            elif it["type"] == "test":
                res.append((f"t{it['id']}", f"ID {it['id']}"))
    return res


if __name__ == "__main__":
    html = build_html({a: "—" for a, _ in anchors()}, "—")
    open(f"{OUT}/SPRIX-Financial-Literacy-Subject7.html", "w", encoding="utf-8").write(html)
    print("wrote html", len(html))
