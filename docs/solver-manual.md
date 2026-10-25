# Solver Manual — المرجع الأساسي لأي شات جديد

> لو بتقرا الملف ده في شات جديد: ده ملف التشغيل الكامل لمشروع حل منصتي QUREO و SPRIX
> (سكربتات bash + تطبيق أندرويد). أي طلب تعديل أو إضافة فصول جديدة نفّذه حسب الـ workflows تحت.
> المستخدم بيبعت لينك المنصة/المادة الجديدة + بيانات الدخول في `/home/omsa/pass.md` (خارج الريبو عمدا — لا تنسخه داخل المشروع).
>
> جذر المشروع: `ROOT=/home/omsa/Projects/solver-project` — كل المسارات تحت هي مطلقة من الجذر الجديد
> (المشروع اتنقل من `/home/omsa/` القديمة إلى `ROOT`).

---

## 1. نظرة عامة

| المنصة | المادة/الكورس | السكربت | الإجابات | الحالة |
|---|---|---|---|---|
| QUREO | JavaScript_ar (`https://me-tp.qureo.education/course/javascript_ar`) | `ROOT/qureo-solver/solve.sh` | `ROOT/qureo-solver/answers.json` (54 فصل، 335 سؤال، 270 دايموند PERFECT) | ✅ كاملة |
| QUREO EN | JavaScript_en (`https://me-tp.qureo.education/course/javascript_en`) | `ROOT/qureo-js-en-solver/solve.sh` | ذاتي الاكتشاف (بدون answers.json) — 54 فصل 30001–30054، 270 دايموند PERFECT | ✅ كاملة |
| QUREO2 | python_short_ar (`https://me-tp.qureo.education/course/python_short_ar`) | `ROOT/qureo2-solver/solve.sh` | `ROOT/qureo2-solver/answers.json` (25 فصل 511001–511025، 153 سؤال، 125 دايموند PERFECT) | ✅ كاملة |
| QUREO2 EN | python_short_en (`https://me-tp.qureo.education/course/python_short_en`) | `ROOT/qureo2-en-solver/solve.sh` | ذاتي الاكتشاف (بدون answers.json) — 10 فصل 531001–531010، 50 دايموند PERFECT | ✅ كاملة |
| SPRIX | الثقافة المالية subject 7 (`https://egy.app.spx-learning-square.com/subjects/7`) | `ROOT/sprix-solver/solve.sh` | `ROOT/sprix-solver/answers.json` (54 فصل/274 إجابة + 22 اختبار/380 إجابة) | ✅ كاملة 100% كل الوحدات 19–24 |
| SPRIX EN | Financial Literacy subject 3 (`https://egy.app.spx-learning-square.com/subjects/3`) | `ROOT/sprix-en-solver/solve.sh` | ذاتي الاكتشاف (بدون answers.json) — الوحدات 1–6، 137 عنصر، 100% | ✅ كاملة |
| SPHINX | Global Finance Quest subject 8 (`https://egy.app.spx-learning-square.com/subjects/8`) | `ROOT/sphinx-solver/solve.sh` | ذاتي الاكتشاف (بدون answers.json) — لعبة محفظة أسهم 30 يوم، استراتيجية أخبار→غد، ضمان **SS (100/100)** | ✅ كاملة |

تطبيق الأندرويد: `ROOT/solver-app` (Kotlin Native، اسم العرض Solver App، حاليا **v1.7.0 versionCode 9**) — فيه المحركات الثلاثة (SPRIX + QUREO + QUREO2) وملفات الإجابات مضمنة كـ assets (متطابقة حاليا مع `*-solver/answers.json`). الخدمة **متعددة الجلسات (حتى 3 بالتوازي + queue + retry + progress + WakeLock + auto-retry)** + **⚡ Boost منفصل لكل منصة** (سويتش محفوظ per-platform، `Pace.kt`: ×0.3 SPRIX المثبت من الدفعة / ×0.4 QUREO+QUREO2، jitter ±25%، حد أدنى 120ms، وحارس 429/403 auto-disable). مختبر end-to-end على محاكي (افحص قسم 9).

## 2. خريطة الملفات (مسارات مطلقة)

