# خطة مشروع Solver Platform (نسخة 1)

> هذا الملف هو المرجع الأساسي لأي شات جديد. اقرأه بالكامل قبل أي تنفيذ.
> المشروع جذر حالي: `/home/omsa/Projects/solver-project` — والمجلد ده (`solver-platform/`) هو الحاوية الجديدة للـ V1.

---

## 0) الرؤية العامة

منصة تعليمية (تطبيق موبايل + لوحة أدمن ويب) بيستخدمها الطلاب لحل المنصات التعليمية
(`QUREO` جافاسكريبت، `QUREO2` بايثون، `SPRIX` الثقافة المالية) بمنطق محركات موجود بالفعل
في نفس الريبو، مع نظام عملات/فتح فصول، إحالات، وشات دعم.

**أولويات صارمة (بالترتيب):**
1. البساطة التقنية مع المفعول الكبير (نتيجة مع أنضف وأسهل تعديلات).
2. تجربة المستخدم والشكل أولاً.
3. الأداء (أداء المحركات).
4. الأمان ثم الأمان ثم الأمان + سرية بيانات المستخدم.

---

## 1) المعمارية العامة

```
[Flutter Android App]  ──(Auth/Data/RPC/Realtime)──►  [Supabase]
   │  المحركات تشتغل محليًا (port لدارت)                ├─ Auth (Google)
   │  الإجابات مشفّرة جوه الـ APK (AES-GCM)             ├─ Postgres + RLS
   └─ بيانات دخول المنصات لا تُخزَّن أبدًا               ├─ RPC (عملات/فتح)
                                                        ├─ Realtime (شات)
[Next.js Dashboard] ──(admin, service role)────────────►└─ Edge Functions
```

- **التطبيق:** Flutter — **أندرويد فقط**.
- **الباك-إند:** Supabase كله (Auth + Postgres + RLS + Realtime + RPC).
- **اللوحة:** Next.js على Vercel.
- **المحركات:** تتنقل لدارت وتشتغل **على جهاز المستخدم** (IP منزلي = تفادي حظر 403 + صفر تكلفة سيرفر).
- **نظام الأكواد الأوفلاين القديم (HMAC `om-xxxx`):** يُلغى ويُستبدل بـ Supabase Auth + Entitlements.

---

## 2) القرارات المؤكدة (لا تُناقش من جديد)

- **المحركات على الجهاز محليًا**، والإجابات **مشفّرة جوه الـ APK** (الحل البسيط السريع للـ V1).
- **اللغة جزء من هوية الطالب:** `عام` = عربي، `لغات` = إنجليزي. **مقفولة** بعد التسجيل.
  الطالب اللغات لا يرى منصات العام أبدًا؛ لو عايز محركات برّه نطاقه → يكون **تاجر** (V2).
- **الشحن يدوي دائمًا:** المستخدم يكلّم التيم → يحوّل ويبعت صورة الدفع في الشات → الأدمن يعتمد ويعدّل الرصيد من الداشبورد.
- **تغيير المسار ممنوع** بعد التسجيل. الاختيار الأكاديمي كله (مرحلة/مسار/لغة) **مقفول**.
- **التجربة المجانية مرة واحدة للعمر** على مستوى الحساب.
- **الإحالة:** مكافأة صغيرة عند التسجيل + مكافأة معقولة عند **شحن** المُحال. الأرقام قابلة للتعديل من اللوحة.
- **التاجر (V2):** كل المحركات + أسعار أقل (tier) + بدون إحالة. يبيع للناس خارجيًا باسمه ولا أحد يعرف أنه يستخدم تطبيقنا.
- **الاستضافة:** Supabase مجاني + Vercel مجاني.

---

## 3) المنطق الأكاديمي (فصول مش دروس)

| المرحلة | المسار | المحركات المتاحة |
|---|---|---|
| أولى ثانوي | — | `QUREO` فقط، لحد فصل **42** |
| تانية ثانوي | الطب والعلوم الحيوية | `SPRIX` (ثقافة مالية) |
| تانية ثانوي | إدارة الأعمال | `SPRIX` |
| تانية ثانوي | الآداب والفنون | `SPRIX` |
| تانية ثانوي | الهندسة وعلوم الحاسب | `SPRIX` + `QUREO` (54) + `QUREO2` (بايثون) |

**تأثير اللغة (عام/لغات) على المحرك:**

| المحرك | الكود العربي | الكود الإنجليزي |
|---|---|---|
| QUREO JS | `qureo` (javascript_ar, 90001–90054) | `qureo_js_en` (javascript_en, 30001–30054) |
| QUREO2 Python | `qureo2` (python_short_ar, 511001–511025) | `qureo2_en` (python_short_en, 531001–531010) |
| SPRIX | `sprix` (subject 7) | `sprix_en` (subject 3, Financial Literacy) |

