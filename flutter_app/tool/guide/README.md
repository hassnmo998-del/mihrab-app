# تصوير شاشات التطبيق الحقيقية لفيديو دليل الإدارة

يشغّل التطبيق الحقيقي (`MainShell` بثيمه وخطوطه وتنقّله) داخل اختبار Flutter ببيانات «مسجد تجريبي»، ويحفظ كل شاشة
كصورة PNG بدقة 3x مع مستطيلات عناصرها كما هي في شجرة الواجهة. لا شيء يُرسم يدوياً: الفيديو يوجّه العدسة إلى العنصر
الحقيقي. التركيب (Remotion) خارج المستودع في `C:\clurlelo\output\mihrab_guide\studio`.

```bash
cd flutter_app
python tool/guide/make_blank_font.py "C:/clurlelo/output/mihrab_guide/cache" assets/fonts/Amiri-Regular.ttf assets/fonts/Cairo-Regular.ttf assets/fonts/Tajawal-Regular.ttf assets/fonts/NotoNaskhArabic-SemiBold.ttf
GUIDE_OUT='C:\clurlelo\output\mihrab_guide\shots' flutter test tool/guide/capture_test.dart
GUIDE_ONLY=admin,sheikh flutter test tool/guide/capture_test.dart   # أجزاء: portal superadmin admin women sheikh student cashier
```

- `demo_story.dart`: القصة التجريبية تُكتب بدوال `DataService` نفسها (مسجدان، ثلاثة مشايخ، حلقات، طلاب، حضور، تسميع، جوائز…).
- `harness.dart`: الخطوط الحقيقية، `GuideApp` (نسخة حرفية من `MasjedApp`)، التقاط الصور، ومسح الأهداف (أزرار، تلميحات، حقول، نصوص، إيموجي).
- `capture_test.dart`: السيناريو رتبةً رتبة بالنقر على عناصر التطبيق الفعلية. `explore_test.dart` يطبع نصوص نافذة ما قبل كتابة خطوة.

## ما يجب أن يبقى صحيحاً

- **لا بيانات تخرج من الجهاز**: `GuideNetworkPolicy` يرفض كل مضيف غير خوادم خطوط Google (يجلب التطبيق الحقيقي الخطوط
  الثقيلة منها)، فلا يصل شيء إلى Supabase. لا تستعمل `HttpOverrides` آخر.
- **الإيموجي**: اختبار Flutter لا يرسم الإيموجي الملوّن (Segoe UI Emoji من نوع COLRv1). خط `BlankEmoji` يترك مكانه فارغاً،
  و`scanEmoji` يسجّل نصه ومستطيله لترسمه الطبقة المركِّبة ملوّناً فوقه.
- أكواد المشايخ والطلاب تُشتق من الميلي ثانية، فالقصة تفصل بين الإنشاءات (`_tick`) كي لا يتكرر كود.
- نوافذ التطبيق تعيد البناء بسياق خارجي في وضع الـ debug عند الكتابة بـ `enterText`؛ لذلك يكتب `typeInto` في الـ controller مباشرة.

## من اللقطات إلى فيديوهات التطبيق

التركيب في `C:\clurlelo\output\mihrab_guide\studio`: `build_timeline.py` يبني `src/timeline.json` من `storyboard.py` والصوت الجاهز،
و`COMP=GuideV node render.mjs video` يصيّر النسخة العمودية 1080×1920 (الكاميرا تكبّر على العنصر الحقيقي ليُقرأ على الهاتف).
يُقصّ الناتج حسب الرتبة بـ ffmpeg إلى `assets/videos/guide_*.mp4` (720×1280، بصوت الشرح) مع غلاف `posters/<id>.jpg`؛
وفيديوهات «تعرّف على محراب» `intro_*` مقصوصة من إعلان كريلو العمودي: صوت الشرح وحده (يُبنى من مقاطع الصوت نفسها بـ`layNarration` بلا الموسيقى، لا باستخراج صوت الإعلان المخلوط) بلا مقدمة ولا خاتمة تسويقية، وحدودها عند بدايات المشاهد.
بعد أي تغيير في الفهرس حدّث `lib/data/help_videos_data.dart` (المدد والأوصاف)، و`test/help_videos_data_test.dart` يحرس الملفات والحجم.
`help_ui_capture_test.dart` يصوّر شاشات «تعلّم الاستخدام» نفسها للتحقق البصري.