```
ROOT=/home/omsa/Projects/solver-project
/home/omsa/pass.md                        ← بيانات الدخول (خارج الريبو عمدا — لا تنسخ الباسورد في أي ملف تاني)
/home/omsa/Projects/solver-project/qureo-solver/solve.sh          ← حل QUREO
/home/omsa/Projects/solver-project/qureo-solver/answers.json      ← إجابات QUREO
/home/omsa/Projects/solver-project/qureo-js-en-solver/solve.sh    ← حل QUREO EN (javascript_en — ذاتي الاكتشاف، بدون answers.json)
/home/omsa/Projects/solver-project/qureo2-solver/solve.sh         ← حل QUREO2 (port من QUREO لكورس python_short_ar)
/home/omsa/Projects/solver-project/qureo2-solver/answers.json     ← إجابات QUREO2 (25 فصل، 153 سؤال)
/home/omsa/Projects/solver-project/qureo2-en-solver/solve.sh      ← حل QUREO2 EN (python_short_en — ذاتي الاكتشاف، بدون answers.json)
/home/omsa/Projects/solver-project/sprix-solver/solve.sh          ← حل SPRIX
/home/omsa/Projects/solver-project/sprix-solver/answers.json      ← إجابات SPRIX
/home/omsa/Projects/solver-project/sprix-en-solver/solve.sh       ← حل SPRIX EN (Financial Literacy subject 3 — ذاتي الاكتشاف، بدون answers.json)
/home/omsa/Projects/solver-project/solver-app/                    ← مشروع الأندرويد
  app/build.gradle.kts                    ← عدّل versionCode/versionName هنا
  app/src/main/AndroidManifest.xml
  app/src/main/assets/qureo_answers.json  ← نسخة من إجابات QUREO (انسخها يدوي بعد أي تحديث)
  app/src/main/assets/qureo2_answers.json ← نسخة من إجابات QUREO2 (انسخها يدوي بعد أي تحديث)
  app/src/main/assets/sprix_answers.json  ← نسخة من إجابات SPRIX (انسخها يدوي بعد أي تحديث)
  app/src/main/java/com/solver/app/
    Api.kt          ← عميل OkHttp + CookieJar مشترك + هيدرات + isJson + SolverStop
    Answers.kt      ← تحميل الإجابات من assets (qureo/qureo2 نفس السكيما)
    SprixSolver.kt  ← محرك SPRIX (port من solve.sh)
    QureoSolver.kt  ← محرك QUREO + QUREO2 (نفس الكلاس ببراميتر QureoCourse: كوكي/سكشن/دايموند/ستارت)
    Pace.kt         ← حاكم سرعة Boost: step() يأخر scaled+jitter (floor 120ms)، auth() مش بيتسارع أبدا، onRateLimit() بيعمل cooldown + تسليح السكيل + auto-disable بعد 3 إصابات 429/403
    SolverService.kt← فورجراوند سيرفس (dataSync) متعدد الجلسات (حتى 3 بالتوازي + queue + retry) + إشعار تقدم + تنبيه انتهاء (صوت/اهتزاز) + **WakeLock ضد Doze + START_STICKY + auto-retry تلقائي (3 مرات) عند انقطاع الشبكة من آخر نقطة**
    MainActivity.kt ← شاشة دخول (3 تبويبات SPRIX/QUREO/QUREO2 **بأرقام طبيعية 1-based** + سويتش **⚡ Boost منفصل لكل منصة محفوظ في SharedPreferences**) + شاشة لوج حي + chips للجلسات (**بأرقام طبيعية #N** + ⚡ للجلسات المبوستة) + progress bar + **loginPinned (سطور اللوج لا تخطف شاشة الدخول أثناء إدخال جلسة جديدة)** + **ضغطة مطولة على اسم عمر تفتح مولد الأكواد Admin Key Generator**
    LicenseEngine.kt← محرك التشفير والتراخيص (توليد كود الجهاز OM-XXXX-XXXX، وتوليد كود التفعيل والتحقق منه محليا HMAC-SHA256)
  app/src/main/res/values/strings.xml     ← كل النصوص إنجليزي
  app/src/main/res/values/colors.xml      ← بيرجاندي #800020 أساسي + ذهبي #D4AF37 مساعد
  app/src/main/res/font/                  ← poppins (واجهة) + jetbrains_mono (تيرمنال)
  app/build/outputs/apk/debug/app-debug.apk ← الـ APK الجاهز (نسخة المطور / Admin الكاملة)
/home/omsa/Projects/solver-project/client-solver-app/   ← نسخة العميل المستقلة بالكامل (com.solver.client)
  app/build/outputs/apk/debug/app-debug.apk ← الـ APK المخصص للعميل (تجربة فصل واحد فقط حتى إدخال كود التفعيل الدائم)
```

## 3. بيانات الدخول

- كل البيانات في `/home/omsa/pass.md` (اقراه وقت التنفيذ فقط، لا تطبع الباسورد في اللوج ولا في ملفات).
- الأكونت الأساسي المستخدم في كل الحلول والاختبارات: `472713104` (اتحل عليه كل حاجة 100%).
- أكونت ثانوي اتجرب: `465271232` — وأكونت `472980760` اتستخدم لتشغيل السكربت من جهاز المستخدم (عنده صفوف `null` زيادة في رد `start` — السكربت بيتجاهلها، افحص quirk رقم 7).

## 4. QUREO — مرجع الـ API

- Portal: `https://me-portal.qureo.education` — TP: `https://me-tp.qureo.education`
- دخول: `POST /oauth2/password-login` جسم `{"student_id":"...","password":"..."}`
- تحقق: `GET /oauth2/userinfo` ثم `GET {TP}/api/study/students/me` (bootstrap جلسة TP)
- **كوكيز إجبارية** (من غيرها `/api/study/chapters/*` بيرجع non-JSON):
  `student_selected_content_id=javascript_ar` + `i18next=ar` على دومين `.qureo.education`
- الفصل: `GET {TP}/api/study/chapters/{cid}` → `lectures[].id`
- المحاضرة: `PUT students/lectures/{lid}` ثم `GET lectures/{lid}` → `talks[]`
  - حل talks اللي `type` يبدأ بـ `try`: خد `body.codes[0]` → `lang` (default javascript)، `model_answer` (لو فاضي استخدم `code`)، `placeholders` + هل `code` فيه `fitbBlock`
  - عادي: `PUT lecture-talks/{tid}` جسم `{"value":{"lang":L,"answer":MODEL}}`
  - fill-in-the-blank: `{"value":{"lang":L,"answers":[{"name":N,"code":MODEL}...]}}`
  - ثم `PUT lectures/{lid}/complete`
- الاختبار: `PUT students/chapters/{cid}/test` ثم لكل سؤال
  `PUT students/{review-questions|test-questions}/{qid}/answer/{choice|description}`
  جسم `{"choice_id":N}` أو `{"answer_code":"..."}` — الرد `{}` عادي وآخر سؤال بيرجع `{"complete":{...}}`
- التقرير: `GET students/sections/5/chapters` (عُد `completed_at` + اللي `diamond<5`) و`GET courses/javascript_ar/diamond` (المفروض 270/270)
- الفصول `90001`–`90054` (54 فصل، لازم **بالترتيب** — المقفول بيرجع locked)
- تشغيل السكربت: `./solve.sh [login] ['pass'] [start]` أو `START=.. LOGIN_ID=.. PASSWORD=.. ./solve.sh` — الـ `start` **رقم طبيعي 1–54** (الأرقام الخام 90001–90054 مقبولة أيضا وتعدي كما هي)

