# SPRIX Financial Literacy EN Solver (CLI)

محرك حل تلقائي ذاتي الاكتشاف لمادة **Financial Literacy الإنجليزية** على منصة **SPRIX** (subject 3 — الوحدات 1–6، 137 عنصر).

---

## 📋 المميزات
- **100% كل الوحدات**: الفصول بنجوم 5 (brute-force الخيارات) والاختبارات 100% (harvest من submit treasure).
- **ذاتي الاكتشاف بدون answers.json**: الفصول تجرب كل خيار لحد `is_correct:true` (الإعادة مجانية)، والاختبارات جولة تعلّم (تخمين + submit) تقرأ الصح من `options[].is_correct` ثم جولة تطبيق.
- **فصول المحاكاة** (بدون أسئلة): `complete` مباشر.
- **تحديد وحدات مرن**: دعم البدء من أي وحدة (1–6).

---

## 🚀 طريقة الاستخدام

### المتطلبات:
- `curl`
- `jq`
- `python3`

### التشغيل:
```bash
./solve.sh <LOGIN_ID> <PASSWORD> [START_UNIT]
```

### أمثلة:
- حل المنهج كاملاً (الوحدات 1 إلى 6):
  ```bash
  ./solve.sh 482438443 'pass'
  ```
- حل من الوحدة 3:
  ```bash
  ./solve.sh 482438443 'pass' 3
  ```

---

## 📐 البنية المكتشفة
- Subject `3` = **Financial Literacy** (lang=en) — الحساب عنده كمان subject `8` = Global Finance Quest (كورس تاني)
- الوحدات: 1–6 (137 عنصر: فصول + مراجعات + اختبارات)
- رد الاختبار الغلط ما يكشفش الصح (`correct_option_id: null`) → brute-force
- رد `submit` كنز: `options[qid][].is_correct:true` لكل الأسئلة
- اختبارات نهاية الوحدات (5/9/13/17) فيها 50 سؤال
