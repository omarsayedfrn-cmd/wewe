# 🚀 دليل التشغيل والإصدار الشامل — Solver Platform V1

> هذا المستند يحتوي على شرح تفصيلي خطوة بخطوة لتجهيز المشروع بالكامل، ربط الخدمات السحابية، واختباره وتجهيزه للإصدار النهائي للطلاب (Production Release).

---

## 📑 فهرس المحتويات
1. [المعمارية التقنية للمنظومة](#1-المعمارية-التقنية-للمنظومة)
2. [المتطلبات الأساسية (Prerequisites)](#2-المتطلبات-الأساسية)
3. [الخطوة 1: تجهيز وربط قاعدة بيانات Supabase](#الخطوة-1-تجهيز-وربط-قاعدة-بيانات-supabase)
4. [الخطوة 2: تشغيل ونشر لوحة الأدمن (Next.js Dashboard)](#الخطوة-2-تشغيل-ونشر-لوحة-الأدمن-nextjs-dashboard)
5. [الخطوة 3: تجهيز وبناء تطبيق الأندرويد (Flutter APK)](#الخطوة-3-تجهيز-وبناء-تطبيق-الأندرويد-flutter-apk)
6. [الخطوة 4: دورة التشغيل الحية وإدارة العملاء (Operations)](#الخطوة-4-دورة-التشغيل-الحية-وإدارة-العملاء)
7. [الخطوة 5: قائمة التحقق الأمنية قبل الإطلاق (Launch Checklist)](#الخطوة-5-قائمة-التحقق-الأمنية-قبل-الإطلاق)

---

## 1. المعمارية التقنية للمنظومة

```
[تطبيق الطالب Flutter (Android)]  ──(Auth/Data/RPC/Realtime)──►  [سحابة Supabase المجانية]
       │  المحركات تعمل محلياً على الهاتف                           ├─ Auth (Google Sign-In)
       │  بنك الإجابات مشفر داخل التطبيق (AES-256)                 ├─ Postgres + RLS (13 جدول)
       └─ بيانات الدخول لحظية ولا تُخزن على السيرفر                 ├─ دوال الأمان (RPCs)
                                                                   └─ Realtime (شات الدعم)
[لوحة الأدمن Next.js على Vercel] ──(Admin Client / Service Role)───►
```

---

## 2. المتطلبات الأساسية

تأكد من توفر الأدوات التالية على بيئة التطوير الخاصة بك:
- **Node.js** إصدار 20 أو أحدث + **npm**
- **Flutter SDK** إصدار 3.24 أو أحدث + **Android SDK**
- **Python 3** (معه مكتبة `cryptography` لتوليد الأصول المشفرة)
- حساب مجاني على [Supabase](https://supabase.com)
- حساب مجاني على [Vercel](https://vercel.com) (لاستضافة لوحة الأدمن)
- مشروع على [Google Cloud Console](https://console.cloud.google.com) لتفعيل Google Sign-In

---

## الخطوة 1: تجهيز وربط قاعدة بيانات Supabase

### 1.1 إنشاء المشروع على Supabase
1. ادخل على [Supabase Dashboard](https://supabase.com/dashboard) واضغط **New Project**.
2. اختر اسماً للمشروع (مثلاً: `solver-platform`) وكلمة سر قوية لقاعدة البيانات (`Database Password`).
3. اختر أقرب منطقة جغرافية للمستخدمين (مثلاً: `Frankfurt` أو `London`).

### 1.2 تطبيق الـ Schema والميجريشن
1. في القائمة الجانبية في Supabase، افتح **SQL Editor**.
2. اضغط **New Query** وانسخ محتوى الملف المجهز بالكامل:
   ```
   solver-platform/supabase/migrations/00001_initial_schema.sql
   ```
3. اضغط **Run**.
4. سيتم إنشاء:
   - كافة الجداول الـ 13 (`profiles`, `engines`, `wallets`, `entitlements`, إلخ).
   - تفعيل سياسات الأمان الـ RLS بالكامل.
   - دوال العمليات الحساسة (`purchase_engine`, `admin_grant_coins`, إلخ).
   - بذور البيانات الأساسية للمحركات الستة، والأسعار المبدئية، وإعدادات التجربة المجانية.

### 1.3 استخراج مفاتيح الـ API
من قائمة **Project Settings** ← **API**:
- انسخ **Project URL** (مثال: `https://xyzcompany.supabase.co`).
- انسخ **anon public key**.
- انسخ **service_role secret key** (⚠️ يُستخدم للوحة الأدمن فقط ولا يوضع داخل تطبيق الهاتف).

### 1.4 تفعيل Google Sign-In
1. في Supabase افتح **Authentication** ← **Providers** ← **Google** وقم بتفعيله (`Enable Google`).
2. افتح [Google Cloud Console](https://console.cloud.google.com):
   - **الخطوة أ: إنشاء Web Client ID**:
     - أنشئ **OAuth 2.0 Client IDs** من نوع **Web application**.
     - أضف الـ **Authorized redirect URIs** المعطى لك من Supabase (مثال: `https://xyzcompany.supabase.co/auth/v1/callback`).
     - انسخ `Client ID` و `Client Secret` وضعهما في إعدادات Supabase واحفظ التغييرات.
     - انسخ أيضاً `Client ID` وضعه في `AppConstants.googleWebClientId` في تطبيق Flutter.
- **الخطوة ب: إنشاء Android Client ID (ضروري جداً لعمل الدخول على هواتف الطلاب)**:
      - أنشئ معرفاً ثانياً بالضغط على **Create Credentials** ← **OAuth client ID**.
      - اختر نوع التطبيق: **Android**.
      - أدخل الـ Package name: `com.solver.solver_app`
      - أنشئ **Release Keystore** أولاً ثم استخدم بصمة SHA-1 الخاصة به:
        ```bash
        cd solver-platform/app
        ./tool/generate_release_keystore.sh
        ```
        السكربت يطبع `SHA1:` الخاصة بمفتاح الإصدار — استخدمها هنا.
        > لا تستخدم بصمة الـ Debug Key القديمة؛ تم إلغاء توقيع الإصدارات بمفتاح Debug.
      - احفظ الإعدادات (قد يستغرق 2-5 دقائق ليعمل).
   - **الخطوة ج: إعداد شاشة الموافقة (OAuth Consent Screen)**:
     - تأكد من إضافة `User support email` و `Developer contact information`.
     - تأكد من تعيين الحالة إلى **Publish App** (أو إضافة حسابات التجربة في Test Users إن كانت قيد الاختبار).

### 1.5 إنشاء أول حساب أدمن
1. بعد تسجيل أول حساب لك عبر Google أو البريد في المنظومة، اذهب إلى جدول `profiles` في Supabase **Table Editor**.
2. ابحث عن صفك وغير قيمة الحقل `role` من `'student'` إلى `'admin'`.

---

## الخطوة 2: تشغيل ونشر لوحة الأدمن (Next.js Dashboard)

المشروع يقع في المجلد: `solver-platform/dashboard/`

### 2.1 إعداد ملف المتغيرات البيئية `.env.local`
في مجلد `dashboard/`، عدل ملف `.env.local`:
```env
NEXT_PUBLIC_SUPABASE_URL=https://your-project.supabase.co
NEXT_PUBLIC_SUPABASE_ANON_KEY=your-actual-anon-key
SUPABASE_SERVICE_ROLE_KEY=your-actual-service-role-key
```

### 2.2 تشغيل واختبار الداشبورد محلياً
```bash
cd solver-platform/dashboard
npm run dev
```
افتح المتصفح على `http://localhost:3000`:
- ستظهر لك شاشة الدخول `http://localhost:3000/login`.
- ادخل بحسابك الإداري.
- ستفتح لك لوحة التحكم: متابعة الطلاب، تعديل الأسعار، شحن العملات، صندوق الدعم والمحادثات الحية.

### 2.3 النشر السحابي المجاني على Vercel
1. ارفع المشروع على GitHub في مستودع خاص (Private Repository).
2. ادخل على [Vercel](https://vercel.com) واضغط **Add New** ← **Project**.
3. اختر مجلد المشروع مع تحديد **Root Directory**: `solver-platform/dashboard`.
4. في قسم **Environment Variables** أضف نفس المفاتيح الثلاثة:
   - `NEXT_PUBLIC_SUPABASE_URL`
   - `NEXT_PUBLIC_SUPABASE_ANON_KEY`
   - `SUPABASE_SERVICE_ROLE_KEY`
5. اضغط **Deploy**.
6. ستحصل على رابط رسمي للوحة الأدمن (مثل: `https://solver-admin.vercel.app`) محمي بشهادة SSL مجانية وتحديثات تلقائية.

---

## الخطوة 3: تجهيز وبناء تطبيق الأندرويد (Flutter APK)

المشروع يقع في المجلد: `solver-platform/app/`

### 3.1 ربط إعدادات التطبيق
افتح الملف:
[`solver-platform/app/lib/core/constants.dart`](file:///home/omsa/Projects/solver-project/solver-platform/app/lib/core/constants.dart)
وقم بوضع المفاتيح الحقيقية:
```dart
static const String supabaseUrl = 'https://your-project.supabase.co';
static const String supabaseAnonKey = 'your-actual-anon-key';
static const String googleWebClientId = 'your-google-web-client-id.apps.googleusercontent.com';
```

### 3.2 رفع بنك الإجابات إلى السيرفر (لم يعد يُضمَّن في الـ APK)
بنك الإجابات أصبح **سيرفر-سايد فقط** داخل جدول خاص `solver_answers` لا يستطيع أي عميل قراءته مباشرة. التطبيق يطلب الإجابات من Edge Function اسمها `solver-answers` بعد التحقق من الجلسة والموافقة على الحساب والاشتراك.

1. طبّق الترحيلات الجديدة `00008` و`00009` (عبر `supabase db push` أو SQL Editor).
2. انشر الـ Edge Function:
   ```bash
   supabase functions deploy solver-answers
   ```
3. ارفع الإجابات من مجلد `Engines/` إلى الجدول باستخدام مفتاح `service_role`:
   ```bash
   export SUPABASE_URL="https://your-project.supabase.co"
   export SUPABASE_SERVICE_ROLE_KEY="your-service-role-key"
   python3 solver-platform/supabase/scripts/upload_answers.py
   ```

> لم يعد هناك ملف `assets/answers.enc` ولا مفتاح تشفير داخل التطبيق. أي نسخة قديمة تحتوي عليها يجب التخلص منها.

### 3.3 التحقق من سلامة الأكواد
```bash
cd solver-platform/app
flutter pub get
flutter analyze
```
يجب أن تحصل على: `No issues found!`.

### 3.4 بناء الـ Release APK الجاهز للنشر
أولاً أنشئ مفتاح الإصدار (مرة واحدة فقط، واحتفظ بنسخة احتياطية آمنة منه):
```bash
cd solver-platform/app
./tool/generate_release_keystore.sh
```
سيُنشئ `android/app/release-keystore.jks` و`android/key.properties` (كلاهما مستثنى من git).

ثم ابنِ الإصدار:
```bash
cd solver-platform/app
flutter build apk --release
```
الملف الناتج سيكون جاهزاً للإرسال والتثبيت على هواتف الطلاب فوراً في المسار:
```
solver-platform/app/build/app/outputs/flutter-apk/app-release.apk
```

> إذا لم يوجد `android/key.properties` سيفشل بناء الإصدار برسالة واضحة. هذا مقصود: لا يُسمح بعد الآن بالتوقيع بمفتاح Debug للتوزيع.

---

## الخطوة 4: دورة التشغيل الحية وإدارة العملاء

1. **تسجيل الطالب والأنبوردنج:**
   - يفتح الطالب التطبيق ويسجل بحساب Google.
   - تظهر شاشة الأنبوردنج الإجبارية:
     - اختيار المرحلة (أولى ثانوي / تانية ثانوي).
     - اختيار المسار (لو تانية ثانوي: علمي علوم / أدبي / فنون / هندسة وحاسب).
     - اختيار نوع التعليم (عام = عربي / لغات = إنجليزي).
     - إدخال كود إحالة صديق (اختياري).
   - يتم تأكيد الاختيار وقفل المسار نهائياً، ويتم تلقائياً إدراج المحركات المستحقة للطالب في جدول `engine_access`.

2. **التجربة المجانية:**
   - يحصل الطالب تلقائياً على تجربة فصول مجانية محددة للتأكد من قوة المحرك قبل الدفع (وفقاً للقيم المضبوطة في إعدادات اللوحة).

3. **شحن العملات:**
   - يتوجه الطالب لتبويب المحفظة أو الدعم الفني ويرسل رسالة مع صورة التحويل (فودافون كاش / إنستاباي).
   - يفتح الأدمن الداشبورد على `Support Inbox` ويتحقق من التحويل.
   - يضغط الأدمن على زر **عرض ملف الطالب** ثم يضغط **شحن عملات**، ويكتب عدد العملات وسبب الشحن (مثلاً: "شحن 500 عملة عبر إنستاباي").
   - تنزل العملات في محفظة الطالب فوراً، وتُسجل في دفتر المعاملات (Ledger)، وإذا كان الطالب مسجلاً بكود إحالة وكان هذا أول شحن له، تمنح مكافأة الشحن للشخص المُحيل تلقائياً عبر دالة `grant_referral_recharge`.

4. **فتح الفصول والحل:**
   - يدخل الطالب على أي محرك متاح له ويضغط على فتح فصل محدد أو فتح المحرك كاملاً.
   - تُستدعى دالة `purchase_engine` الأمنية لتخصم العملات وتمنح الـ Entitlement مباشرة.
   - يضغط الطالب على أيقونة التشغيل فيفتح له تيرمنال الحل الحي، يكتب بيانات دخوله ويفعل زر **⚡ Boost** ويبدأ الحل ليحصل على 100% PERFECT في ثوانٍ معدودة.

---

## الخطوة 5: قائمة التحقق الأمنية قبل الإطلاق

| العنصر | الإجراء | الحالة |
|:---|:---|:---:|
| **RLS Policies** | التأكد من أن جميع جداول الـ Postgres الـ 13 مفعّل عليها RLS | ✅ مؤكد |
| **Service Role Key** | التأكد من عدم استخدام الـ Service Role Key في كود التطبيق الموبايل إطلاقاً | ✅ مؤكد |
| **Ledger Protection** | منع أي تعديل مباشر على المحافظ أو رصيد العملات إلا عبر دوال الـ RPC الآمنة | ✅ مؤكد |
| **Credential Privacy** | عدم تخزين كلمات مرور الطلاب لمنصات QUREO و SPRIX على أي سيرفر أو قاعدة بيانات | ✅ مؤكد |
| **Server-side Answers** | التأكد من نشر `solver-answers` ورفع الإجابات لجدول `solver_answers` الخاص وعدم وجود `answers.enc` في الـ APK | ✅ مؤكد |
| **Release Signing** | التأكد من وجود `android/key.properties` وتوقيع الـ APK بمفتاح Release (لا Debug) | ✅ مؤكد |
| **Profiles RLS** | التأكد من تطبيق ترحيل `00008` ومنع تصعيد `role/approved/trial_used` من العميل | ✅ مؤكد |
| **Rate Limit Guard** | التأكد من تفعيل حاكم السرعة `Pace` وحماية 429 لمنع حظر حسابات الطلاب | ✅ مؤكد |

---
**تم إعداد وتجهيز وتوثيق المنظومة بواسطة Omar Sayed**
