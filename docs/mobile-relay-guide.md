# دليل تحويل الهاتف إلى بروكسي محمول (Mobile Residential Proxy Guide)

> هذا الدليل يشرح خطوة بخطوة كيف تجعل حركة مرور البوت السحابي (Hugging Face Spaces) تمر عبر هاتفك المحمول (4G/5G أو Wi-Fi منزلي) للاستفادة من عنوان الـ IP السكني النظيف (Residential IP) الذي لا يمكن لمنصات SPRIX و QUREO حظره مطلقاً (تخطي خطأ HTTP 403).

---

## 🎯 الفكرة العامة

1. الهاتف المحمول متصل بالإنترنت (4G أو Wi-Fi) ولديه IP محلي حقيقي لا يُحظر.
2. يشغّل الهاتف تطبيق بروكسي محلي خفيف (مثل **Every Proxy**).
3. نقوم بفتح "نفق آمن ومجاني" (Tunnel) يربط المنفذ من هاتفك بسيرفر Hugging Face السحابي عبر **Tailscale** أو **ngrok** أو **Cloudflare Tunnel**.
4. نضع رابط البروكسي الناتج في متغير `PROXY_URL` في Hugging Face Space.
5. البوت يرسل طلبات تسجيل الدخول والحل عبر هاتفك مباشرة بنسبة نجاح 100%.

---

## 📱 الخطة (أ): الطريقة الأسهل عبر تطبيق ngrok (دقيقتين فقط)

### الخطوة 1: تشغيل البروكسي على الموبايل
1. قم بتثبيت تطبيق **Every Proxy** مجاناً من متجر Google Play.
2. افتح التطبيق وفعل خيار **HTTP / HTTPS Proxy**.
3. ستلاحظ أنه يعمل على المنفذ الافتراضي: `8080` (مثلاً: `127.0.0.1:8080`).

### الخطوة 2: فتح النفق الخارجي (Tunnel)
يمكنك تثبيت تطبيق **Termux** على الهاتف وتشغيل ngrok بخطوة واحدة:
```bash
# داخل Termux:
pkg install ngrok
ngrok http 8080
```
- سيعطيك رابطاً خارجياً مثل: `http://2.tcp.ngrok.io:12345` أو رابط https.

### الخطوة 3: الربط مع Hugging Face Space
- في Hugging Face Space > Settings > Variables:
  - أضف `PROXY_URL`: وضع الرابط الذي حصلت عليه (مثال: `http://2.tcp.ngrok.io:12345`).
  - اضغط **Restart Space**.

---

## 🌐 الخطة (ب): الطريقة الأكثر استقراراً عبر شبكة Tailscale (أقوى وأضمن)

1. ثبّت تطبيق **Tailscale** على هاتفك المحمول، وسجل دخول بحسابك (مجاني تماماً).
2. فعّل في إعدادات جهازك داخل Tailscale خيار **Exit Node** (أي جعل الهاتف مخرجاً للإنترنت).
3. في كود البوت أو بيئة السيرفر، يتم الاتصال بشبكة Tailscale ليمر كل الاتصال عبر هاتفك تلقائياً كأنه متصفح منزلي مصري.

---

## ⚙️ التوافق البرمجي في المشروع

الكود في المشروع جاهز بالفعل لهذه الخطة في [`core/config.py`](file:///home/omsa/Projects/solver-project/telegram-bot/core/config.py) و [`core/relay_session.py`](file:///home/omsa/Projects/solver-project/telegram-bot/core/relay_session.py):
- المتغير: `PROXY_URL`
- إذا تم تزويده، يستخدم `RelaySession` البروكسي فوراً ويمرر كل الطلبات عبره:
  ```python
  self.raw_session.proxies = {"http": proxy_url, "https": proxy_url}
  ```
- وإذا لم يتم تزويده، يستخدم `RELAY_URL` (Cloudflare Worker) كحل سحابي بديل.