## 4ب. QUREO2 (python_short_ar) — الفروقات عن QUREO

- الكورس: `https://me-tp.qureo.education/course/python_short_ar` — سكشن `106` — الفصول `511001`–`511025` (25 فصل، 153 سؤال، 125 دايموند) — لازم **بالترتيب** (المقفول بيرجع `{"not_contracted":false,"not_fulfill_preconditions":true}`)
- الكوكي: `student_selected_content_id=python_short_ar` (نفس ميكانيكا QUREO)
- قائمة الفصول: `GET {TP}/api/study/sections/106` ← `{chapters:[{id,test_type:review|test,question_count}], section}` (مفيش curriculum منفصل)
- المحاضرات: نفس QUREO، لكن `type` بتاع الـ try هو `"try"` بالظبط (فلتر `startswith("try")` شغال للاتنين) و`lang` بييجي `python` من الـ API — و talks من نوع `choice_question`/`choice_survey` حوارات قصصية **تجاهلها** (المحاضرة بتكتمل من غيرها)
- أسئلة الاختبار (قراءة فقط، للحصد): `GET {TP}/api/study/chapters/{cid}/test` ← `[{question{id,content,type}, choices[{id,content}], descriptions[{code,editable,lang}]}]`
- نتيجة الاختبار التفصيلية (كنز التشخيص): `GET students/chapters/{cid}/test|review/result` ← `{histories, result:{choice_results[{choice_id,correct,choices[][].correct,explanation}], description_results[{answer_code,correct,model_answer,explanation}]}}` — استخدمها لو فصل نقص عن PERFECT: بتكشف الصح + `model_answer` (الإعادة **مجانية** و`best_correct_count` هو الأقصى)
- صور الأسئلة: `GET /contents/chapter/{cid}/test/{file}` — محتاجة الكوكيز الموقعة من `GET students/chapters/{cid}/cookies` (ابعت `values[]` كهيدر `Cookie` مع كوكيز الجلسة)
- إجابات QUREO2 بنفس سكيما QUREO (`type` = `review` → prefix `review-questions` و`test` → `test-questions`)
- غلطات المصحح المثبتة (المصحح هو الملك): فصل `511007` سؤال `511007010` الصح `5110070101` (رغم `If` الكابيتال!)، فصل `511012` سؤال `511012060` الصح سطر الـ print فقط (من غير imports)، فصل `511014` سؤال `511014050` الصح الكود الكامل (نفس الـ starter بشكل مختلف عن 511012060!)، فصل `511021` سؤال `511021050` الصح `5110210501` (المنهج مدرّس الـ loop-scope كـ block-scope — عكس بايثون الحقيقية!)، فصل `511021` سؤال `511021040` الصح `for` loop (التعليمات قالت while لكن المصحح عايز for)، فصل `511025` سؤال `511025020` الصح `calculation3(5, 10, 15)`، فصل `511025` سؤال `511025070` الصح `5110250701` (مفتاح الفلوشارت debatable — المصحح rules)
- تشغيل السكربت: `cd ROOT/qureo2-solver && ./solve.sh [login] ['pass'] [start]` — الـ `start` **رقم طبيعي 1–25** (الأرقام الخام 511001–511025 مقبولة أيضا)

### شكل `qureo answers.json`

```json
{"90001": {"type": "review", "questions": [
  {"qid": 90001010, "qtype": "choice", "choice_id": 900010101},
  {"qid": 90001020, "qtype": "description", "answer_code": "console.log(\"Hi\");"}
]}}
```
`type` = `review` أو `test` (يحدد prefix سؤال الاختبار).

## 4ج. QUREO2 EN (python_short_en) — ذاتي الاكتشاف بدون answers.json

- الكورس: `https://me-tp.qureo.education/course/python_short_en` — سكشن `202` — الفصول `531001`–`531010` (10 فصول، 50 دايموند) — لازم **بالترتيب** (المقفول يرجع 403 على `/test` أو `not_fulfill_preconditions` على المحاضرات)
- الكوكي: `student_selected_content_id=python_short_en` + `i18next=en` على دومين `.qureo.education`
- نوع الفصول: `review` عدا `531004` و`531008` = `test` (prefix `test-questions` بدل `review-questions`)
- **المحاضرات**: نفس QUREO2 العربي — حل try talks حياً من `model_answer` (لو فاضي استخدم `code`)
- **الاختبار — جولة التعلّم (learn pass)**: ابدأ الاختبار `PUT students/chapters/{cid}/test` ثم جاوب بتخمين (أول اختيار / الكود الفارغ يتعوّض بـ `print("x")`)
  - أسئلة `review`: رد الإجابة نفسها يكشف الصح — `result.choices[].correct==true → .choice.id` و`result.model_answer`
  - أسئلة `test`: الرد `{}` لكل سؤال (لا نتيجة) — بعد اكتمال المحاولة (آخر سؤال يرجع `complete`) يصبح `GET students/chapters/{cid}/test/result` متاحاً ← فيه `result.choice_results[]` (الصح من `choices[].correct`) و`result.description_results[]` (`model_answer`)
- **الاختبار — جولة التطبيق (apply pass)**: أعد `PUT .../test` (إعادة المحاولة مجانية و`best_correct_count` هو الأقصى) ثم جاوب بالإجابات المُست harvested ← `diamond:5`
- الحساب المُختبر: `482438443` — **50/50 PERFECT** (2026-10-23)
- تشغيل السكربت: `cd ROOT/qureo2-en-solver && ./solve.sh [login] ['pass'] [start]` — الـ `start` **رقم طبيعي 1–10** (الأرقام الخام 531001–531010 مقبولة أيضا)
- ملاحظة: الأكونت الإنجليزي عنده كمان `javascript_en` و`javascript_trial_en` (محرّك `javascript_en` مبني في `ROOT/qureo-js-en-solver` — شوف قسم 4د)

