# 🔒 تقرير المراجعة الأمنية — Solver Platform

> **تاريخ المراجعة:** 2026-10-29
> **النطاق:** تطبيق Flutter (`app/`)، قاعدة بيانات Supabase وترحيلاتها (`supabase/`)، لوحة الأدمن (`dashboard/`)، وموقع التوزيع (`WebSiteForApp/`).
> **نوع المراجعة:** مراجعة كود + فحص الـ APK المُوزَّع فعليًا (Read-Only). لم يتم تعديل أي كود إنتاجي.
> **الهدف:** التطبيق سيُوزَّع على مجموعة من الطلاب وسيكون متاحًا للعامة، لذلك هذا التقرير مسؤول عن كل ثغرة تم رصدها وترتيبها حسب خطورتها.

---

## 📑 الفهرس

1. [الملخص التنفيذي](#1-الملخص-التنفيذي)
2. [منهجية المراجعة والنطاق](#2-منهجية-المراجعة-والنطاق)
3. [جدول الترتيب السريع](#3-جدول-الترتيب-السريع)
4. [الثغرات الحرجة (Critical)](#4-الثغرات-الحرجة-critical)
5. [الثغرات العالية (High)](#5-الثغرات-العالية-high)
6. [الثغرات المتوسطة (Medium)](#6-الثغرات-المتوسطة-medium)
7. [الثغرات المنخفضة / دفاع متعدد الطبقات](#7-الثغرات-المنخفضة--دفاع-متعدد-الطبقات)
8. [نقاط إيجابية (ما هو مطبّق صح)](#8-نقاط-إيجابية-ما-هو-مطبّق-صح)
9. [فجوات التحقق وحدود المراجعة](#9-فجوات-التحقق-وحدود-المراجعة)
10. [بوابة ما قبل التوزيع](#10-بوابة-ما-قبل-التوزيع)
11. [ملحق: خريطة الملفات الحساسة](#11-ملحق-خريطة-الملفات-الحساسة)

---

## 1) الملخص التنفيذي

المشروع فيه **ثلاث ثغرات حرجة** يجب إصلاحها قبل أي توزيع، لأنها تسمح إما باختراق كامل للنظام أو بسرقة المنتج نفسه:

| الرقم  | الثغرة                                                                    | لماذا خطيرة؟                                                                     |
| ------ | ------------------------------------------------------------------------- | -------------------------------------------------------------------------------- |
| **C1** | تصعيد صلاحيات إلى `admin` من أي حساب طالب عبر RLS على `profiles`          | أي طالب يستطيع قراءة بيانات كل الطلاب، منح نفسه عملات، والتحكم في المنصة بالكامل |
| **C2** | مفتاح تشفير بنك الإجابات مضمّن داخل الـ APK ومؤكد استخراجه من `libapp.so` | أي شخص يفك تشفير كل الإجابات (6 محركات) ويوزّعها أو يبني عميلًا مجانيًا          |
| **C3** | الـ APK المُوزَّع موقّع بمفتاح **Debug**                                  | خطر تزوير تحديثات خبيثة، وغير صالح للنشر العام أو المتاجر                        |

> **الحكم الأصلي:** 🔴 **لا يجب توزيع التطبيق على الطلاب قبل إصلاح C1 و C2 و C3.** باقي الثغرات (High/Medium) تُغلق قبل الإطلاق العام.

### ✅ حالة الإصلاحات المنفذة (C1 / C2 / C3)

| الثغرة | ما تم تنفيذه | الملفات |
|---|---|---|
| **C1** | ترحيل جديد يقيّد `INSERT/UPDATE` على `profiles` ويمنع تغيير `role/approved/trial_used/platform_*` من العميل | `supabase/migrations/00008_security_hardening.sql` |
| **C2** | إزالة `answers.enc` والمفتاح من التطبيق، إضافة جدول `solver_answers` خاص + Edge Function `solver-answers` تتحقق من الاشتراك، وتحديث التطبيق ليطلب الإجابات من السيرفر | `supabase/migrations/00009_solver_answers.sql`, `supabase/functions/solver-answers/index.ts`, `supabase/scripts/upload_answers.py`, `app/lib/services/answers_service.dart` |
| **C3** | إزالة توقيع Debug، وربط توقيع Release بـ `android/key.properties`، وإضافة سكربت توليد keystore | `app/android/app/build.gradle.kts`, `app/android/key.properties.example`, `app/tool/generate_release_keystore.sh` |

> ⚠️ **خطوات مطلوبة منك قبل التوزيع:** تطبيق الترحيلات `00008` و`00009` على Supabase، نشر الـ Edge Function، رفع الإجابات بالسكربت، توليد الـ release keystore، وإعادة بناء الـ APK. الـ APK القديم (الضعيف) تم عزله من مجلد التوزيع.

---

## 2) منهجية المراجعة والنطاق

### ما تم فحصه
- **Flutter App:** 40 ملف Dart — `lib/` بالكامل (الخدمات، المزوّدات، الشاشات، المحركات)، و`android/` (Manifest + Gradle).
- **Supabase:** كل الترحيلات `00001` → `00007`، و`config.toml`، وسكربت `promote_admin.sql`.
- **Dashboard (Next.js):** كل مسارات `src/app/api/admin/*`، صفحات `users`، `login`، ومكتبة Supabase.
- **WebSiteForApp:** `index.html`، `vercel.json`، وملف `Solver-Platform.apk` نفسه.
- **تاريخ Git:** البحث عن أسرار مسرّبة في commits.

### ما لم يتم
- لم يتم إجراء اختبار استغلال حي (Pen-test) على قاعدة البيانات المستضافة؛ الأدلة مبنية على نص السياسات ومسارات PostgREST.
- لم يتم تشغيل `apksigner`/`aapt` (غير مثبتين)؛ توقيع الـ Debug مؤكد من ملف البناء + دليل الإصدار + غياب ملفات `META-INF/*.RSA`.
- إعدادات Supabase **المستضاف** قد تختلف عن `config.toml` المحلي (يجب التحقق من لوحة Supabase).

---

## 3) جدول الترتيب السريع

| # | الثغرة | الخطورة | المكوّن | حالة الإطلاق |
|---|---|---|---|---|
| **C1** | تصعيد صلاحيات إلى `admin` عبر RLS على `profiles` | 🔴 حرجة | Supabase | ✅ تم الإصلاح (`00008`) |
| **C2** | مفتاح AES لملف الإجابات مكشوف داخل الـ APK | 🔴 حرجة | Flutter / APK | ✅ تم الإصلاح (سيرفر-سايد) |
| **C3** | توقيع الـ APK بمفتاح Debug | 🔴 حرجة | Android | ✅ تم الإصلاح (release keystore) |
| **H1** | إنفاذ الاشتراك والموافقة على الحساب من جهة العميل فقط | 🟠 عالية | Flutter | مطلوب |
| **H2** | جلسة Supabase في SharedPreferences عادية + حفظ كلمة سر المنصة | 🟠 عالية | Flutter | مطلوب |
| **H3** | لا تحقق من الهاتف/الإيميل + سياسة كلمات مرور ضعيفة | 🟠 عالية | Supabase Auth | مطلوب |
| **H4** | مفتاح `service_role` الحقيقي على القرص في `.env.local` | 🟠 عالية | Dashboard | مطلوب |
| **H5** | `GRANT ALL` لـ `anon` + دوال إحالة بلا تحقق | 🟠 عالية | Supabase | مطلوب |
| **M1** | تسريب PII في السجلات (logcat) | 🟡 متوسطة | Flutter | موصى به |
| **M2** | `allowBackup` غير معطّل + لا `FLAG_SECURE` | 🟡 متوسطة | Android | موصى به |
| **M3** | Dashboard يستخدم `service_role` معتمدًا على Middleware فقط + fallback anon | 🟡 متوسطة | Dashboard | موصى به |
| **M4** | `purchase_engine` لا يتحقق من `engine_access` | 🟡 متوسطة | Supabase | موصى به |
| **M5** | رسائل الدعم بلا حد طول / بلا Rate limiting | 🟡 متوسطة | Supabase | موصى به |
| **M6** | تسريب رسائل أخطاء DB الخام | 🟡 متوسطة | Dashboard | موصى به |
| **L1** | غياب CSP/Security Headers + لا CSRF صريح | 🟢 منخفضة | Dashboard/Web | تحسين |
| **L2** | لا Checksum للـ APK + لا MFA للأدمن | 🟢 منخفضة | Web/Dashboard | تحسين |
| **L3** | نظام الإحالات معطّل فعليًا (لا صفوف `referrals`) | 🟢 وظيفي | Supabase | تحسين |

---

## 4) الثغرات الحرجة (Critical)

### 🔴 C1 — تصعيد صلاحيات إلى `admin` (أخطر ثغرة)

#### الموقع
`supabase/migrations/00001_initial_schema.sql:302-321`

```sql
ALTER TABLE profiles ENABLE ROW LEVEL SECURITY;

-- المستخدم يقرأ صفّه فقط
CREATE POLICY profiles_select_own ON profiles
    FOR SELECT USING (id = auth.uid() OR is_admin());

-- المستخدم يعدّل صفّه فقط لو الإعداد غير مقفول
CREATE POLICY profiles_update_own ON profiles
    FOR UPDATE USING (id = auth.uid() AND onboard_locked = FALSE)
    WITH CHECK (id = auth.uid() AND onboard_locked = FALSE);

-- ⚠️ الاسم مضلّل: أي مستخدم يستطيع إدخال صفّه
CREATE POLICY profiles_insert_admin ON profiles
    FOR INSERT WITH CHECK (is_admin() OR id = auth.uid());
```

وأيضًا `supabase/migrations/00001_initial_schema.sql:826-833`:

```sql
GRANT ALL ON ALL TABLES IN SCHEMA public TO anon, authenticated, service_role;
```

#### الدليل على الثغرة
- صلاحية `INSERT` تسمح لأي مستخدم مُصادَق بإدخال صفّه (`id = auth.uid()`) **بدون تقييد عمود `role`**.
- صلاحية `UPDATE` تسمح بتعديل **أي عمود** (بما فيه `role`, `approved`, `trial_used`, `referral_code`, `referred_by`) طالما `onboard_locked = FALSE`.
- `GRANT ALL` يمنح صلاحية الكتابة على كل الأعمدة.
- **لا يوجد** `REVOKE` ولا trigger يفرض `role='student'` (تم التأكد من الترحيلات 00001–00007 كلها).
- دالة `is_admin()` تعتمد فقط على `profiles.role = 'admin'` (`00001:213-225`).

#### سيناريو الاستغلال (بدون تعديل الـ APK)
1. يسجّل المهاجم حسابًا عاديًا (التسجيل مفتوح — انظر H3).
2. يرسل طلبًا مباشرًا إلى PostgREST باستخدام الـ anon key + توكن جلسته:
   ```http
   PATCH /rest/v1/profiles?id=eq.<USER_ID>
   Authorization: Bearer <USER_JWT>
   apikey: <ANON_KEY>
   Content-Type: application/json

   { "role": "admin" }
   ```
   (أو `INSERT` لصفّه بدور admin إن لم يكن له صف).
3. بعدها `is_admin()` ترجع `true`.
4. يحصل على:
   - قراءة **كل** البروفايلات وعملاء المنصات (`platform_login`) وأرقام الهواتف داخل `display_name`.
   - قراءة كل المحافظ والمعاملات و`audit_logs`.
   - منح نفسه عملات عبر `admin_grant_coins`.
   - الموافقة على أي حساب عبر `admin_set_approval`.
   - فك ربط حسابات أي طالب عبر `admin_unbind_platform_account`.
   - الدخول إلى **لوحة الأدمن** من المتصفح بالايميل/الهاتف + كلمة المرور.

#### التأثير
اختراق كامل للباك-إند + تسريب PII لكل الطلاب + عملات مجانية + العبث بالمنصة. **هذه الثغرة وحدها تمنع الإطلاق.**

#### الإصلاح المقترح
1. **إزالة `OR id = auth.uid()`** من `profiles_insert_admin`، أو إلغاء صلاحية INSERT المباشر نهائيًا والاعتماد على `complete_onboarding()` فقط (`SECURITY DEFINER`).
2. **تقييد `profiles_update_own` بأعمدة محددة** — إما:
   - Trigger `BEFORE UPDATE` يرفض تغيير `role`, `approved`, `approved_at`, `trial_used`, `referral_code`, `referred_by`.
   - أو استخدام `GRANT UPDATE (display_name, avatar, ...)` بدل `GRANT ALL`.
3. Trigger `BEFORE INSERT` يفرض `role='student'` و `approved=FALSE` عند الإنشاء من العميل.
4. تقليل `GRANT ALL` إلى الصلاحيات الدنيا المطلوبة.

---

### 🔴 C2 — مفتاح تشفير الإجابات مكشوف داخل الـ APK

#### الموقع
`app/lib/solver/answers.dart:47-73`:

> **تم الإصلاح:** تم حذف `AnswersBundle` والمفتاح نهائيًا من الكود، وحذف `assets/answers.enc` و`tool/encrypt_answers.py`، ونُقل بنك الإجابات إلى جدول `solver_answers` الخاص + Edge Function `solver-answers`. القيم أدناه محجوبة (REDACTED) لأنها كانت مكشوفة.

```dart
// (الكود القديم — أُزيل)
class AnswersBundle {
  static const String _k1 = '<REDACTED>';
  static const String _k2 = '<REDACTED>';
  // ... rootBundle.load('assets/answers.enc') + AES-CBC ...
}
```

`app/tool/encrypt_answers.py` (الكود القديم — حُذف):

```python
# Obfuscated Key: 32 bytes
KEY = b"<REDACTED>"
IV = b"<REDACTED>"
```

#### الدليل العملي (كان مستخرجًا من الـ APK القديم)
```bash
unzip -p <old-apk> lib/arm64-v8a/libapp.so | strings | grep -E "<old-key-parts>"
# كان الناتج يحتوي جزأي المفتاح نصًا صريحًا.
```

وكان `assets/answers.enc` موجودًا داخل الـ APK القديم بحجم ~109KB:
```
assets/flutter_assets/assets/answers.enc   109408 bytes
```

> ⚠️ **تحذير متبقٍ:** نسخة الـ APK القديمة محفوظة في `/tmp/opencode/solver-quarantine/` ولم تعد تُخدم من الموقع. وتاريخ Git القديم ما زال يحتوي `answers.enc` والمفتاح؛ يجب purge للتاريخ أو افتراض أن مفتاح الإجابات القديم **محروق**.

#### التأثير
- أي شخص يستخرج `answers.enc` + المفتاح من الـ APK ويفك التشفير → **كل إجابات المحركات الستة** (QUREO، QUREO2، SPRIX عربي/إنجليزي).
- **تجاوز الدفع بالكامل:** لا حاجة للاشتراك لامتلاك الإجابات، ويمكن توزيعها أو بناء أي عميل مجاني.
- AES-CBC **بلا مصادقة** (لا GCM) و IV ثابت → التشفير هنا "إخفاء" فقط، ولا يوفر حماية حقيقية.
- تقسيم المفتاح إلى `_k1` + `_k2` لا يضيف أي أمان لأن الجزأين في نفس الملف ويُعاد تجميعهما في وقت التشغيل.

#### الإصلاح المقترح
1. **الحل الجذري (موصى به):** إخراج الإجابات من الـ APK نهائيًا — تسليم إجابات الفصل المطلوب **لحظيًا** من Edge Function بعد التحقق من الـ entitlement على السيرفر، وموقّعة ومرتبطة بالحساب/الجلسة.
2. **حل مرحلي:** تشفير AES-GCM بمفتاح مشتق من Keystore/الجهاز، مع إدراك أن هذا **يرفع العتبة فقط ولا يمنع الاستخراج**.
3. **تدوير المفتاح الحالي فورًا** وافتراض أنه "محروق" لأن نسخ APK تم بناؤها بالفعل.
4. إزالة سكربت التشفير/المفتاح من المستودع أو نقله لمكان آمن.

---

### 🔴 C3 — الـ APK موقّع بمفتاح Debug

#### الموقع
`app/android/app/build.gradle.kts:34-38`:

```kotlin
buildTypes {
    release {
        // TODO: Add your own signing config for the release build.
        // Signing with the debug keys for now, so `flutter run --release` works.
        signingConfig = signingConfigs.getByName("debug")
    }
}
```

ودليل الإصدار `RELEASE_GUIDE.md:82-83` ينص صراحة على استخدام "Debug Key" وينشر بصمة SHA-1 الخاصة به.

#### الدليل
- ملف البناء يستخدم `signingConfigs.getByName("debug")` لنسخة release.
- الـ APK المُوزَّع لا يحتوي `META-INF/*.RSA` (توقيع v2+ فقط)، ما يتوافق مع توقيع debug الافتراضي.
- دليل الإصدار يذكر البصمة `8B:98:...` كبصمة Debug.

#### التأثير
- **غير مقبول للنشر العام أو المتاجر**، وقد يُظهر Play Protect تحذيرًا.
- إذا تسرّب/شُورك الـ debug keystore (أو استُخدم الـ default keystore المعروف بـ `android` / `androiddebugkey`)، يمكن للمهاجم توقيع تحديث خبيث بنفس هوية التطبيق فيقبله Android كتحديث شرعي.
- فقدان الـ keystore = عدم القدرة على إصدار تحديثات فوق النسخة المثبّتة.

#### الإصلاح
1. إنشاء **release/upload keystore** خاص قوي.
2. تخزينه خارج المستودع (Secrets / keystore.properties مستثنى من git).
3. تفعيل **Play App Signing** إن أمكن.
4. عدم نشر البصمة الحقيقية أو الـ keystore.
5. إعادة بناء وتوقيع الـ APK قبل التوزيع.

---

## 5) الثغرات العالية (High)

### 🟠 H1 — إنفاذ الاشتراك والموافقة من جهة العميل فقط

#### الموقع
- **الموافقة على الحساب:** `app/lib/screens/home/home_screen.dart:53-57`
  ```dart
  final p = profile.valueOrNull;
  if (user != null && p != null && p.onboardLocked && !p.isApproved) {
    return const PendingScreen();
  }
  ```
  هذا مجرد عرض واجهة؛ لا شيء يمنع حسابًا غير معتمد من استدعاء RPCs مباشرة (`claim_trial`, `purchase_engine`, `bind_platform_account`).
- **التجربة المجانية:** `app/lib/models/trial_info.dart:17` و`app/lib/screens/engine/engine_detail_screen.dart:566-577` — إذا فشل الـ backend يتم استخدام تجربة **محلية** ("backend not migrated").
- **الاشتراك:** `app/lib/screens/engine/solving_screen.dart:154-165` و`436-455` — قرار التشغيل مبني على حالة العميل (`entitlementsProvider`).

#### التأثير
- تجاوز الاشتراك والتجربة بعدة طرق: تعديل APK، استدعاء RPCs مباشرة، أو استخراج الإجابات (C2).
- المحرك نفسه وبنك الإجابات يعملان على الجهاز، فلا يوجد تحقق سيرفري قبل الحل.

#### الإصلاح
- نقل قرار الاستحقاق إلى السيرفر: Edge Function تتحقق من `entitlements` + `approved` وترجع الإجابات/الصلاحية لحظيًا.
- إضافة تحقق `approved` داخل الدوال الحساسة (`purchase_engine`, `claim_trial`, `bind_platform_account`).
- إزالة مسار "التجربة المحلية" عند فشل الـ backend.

---

### 🟠 H2 — تخزين غير آمن لجلسة Supabase + حفظ كلمة سر المنصة

#### الموقع
- `app/lib/main.dart:29-32`:
  ```dart
  await Supabase.initialize(
    url: AppConstants.supabaseUrl,
    publishableKey: AppConstants.supabaseAnonKey,
  );
  ```
  بدون `authOptions`؛ الافتراضي في `supabase_flutter` هو `SharedPreferencesLocalStorage` أي أن **توكنات الوصول/التحديث غير مشفّرة**.
- `app/lib/services/secure_credentials.dart:15,28-32`: يتم حفظ كلمة سر منصة QUREO/SPRIX على الجهاز (عبر Keystore لكنها تبقى محفوظة)، وهذا يخالف `PLAN.md:127` و`RELEASE_GUIDE.md:206`.

#### التأثير
- على جهاز rooted، أو نسخة احتياطية، أو برمجية خبيثة → سرقة جلسة Supabase (اختطاف الحساب).
- سرقة كلمة سر المنصة التعليمية للطالب.

#### الإصلاح
- تمرير `FlutterAuthClientOptions(localStorage: SecureLocalStorage(...))` أو تكامل `flutter_secure_storage`.
- عدم حفظ كلمة سر المنصة (إعادة إدخالها كل مرة أو استخدام جلسة مؤقتة).
- إضافة `FLAG_SECURE` على شاشات إدخال البيانات.

---

### 🟠 H3 — لا تحقق من الهاتف/الإيميل + كلمات مرور ضعيفة

#### الموقع
`supabase/config.toml`:
```toml
enable_signup = true                    # :177
minimum_password_length = 6             # :183
password_requirements = ""              # :186
enable_confirmations = false            # :227  (تأكيد الإيميل معطّل)
```

و`app/lib/services/auth_service.dart:17-21`:
```dart
static String phoneToEmail(String phone) {
  final digits = phone.replaceAll(RegExp(r'\D'), '');
  return 'user_$digits@solver.app';   // لا يوجد تحقق OTP من الهاتف
}
```

#### التأثير
- **حجز/انتحال رقم طالب** قبل صاحبه (لأن الهاتف مجرد إيميل اصطناعي غير مُتحقَّق).
- حسابات spam بسهولة، وإساءة الإحالات لاحقًا.
- كلمات مرور 6 أحرف بلا تعقيد سهلة التخمين.

#### الإصلاح
- تفعيل تحقق الهاتف (OTP) أو الإيميل.
- رفع الحد الأدنى للكلمة إلى 8+ مع تعقيد.
- تفعيل Captcha + Rate limiting.
- منع التسجيل المتعدد لنفس الرقم/الجهاز.

---

### 🟠 H4 — مفتاح `service_role` الحقيقي على القرص

#### الموقع
`dashboard/.env.local` يحتوي المفتاح الحقيقي:
```
SUPABASE_SERVICE_ROLE_KEY=<REDACTED>
```
> **ملاحظة:** الملف **غير متعقّب في git** (تم التحقق من تاريخ Git: لا يوجد تسريب للمفتاح في commits؛ الموجود فقط placeholders في الوثائق). هذه نقطة إيجابية، لكن الملف موجود على القرص.

#### التأثير
- أي نسخة مضغوطة/مشتركة من مجلد المشروع، أو جهاز مطوّر مخترق → سيطرة كاملة على قاعدة البيانات متجاوزة RLS.
- المفتاح يمنح كل الصلاحيات بما فيها `auth.admin` (قراءة/تعديل كل المستخدمين).

#### الإصلاح
- إبقاء المفتاح في Vercel/Secrets فقط، وعدم وضعه في أي ملف داخل المشروع يُشارَك.
- إضافة `import 'server-only';` في `dashboard/src/lib/supabase/server.ts`.
- **تدوير المفتاح (Rotate)** قبل التوزيع.
- التأكد من عدم وجوده في أي حزمة/لقطة/`.next`.

---

### 🟠 H5 — `GRANT ALL` لـ `anon` + دوال بلا تحقق

#### الموقع
`supabase/migrations/00001_initial_schema.sql:826-833`:
```sql
GRANT USAGE ON SCHEMA public TO anon, authenticated, service_role;
GRANT ALL ON ALL TABLES IN SCHEMA public TO anon, authenticated, service_role;
GRANT ALL ON ALL ROUTINES IN SCHEMA public TO anon, authenticated, service_role;
GRANT ALL ON ALL SEQUENCES IN SCHEMA public TO anon, authenticated, service_role;
```

والدوال `grant_referral_signup` / `grant_referral_recharge` (`00001:546-650`) هي `SECURITY DEFINER` **بلا أي تحقق من `auth.uid()`**، ولا يوجد `REVOKE` في أي ترحيل.

#### التأثير
- أي خطأ مستقبلي في RLS (مثل C1) يتحول إلى اختراق كامل لأن `anon` يملك صلاحيات الكتابة على مستوى الجدول.
- دوال الإحالة قابلة للاستدعاء بدون تسجيل دخول (حاليًا no-op لأن `referrals` لا تُملأ، لكنها خطر عند تفعيلها).

#### الإصلاح
- تقليل الصلاحيات إلى الحد الأدنى (SELECT/INSERT محدد) بدل `GRANT ALL`.
- `REVOKE EXECUTE` عن `anon` للدوال الحساسة.
- إضافة تحقق هوية داخل دوال الإحالة.

---

## 6) الثغرات المتوسطة (Medium)

### 🟡 M1 — تسريب PII في السجلات
- `app/lib/solver/qureo_solver.dart:143` يسجّل جسم `userinfo` كاملًا:
  ```dart
  log(uinfo.body.length > 300 ? uinfo.body.substring(0, 300) : uinfo.body);
  ```
- `app/lib/solver/sprix_solver.dart:45` يسجّل جسم `/auth/me`.
- `app/lib/main.dart:18,23` و`app/lib/core/app_error.dart:38` يسجّلون تفاصيل الأخطاء.
- `debugPrint` **لا يُزال في release** ويظهر في logcat (متاح عبر USB debugging).

**الإصلاح:** حذف/إخفاء هذه السجلات في release أو استخدام logger بمرشّحات.

---

### 🟡 M2 — إعدادات أندرويد
`app/android/app/src/main/AndroidManifest.xml`:
- لا يضبط `android:allowBackup="false"` (الافتراضي `true`).
- لا يضبط `android:usesCleartextTraffic` صراحة (targetSdk الحديث يمنعه افتراضيًا، لكن يُفضّل تثبيته).
- لا `FLAG_SECURE` على شاشة بيانات الدخول (لقطة شاشة/تسجيل).

**الإصلاح:** `allowBackup=false`، `usesCleartextTraffic=false` صراحة، و`FLAG_SECURE`.

---

### 🟡 M3 — لوحة الأدمن: `service_role` مع الاعتماد على Middleware فقط
- `dashboard/src/app/users/page.tsx:1-12` و`dashboard/src/app/users/[id]/page.tsx:1-20` يستخدمان `createAdminClient()` (service_role) **دون تحقق أدمن داخل الصفحة**، معتمدين فقط على `middleware.ts`.
- `dashboard/src/lib/supabase/server.ts:54-67` — `createAdminClient` يرجع للـ anon key بصمت عند غياب المفتاح:
  ```ts
  const key =
    process.env.SUPABASE_SERVICE_ROLE_KEY ||
    process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY ||   // ← fallback خطير
    'placeholder-service-key';
  ```

**الإصلاح:** استدعاء `getAdminUser()` داخل كل صفحة server-component تستخدم service_role (دفاع متعدد الطبقات)، ورمي خطأ صريح بدل fallback.

---

### 🟡 M4 — تجاوز قيد المسار الدراسي
`purchase_engine` (`00004:212-270` / `00006:96-158`) لا يتحقق أن `p_engine_code` ضمن `engine_access` للمستخدم. أي طالب grade_2 غير هندسي يمكنه استدعاء RPC لشراء/فتح QUREO2.

**الإصلاح:** التحقق من `engine_access` (أو من grade/track/language) داخل الدالة.

---

### 🟡 M5 — رسائل الدعم بلا حدود
`support_messages.body TEXT` بلا حد طول، ولا Rate limiting على الإدراج (`00001:170-176`).

**التأثير:** إغراق التخزين/لوحة الأدمن (DoS بسيط).
**الإصلاح:** حد أقصى للطول + rate limit + فحص محتوى.

---

### 🟡 M6 — تسريب رسائل أخطاء DB
كل مسارات `dashboard/src/app/api/admin/*/route.ts` تُرجع `error.message` الخام للعميل، مثل `grant-coins/route.ts:27`:
```ts
if (error) {
  return NextResponse.json({ error: error.message }, { status: 500 });
}
```

**الإصلاح:** رسائل عامة للمستخدم وتفاصيل في السجلات فقط.

---

## 7) الثغرات المنخفضة / دفاع متعدد الطبقات

### 🟢 L1 — غياب Security Headers + CSRF صريح
- `dashboard/next.config.ts` لا يضيف CSP أو Security Headers.
- `WebSiteForApp/vercel.json` يضيف فقط ترويسات الـ APK والخطوط.
- مسارات POST لا تتحقق صراحة من `Origin` (تعتمد على SameSite).

**الإصلاح:** أضف `Content-Security-Policy`, `X-Frame-Options`, `Referrer-Policy`, `X-Content-Type-Options`, وتحقق `Origin` على مسارات API.

---

### 🟢 L2 — لا Checksum للـ APK + لا MFA للأدمن
- الموقع لا ينشر SHA-256/بصمة توقيع للـ APK؛ المستخدم لا يستطيع التحقق.
- لوحة الأدمن محمية بكلمة مرور فقط بدون MFA/تقييد IP.

**الإصلاح:** انشر SHA-256 وتوقيعًا، وفعّل MFA/Allowlist للوحة.

---

### 🟢 L3 — نظام الإحالات معطّل فعليًا (وظيفي)
لا يوجد `INSERT INTO referrals` في أي ترحيل — `complete_onboarding` يضبط `profiles.referred_by` فقط، لذا `grant_referral_signup` لا يجد صفوفًا ولا يمنح مكافآت.

**الإصلاح:** أضف trigger/RPC لإنشاء صف الإحالة، أو أزل الدوال المكشوفة.

---

## 8) نقاط إيجابية (ما هو مطبّق صح)

- ✅ **لا يوجد تسريب** لمفتاح `service_role` في تاريخ Git (فقط placeholders في الوثائق).
- ✅ **RLS مفعّل** على كل الجداول، وعمليات المحفظة/الاستحقاق محصورة في RPCs `SECURITY DEFINER` (`wallets` / `wallet_transactions` / `entitlements` بلا سياسات كتابة للعميل).
- ✅ **`flutter_secure_storage`** مُستخدم لكلمة سر المنصة (EncryptedSharedPreferences).
- ✅ كل الاتصالات للمنصات التعليمية وSupabase عبر **HTTPS**.
- ✅ التحقق من الاشتراك/الحساب موجود كطبقة أولى في الواجهة (لكنه قابل للتجاوز — H1).
- ✅ React يهرّب النصوص تلقائيًا في شات الدعم (لا `dangerouslySetInnerHTML`، لا XSS ظاهر).

---

## 9) فجوات التحقق وحدود المراجعة

| البند | الحالة |
|---|---|
| توقيع الـ APK | مؤكد من `build.gradle.kts` + `RELEASE_GUIDE.md` + غياب `META-INF/*.RSA` (لم أشغّل `apksigner` لأنه غير مثبت) |
| إعدادات Supabase المستضاف | قد تختلف عن `config.toml` المحلي — يجب التحقق من لوحة Supabase |
| استغلال حي على DB | لم يُنفَّذ Pen-test فعلي؛ C1 مثبتة من نص السياسات ومسارات PostgREST |
| مفتاح الإجابات | مؤكد استخراجه من `libapp.so` بالأمر المذكور أعلاه |
| `.env.local` | مؤكد وجوده على القرص؛ غير متعقّب في Git |

---

## 10) بوابة ما قبل التوزيع

| الأولوية | الإجراء | الحالة المطلوبة |
|---|---|---|
| **P0** | إصلاح C1 (سياسات `profiles`) وإعادة اختبار التصعيد | ⛔ مانع إطلاق |
| **P0** | إزالة الإجابات من الـ APK أو اعتبار المفتاح محروقًا + تدويره | ⛔ مانع إطلاق |
| **P0** | توقيع الـ APK بمفتاح Release حقيقي | ⛔ مانع إطلاق |
| **P1** | نقل التحقق من الاشتراك/الموافقة للسيرفر | مطلوب |
| **P1** | تأمين جلسة Supabase + إزالة حفظ كلمة سر المنصة | مطلوب |
| **P1** | تحقق هاتف/إيميل + سياسة كلمات مرور + Captcha | مطلوب |
| **P1** | تدوير `service_role` ونقله للـ Secrets فقط | مطلوب |
| **P2** | تقليل `GRANT` + `REVOKE` الدوال عن anon | مطلوب |
| **P2** | إزالة PII من السجلات + `allowBackup=false` + `FLAG_SECURE` | مطلوب |
| **P2** | Security headers + CSRF + MFA للأدمن + Checksum للـ APK | موصى به |

---

## 11) ملحق: خريطة الملفات الحساسة

| الملف | ما يحتويه |
|---|---|
| `supabase/migrations/00001_initial_schema.sql` | الجداول، RLS، `is_admin()`, `GRANT ALL` (C1, H5) |
| `supabase/migrations/00002..00007_*.sql` | RPCs (onboarding, trials, binding, approval) |
| `app/lib/solver/answers.dart` | مفتاح AES (C2) |
| `app/tool/encrypt_answers.py` | نفس المفتاح + IV (C2) |
| `app/lib/main.dart` | تهيئة Supabase بلا secure storage (H2) |
| `app/lib/services/secure_credentials.dart` | حفظ كلمة سر المنصة (H2) |
| `app/lib/screens/home/home_screen.dart` | بوابة الموافقة client-side (H1) |
| `app/lib/screens/engine/solving_screen.dart` | إنفاذ الاشتراك client-side (H1) |
| `app/android/app/build.gradle.kts` | توقيع Debug (C3) |
| `app/android/app/src/main/AndroidManifest.xml` | إعدادات أندرويد (M2) |
| `dashboard/.env.local` | `service_role` key (H4) |
| `dashboard/src/lib/supabase/server.ts` | `createAdminClient` + fallback (M3) |
| `dashboard/src/app/api/admin/*/route.ts` | تسريب أخطاء (M6) |
| `supabase/config.toml` | إعدادات Auth (H3) |
| `WebSiteForApp/downloads/Solver-Platform.apk` | الـ APK القديم — تم عزله من مجلد التوزيع |

---

## ✅ الخلاصة

> **تم إصلاح C1 و C2 و C3 في الكود.** لكن الإصلاح لا يكتمل إلا بعد:
>
> 1. تطبيق الترحيلات `00008` و`00009` على مشروع Supabase.
> 2. نشر Edge Function `solver-answers`.
> 3. رفع الإجابات عبر `upload_answers.py` بمفتاح `service_role`.
> 4. توليد release keystore عبر `generate_release_keystore.sh`.
> 5. إعادة بناء الـ APK وتوقيعه بمفتاح الإصدار، ثم رفعه للموقع.
> 6. تدوير مفتاح `service_role` القديم (لأنه كان على القرص).
> 7. افتراض أن مفتاح الإجابات القديم **محروق**، وتنظيف تاريخ Git إن أمكن.
>
> باقي الثغرات (H/M) تُغلق قبل الإطلاق العام.

---

*أُعدّ هذا التقرير آليًا كمراجعة أمنية شاملة، وتم تنفيذ إصلاحات C1/C2/C3 بناءً على طلب المالك.*