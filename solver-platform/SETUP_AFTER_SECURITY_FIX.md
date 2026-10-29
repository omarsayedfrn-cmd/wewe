# ✅ خطوات التشغيل بعد إصلاح الأمان (بسيطة)

> اتغير إيه؟ الإجابات كانت جوّه التطبيق، ودلوقتي بقت على Supabase.
> معناه: لازم ترفع الإجابات على Supabase مرة واحدة، وتولّد مفتاح توقيع، وتبني APK جديد.
> لو ما عملتش الخطوات دي، التطبيق مش هيقدر يحل (لأنه بيسأل السيرفر).

---

## 🧭 نظرة سريعة (4 خطوات)

```
1) طبّق الترحيلات على Supabase      → مرة واحدة
2) انشر Edge Function للمحرك        → مرة واحدة
3) ارفع ملفات الإجابات للسيرفر      → مرة واحدة
4) ولّد مفتاح الإصدار وابنِ APK جديد → عند كل إصدار
```

---

## 1️⃣ طبّق الترحيلات (تعديل قاعدة البيانات)

**أسهل طريقة: من لوحة Supabase (بدون أي أدوات):**

1. افتح [supabase.com/dashboard](https://supabase.com/dashboard) → اختر مشروعك.
2. من القائمة اليسرى: **SQL Editor** → **New query**.
3. افتح الملف التالي على جهازك وانسخ **كل** محتواه والصقه ثم **Run**:
   ```
   solver-platform/supabase/migrations/00008_security_hardening.sql
   ```
4. افتح `New query` تاني، وانسخ والصق محتوى:
   ```
   solver-platform/supabase/migrations/00009_solver_answers.sql
   ```
   ثم **Run**.

> النتيجة: تم منع تصعيد الصلاحيات، وإنشاء جدول الإجابات الخاص.

---

## 2️⃣ انشر الـ Edge Function

**أسهل طريقة: من لوحة Supabase:**

1. من القائمة اليسرى: **Edge Functions** → **Create a new function**.
2. سمّها بالضبط: `solver-answers`
3. انسخ محتوى الملف ده والصقه داخل المحرر:
   ```
   solver-platform/supabase/functions/solver-answers/index.ts
   ```
4. اضغط **Deploy**.
   - تأكد إن **Verify JWT** مفعّل (الافتراضي) — سيبها زي ما هي.

> **بديل (لو عندك Supabase CLI):**
> ```bash
> cd solver-platform
> supabase functions deploy solver-answers
> ```

---

## 3️⃣ ارفع الإجابات على السيرفر

محتاج Python 3 (موجود عندك) ومفتاح `service_role`.

1. من Supabase: **Project Settings** → **API** → انسخ **service_role** key.
2. من مجلد المشروع نفّذ (استبدل القيم):

```bash
cd /home/omsa/Projects/solver-project/solver-platform

export SUPABASE_URL="https://sjelihyjbptoktpfdchy.supabase.co"
export SUPABASE_SERVICE_ROLE_KEY="ضع_المفتاح_هنا"

python3 supabase/scripts/upload_answers.py
```

المفروض تشوف:
```
Loaded qureo (...)
Loaded qureo_js_en (...)
...
Uploaded 6 engine bundles (HTTP 201).
```

> ⚠️ متحطش المفتاح ده في أي مكان عام، ولا في git.

---

## 4️⃣ ولّد مفتاح الإصدار وابنِ الـ APK

**أ. اعمل مفتاح التوقيع (مرة واحدة بس، واحتفظ بنسخة آمنة منه):**

```bash
cd /home/omsa/Projects/solver-project/solver-platform/app
./tool/generate_release_keystore.sh
```
هيسألك على كلمة سر… هيكوّن:
- `android/app/release-keystore.jks`
- `android/key.properties`
- وهيطبع `SHA1:` → احتفظ بيها.

**ب. ضيف بصمة SHA-1 في Google Cloud** (عشان تسجيل الدخول بـ Google):
- [Google Cloud Console](https://console.cloud.google.com) → APIs & Services → Credentials.
- افتح الـ **Android OAuth client** الخاص بـ `com.solver.solver_app`.
- ضيف فيها `SHA1:` اللي طبعها السكربت.

**ج. ابنِ الإصدار:**

```bash
cd /home/omsa/Projects/solver-project/solver-platform/app
flutter build apk --release
```

**د. انسخ الناتج للموقع:**

```bash
cp build/app/outputs/flutter-apk/app-release.apk \
   /home/omsa/Projects/solver-project/solver-platform/WebSiteForApp/downloads/Solver-Platform.apk
```

---

## 🔍 كيف تتأكد إن كل حاجة تمام؟

1. **الترحيلات:** في SQL Editor نفّذ:
   ```sql
   select count(*) from solver_answers;   -- لازم يطلع 6
   ```
2. **الـ Function:** Edge Functions → لازم تشوف `solver-answers` بحالة Active.
3. **التطبيق:** نزّل الـ APK الجديد على تليفون → سجّل دخول → ابدأ الحل.
   لو ظهرت رسالة «هذه المنصة غير مفتوحة» فهذا طبيعي قبل الشراء/التجربة.

---

## ⛔ حاجات مهمة

- **الـ APK القديم خطر** (فيه الإجابات والمفتاح). تم عزله من الموقع — متوزّعهوش تاني.
- **دوّر مفتاح `service_role`** القديم (كان موجود في `.env.local` على الجهاز).
- تاريخ Git فيه نسخة قديمة من الإجابات → لو المستودع هيتشارك، لازم تتنضّف، أو اعتبر مفتاحها **محروق**.
- لو نسيت الخطوة رقم 3 (رفع الإجابات)، التطبيق هيفشل في الحل برسالة واضحة.

---

## ❓ لو مش عارف حاجة

قول لي في أي خطوة واقف وأنا أوضّحها لك خطوة بخطوة.
