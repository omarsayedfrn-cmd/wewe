#!/usr/bin/env python3
# Build beginner-friendly explanations for all QUREO chapters (own style, no dialogue copy)
import json, os, re, html as ihtml

ROOT = "/home/omsa/Projects/solver-project"
CH = json.load(open("/tmp/qureo_chapters.json", encoding="utf-8"))
LEC = json.load(open("/tmp/qureo_lectures.json", encoding="utf-8"))
ANS = json.load(open(f"{ROOT}/qureo-solver/answers.json", encoding="utf-8"))
OUT = f"{ROOT}/qureo-solver/explain"
os.makedirs(OUT, exist_ok=True)

def clean(s):
    if not s: return ""
    s = ihtml.unescape(s)
    s = re.sub(r"\[\[/?bdi\]\]", "", s)
    s = re.sub(r"\[\[/?bold\]\]", "", s)
    s = re.sub(r"\[\[/?[a-z]+\]\]", "", s)
    return s.strip()

def analogy_for(test_range, name):
    tr = (test_range or "").lower()
    if "console.log" in tr or "console" in tr and "variable" in tr:
        return ("الطابعة التي تتكلم", "تخيل أن الكمبيوتر شخص أخرس. أمر <code>console.log</code> هو مثل أن تقول له: «قول بصوت عالي». أي شيء تضعه بين القوسين يظهر على الشاشة. هذه أول مهارة: أن تجعل البرنامج يعرض شيئًا.")
    if "calculation" in tr or "string" in tr:
        return ("الآلة الحاسبة + الكلمات", "الكمبيوتر يحسب مثل الآلة الحاسبة (<code>+ - * /</code>)، ويتعامل مع النصوص إذا وضعتها بين علامتي تنصيص <code>\"...\"</code>. الرقم بدون تنصيص يُحسب، والنص بين تنصيص يُعرض كما هو.")
    if "variable" in tr and "console" not in tr:
        return ("علبة عليها اسم", "المتغير مثل علبة بلاستيك تلصق عليها ورقة باسمها. <code>let age = 10;</code> تعني: أحضر علبة اسمها age وضع فيها الرقم 10. بعد ذلك يمكنك فتح العلبة واستخدام ما فيها أو تبديله.")
    if tr.strip() == "if":
        return ("بوابة تفتح بشرط", "جملة <code>if</code> مثل بوابة نادٍ: الحارس ينظر للشرط (مثلًا: هل عمرك فوق 18؟). إذا تحقق الشرط تفتح البوابة وينفذ ما بداخل الأقواس <code>{ }</code>. إذا لم يتحقق، يتجاهل كل شيء بداخلها.")
    if "if - else" in tr or tr.strip() == "if-else":
        return ("طريقان: نعم أو لا", "تخيل مفترق طريق: إذا تحقق الشرط تسلك الطريق الأول (<code>if</code>)، وإلا تسلك الطريق الثاني (<code>else</code>). لا يوجد طريق ثالث — واحد منهما سيحدث حتمًا.")
    if "else if" in tr:
        return ("عدة أبواب مرتبة", "أحيانًا عندك أكثر من احتمال (ممتاز / جيد / راسب). <code>else if</code> يعني: جرّب الباب الأول، إن لم يناسب جرّب الثاني، ثم الثالث. أول باب يتحقق شرطه هو الذي يُفتح فقط.")
    if "logical operator" in tr or "operators" in tr and "repetition" not in tr:
        return ("مفتاحان معًا", "العامل المنطقي يربط شرطين: <code>&&</code> تعني «و» (لازم الشرطان معًا)، و<code>||</code> تعني «أو» (يكفي واحد). مثل دخول مدينة ألعاب: «لازم تذكرة <b>و</b> طول مناسب» مقابل «تذكرة <b>أو</b> دعوة خاصة».")
    if "repetition" in tr or tr.strip() in ("loops", "iterative operation"):
        return ("الغسالة تكرر", "التكرار يعني: لا تكتب نفس السطر 10 مرات. جملة <code>for</code> مثل مؤقت الغسالة: «ابدأ من 0، واستمر ما دمت أقل من 10، وزد 1 كل مرة». الكمبيوتر يكرر ما بداخل <code>{ }</code> تلقائيًا.")
    if tr.strip() == "function" or "function" in tr and "for" not in tr and "array" not in tr.lower():
        return ("آلة بوصفة", "الدالة مثل آلة صنع العصير: تضع فيها مكونات (تسمى معاملات)، وتضغط الزر (تستدعيها باسمها)، فتخرج لك نتيجة. تكتب الوصفة مرة واحدة ثم تستخدمها 100 مرة بدون إعادة الكتابة.")
    if tr.strip() == "types":
        return ("التفريق بين الرقم والكلمة", "الكمبيوتر يفرق بين الأنواع: الرقم <code>5</code> يُحسب، والنص <code>\"5\"</code> يُعامل ككلمة. الخلط بينهما سبب أخطاء كثيرة. دائمًا اسأل نفسك: هل أريد حسابًا أم عرضًا؟")
    if "array" in tr:
        return ("قطار بعربات مرقمة", "المصفوفة مثل قطار له عربات مرقمة تبدأ من <b>0</b> وليس 1. <code>[36, 26, 27]</code> يعني 3 عربات. للوصول لعربة معينة تكتب <code>list[0]</code> للأولى و<code>list[2]</code> للثالثة. والطول <code>.length</code> يخبرك بعدد العربات.")
    if tr.strip() == "html":
        return ("هيكل البيت", "صفحة الويب مثل بيت: <code>HTML</code> هو الهيكل والجدران (عناوين <code>h1</code> وفقرات <code>p</code> وصور <code>img</code> وقوائم <code>ul/li</code>). الوسوم غالبًا زوجان: بداية ونهاية، مثل فتح وإغلاق باب.")
    if tr.strip() == "css":
        return ("الدهان والديكور", "إذا كان HTML هو الهيكل، فـ <code>CSS</code> هو الدهان والديكور: اللون والحجم والحدود. نفس الغرفة يمكن أن تبدو مختلفة تمامًا بتغيير الديكور فقط، بدون هدم الجدران.")
    if "conditional" in tr:
        return ("اتخاذ القرار", "الشروط المتقدمة تجمع ما تعلمته: مقارنات وحسابات داخل <code>if</code>. الفكرة: احسب أولًا ثم قرر. مثل: احسب المجموع ثم قرر هل ناجح أم لا.")
    if tr.strip() == "loops":
        return ("التكرار الذكي", "هنا نستخدم التكرار مع الشروط والمصفوفات معًا. بدل تكرار أعمى، نكرر ونفحص كل مرة: مثل المرور على قائمة درجات وطباعة الناجح فقط.")
    if "functions" in tr:
        return ("وصفات جاهزة", "دوال متقدمة بمعاملات متعددة ونطاقات. القاعدة: ما يحدث داخل الدالة يبقى داخلها (النطاق)، وما ترسله كمعامل يدخل، وما تُرجعه يخرج.")
    if "arrays" in tr:
        return ("التعامل مع القوائم", "مصفوفات متقدمة: الجمع بين الحلقات والمصفوفات و<code>if</code> لمعالجة كل عنصر. مثل حساب مجموع درجات الفصل من قائمة.")
    if "for of" in tr:
        return ("المرور على كل ضيف", "جملة <code>for...of</code> أسهل من العد بالأرقام: تعني «لكل عنصر في القائمة، نفذ». بدل أن تقول «العربة 0 ثم 1 ثم 2»، تقول «لكل عربة في القطار افعل». ولا تنسَ <code>let</code> وليس <code>const</code>.")
    if "flowchart" in tr:
        return ("خريطة قبل البناء", "المخطط الانسيابي رسم يوضح خطوات البرنامج (ابدأ → شرط؟ → نعم/لا → انتهِ) قبل كتابة الكود. مثل رسم خريطة طريق قبل السفر: توفر عليك التوهان.")
    if "switch" in tr:
        return ("قائمة مطعم", "جملة <code>switch</code> أنسب عندما عندك قيمة واحدة بعدة احتمالات (فصيلة دم A/B/O/AB). بدل كتابة <code>if</code> طويلة، تكتب قائمة: <code>case \"A\": ... break;</code> و<code>default</code> للاحتمال غير المتوقع. لا تنسَ <code>break</code> وإلا سينفذ ما بعدها أيضًا.")
    if "modulo" in tr:
        return ("الباقي بعد التوزيع", "العامل <code>%</code> يعطي باقي القسمة. وزعت 7 حبات على 3 أطفال بالتساوي (2 لكل واحد) فيتبقى 1 — هذا هو <code>7 % 3 = 1</code>. مفيد لمعرفة الزوجي/الفردي (<code>% 2</code>) أو كل ثالث عنصر.")
    if "const" in tr or "inequality" in tr:
        return ("الثابت والمختلف", "<code>const</code> علبة مغلقة لا تتغير بعد أول مرة (مثل تاريخ الميلاد)، و<code>let</code> علبة مفتوحة تتغير (مثل العمر). وعلامة <code>!=</code> تعني «لا يساوي» — عكس <code>==</code>.")
    if "while" in tr:
        return ("كرر ما دمت قادرًا", "جملة <code>while</code> تكرر «ما دام الشرط صحيحًا» بدون عدد محدد مسبقًا. مثل: «ما دامت البطارية فيها شحن، استمر». احذر الحلقة اللانهائية: لازم شيء يغير الشرط داخل التكرار وإلا لن تتوقف أبدًا.")
    if "array operations" in tr:
        return ("إدارة القائمة", "عمليات المصفوفة: إضافة للنهاية <code>push</code>، وحذف من النهاية <code>pop</code>، وحذف من البداية <code>shift</code>، وإضافة للبداية <code>unshift</code>، والفرز <code>sort</code> والعكس <code>reverse</code> والتحقق من الترتيب. مثل إدارة طابور: من يدخل من أين ومن يخرج.")
    if "review" in str(ANS.get("x", "")) or "مراجعة" in name:
        return ("مراجعة وتثبيت", "هذا فصل مراجعة: لا مفهوم جديد، بل تثبيت ما سبق. أفضل طريقة: أعد كتابة الأمثلة بيدك وغيّر الأرقام ولاحظ النتيجة.")
    return ("خطوة جديدة", "مفهوم جديد يبني على ما قبله. القاعدة الذهبية: جرّب بنفسك وغيّر رقمًا واحدًا ولاحظ الفرق.")

