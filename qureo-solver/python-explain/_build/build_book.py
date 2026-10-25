#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""Build the QUREO Python (python_short_ar) self-study book (HTML) in the same
book style as QUREO-JavaScript-54chapters.html."""
import json, html as ihtml, os, sys, re
sys.path.insert(0, "/tmp/qureo_py")
from meta import DESC_ANSWERS, CHAPTER_META

BASE = "/tmp/qureo_py"
OUT = "/home/omsa/Projects/solver-project/qureo-solver/python-explain"
CSS = open(f"{OUT}/_style.css", encoding="utf-8").read()
# Extended (book-consistent) rules for the Python edition — no emoji, no symbols.
CSS += """
.card li.ok{font-weight:700;color:var(--navy)}
.card li.ok .ok-tag{font-weight:400;font-size:.85em;color:var(--muted)}
"""
COURSE = json.load(open(f"{BASE}/course.json", encoding="utf-8"))

TOTAL_CH = len(COURSE)


def esc(s):
    return ihtml.escape(s or "")


def explain_line(s):
    st = s.strip()
    if not st:
        return ""
    if st.startswith("#"):
        return "تعليق: الكمبيوتر يتجاهل هذا السطر (ملاحظة للبشر فقط)."
    if st.startswith("import "):
        return "نستدعي وحدة (مكتبة) جاهزة لنستخدم دوالها."
    if st.startswith("def "):
        return "تعريف دالة (وصفة): نكتب اسمها ووسائطها ثم معالجتها."
    if st.startswith("return"):
        return "أرجِع هذه القيمة لمن استدعى الدالة."
    if st.startswith("while "):
        return "كرر الكتلة المُزاحة ما دام الشرط صحيحًا."
    if st.startswith("for ") and " in range(" in st.replace(" ", " "):
        return "كرر الكتلة المُزاحة بعدد المرات المحدد في range()."
    if st.startswith("for ") and " in " in st:
        return "لكل عنصر في القائمة نفّذ الكتلة المُزاحة."
    if st.startswith("elif "):
        return "وإلا إذا تحقق هذا الشرط نفّذ الكتلة المُزاحة."
    if st.startswith("else"):
        return "وإلا (لم يتحقق أي شرط سابق) نفّذ الكتلة المُزاحة."
    if st.startswith("if "):
        return "إذا تحقق الشرط نفّذ الكتلة المُزاحة."
    if st.startswith("print"):
        return "اطبع ما بين القوسين في وحدة التحكم."
    if "math.floor" in st:
        return "قرّب العدد العشري إلى أقرب عدد صحيح أصغر."
    if "random.random" in st:
        return "أنتج رقمًا عشوائيًا بين 0 وأقل من 1."
    if st.startswith("len(") or " len(" in st:
        return "أعطِ عدد العناصر في القائمة."
    if "round(" in st:
        return "قرّب العدد لأقرب عدد صحيح."
    if "type(" in st:
        return "اطبع نوع البيانات (رقم أم نص)."
    if "str(" in st:
        return "حوّل القيمة إلى نص لتُدمج مع الكلام."
    if re.search(r"(^|[^=!<>])=([^=]|$)", st) and not re.search(r"==|>=|<=|!=", st):
        return "أنشئ متغيرًا أو أسند له قيمة جديدة."
    if st.endswith(":"):
        return "بداية كتلة مُزاحة (لاحظ النقطتين)."
    return "نفّذ هذا السطر بالترتيب مع ما قبله."


def explain_code_block(code):
    out = []
    for ln in (code or "").strip().split("\n"):
        if not ln.strip():
            continue
        ex = explain_line(ln)
        if ex:
            out.append(f"<code>{esc(ln)}</code> — {ex.rstrip('.')}.")
    return "<br>".join(out)


def pick_examples(ch):
    seen, picks = set(), []
    for lec in ch["lectures"]:
        for t in lec["tries"]:
            code = (t.get("model_answer") or "").strip()
            if not code or code in seen:
                continue
            seen.add(code)
            picks.append({"lec": lec["title"], "code": code,
                          "guide": t.get("guide", ""), "q": t.get("title", "")})
    return picks[:5]


def render_exam(ch):
    cards = []
    for q in ch.get("test_questions", []):
        if q["type"] == "choice":
            opts = []
            for c in q["choices"]:
                if str(c["id"]).endswith("01"):
                    opts.append(f"<li class='ok'>{esc(c['content'])}"
                                f" <span class='ok-tag'>(الإجابة الصحيحة)</span></li>")
                else:
                    opts.append(f"<li>{esc(c['content'])}</li>")
            cards.append(
                f"<div class='card'><b>س{q['seq']} (اختيار من متعدد):</b> {esc(q['content'])}"
                f"<ul>{''.join(opts)}</ul></div>")
        else:
            key = f"{ch['seq']}.{q['seq']}"
            ans = DESC_ANSWERS.get(key, "")
            body = f"<b>س{q['seq']} (اكتب الكود):</b> {esc(q['content'])}"
            hints = q.get("hints") or []
            hint_html = (f"<div class='tip'><b>تلميح:</b> {esc(' — '.join(hints))}</div>" if hints else "")
            ans_html = (f"<pre>{esc(ans)}</pre>" if ans else
                        "<div class='warn'>راجع شرح الدرس لكتابة الحل.</div>")
            cards.append(f"<div class='card'>{body}{ans_html}{hint_html}</div>")
    return "\n".join(cards)


def build_chapter(ch, idx, page):
    meta = CHAPTER_META[ch["seq"]]
    level = "مراجعة الفهم" if ch["test_type"] == "test" else "درس"
    lec_list = "".join(f"<li><b>{esc(l['title'])}</b></li>" for l in ch["lectures"])
    sum_cards = ""
    for lec in ch["lectures"]:
        for s in lec["summaries"]:
            if s["text"]:
                sum_cards += (f"<div class='card'><b>{esc(s['text'])}</b><br>"
                              f"<code>{esc(s['check'])}</code></div>\n")
    ex_cards = ""
    for e in pick_examples(ch):
        ex_cards += (f"<div class='card'><b>مثال من درس: {esc(e['lec'])}</b>"
                     f"<pre>{esc(e['code'])}</pre>"
                     f"<div class='tip'><b>سطر بسطر:</b><br>{explain_code_block(e['code'])}</div></div>\n")
    if not ex_cards:
        ex_cards = "<div class='card'>لا توجد أمثلة كود في هذا الفصل؛ راجع المفاهيم أعلاه ثم حل أسئلة الاختبار بالأسفل.</div>"
    mistakes = "".join(f"<li>{m}</li>" for m in meta["mistakes"])
    selftest = "".join(f"<li>{s}</li>" for s in meta["selftest"])
    exam = render_exam(ch)
    test_info = f"نطاق الاختبار: <code>{esc(ch['test_range'])}</code> — عدد أسئلة الاختبار: {ch['question_count']}"

    return f"""<section class='chap' id='ch{idx:02d}'><div class='backtop'><a href='#top'>العودة للفهرس</a> — الفصل {idx} / {TOTAL_CH}</div><div class="wrap">
