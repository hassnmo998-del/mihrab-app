# 🤖 دليل الوكلاء والمطورين — مشروع محراب (Mihrab App)

هذا الملف مخصص لأي وكيل ذكاء اصطناعي (AI Agent) أو مطوّر يعمل على هذا المشروع. يشرح بنية المشروع وآلية إطلاق الإصدارات الجديدة المؤتمتة بالكامل.

---

## 📌 نبذة عن المشروع (Project Overview)
- **محراب (Mihrab):** تطبيق فلاتر (Flutter) لإدارة حلقات تحفيظ القرآن الكريم في المساجد.
- **المنصات المدعومة:** Android و Windows (مع دعم مستقبلي لـ Web/iOS).
- **المستودع الرسمي:** `hassnmo998-del/mihrab-app`
- **موقع الويب الرسمي:** `https://hassnmo998-del.github.io/mihrab-app/`
- **قاعدة البيانات السحابية:** Supabase (مع تخزين محلي يعمل بدون إنترنت 100%).

---

## 🏗️ هيكل المجلدات (Directory Structure)
```
├── flutter_app/          # تطبيق Flutter الرئيسي
│   ├── lib/              # شيفرة Dart
│   │   ├── services/
│   │   │   ├── app_update_service.dart  # نظام التحديث التلقائي الذكي
│   │   │   └── update_config.dart       # ثوابت المستودع (Owner/Repo)
│   │   └── ...
│   └── pubspec.yaml      # تعريف الحزم ورقم الإصدار (version: X.Y.Z+B)
├── website/              # موقع الويب التعريفي وصفحة التحميل المباشر
│   ├── index.html        # واجهة الموقع بالزخرفة الدمشقية الإسلامية
│   ├── style.css         # تصميم الموقع والألوان الدمشقية
│   └── app.js            # سحب إحصائيات التحميل الحية من GitHub API
├── .github/workflows/
│   ├── release.yml       # بناء ونشر إصدارات Windows (.exe) و Android (.apk)
│   └── pages.yml         # نشر الموقع وتوفير التحميل المباشر عبر Fastly CDN
└── installer/
    └── mihrab.iss        # إعدادات مثبت Inno Setup لنظام Windows
```

---

## 🚀 كيف تُطلق إصداراً جديداً بالكامل؟ (Step-by-Step Release Flow)

عندما يطلب منك المستخدم تعديلاً في التطبيق ثم إطلاق نسخة جديدة (Release)، اتبع الخطوات التالية بدقة:

### 1. تطبيق التعديلات واختبارها
قم بإجراء التعديلات المطلوبة داخل `flutter_app/`.

### 2. ترقية رقم الإصدار (Version Bump)
افتح [`flutter_app/pubspec.yaml`](flutter_app/pubspec.yaml) وحدّث سطر `version`:
```yaml
version: 1.0.1+2   # الصيغة: X.Y.Z+BuildNumber
```
> **ملاحظة مهمة:** لا حاجة لتعديل أي رقم إصدار في كود Dart؛ فنظام `AppUpdateService` يقرأ الإصدار تلقائياً من `PackageInfo.fromPlatform()`.

### 3. حفظ التغييرات والرفع إلى Git
```bash
git add .
git commit -m "feat: <وصف التعديلات باختصار>"
git push origin main
```

### 4. إطلاق وسم الإصدار (Push Git Tag)
أنشئ وسماً يطابق رقم الإصدار مسبوقاً بحرف `v`، وادفعه إلى GitHub:
```bash
git tag v1.0.1
git push origin v1.0.1
```

---

## ⚡ ماذا يحدث تلقائياً بعد رفع الـ Tag؟ (Automated CI/CD)

بمجرد رفع الـ Tag، يتولى GitHub كل شيء في السحابة دون أي تدخل:

1. **سيرفر GitHub Actions الأول (`release.yml`):**
   - يعمل على خوادم Windows و Ubuntu سحابية.
   - يبني مثبّت Windows الرسمي الموقّع `mihrab-windows-v1.0.1.exe`.
   - يبني حزمة الأندرويد الموقّعة بمفتاح الـ Release الرسمي `mihrab-android-v1.0.1.apk`.
   - ينشئ Release رسمي على GitHub ويُرفق به الملفين مع ملاحظات التغييرات.

2. **سيرفر GitHub Actions الثاني (`pages.yml`):**
   - يستشعر نشر الـ Release تلقائياً (`release: types: [published]`).
   - يسحب ملفات الـ APK والـ EXE الجديدة من الـ Release فوراً.
   - يضعها داخل مجلد `website/downloads/` على الموقع.
   - ينشر الموقع المحدّث على شبكة **Fastly CDN العالمية** (`https://hassnmo998-del.github.io/mihrab-app/`).
   - بذلك يحصل أي زائر في العالم (بما في ذلك سوريا والدول الخاضعة للقيود) على تحميل مباشر سريع جداً وخالٍ من الحجب والتحويلات المعقدة.

3. **تحديث التطبيق لدى المستخدمين الحاليين (In-App Auto Update):**
   - التطبيق يتضمن خدمة `AppUpdateService` التي تفحص `api.github.com/repos/hassnmo998-del/mihrab-app/releases/latest`.
   - فور فتح التطبيق، يكتشف وجود الإصدار الجديد ويعرض نافذة التحديث للمستخدم ليقوم بالتحديث بنقرة زر واحدة.

---

## ⚠️ قواعد ومحاذير مهمة (Strict Guidelines)
1. **لا تضع روابط خارجية محجوبة:** روابط التحميل في الموقع يجب أن تظل نسبية `downloads/mihrab-android.apk` و `downloads/mihrab-windows.exe` لتُخدم عبر Fastly CDN لموقع GitHub Pages بدون تحويل لـ Azure Blob Storage.
2. **معرف Inno Setup ثابت:** لا تُغيّر قيمة `AppId` (`{{55F5CBCD-A28A-45AE-84FD-F2C59E314981}}`) في `installer/mihrab.iss` حتى يتمكن ويندوز من تحديث النسخة السابقة بسلاسة بدل تثبيت نسختين بجانب بعضهما.
3. **أسرار التوقيع محفوظة في GitHub Secrets:** مفاتيح توقيع الأندرويد (`KEY_ALIAS`, `KEY_PASSWORD`, `STORE_PASSWORD`, إلخ) مخزنة في GitHub Secrets ومحمية في `.gitignore`.
