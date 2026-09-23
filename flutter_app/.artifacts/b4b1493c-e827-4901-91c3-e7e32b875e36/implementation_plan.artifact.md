# إضافة خيار اختيار المسجد في إدارة دروس الشيخ

تمكين المحفظ (الشيخ) من اختيار أو تغيير المسجد الذي تقام فيه الفعالية العامة، مع عرض اسم المسجد وعنوانه في القائمة المنسدلة لسهولة التحديد.

## التغييرات المقترحة

### 1. واجهات نوافذ الفعاليات (Discover Dialogs)

#### [MODIFY] [discover_event_dialog.dart](file:///C:/Users/moham/Desktop/masjed app/flutter_app/lib/screens/discover/dialogs/discover_event_dialog.dart)
- **في نافذة الإضافة (`showAddPublicEventModal`)**:
    - تحديث عناصر القائمة المنسدلة للمساجد لتعرض "اسم المسجد" و "العنوان" (أو المدينة في حال عدم توفر عنوان) بشكل واضح.
- **في نافذة التعديل (`showEditPublicEventModal`)**:
    - إضافة معامل `ActiveSession? session` للدالة.
    - إضافة قائمة منسدلة لاختيار المسجد (تظهر للشيخ) تسمح له بتغيير المسجد الذي يتبع له الدرس.
    - استخدام نفس تنسيق العرض (الاسم + العنوان) في القائمة.

---

### 2. واجهة إدارة الفعاليات (Discover Management Widgets)

#### [MODIFY] [discover_event_management_view.dart](file:///C:/Users/moham/Desktop/masjed app/flutter_app/lib/screens/discover/widgets/discover_event_management_view.dart)
- تمرير `session` الحالي عند استدعاء `DiscoverEventDialog.showEditPublicEventModal` لتمكين منطق اختيار المسجد داخل نافذة التعديل.

---

## خطة التحقق

### التحقق اليدوي
1. الدخول كشيخ والضغط على "إعلان درس عام".
2. التأكد من أن قائمة المساجد تعرض الاسم والعنوان لكل مسجد.
3. فتح "إدارة دروسي العامة" والضغط على تعديل لدرس موجود.
4. التأكد من ظهور قائمة اختيار المسجد والقدرة على تغيير المسجد وحفظ التعديلات بنجاح.
