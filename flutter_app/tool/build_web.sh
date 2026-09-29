#!/usr/bin/env bash
# يبني نسخة الويب (نسخة الآيفون) كما تُنشر على الموقع تحت /mihrab-app/app/
# الناتج: flutter_app/build/web
#
#   bash tool/build_web.sh                                  # بناء محلي للتجربة
#   MIHRAB_FALLBACK_FONTS=1 bash tool/build_web.sh          # بناء النشر (GitHub Actions)
set -euo pipefail
cd "$(dirname "$0")/.."

# --no-web-resources-cdn: محرّك الرسم (CanvasKit) يُخدم من موقعنا لا من gstatic،
# فلا يعلق فتح التطبيق على شبكة بطيئة أو محجوبة.
# MSYS_NO_PATHCONV: يمنع Git Bash على ويندوز من تحويل /mihrab-app/ إلى مسار ملف.
MSYS_NO_PATHCONV=1 flutter build web --release \
  --no-web-resources-cdn \
  --no-wasm-dry-run \
  --base-href /mihrab-app/app/ \
  "$@"

# المحرّك ينتظر خط Roboto من fonts.gstatic.com قبل أول إطار ما لم يكن مسجّلاً في
# FontManifest. الملف نفسه في web/assets/fonts/ (فيدخل في تخزين الـ service worker)،
# وهنا نسجّله للويب وحده دون أن يمسّ خطوط أندرويد وويندوز.
node -e '
const fs = require("fs");
const file = "build/web/assets/FontManifest.json";
const fonts = JSON.parse(fs.readFileSync(file, "utf8"));
if (!fonts.some(f => f.family === "Roboto")) {
  fonts.push({ family: "Roboto", fonts: [{ asset: "fonts/Roboto-Regular.ttf" }] });
  fs.writeFileSync(file, JSON.stringify(fonts));
}
'
test -f build/web/assets/fonts/Roboto-Regular.ttf

# الخطوط الاحتياطية (الإيموجي والرموز ونصوص نادرة) تُستضاف مع الموقع بدل fonts.gstatic.com.
# تُجلب عند الحاجة فقط، ولا تدخل في تخزين الـ service worker. تُستثنى الصينية واليابانية
# والكورية (مئات الملفات). إن فشل الجلب يبقى التطبيق على gstatic كما هو.
if [ "${MIHRAB_FALLBACK_FONTS:-}" = "1" ]; then
  node -e '
const js = require("fs").readFileSync("build/web/main.dart.js", "utf8");
const paths = new Set(js.match(/"[a-z0-9]+\/v\d+\/[A-Za-z0-9_.-]+\.(?:woff2|ttf)"/g).map(s => s.slice(1, -1)));
for (const p of paths) if (!/^notosans(kr|jp|hk|tc|sc)\//.test(p)) console.log(p);
' > build/fallback-fonts.txt
  total=$(wc -l < build/fallback-fonts.txt)
  xargs -P 16 -I{} sh -c 'mkdir -p "$(dirname "build/web/fonts/fallback/{}")" && curl -sfL --retry 3 -o "build/web/fonts/fallback/{}" "https://fonts.gstatic.com/s/{}"' \
    < build/fallback-fonts.txt || true
  got=$(find build/web/fonts/fallback -type f | wc -l)
  echo "Fallback fonts: $got / $total"
  if [ "$got" -ge "$total" ]; then
    sed -i "s|var mihrabFontBase = null;|var mihrabFontBase = 'fonts/fallback/';|" build/web/flutter_bootstrap.js
  else
    rm -rf build/web/fonts/fallback
    echo "::warning::Fallback fonts incomplete; the app keeps using fonts.gstatic.com"
  fi
fi

echo "✓ build/web جاهز"