## 4د. QUREO EN (javascript_en) — ذاتي الاكتشاف بدون answers.json

- الكورس: `https://me-tp.qureo.education/course/javascript_en` — سكشن `2` — الفصول `30001`–`30054` (54 فصل، 270 دايموند) — لازم **بالترتيب** (المقفول يرجع 403 على `/test` أو `not_fulfill_preconditions` على المحاضرات)
- الكوكي: `student_selected_content_id=javascript_en` + `i18next=en` على دومين `.qureo.education`
- **قائمة الفصول ديناميكية**: `GET /api/study/sections/2` ← `{chapters:[{id, test_type}], section}` — نوع الفصل (`review`/`test`) يُقرأ من `test_type` بدون hardcode (عكس python_en اللي أرقام الفصول الـ test محفوظة يدويا)
- **المحاضرات**: نفس QUREO العربي — `lang=javascript` من الـ API، حل try talks حياً من `model_answer` (لو فاضي استخدم `code`)
- **الاختبار — جولة التعلّم (learn pass)**: ابدأ الاختبار `PUT students/chapters/{cid}/test` ثم جاوب بتخمين (أول اختيار / الكود الفارغ يتعوّض بـ `console.log("x")`)
  - أسئلة `review`: رد الإجابة نفسها يكشف الصح — `result.choices[].correct==true → .choice.id` و`result.model_answer`
  - أسئلة `test`: الرد `{}` لكل سؤال (لا نتيجة) — بعد اكتمال المحاولة (آخر سؤال يرجع `complete`) يصبح `GET students/chapters/{cid}/test/result` متاحاً ← فيه `result.choice_results[]` (الصح من `choices[].correct`) و`result.description_results[]` (`model_answer`)
- **الاختبار — جولة التطبيق (apply pass)**: أعد `PUT .../test` (إعادة المحاولة مجانية و`best_correct_count` هو الأقصى) ثم جاوب بالإجابات المُست harvested ← `diamond:5`
- الحساب المُختبر: `482438443` — الفصول 1–45 كانت محلولة مسبقاً (225 دايموند)، المحرّك أكمل 46–54 ← **270/270 PERFECT** (2026-10-23)
- تشغيل السكربت: `cd ROOT/qureo-js-en-solver && ./solve.sh [login] ['pass'] [start]` — الـ `start` **رقم طبيعي 1–54** (الأرقام الخام 30001–30054 مقبولة أيضا)
- ملاحظة: كمان فيه `javascript_trial_en` (كورس تجريبي) — لسه بدون محرّك لو اتحتاج

## 5. SPRIX — مرجع الـ API

- Base: `https://egy.app.spx-learning-square.com` — دخول: `POST /api/v1/auth/login` جسم `{"login_id":"...","password":"..."}`
- تحقق: `GET /api/v1/auth/me` — المنهج: `GET /api/v1/subjects/7/curriculum` (الوحدات 19–24، كل item فيه `id` + `item_type` ∈ chapter/review/test)
- الفصل: `GET /api/v1/chapters/{id}/blocks` → `data.blocks[]` (السؤال: `type=="question"`, `question_id`, `question.question_text`, `options[].text`)
- إجابة: `POST chapters/{id}/answer` جسم `{"block_id":B,"selected_option_id":O}` ← **ممنوع حقل `hint_used` (السيرفر بيرفضه 400)** — الرد فيه `is_correct:true/false` (والغلط **لا** يكشف الصح)
- إتمام فصل: `POST chapters/{id}/complete` → `{"completed":true,"star_score":5}`
- مراجعة: `POST reviews/{id}/complete` مباشرة
- اختبار: `POST tests/{id}/start` ← **لازم POST (الـ GET بيرجع `404 page not found` كنص!)** — الرد فيه `data.test_questions[]` (`id` ثابت لكل اختبار + `question_id`) و`data.questions{}` و`data.options{qid:[]}` — ثم `PUT tests/{id}/questions/{tqid}/answer` جسم `{"selected_option_id":O}` ثم `POST tests/{id}/submit` (لازم ≥80، والإعادة **مجانية** وأي عدد attempts، وأفضل درجة بتتحفظ)
- التقرير: `GET /api/v1/subjects/7/units` → `completed_items/total_items/progress_pct`
- تشغيل السكربت: `./solve.sh [login] ['pass'] [start]` — الـ `start` **رقم طبيعي 1–6** (الأرقام الخام 19–24 مقبولة أيضا) (التحقق: الوحدة 1–6)

### شكل `sprix answers.json`

```json
{"chapters": {"112": [[11387,4531],[11389,4533]]},
 "tests": {"40": [[1229,4913],[1233,4931]], "39": [[1179,4715], ...]}}
```
الفصول: `[block_id, option_id]` — الاختبارات: `[question_id, option_id]` (والـ `tqid` بيتبني لحظيا من رد `start`).

## 5ب. SPRIX EN (Financial Literacy subject 3) — ذاتي الاكتشاف بدون answers.json

