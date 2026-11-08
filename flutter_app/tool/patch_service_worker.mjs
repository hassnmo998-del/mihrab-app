// يصلح الـ service worker الذي يولّده Flutter كي يعمل التطبيق من التخزين تحت /mihrab-app/app/.
//
//   node tool/patch_service_worker.mjs [build/web/flutter_service_worker.js]
//
// لماذا: قالب Flutter يحسب مفتاح كل ملف من أصل الموقع (origin) لا من مجلد التطبيق، فيصير
// مفتاح main.dart.js على موقعنا «mihrab-app/app/main.dart.js» ولا يوجد في قائمة RESOURCES.
// النتيجة أن الـ worker يخزّن الملفات ولا يخدم منها شيئاً أبداً: كل فتحة على الآيفون تنزّل
// التطبيق كاملاً من جديد (نحو 6 ميغابايت)، فيبقى على شاشة البداية حين تكون الشبكة ضعيفة،
// ولا يفتح إطلاقاً بلا إنترنت.
//
// التعديلات:
//   1. المفتاح يُحسب من نطاق الـ worker (self.registration.scope) لا من أصل الموقع.
//   2. طلبات Range (تشغيل الفيديو) تُترك للمتصفح: Safari يحتاج ردّ 206 لا ملفاً كاملاً من التخزين.
//   3. صفحة البداية: الشبكة أولاً لكن بمهلة 3 ثوانٍ، ثم النسخة المخزّنة، فلا تعلق على شبكة بطيئة.
//      النسخة الجديدة تُخزَّن في الخلفية وتظهر في الفتحة التالية.
//
// إن تغيّر قالب Flutter ولم يعد نمط منها موجوداً يفشل البناء بدل أن يُنشر worker معطوب.
import fs from 'node:fs';

const file = process.argv[2] || 'build/web/flutter_service_worker.js';
let src = fs.readFileSync(file, 'utf8');

function replaceAll(pattern, replacement, expectedAtLeast = 1) {
  const count = src.split(pattern).length - 1;
  if (count < expectedAtLeast) {
    console.error(`patch_service_worker: expected ${expectedAtLeast}+ of ${JSON.stringify(pattern)}, found ${count}. Flutter's template changed; update this script.`);
    process.exit(1);
  }
  src = src.split(pattern).join(replacement);
}

if (src.includes('MIHRAB_SW_PATCHED')) {
  console.log('patch_service_worker: already patched');
  process.exit(0);
}

// 1. المفاتيح نسبةً إلى مجلد التطبيق (التفعيل، الجلب، التنزيل للعمل بلا إنترنت)
replaceAll('request.url.substring(origin.length + 1)', 'request.url.substring(self.registration.scope.length)', 3);

// 2. الفيديو وأي طلب جزئي: للمتصفح مباشرة
replaceAll("if (event.request.method !== 'GET') {", "if (event.request.method !== 'GET' || event.request.headers.has('range')) {", 1);

// 3. صفحة البداية بمهلة. تعريف دالة بالاسم نفسه في آخر الملف يحلّ محل تعريف القالب.
if (!/function onlineFirst\(event\)/.test(src)) {
  console.error('patch_service_worker: onlineFirst() not found in the template.');
  process.exit(1);
}
src += `
// MIHRAB_SW_PATCHED — انظر tool/patch_service_worker.mjs
function onlineFirst(event) {
  var network = fetch(event.request).then(function (response) {
    if (response && response.ok) {
      var copy = response.clone();
      caches.open(CACHE_NAME).then(function (cache) { return cache.put(event.request, copy); });
    }
    return response;
  });
  event.waitUntil(network.then(function () {}, function () {}));
  function cached() {
    return caches.open(CACHE_NAME).then(function (cache) {
      return cache.match(event.request).then(function (r) { return r || cache.match('index.html'); });
    });
  }
  return event.respondWith(new Promise(function (resolve, reject) {
    var done = false;
    function finish(r) { if (!done) { done = true; resolve(r); } }
    network.then(finish, function (error) {
      cached().then(function (r) { if (r) finish(r); else if (!done) { done = true; reject(error); } });
    });
    setTimeout(function () {
      if (done) return;
      cached().then(function (r) { if (r) finish(r); });
    }, 3000);
  }));
}
`;

fs.writeFileSync(file, src);
console.log('patch_service_worker: ok');