CSS = """
*{box-sizing:border-box}
@page{size:A4;margin:14mm 12mm}
body{font-family:"Noto Sans Arabic","Noto Naskh Arabic",sans-serif;background:#F8FAFC;color:#26314B;line-height:2;font-size:12.5pt;margin:0}
.wrap{max-width:100%}
.head{background:linear-gradient(135deg,#E0F2FE 0%,#FEF9E7 100%);border:2px solid #BFDBFE;border-radius:16px;padding:22px 20px;text-align:center;margin-bottom:16px}
.head h1{color:#1D4ED8;font-size:22pt;margin:4px 0}
.head h2{color:#475569;font-size:14pt;margin:4px 0;font-weight:normal}
.pill{display:inline-block;background:#DBEAFE;color:#1E40AF;border:1px solid #93C5FD;padding:2px 14px;border-radius:20px;font-size:11pt;margin:3px}
.pill.g{background:#FEF3C7;color:#92400E;border-color:#FCD34D}
.pill.t{background:#D1FAE5;color:#065F46;border-color:#6EE7B7}
h2.s{color:#1D4ED8;background:#EFF6FF;border-right:6px solid #60A5FA;padding:6px 14px;border-radius:8px;font-size:15pt;margin-top:22px}
h3{color:#0E7490;font-size:13.5pt;margin-top:16px}
.card{background:#fff;border:1.5px solid #DCE6F5;border-radius:12px;padding:12px 14px;margin:10px 0;box-shadow:0 1px 4px rgba(60,100,180,.07)}
.idea{background:#FFFBEB;border:1.5px solid #FCD34D;border-radius:12px;padding:12px 14px;margin:10px 0}
code{direction:ltr;unicode-bidi:embed;background:#F1F5F9;border:1px solid #CBD5E1;border-radius:6px;padding:0 6px;font-family:Consolas,monospace;font-size:11pt;color:#0F172A}
pre{direction:ltr;text-align:left;background:#F1F5F9;border:1.5px solid #CBD5E1;border-radius:10px;padding:10px 12px;overflow-x:auto;font-size:10.5pt;line-height:1.7;color:#0F172A}
table{width:100%;border-collapse:collapse;margin:8px 0;font-size:11.5pt}
th,td{border:1px solid #CBD5E1;padding:7px;text-align:right}
th{background:#EFF6FF;color:#1E40AF}
.warn{background:#FEF2F2;border:1.5px solid #FCA5A5;border-radius:10px;padding:10px 12px;margin:8px 0}
.tip{background:#ECFDF5;border:1.5px solid #6EE7B7;border-radius:10px;padding:10px 12px;margin:8px 0}
.foot{margin-top:18px;font-size:10.5pt;color:#64748B;border-top:1px dashed #94A3B8;padding-top:8px;text-align:center}
ul{margin:6px 0}li{margin:3px 0}
"""