- المادة: subject `3` = **Financial Literacy** (lang=en) على نفس الـ Base `https://egy.app.spx-learning-square.com` — الوحدات `1`–`6` (137 عنصر: فصول + مراجعات + اختبارات) — لازم **بالترتيب** (المقفول يرجع `403 chapter_locked` / `test_locked`)
- الأكونت الإنجليزي `482438443` عنده كمان subject `8` = Global Finance Quest — وله محرّك مستقل `ROOT/sphinx-solver/solve.sh` (شوف قسم 5ج)
- **الفصول — brute-force**: رد الإجابة الغلط ما يكشفش الصح (`correct_option_id: null`) — جرب كل خيار في السؤال لحد ما يرجع `is_correct:true` (الإعادة **مجانية** و`star_score` يفضل 5) ثم `POST chapters/{id}/complete` → `star_score:5`
- **الفصول المحاكاة** (0 أسئلة، مثلاً EN: 16/26/36/46): `complete` مباشرة
- **الاختبارات — treasure من submit**:
  1. `POST tests/{id}/start` (لازم POST) → جاوب كل الأسئلة بأول خيار → `POST tests/{id}/submit`
  2. رد الـ submit فيه `data.options[qid][].is_correct:true` لكل الأسئلة ← harvest الإجابات الصحيحة
  3. أعد `POST start` (الـ `tqid` بيتغير كل محاولة!) ثم جاوب بالإجابات المستخرجة → `submit` → `total_score:100`
- اختبارات نهاية الوحدات (EN: 5/9/13/17) فيها **50 سؤال** (مش 10) — نفس آلية الـ treasure
- المراجعات: `POST reviews/{id}/complete` مباشرة
- **ممنوع `hint_used`** (400) — نفس quirk العربي
- الحساب المُختبر: `482438443` — **كل الوحدات 1–6 = 100%** (2026-10-23)
- تشغيل السكربت: `cd ROOT/sprix-en-solver && ./solve.sh [login] ['pass'] [start]` — الـ `start` **رقم طبيعي 1–6**

## 5ج. SPHINX / Global Finance Quest (subject 8) — لعبة أسهم ذاتية الاكتشاف

- المادة: subject `8` = **Global Finance Quest** (لعبة `sphinx`) — نفس الـ Base `https://egy.app.spx-learning-square.com` — **كل الطلبة عندهم المادة** (متحقق على 5 حسابات).
- **جلسة اللعبة**: `POST /api/v1/subjects/8/games/sphinx/token` (جسم `{}`) **إجباري** قبل أي طلب على `/game/sphinx/api/v1/*` وإلا `AUTH_REQUIRED`. الدور: `learning_token` ثم `game_token`.
- الـ endpoints (كلها `?lang=ar`):
  - `GET  /game/sphinx/api/v1/me` → `data.currentGameId` (+ إحصائيات bestTotalAssets/clearCount).
  - `GET  /game/sphinx/api/v1/stocks` → `data.instruments[]` (15 سهم + 3 صناديق؛ كل سهم عنده `sector`/`region`/`currency`/`initialPrice`).
  - `POST /game/sphinx/api/v1/games` (جسم `{}`) → يبدأ لعبة جديدة؛ لو فيه لعبة شغالة يرجع `GAME_ALREADY_ACTIVE` (خد الـ id من `/me`).
  - `GET  /game/sphinx/api/v1/games/{id}` → `data.game` (currentDay/status/cash/totalAssets) + `data.holdings` + `data.prices` + `data.news` + `data.fx` + `data.score` + `data.diversitySum`.
  - `POST /game/sphinx/api/v1/games/{id}/trades` جسم `{code,side,quantity,expectedDay,clientTradeId}` (الـ clientTradeId UUID لكل صفقة).
  - `POST /game/sphinx/api/v1/games/{id}/advance` جسم `{expectedDay}` (بديل `dayJump`).
  - `GET  /game/sphinx/api/v1/games/{id}/result` → `.data.result = {totalScore,returnScore,diversityScore,grade,finalAssets,profit,zakatAmount,passed,isNewRecord}`.
- **ميكانيكا السعر**: الأسعار عشوائية (GBM) + خبر اليوم N يضرب سعر اليوم N+1 بمضاعف حسب النوع/الاتجاه:
  `stock bull×1.15 / bear×0.85` — `sector bull×1.08 / bear×0.92` — `macro bull×1.05 / bear×0.95`؛ `uncertain` مضاعف 1 لكن تقلّب ×2–3. الأخبار تتراكب (تُضرب) على السهم المتأثر. توجد تشويشات (تقلّب السهم) لذلك التوزيع على كل الإيجابيات أثبت من التركيز.
- **نظام الدرجات (مُتحقق حيّاً)**:
  - `returnScore = min(70, round(profitPct × 1.75))` — السقف عند ربح **40%** (total ≈ 700,000).
  - `diversityScore = min(30, 3 × عدد الأيام التي ≥5 أدوات مختلفة)` — السقف بعد 10 أيام.
  - `totalScore = returnScore + diversityScore` (أقصى **100 = SS**)؛ تدرّج الدرجات: C≈60، B≈70، A≈80، S≈90، SS=100.
- **استراتيجية المحرك**: قراءة أخبار اليوم → ترجيح كل سهم بمضاعفه المتوقع → بيع الكل ثم توزيع رأس المال على الإيجابيات + 5 تعبئات رخيصة (تنويع) → `advance`. عند الربح ≥40% (LOCK_ASSETS=700000) يقفل: نقد + 5 تعبئات ويُكمل لحد اليوم 30 (بدون مخاطرة) لضمان SS.
- الحسابات المُختبرة: `471352766` و`476194368` و`473694066` و`472645429` و`472713104` — **كلها 100/SS** (2026-10-25). المحرك وصل SS عادةً بين اليوم 8–15.
- تشغيل السكربت: `cd ROOT/sphinx-solver && ./solve.sh [login] ['pass']` — يُكمل اللعبة الجارية تلقائياً (idempotent)، ويعيد التشغيل بأمان.

## 6. الـ Quirks الحرجة (اكتُشفت بالتجربة — لا تتجاهلها)

