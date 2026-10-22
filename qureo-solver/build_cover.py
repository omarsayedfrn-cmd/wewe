#!/usr/bin/env python3
import json, html as ihtml
rows = json.load(open("/tmp/index_rows.json", encoding="utf-8"))
# rows: [idx, cid, name, tr, npages]
# offset = front pages count (cover+index). passed via env/arg; default estimate
import sys
OFFSET = int(sys.argv[1]) if len(sys.argv) > 1 else 0
CSS = """
@page{size:A4;margin:14mm 12mm}
body{font-family:"Noto Sans Arabic","Noto Naskh Arabic",sans-serif;background:#F8FAFC;color:#26314B;line-height:2;font-size:12pt;margin:0}
.cover{background:linear-gradient(135deg,#E0F2FE 0%,#FEF9E7 100%);border:2px solid #BFDBFE;border-radius:16px;padding:40px 24px;text-align:center;margin:10px 0 16px}
.cover h1{color:#1D4ED8;font-size:26pt;margin:6px 0}
.cover h2{color:#475569;font-size:14pt;font-weight:normal;margin:4px 0}
.pill{display:inline-block;background:#DBEAFE;color:#1E40AF;border:1px solid #93C5FD;padding:2px 14px;border-radius:20px;font-size:11pt;margin:3px}
.pill.g{background:#FEF3C7;color:#92400E;border-color:#FCD34D}
h2.s{color:#1D4ED8;background:#EFF6FF;border-right:6px solid #60A5FA;padding:6px 14px;border-radius:8px;font-size:15pt;margin-top:22px}
table{width:100%;border-collapse:collapse;margin:8px 0;font-size:11pt}
th,td{border:1px solid #CBD5E1;padding:6px 8px;text-align:right}
th{background:#EFF6FF;color:#1E40AF}
tr:nth-child(even) td{background:#F8FAFC}
.how{background:#fff;border:1.5px solid #DCE6F5;border-radius:12px;padding:12px 14px;margin:10px 0}
.foot{text-align:center;color:#64748B;font-size:10.5pt;border-top:1px dashed #94A3B8;margin-top:14px;padding-top:8px}
a{color:#1D4ED8}
"""
# compute start pages
start = OFFSET + 1
items = []
for idx, cid, name, tr, n in rows:
    items.append((idx, cid, name, tr, start))
    start += n
total_pages = start - 1
trs = "".join(
    f"<tr><td>{idx}</td><td><b>{ihtml.escape(name)}</b><br><span style='color:#64748B;font-size:10pt'>{ihtml.escape(tr)} • ID {cid}</span></td><td style='text-align:center'><b>{p}</b></td></tr>"
    for idx, cid, name, tr, p in items
)
html = f"""<!DOCTYPE html><html lang="ar" dir="rtl"><head><meta charset="utf-8"><style>{CSS}</style></head><body>
<div class="cover">
<span class="pill">QUREO • JavaScript_ar</span> <span class="pill g">54 فصلًا • شرح مبسط للمبتدئين</span>
<h1>الثقافة البرمجية — JavaScript من الصفر</h1>
<h2>ملف واحد يجمع كل الفصول بأسلوب خاص مبسط (بدون حوارات المنصة) — ألوان فاتحة متناسقة</h2>
<div><span class="pill">عدد الصفحات الكلي: {total_pages}</span> <span class="pill g">الفصول 90001 – 90054</span></div>
</div>
<div class="how">📖 <b>كيف تستخدم هذا الملف؟</b><ol>
<li>ابدأ من الفصل 1 وتقدم بالترتيب — كل فصل يبني على ما قبله.</li>
<li>اقرأ «الفكرة في جملة واحدة» أولًا ثم المثال العملي.</li>
<li>أعد كتابة مثال واحد بيدك وغيّر رقمًا ولاحظ النتيجة.</li>
<li>فصول «مراجعة الفهم» للتثبيت — لا تتجاوزها.</li>
</ol></div>
<h2 class="s">📑 الفهرس — اضغط رقم الفصل في النسخة الإلكترونية</h2>
<table><tr><th style="width:50px">#</th><th>الفصل</th><th style="width:90px;text-align:center">صفحة</th></tr>{trs}</table>
</body></html>"""
open("/home/omsa/Projects/solver-project/qureo-solver/explain/00-cover-index.html", "w", encoding="utf-8").write(html)
print("wrote cover html, OFFSET=", OFFSET, "total=", total_pages)