def explain_code(code):
    lines = (code or "").strip().split("\n")
    out = []
    for ln in lines[:12]:
        s = ln.strip()
        if not s: continue
        if s.startswith("console.log"):
            out.append(f"<code>{ihtml.escape(s)}</code> — اعرض ما بين القوسين على الشاشة.")
        elif s.startswith("let "):
            out.append(f"<code>{ihtml.escape(s)}</code> — أحضر علبة (متغير) وضع فيها القيمة.")
        elif s.startswith("const "):
            out.append(f"<code>{ihtml.escape(s)}</code> — علبة ثابتة لا تتغير بعد ذلك.")
        elif s.startswith("if"):
            out.append(f"<code>{ihtml.escape(s)}</code> — إذا تحقق الشرط نفذ ما بعده.")
        elif s.startswith("else"):
            out.append(f"<code>{ihtml.escape(s)}</code> — وإلا نفذ البديل.")
        elif s.startswith("for"):
            out.append(f"<code>{ihtml.escape(s)}</code> — كرر ما بداخل الأقواس حسب العد.")
        elif s.startswith("while"):
            out.append(f"<code>{ihtml.escape(s)}</code> — كرر ما دام الشرط صحيحًا.")
        elif s.startswith("switch"):
            out.append(f"<code>{ihtml.escape(s)}</code> — افحص القيمة واختر الحالة المطابقة.")
        elif s.startswith("case") or s.startswith("default") or s.startswith("break"):
            out.append(f"<code>{ihtml.escape(s)}</code> — حالة من حالات switch (و break لمنع الاستمرار).")
        elif s.startswith("//") or s.startswith("<!--"):
            out.append(f"<code>{ihtml.escape(s)}</code> — تعليق يتجاهله الكمبيوتر (ملاحظة للبشر فقط).")
        elif s.startswith("<"):
            out.append(f"<code>{ihtml.escape(s)}</code> — وسم HTML يبني جزءًا من الصفحة.")
        elif "function" in s:
            out.append(f"<code>{ihtml.escape(s)}</code> — تعريف دالة (وصفة جاهزة).")
        elif "return" in s:
            out.append(f"<code>{ihtml.escape(s)}</code> — أرجع النتيجة لمن استدعى الدالة.")
        else:
            out.append(f"<code>{ihtml.escape(s)}</code>")
    return "<br>".join(out)