1. **QUREO بدون كوكي `student_selected_content_id`**: رد non-JSON → خطأ `jq: Invalid numeric literal`. الحل: الكوكيز اليدوية قبل أي chapters call.
2. **SPRIX فصول مقفولة**: لازم المشي **بالترتيب** من START، الفصل المقفول بيرجع `403`.
3. **`start` الاختبار لازم POST**: الـ GET بيرجع `404 page not found` (نص مش JSON).
4. **ممنوع `hint_used`** في إجابة SPRIX (400 من السيرفر).
5. **صفوف `null` في رد `start`** عند بعض الأكونتات: ابنِ خريطة `qid→tqid` مع تجاهل الـ null (كانت بتوقع `jq: Cannot use null as object key`).
6. **فصول المحاكاة بلا أسئلة** (SPRIX: 85/95/105/115): مش موجودة في answers — اعمل `complete` مباشرة بعد التأكد أن `blocks` مفيهاش `type=="question"` (السكربت والتطبيق بيعملوا كده، وإلا توقف خاطئ).
7. **أسئلة المصحح فيها مخالف للشرح** (مثبتة بالإعادة): فصل 92 سؤال 9560 الصح `3532`، اختبار 35 سؤال 1082 الصح `4327` وسؤال 1091 الصح `4362`، اختبار 40 سؤال 1233 الصح `4931` (القيمة غير المحققة لا تتقلب قبل البيع الفعلي).
8. **اختبار 35 سؤال 1071 بايظ**: اختياراته الأربعة كلها مرفوضة — أقصى درجة 98 (ناجح لأنه ≥80، ومتسجل في تعليق `solve.sh`).
9. **رد `submit` كنز**: فيه `question_responses[].is_correct` + `options[][].is_correct:true` + `explanation` — استخدمه للتصحيح الذاتي: جاوب بأحسن تخمين، اقرأ الصح من الرد، أعد المحاولة → 100 مضمونة.
10. **أسئلة الجداول صور**: روابط `/media/subjects/7/questions/{qid}/{image}` محمية بـ CloudFront cookies (curl العادي بيرجع 403) — شوفها من تبويبات المتصفح (screenshot بصيغة jpeg لو الـ png علّق).

## 7. Workflow إضافة فصول/اختبارات جديدة (SPRIX)

1. افتح المنهج: `GET /subjects/7/curriculum` — حدد الفصول الناقصة (امشِ بالترتيب).
2. لكل فصل: `GET /chapters/{id}/blocks` — استخرج أسئلة `type=="question"` (النص + الاختيارات بـ ids) — لو مفيش أسئلة: `POST complete` مباشرة (محاكاة).
3. جاوب من الفهم، ثم `POST answer` لكل سؤال — لازم كلها `is_correct:true` ثم `POST complete` (تأكد `star_score:5`).
4. لكل اختبار: `POST start` → اعرض الأسئلة (`data.questions` + `data.options[qid]`) → جاوب → `PUT answer` لكل سؤال → `POST submit` → لو <100: اقرأ `is_correct` الحقيقية من رد الـ submit وأعد.
5. حدّث `ROOT/sprix-solver/answers.json` بنفس الشكل، ثم انسخه لـ `solver-app/app/src/main/assets/sprix_answers.json` (والـ QUREO بالمثل)، ارفع `versionCode`، ابنِ الـ APK (قسم 8)، وجرّب على المحاكي (قسم 9).

## 8. تطبيق الأندرويد — بناء وتعديل

- المتطلبات موجودة: JDK 21 + `ANDROID_HOME=/home/omsa/Android/Sdk` + Gradle 8.9 (wrapper مولّد في المشروع `gradle-8.9-bin.zip` — متحقق منه).
- البناء: `cd ROOT/solver-app && ./gradlew :app:assembleDebug --no-daemon` → الـ APK في `app/build/outputs/apk/debug/app-debug.apk`.
- بعد أي تعديل منطق/إجابات: انسخ `answers.json` للـ assets + زوّد `versionCode` (و`versionName`) في `app/build.gradle.kts` عشان يتثبت فوق القديم. (الحالة الحالية: **v1.6.0 versionCode 8** والأصول الثلاثة متطابقة مع `*-solver/answers.json` — متحقق بـ md5).
- الإدخال في التطبيق **بأرقام طبيعية**: QUREO فصل 1–54، QUREO2 فصل 1–25، SPRIX وحدة 1–6 (التطبيق يحوّل للرقم الخام داخليا — الخدمة والـ retry يتعاملان بالخام فقط).
- ثبات الخلفية: `WAKE_LOCK` + `PARTIAL_WAKE_LOCK` أثناء الجلسات + `START_STICKY` + **auto-retry تلقائي حتى 3 مرات** عند `IOException` من آخر نقطة محفوظة (`resumeStart`) — ولو استمر القتل من النظام: افتح إعدادات البطارية واعفِ التطبيق من التحسين (battery optimization off).
- ملف مسؤول عن إيه: `Api` شبكة/كوكيز/هيدرات — `Answers` تحميل assets (qureo/qureo2 نفس السكيما) — `SprixSolver` المنطق (port مباشر من السكربت) — `QureoSolver` + `QureoCourse` (كونفج لكل كورس: كوكي/سكشن/دايموند/ستارت — QUREO وQUREO2 نفس الكلاس) — `SolverService` تشغيل خلفية **متعدد الجلسات (MAX_PARALLEL=3 + queue + retry + progress + تنبيه صوت/اهتزاز)** — `MainActivity` دخول (3 تبويبات SPRIX/QUREO/QUREO2)+لوج+chips+progress — `strings.xml` إنجليزي — `colors.xml` بيرجاندي/ذهبي — `res/font` خطوط Poppins/JetBrains Mono — `res/layout/activity_main.xml` شاشتي الدخول واللوج.
- سطر الحقوق في `strings.xml`: `Developed by` + `footer_name` = **Omar Sayed** (بالذهبي).