> **المحركات الستة:** `qureo`, `qureo_js_en`, `qureo2`, `qureo2_en`, `sprix`, `sprix_en`.

**التجربة المجانية (مرة واحدة للعمر):**

| الحالة | عدد فصول التجربة |
|---|---|
| أولى ثانوي | 5 فصول QUREO (من الأوائل) |
| تانية - هندسة وحاسب | 10 فصول QUREO (من الأوائل) |
| باقي مسارات تانية | فصل SPRIX واحد فقط |

---

## 4) الأنبوردنج (مرة واحدة، مقفول)

Google Sign-In → نوع الحساب (طالب/تاجر) → المرحلة → (المسار لو تانية) → (عام/لغات) → يحدّد `engine_access` **نهائيًا**.

> لسه فيه مساحة رقم 1 للإصدار الأول: نوع الحساب "طالب" فقط فعليًا، والتاجر V2.

---

## 5) قاعدة البيانات (Supabase Schema)

| الجدول | الحقول الأساسية | ملاحظات |
|---|---|---|
| `profiles` | `id`(=auth.uid), `role`(student/merchant/admin), `grade`, `track`, `language`(ar/en), `display_name`, `avatar`, `referral_code`, `referred_by`, `trial_used`, `onboard_locked`, `created_at` | الاختيار الأكاديمي مقفول بعد الأنبوردنج |
| `engines` | `code`, `name_ar`, `name_en`, `platform`, `course`, `language`, `max_chapter` | كتالوج المحركات الستة (max_chapter=42 لأولى ثانوي) |
| `engine_access` | `user_id`, `engine_code` | المحركات المتاحة للطالب (محسوبة وقت التسجيل) |
| `entitlements` | `id`, `user_id`, `engine_code`, `scope`(full/chapter), `chapters[]`, `source`(trial/purchase/gift), `created_at`, `expires_at` | مين ليه حق يحل إيه |
| `products` | `id`, `name`, `coins`, `price`, `active`, `sort` | باقات شحن العملات |
| `pricing` | `engine_code`, `kind`(full/chapter), `cost` | سعر الفتح — **قابل للتعديل من الداشبورد** |
| `wallets` | `user_id`, `balance` | |
| `wallet_transactions` | `id`, `user_id`, `delta`, `reason`, `ref_id`, `created_at` | ledger — يُكتب بـ RPC فقط |
| `referrals` | `referrer_id`, `referred_id`, `code`, `signup_reward`, `recharge_reward`, `status` | |
| `support_threads` | `id`, `user_id`, `status`, `last_message_at`, `unread_admin`, `unread_user` | Realtime |
| `support_messages` | `id`, `thread_id`, `sender_role`, `body`, `created_at` | Realtime |
| `settings` | `key`, `value`(jsonb) | حدود التجربة، مكافآت الإحالة، أسعار عامة |
| `audit_logs` | `id`, `admin_id`, `action`, `payload`, `created_at` | سجل تدقيق الأدمن |

**RPCs (كلها SECURITY DEFINER — العمليات الحساسة سيرفر-سايد فقط):**
- `purchase_engine(engine_code, scope, chapters[])` — يتحقق من الرصيد، يخصم، ينشئ entitlement، ويسجّل في الـ ledger في transaction واحدة.
- `grant_referral_signup(new_user_id)` — عند تسجيل مستخدم بكود إحالة.
- `grant_referral_recharge(referred_user_id, amount)` — عند شحن المُحال.
- `admin_grant_coins(user_id, amount, note)` — اعتماد الدفع اليدوي وزيادة الرصيد.
- `admin_set_entitlement(user_id, engine_code, scope, chapters[])` — منح يدوي.

---

## 6) المحركات (port لدارت)

- **المصدر الحالي:** تطبيق كوتلن في `ClientProjectForZoserAccount/` (المحركات الأصلية سكربتات في `qureo-solver/`, `qureo2-solver/`, `sprix-solver/`, والنسخ EN).
- **الملفات المطلوب نقلها:** `Api.kt` (OkHttp+CookieJar+هيدرات) → `dio` + cookie jar، `Pace.kt` (Boost/jitter + حارس 429/403)، `QureoSolver.kt` + `QureoCourse`، `SprixSolver.kt`، `Answers.kt`.
- **الخلفية:** `flutter_foreground_task` + WakeLock — متعدد الجلسات (MAX_PARALLEL) + queue + retry/resume + progress + تنبيه انتهاء.
- **الإجابات:** تُجمّع من `*-solver/answers.json` → تشفير AES-GCM وقت البناء → asset مشفّر؛ المفتاح مخزّن مقسّم مع إبهام بسيط.
  - ملاحظة أمنية: ده **يرفع العتبة مش يمنع الاستخراج 100%**. خيار V2 (لو اتطلب): تسليم إجابات الفصل المطلوب فقط لحظيًا من Edge Function موقّعة.