<div class="head"><span class="pill">QUREO • Python_ar</span> <span class="pill g">الفصل {idx} / {TOTAL_CH}</span> <span class="pill t">{level}</span>
<h1>{idx}. {esc(ch['name'])}</h1><h2>{esc(ch['description'])}</h2>
<div><span class="pill">{esc(ch['test_range'])}</span> <span class="pill g">ID {ch['id']}</span></div></div>
<h2 class="s">1. الفكرة في جملة واحدة</h2>
<div class="idea"><b>{esc(meta['ana_t'])}:</b> {meta['ana']}</div>
<h2 class="s">2. ماذا ستتعلم؟ (دروس المنصة)</h2>
<div class="card"><ol>{lec_list}</ol><div>{test_info}</div></div>
<h2 class="s">3. الشرح خطوة بخطوة (المفاهيم)</h2>
{sum_cards}
<h2 class="s">4. أمثلة عملية مشروحة سطرًا بسطر</h2>
{ex_cards}
<h2 class="s">5. أخطاء شائعة (حتى لا تقع فيها)</h2>
<div class="warn"><b>أخطاء المبتدئين في هذا الموضوع:</b><ul>{mistakes}</ul></div>
<h2 class="s">6. أسئلة الاختبار الرسمي (مع الحل)</h2>
{exam}
<h2 class="s">7. الخلاصة واختبر نفسك</h2>
<div class="card"><b>الخلاصة:</b> {meta['summary']}<br><br>
<b>اختبر نفسك (بدون غش):</b><ol>{selftest}</ol></div>
</div><div class='backtop'><a href='#top'>العودة للفهرس</a></div></section>"""


def toc_html(pages):
    rows = ""
    for i, ch in enumerate(COURSE, start=1):
        p = pages.get(i, "—")
        rows += (f"<tr><td><a href='#ch{i:02d}'>{i}</a></td>"
                 f"<td><b>{esc(ch['name'])}</b><br>"
                 f"<span style='color:#5E5E5E;font-size:10pt'>{esc(ch['test_range'])} • ID {ch['id']}</span></td>"
                 f"<td style='text-align:center'><b>{p}</b></td></tr>")
    return rows


def build_front(pages, total_pages):
    return f"""<div class='toc'>