## 9. الاختبار على المحاكي (workflow مجرّب)

```bash
adb devices -l                                   # لازم emulator-5554 device
adb install -r app/build/outputs/apk/debug/app-debug.apk
adb shell am start -n com.solver.app/.MainActivity
adb shell uiautomator dump /sdcard/ui.xml && adb pull /sdcard/ui.xml /tmp/ui.xml
# حلل الـ XML (python/regex) وهات مراكز الأزرار والحقول، ثم:
adb shell input tap X Y                          # تعبئة الحقول
adb shell input text '472713104'
adb shell "input text '<PASSWORD>'"              # الباسورد من /home/omsa/pass.md (لا تكتبها في اللوج)
adb shell input keyevent 67                       # مسح (كرر حسب الحاجة)
adb exec-out screencap -p > /tmp/emu.png         # screenshot واقراه بأداة Read
adb logcat -d --pid=$(adb shell pidof com.solver.app) | tail   # تشخيص كراش
```
- تنبيهات: إحداثيات اللمس بتتغير مع الكيبورد — اعتمد على الـ dump الطازج دائما، و`uiautomator dump /dev/stdout` لا تعمل (استخدم ملف). الإدخال في حقل غلط (باسورد بدل بداية) يكسر التحقق — اتأكد من الـ dump قبل Start.
- ما تم验证ه فعلا على المحاكي: SPRIX كامل (كل الوحدات 100% + اختبارات 100) + QUREO فصل 90054 (lectures + 8 أسئلة + `diamond:5` + `54/54` + `270`) + زرار Stop (`STOPPED by user.`).

## 10. أعطال شائعة

| العرض | السبب | الحل |
|---|---|---|
| شاشة لوج فاضية | ضغط Start وهو شغال / bind مكرر (متصلح: سطر `▶ starting` الفوري + منع التكرار) | التأكد من ظهور سطر البداية أولا |
| `404 page not found` عند test start | GET بدل POST | POST دائما |
| `Cannot use null as object key` | صفوف null في رد start | فلترة null من الخريطة |
| `unexpected domain: .qureo...` كراش | OkHttp يرفض الدومين اللي أوله نقطة | `trimStart('.')` (متصلح في `Api.kt`) |
| توقف عند فصل محاكاة | غير موجود في answers | `complete` مباشر بعد فحص blocks |
| `jq: Invalid numeric literal` (QUREO) | ناقص كوكي المحتوى المختار | إضافة الكوكيز قبل chapters calls |
| درجة اختبار <100 | تخمين غلط | قراءة `is_correct` من رد submit + إعادة |
| التطبيق يموت في الخلفية + `ERROR` | Doze نوم CPU/شبكة أو قتل النظام للعملية | متصلح: WakeLock + START_STICKY + auto-retry ×3 من `resumeStart` (سطر `↻ connection lost`) — ولو استمر: اعفِ التطبيق من battery optimization |
| شاشة الدخول تختفي أثناء إدخال جلسة 2 | سطور لوج الجلسة 1 كانت تسحب الواجهة للوج تلقائيا | متصلح: `loginPinned` — لا سحب تلقائي وأنت على الدخول (Start/Chips/ViewLog يفك التثبيت) |

## 11. التشغيل الجماعي للطلاب (SPRIX batch — الثقافة المالية فقط)

- الدخل: `ROOT/students_boys.json` (سكيما `[{name, code, password}]`) — الأدوات في `ROOT/sprix-solver/batch/`
- `check_logins.py`: فحص دخول فقط (login + me) بتوازي آمن — workers=3 + stagger + jitter + backoff واحد عند 429.
  الرد الحاسم: `401 {"success":false,"error":{"code":"invalid_credentials"}}` = باسورد غلط، `200 {"success":true}` = سليم.
  المخرجات: `valid_students.json` + `wrong_passwords.json` (نفس السكيما + حقل `error`) + `retry_later.json` (أخطاء شبكة/429 — يُعاد فحصها) + `check_report.json`.
- `run_batch.py`: حل كامل (START=1، وحدات 19–24) للناجحين — workers=3 + stagger عشوائي 2–6s + تخطي تلقائي للي خلصان 100% أصلا (فحص `/units` أولا) + retry واحدة للشبكة فقط (فشل الإجابة لا يُعاد — محتاج تحديث answers) + لوج لكل طالب `logs/<code>.log` + `summary.json` + `batch_progress.log`.
- التشغيل يجب أن يكون **مفصولا بـ `setsid`** (أي `bash` tool timeout يقتل الـ process group بما فيها الخلفيات العادية!):
  `setsid nohup python3 run_batch.py --workers 3 --start 1 > batch.out 2>&1 < /dev/null & disown`
  وخيارات: `--only CODE1,CODE2` لمجموعة فرعية.
- القياسات (2026-10-14): فحص 47 طالب ≈ دقيقتين بلا أي 429. الطالب الكامل ≈ 8 دقائق (481s) بالسرعة العادية و≈5.5 دقيقة (334–340s) مع `SLEEP_SCALE=0.3`. الدفعة النهائية: **46/46 مكتمل 100%** (تحقق مستقل عبر `/units` لكل طالب — `verify_report.json`) بلا أي حظر حتى مع 8 عمال.
- `verify_all.py`: تحقق مستقل (login + `/units` لكل طالب) — المكتمل = وحدات 19–24 كلها ≥100 — ينتج `completed_students.json` [{name, code, password}] + `needs_work.json` + `verify_report.json`.
- درس مستفاد: `results = []` مكررة بعد بلوك الـ resume كانت تمسح الملخص (المتهم سطر 168 — اتصلح). وأي `bash` tool timeout يقتل الـ process group بما فيها الخلفيات العادية — التشغيل الخلفي **لازم** `setsid`، والقتل الانتقائي عبر `/proc` مع استبعاد الأسلاف (لا تستخدم `pkill -f` بنمط يطابق سطر أمرك).
- الحل idempotent وآمن الإعادة: إعادة الإجابة/الإتمام مجانية، الاختبارات تُعاد وأحسن درجة تُحفظ، والطالب الخلصان يُتخطى تلقائيا.