- **بيانات الدخول (QUREO/SPRIX):** تتستخدم لحظيًا على الجهاز ولا تُخزَّن ولا تُرسل للسيرفر؛ توكن جلسة التطبيق في `flutter_secure_storage`.

---

## 7) منطق الأعمال

- **العملات:** تشتري حل **فصل/فصول** أو **منصة كاملة**. السعر يجي من `pricing` (يُعدّل من اللوحة).
- **الشحن:** يدوي عبر شات الدعم + صورة دفع → الأدمن يعدّل الرصيد من الداشبورد (`admin_grant_coins`).
- **الإحالة:** كود لكل مستخدم؛ مكافأة صغيرة عند التسجيل + معقولة عند شحن المُحال؛ القيم من `settings`.
- **التاجر (V2):** `role=merchant` + tier أسعار أقل + كل المحركات + بدون إحالة.

---

## 8) لوحة الأدمن (Next.js)

- **Users:** بحث/فلترة/أدوار/منح عملات/عرض الرصيد والسجلات.
- **المنتجات والأسعار:** إدارة `products` و `pricing`.
- **الإعدادات:** حدود التجربة + مكافآت الإحالة (`settings`).
- **صندوق الدعم:** قائمة threads (Realetime) + غير المقروء + رد مباشر.
- **المحركات/الإجابات:** رفع/إصدارات ملفات الإجابات (لتوليد الـ assets المشفّرة).
- **التحليلات:** مستخدمين، عمليات حل، إيراد بالعملات.
- **سجل تدقيق:** `audit_logs`.

---

## 9) الأمان (الأولوية القصوى)

- **RLS** على كل الجداول: المستخدم يقرأ/يعدّل صفّه فقط.
- **أي عملية على العملات/الفتح ممنوعة من الكلاينت تمامًا** — RPC فقط بـ `SECURITY DEFINER`.
- **بيانات دخول المنصات لا تُخزَّن ولا تمر للسيرفر**؛ توكن الجلسة في Keystore.
- `service_role key` في اللوحة فقط، **مش في التطبيق**. Rate limiting + منع إساءة الإحالات.
- الإجابات مشفّرة + المفاتيح مبهمة.

---

## 10) المراحل (Roadmap)

| مرحلة | المخرج | الحالة |
|---|---|---|
| 0 | إعداد المشاريع: Supabase project + Flutter skeleton + Next skeleton | ✅ مكتملة |
| 1 | Auth (Google) + الأنبوردنج المقفول + `profiles` + RLS | ✅ مكتملة |
| 2 | port المحركات لدارت + تشفير الإجابات + شاشة الحل + Pace governor | ✅ مكتملة |
| 3 | المحفظة + الأسعار + الفتح (RPC) + التجربة المجانية | ✅ مكتملة |
| 4 | الإحالة + إعدادات اللوحة | ✅ مكتملة |
| 5 | شات الدعم (Realtime) + صندوق الأدمن | ✅ مكتملة |
| 6 | لوحة الأدمن الكاملة + تحليلات + سجل تدقيق | ✅ مكتملة |
| 7 | التاجر (V2) | ⬜ مجدولة |
| 8 | تحصين + اختبار + إصدار | 🔄 جارية |

---

## 11) حزمة التقنيات المقترحة

**Flutter App:** `supabase_flutter`, `google_sign_in`, `dio` (+ cookie jar), `flutter_foreground_task`, `flutter_secure_storage`, `riverpod`, `go_router`, `cached_network_image`, `intl`, `encrypt` (AES-GCM).

**Next.js Dashboard:** Next.js App Router + `@supabase/ssr` + TypeScript + Tailwind + shadcn/ui + Recharts.

**Supabase:** Postgres + Auth (Google OAuth) + RLS + Realtime + Edge Functions + CLI migrations.

---

## 12) مرجع المحركات والـ API (من الوثائق الحالية)

- المرجع الكامل: `/home/omsa/Projects/solver-project/docs/solver-manual.md`
- خطة SaaS القديمة (مرجع معماري عام): `/home/omsa/Projects/solver-project/docs/saas-plan.md`
- خريطة المشاريع: `/home/omsa/Projects/solver-project/README.md`
- المحركات الأصلية (سكربتات): `qureo-solver/`, `qureo-js-en-solver/`, `qureo2-solver/`, `qureo2-en-solver/`, `sprix-solver/`, `sprix-en-solver/`
- تطبيق الكوتلن المرجعي: `ClientProjectForZoserAccount/`
- **تنبيه:** بيانات الدخول في `/home/omsa/pass.md` (خارج الريبو) — لا تُنسخ داخل المشروع أبدًا.