order = sorted(CH.keys(), key=int)
index_rows = []
for idx, cid in enumerate(order, start=1):
    info = CH[cid]
    name = info["name"]; desc = clean(info.get("desc") or "")
    tr = info.get("test_range") or ""
    lecs = info.get("lectures", [])
    ans = ANS.get(cid, {})
    qn = len(ans.get("questions", []))
    title_ana, ana_txt = analogy_for(tr, name)
    # collect summaries + tries
    sums = []
    tries = []
    for l in lecs:
        d = LEC.get(str(l["id"]), {})
        for s in d.get("summaries", []):
            t = clean(s.get("text") or ""); c = clean(s.get("check") or "")
            if t or c: sums.append((l["title"], t, c))
        for t in d.get("tries", [])[:2]:
            m = (t.get("model") or t.get("code") or "").strip()
            if m: tries.append((l["title"], m))
    tries = tries[:3]
    is_review = "مراجعة" in name
    level = "مراجعة" if is_review else ("تأسيس" if idx <= 17 else ("متوسط" if idx <= 36 else "متقدم"))
    # build html
    lec_list = "".join(f"<li><b>{ihtml.escape(l['title'])}</b></li>" for l in lecs)
    sum_cards = ""
    for lt, t, c in sums[:8]:
        sum_cards += f"<div class='card'><b>📌 {ihtml.escape(lt)}</b><br>🔹 {ihtml.escape(t)}<br>✅ <code>{ihtml.escape(c[:220])}</code></div>\n"
    try_cards = ""
    for lt, m in tries:
        esc = ihtml.escape(m[:600])
        try_cards += f"<div class='card'><b>💻 مثال من درس: {ihtml.escape(lt)}</b><pre>{esc}</pre><div class='tip'>🔍 <b>سطر بسطر:</b><br>{explain_code(m)}</div></div>\n"
    if not try_cards:
        try_cards = "<div class='card'>هذا الدرس نظري أكثر (مثل المفاهيم أو المخططات). طبّق الفكرة بورقة وقلم: ارسم الخطوات ثم قارن بالخلاصة.</div>"
    test_info = f"نطاق الاختبار: <code>{ihtml.escape(tr)}</code> — عدد أسئلة الاختبار: {qn}"
    fname = f"qureo-{idx:02d}-{cid}.html"
    html = f"""<!DOCTYPE html><html lang="ar" dir="rtl"><head><meta charset="utf-8"><style>{CSS}</style></head><body><div class="wrap">
<div class="head"><span class="pill">QUREO • JavaScript_ar</span> <span class="pill g">الفصل {idx} / 54</span> <span class="pill t">{ihtml.escape(level)}</span>
<h1>{idx}. {ihtml.escape(name)}</h1><h2>{desc}</h2>
<div><span class="pill">{ihtml.escape(tr)}</span> <span class="pill g">ID {cid}</span></div></div>
<h2 class="s">1️⃣ الفكرة في جملة واحدة</h2>
<div class="idea"><b>🎯 {ihtml.escape(title_ana)}:</b> {ana_txt}</div>
<h2 class="s">2️⃣ ماذا ستتعلم؟ (دروس المنصة)</h2>
<div class="card"><ol>{lec_list}</ol><div>{test_info}</div></div>
<h2 class="s">3️⃣ الشرح المبسط خطوة بخطوة</h2>
{sum_cards}
<div class="tip">💡 <b>إضافة للتوضيح (من خارج المنصة):</b> إذا شعرت أن الكود مخيف، اقرأه كجملة عربية. <code>let</code> = «ليكن»، <code>if</code> = «إذا»، <code>for</code> = «كرر»، <code>function</code> = «وصفة». البرمجة ليست حفظًا بل ترجمة فكرة لخطوات صغيرة.</div>
<h2 class="s">4️⃣ مثال عملي (كود حقيقي من المنصة + شرح)</h2>
{try_cards}
<h2 class="s">5️⃣ أخطاء شائعة (حتى لا تقع فيها)</h2>
<div class="warn">⚠️ <b>أخطاء المبتدئين في هذا الموضوع:</b><ul>
<li>نسيان الفاصلة المنقوطة <code>;</code> أو الأقواس <code>{{ }}</code> — الكمبيوتر دقيق جدًا.</li>
<li>الخلط بين <code>=</code> (وضع قيمة في علبة) و<code>==</code> (مقارنة هل متساويان؟).</li>
<li>نسيان أن عد المصفوفات يبدأ من <code>0</code> وليس 1.</li>
<li>في <code>switch</code> نسيان <code>break</code> يجعل التنفيذ يكمل للحالة التالية.</li>
<li>في <code>for...of</code> استخدم <code>let</code> وليس <code>const</code>.</li>
</ul></div>
<h2 class="s">6️⃣ الخلاصة واختبر نفسك</h2>
<div class="card"><b>📌 الخلاصة:</b> {desc} تذكر التشبيه: <b>{ihtml.escape(title_ana)}</b>. أعد كتابة مثال واحد بيدك وغيّر رقمًا ولاحظ النتيجة — هذه هي البرمجة فعلًا.<br><br>
<b>✍️ اختبر نفسك (بدون غش):</b><ol>
<li>اشرح الفكرة لطفل في سطرين بكلماتك أنت.</li>
<li>اكتب أصغر مثال ممكن من ذاكرتك ثم قارنه بمثال المنصة أعلاه.</li>
<li>تعمد ارتكاب خطأ واحد (احذف قوسًا) ولاحظ رسالة الخطأ — ستتعلم قراءتها.</li>
</ol></div>
</div>
</div></body></html>"""
    open(os.path.join(OUT, fname), "w", encoding="utf-8").write(html)
    index_rows.append((idx, cid, name, tr, level, fname))

idx_html = "<!DOCTYPE html><html lang='ar' dir='rtl'><head><meta charset='utf-8'><style>" + CSS + "</style></head><body><div class='head'><h1>شروحات QUREO — JavaScript (54 فصلًا)</h1><h2>شرح مبسط خاص للمبتدئين من الصفر — ألوان فاتحة متناسقة</h2></div>"
idx_html += "<table><tr><th>#</th><th>الفصل</th><th>النطاق</th><th>المستوى</th></tr>"
for idx, cid, name, tr, level, fname in index_rows:
    idx_html += f"<tr><td>{idx}</td><td><a href='{fname}'>{ihtml.escape(name)}</a> ({cid})</td><td>{ihtml.escape(tr)}</td><td>{ihtml.escape(level)}</td></tr>"
idx_html += "</table></body></html>"
open(os.path.join(OUT, "index.html"), "w", encoding="utf-8").write(idx_html)
print("HTML done:", len(index_rows))