## 12. نظام التراخيص الأوفلاين ونسخة العميل (Client & Licensing Architecture)

- **الفكرة**: العميل يأخذ نسخة تجريبية تفحص جهازه وتعرض كود الجهاز `OM-XXXX-XXXX` وتسمح له بتجربة **فصل واحد فقط** كإثبات تشغيل (سواء SPRIX أو QUREO/QUREO2)، ثم تقف وتطالبه بكود التفعيل. بعد الدفع، يرسل كود جهازه، ويولد عمر كود التفعيل من تطبيقه مباشرة، ليعمل التطبيق عند العميل بشكل دائم 100%.
- **تطبيق المطور (Admin Version)**: `ROOT/solver-app`
  - فتح مولد الأكواد: **ضغطة مطولة (Long Press)** على جملة `Omar Sayed` أسفل شاشة الدخول.
  - النافذة تتيح لصق كود جهاز العميل أو توليد كود لجهازك الحالي للاختبار، والضغط على **Generate Activation Key** ثم نسخ الكود بزر **Copy Key**.
- **نسخة العميل (Client Version)**: `ROOT/client-solver-app`
  - المعرف: `com.solver.client` (يمكن تثبيته مع تطبيق المطور على نفس الهاتف).
  - الـ APK: `client-solver-app/app/build/outputs/apk/debug/app-debug.apk`.
  - **حماية التجربة (Double Locks ضد التحايل)**:
    1. **منع تغيير الفصل**: طالما غير مفعل، يرفض التطبيق إدخال أي رقم غير `1` (لو كتب 2 أو 5 يرفض ويعيد 1 تلقائياً).
    2. **حرق كارت التجربة (One-time Trial)**: بعد انتهاء حل الفصل 1، يُسجل في الذاكرة `trial_used = true`، ويرفض التطبيق البدء أو الـ Retry مرة أخرى وتظهر رسالة: *"لقد استهلكت تجربتك المجانية بالفعل (تم حل الفصل الأول). يرجى إدخال كود التفعيل للبدء في حل باقي الفصول"*.
  - شاشة التفعيل مدمجة بأعلى الواجهة باللغة العربية مع زر نسخ كود الجهاز وخانة إدخال كود التفعيل وزر التفعيل.
  - كود التفعيل يرتبط رياضياً بالجهاز (HMAC-SHA256 أوفلاين كامل بدون سيرفر) ولا يعمل على جهاز آخر.

---

## 13. منظومة تيليجرام بوت السحابية SaaS (Hugging Face Spaces + aiogram + Gradio)

- **جذر المشروع**: `ROOT/telegram-bot/`
- **البوت**: `@FullMarkSolver_bot` (Token ID: 8728438630).
- **المنصة السحابية**: Hugging Face Spaces (`omar280sa/Solve_Bot`).
- **المكتبات الرئيسية**: aiogram 3.x + Gradio 4.x/6.x + SQLite + requests/RelaySession.
- **آلية العمل والأمان**:
  - العملاء والطلاب يتعاملون مع تيليجرام بوت فقط؛ الكود وبنك الإجابات وسجلات المنصات مخزنة سحابياً ومحمية بالكامل ولا تظهر للعملاء.
  - واجهة Gradio مخصصة للمشرف فقط ومحمية بـ `DASHBOARD_PASSWORD` و `DASHBOARD_USER` (لا يمكن لزائر فتحها أو توليد أكواد بدون كلمة السر).
  - الدعم الفني وواتساب المبيعات مدمج في الواجهة والبوت: `01028551063`.

### بنية مجلد `telegram-bot/`:
- `app.py`: نقطة البداية (تشغيل aiogram في background thread + واجهة Gradio بلوحة إدارة وتوليد أكواد التفعيل).
- `core/config.py`: إعدادات البيئة (BOT_TOKEN, ADMIN_IDS, RELAY_URL, PROXY_URL, DASHBOARD_PASSWORD).
- `core/database.py`: قاعدة بيانات SQLite (`data/solver.db`) لجداول users, vouchers, tasks مع ربط الكود بالطالب ومنع الاستخدام المزدوج.
- `core/answers_loader.py`: قارئ ملفات الإجابات المحفوظة في `answers/`.
- `core/relay_session.py`: عميل HTTP شفاف يتجاوز حظر الـ Datacenter IPs (HTTP 403) بإعادة توجيه الطلبات عبر البروكسي أو Cloudflare Worker.
- `core/sprix_solver.py`: محرك حل SPRIX (وحدات 19–24).
- `core/qureo_solver.py`: محرك حل QUREO (54 فصلاً) و QUREO2 (25 فصلاً).
- `core/queue_manager.py`: إدارة طابور الحل الخلفي وتحديثات التقدم الحية في تيليجرام (معدل خنق 2.5 ثانية).
- `relay-worker/`: كود Cloudflare Worker (`worker.js` + `wrangler.toml`) لتجاوز الـ 403 مجاناً.
- `mobile-relay-guide.md`: دليل تفصيلي كامل لتحويل الهاتف إلى Mobile Residential Proxy عبر Every Proxy + ngrok / Tailscale مع `PROXY_URL`.

