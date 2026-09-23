# 📦 دليل رفع إصدار جديد — تطبيق محراب

## الخطوة صفر — الإعداد الأول (مرة واحدة فقط)

### 1. إعداد GitHub Repository
```bash
# تأكد أنك في مجلد المشروع
cd "c:\Users\moham\Desktop\masjed app"

# إنشاء مستودع جديد (أو استخدم مستودعاً موجوداً)
git init
git remote add origin https://github.com/OWNER/REPO.git
```

### 2. إعداد موقع GitHub Pages
1. افتح مستودعك على GitHub
2. اذهب إلى **Settings → Pages**
3. تحت Source اختر: **GitHub Actions**
4. أو: اختر Branch `main` ومجلد `/website`

### 3. تحديث الإعدادات في الكود
في ملف [`flutter_app/lib/services/update_config.dart`](file:///c:/Users/moham/Desktop/masjed%20app/flutter_app/lib/services/update_config.dart):
```dart
const String kGithubRepoOwner = 'اسم_المستخدم';  // ← غيّر هذا
const String kGithubRepoName  = 'اسم_المستودع';  // ← وهذا
```

في ملف [`website/app.js`](file:///c:/Users/moham/Desktop/masjed%20app/website/app.js):
```javascript
const GITHUB_OWNER = 'اسم_المستخدم';  // ← غيّر هذا
const GITHUB_REPO  = 'اسم_المستودع'; // ← وهذا
```

---

## رفع إصدار جديد (كل مرة)

### الخطوة 1 — تحديث رقم الإصدار
في [`flutter_app/pubspec.yaml`](file:///c:/Users/moham/Desktop/masjed%20app/flutter_app/pubspec.yaml):
```yaml
version: 1.1.0+2   # ← رقم الإصدار + رقم البناء
#        ↑↑↑↑↑ هذا يظهر في التطبيق
#              ↑ هذا يزيد مع كل بناء
```

في [`flutter_app/lib/services/app_update_service.dart`](file:///c:/Users/moham/Desktop/masjed%20app/flutter_app/lib/services/app_update_service.dart):
```dart
const _currentVersion = '1.1.0';  // ← حدّث هنا أيضاً
```

### الخطوة 2 — Commit وTag
```bash
git add .
git commit -m "feat: release v1.1.0 — وصف التغييرات"

# إنشاء tag الإصدار (هذا يشغّل GitHub Actions تلقائياً)
git tag v1.1.0
git push origin main --tags
```

### الخطوة 3 — انتظر GitHub Actions
- اذهب إلى **Actions** في مستودعك
- ستجد workflow اسمه **"Build & Release Mihrab App"**
- انتظر ~10-15 دقيقة
- بعد الانتهاء، ستجد Release جديد تلقائياً في **Releases**

### الخطوة 4 — تحرير Release Notes (اختياري)
1. اذهب إلى **Releases** في مستودعك
2. اضغط ✏️ Edit على الإصدار الجديد
3. أضف وصف التغييرات بالعربي

---

## هيكل ملفات الـ Release

```
v1.1.0 Release
├── mihrab-windows-v1.1.0.exe    ← مثبّت Windows
└── mihrab-android-v1.1.0.apk   ← ملف Android
```

يقرأ الموقع والتطبيق هذه الملفات تلقائياً عبر GitHub API.

---

## التحقق من التحديث التلقائي

بعد رفع إصدار جديد، يمكنك اختباره:
1. ثبّت الإصدار القديم على جهاز
2. شغّل التطبيق
3. يجب أن يظهر حوار التحديث خلال ثوانٍ

---

## روابط مفيدة

| الرابط | الوصف |
|--------|-------|
| `https://github.com/hassnmo998-del/mihrab-app/releases` | صفحة الإصدارات |
| `https://hassnmo998-del.github.io/mihrab-app` | موقع التحميل |
| `https://api.github.com/repos/hassnmo998-del/mihrab-app/releases/latest` | API الإصدار الأخير |

---

## استكشاف الأخطاء

### ❌ GitHub Actions فشل في البناء
- تحقق من Flutter version في `release.yml` يطابق إصدارك
- تحقق من أن `pubspec.yaml` لا يحتوي أخطاء

### ❌ حوار التحديث لا يظهر
- تأكد أن `kGithubRepoOwner` و `kGithubRepoName` صحيحان
- تأكد أن `_currentVersion` في `app_update_service.dart` أقل من إصدار GitHub

### ❌ APK لا يُثبَّت على Android
- تأكد المستخدم فعّل "السماح من هذا المصدر" في إعدادات Android
- تأكد صلاحية `REQUEST_INSTALL_PACKAGES` موجودة في AndroidManifest.xml
