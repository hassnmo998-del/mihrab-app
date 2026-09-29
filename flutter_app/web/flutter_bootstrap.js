{{flutter_js}}
{{flutter_build_config}}

// tool/build_web.sh يضع هنا مسار الخطوط الاحتياطية (إيموجي ورموز) حين يستضيفها مع الموقع؛
// وإلا تبقى null فيجلبها المحرّك من fonts.gstatic.com.
var mihrabFontBase = null;

// يبدأ التطبيق فوراً، إلا حين تعرض index.html دليل الإضافة للشاشة الرئيسية في Safari
// (mihrabHoldBoot)؛ عندها يبدأ فقط إن اختار المستخدم «استخدمه من المتصفح الآن».
window.mihrabBoot = function () {
  if (window.mihrabBooted) return;
  window.mihrabBooted = true;
  _flutter.loader.load({
    config: mihrabFontBase ? { fontFallbackBaseUrl: mihrabFontBase } : {},
    serviceWorkerSettings: {
      serviceWorkerVersion: {{flutter_service_worker_version}},
    },
  });
};

if (!window.mihrabHoldBoot) window.mihrabBoot();