<div class="cover">
<span class="pill">QUREO • Python_ar</span> <span class="pill g">{TOTAL_CH} فصلًا • شرح مبسط للمبتدئين</span>
<h1>البرمجة بلغة Python من الصفر</h1>
<h2>ملف واحد يجمع كل الفصول بأسلوب مبسّط للدراسة الذاتية (بدون حوارات المنصة) + أسئلة الاختبار الرسمي مع الحل</h2>
<div><span class="pill">عدد الصفحات الكلي: {total_pages}</span> <span class="pill g">الفصول 511001 – 511025</span></div>
</div>
<div class="how"><b>كيف تستخدم هذا الملف؟ (دراسة ذاتية)</b><ol>
<li>ابدأ من الفصل الأول وتقدّم بالترتيب — كل فصل يبني على ما قبله.</li>
<li>اقرأ «الفكرة في جملة واحدة» ثم «الشرح خطوة بخطوة» ثم «الأمثلة».</li>
<li>ثبّت بفقرة «أخطاء شائعة»، ثم حُلّ «أسئلة الاختبار الرسمي» بنفسك قبل النظر إلى الحل.</li>
<li>أعد كتابة كل مثال بيدك وغيّر رقمًا ولاحظ النتيجة — هذه هي البرمجة فعلًا.</li>
<li>فصول «مراجعة الفهم» للتثبيت وقياس مستواك — لا تتجاوزها.</li>
</ol></div>
<h2 class="s">الفهرس — اضغط رقم الفصل في النسخة الإلكترونية</h2>
<table><tr><th style="width:50px">#</th><th>الفصل</th><th style="width:90px;text-align:center">صفحة</th></tr>{toc_html(pages)}</table>
</div>"""


def build_html(pages, total_pages):
    body = build_front(pages, total_pages)
    for i, ch in enumerate(COURSE, start=1):
        body += "\n" + build_chapter(ch, i, pages.get(i))
    return ("<!DOCTYPE html><html lang=\"ar\" dir=\"rtl\"><head><meta charset=\"utf-8\">"
            "<meta name=\"viewport\" content=\"width=device-width, initial-scale=1\">"
            "<title>QUREO Python — 25 فصلًا في ملف واحد</title><style>" + CSS +
            "</style></head><body id=\"top\">" + body + "</body></html>")


if __name__ == "__main__":
    pages = {i: "—" for i in range(1, TOTAL_CH + 1)}
    html = build_html(pages, "—")
    path = os.path.join(OUT, "QUREO-Python-25chapters.html")
    open(path, "w", encoding="utf-8").write(html)
    print("wrote", path, len(html), "chars")
