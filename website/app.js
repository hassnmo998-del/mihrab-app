/**
 * محراب — الموقع الرسمي
 * زر تحميل واحد حسب جهاز الزائر، نوافذ الشرح (أندرويد / آيفون)، ورقم الإصدار وعدد التحميلات.
 */
(function () {
  'use strict';

  var ua = navigator.userAgent || '';
  var isIPad = /iPad/.test(ua) || (navigator.platform === 'MacIntel' && navigator.maxTouchPoints > 1);
  var isIOS = /iPhone|iPod/.test(ua) || isIPad;
  var isAndroid = /Android/i.test(ua);
  var isWindows = /Windows NT/i.test(ua) && !/Windows Phone/i.test(ua);
  var standalone = navigator.standalone === true ||
    (window.matchMedia && window.matchMedia('(display-mode: standalone)').matches);

  // أُضيف الموقع نفسه إلى الشاشة الرئيسية بدل التطبيق: نفتح التطبيق مباشرة
  if (standalone) {
    location.replace('app/');
    return;
  }

  // ─── زر واحد حسب الجهاز ───────────────────────────────────────────
  var box = document.getElementById('downloads-box');
  var device = isAndroid ? 'android' : isIOS ? 'ios' : isWindows ? 'windows' : 'other';
  box.setAttribute('data-device', device);
  var otherBtn = document.getElementById('other-devices');
  if (device !== 'other') {
    otherBtn.hidden = false;
    otherBtn.addEventListener('click', function () {
      box.classList.add('show-all');
      otherBtn.hidden = true;
    });
  }

  // ─── النوافذ ─────────────────────────────────────────────────────
  var lastFocus = null;

  function showStep(modal, n) {
    var steps = modal.querySelectorAll('.step');
    for (var i = 0; i < steps.length; i++) steps[i].hidden = steps[i].getAttribute('data-step') !== String(n);
    var video = modal.querySelector('video');
    if (video) {
      if (n === 1) { try { video.currentTime = 0; } catch (e) {} var p = video.play(); if (p && p.catch) p.catch(function () {}); }
      else video.pause();
    }
  }

  function openModal(id) {
    var modal = document.getElementById(id);
    lastFocus = document.activeElement;
    modal.hidden = false;
    document.body.style.overflow = 'hidden';
    showStep(modal, 1);
    var focusable = modal.querySelector('[data-next], .btn');
    if (focusable) focusable.focus({ preventScroll: true });
  }

  function closeModal(modal) {
    var video = modal.querySelector('video');
    if (video) video.pause();
    modal.hidden = true;
    document.body.style.overflow = '';
    if (lastFocus && lastFocus.focus) lastFocus.focus({ preventScroll: true });
  }

  var modals = document.querySelectorAll('.modal');
  for (var m = 0; m < modals.length; m++) {
    (function (modal) {
      modal.addEventListener('click', function (e) {
        var t = e.target;
        if (t === modal || t.closest('[data-close]')) closeModal(modal);
        else if (t.closest('[data-next]')) showStep(modal, 2);
        else if (t.closest('[data-back]')) showStep(modal, 1);
      });
    })(modals[m]);
  }
  document.addEventListener('keydown', function (e) {
    if (e.key !== 'Escape') return;
    for (var i = 0; i < modals.length; i++) if (!modals[i].hidden) closeModal(modals[i]);
  });

  document.getElementById('btn-android').addEventListener('click', function () { openModal('modal-android'); });
  document.getElementById('btn-ios').addEventListener('click', function () { openModal('modal-ios'); });

  // ─── خطوات الآيفون: حسب نسخة Safari وجهاز الزائر ──────────────────
  // متصفحات داخل التطبيقات (واتساب، تيليغرام…) وغير Safari لا تعطي «إضافة إلى الشاشة الرئيسية» بشكل موثوق
  var notSafari = isIOS && /CriOS|FxiOS|EdgiOS|OPiOS|GSA\/|FBAN|FBAV|Instagram|WhatsApp|Telegram|Line\/|Snapchat|MicroMessenger/.test(ua);
  var safariMajor = parseInt((ua.match(/Version\/(\d+)/) || [])[1] || '0', 10);
  var ICON = {
    more: '<svg viewBox="0 0 24 24" fill="currentColor"><circle cx="5" cy="12" r="2"/><circle cx="12" cy="12" r="2"/><circle cx="19" cy="12" r="2"/></svg>',
    share: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M12 15V3M8 7l4-4 4 4"/><path d="M6 11H5a1 1 0 0 0-1 1v8a1 1 0 0 0 1 1h14a1 1 0 0 0 1-1v-8a1 1 0 0 0-1-1h-1"/></svg>',
    add: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round"><rect x="3.5" y="3.5" width="17" height="17" rx="4"/><path d="M12 8v8M8 12h8"/></svg>',
    safari: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><circle cx="12" cy="12" r="9"/><path d="M15.5 8.5l-2 5-5 2 2-5z" fill="currentColor"/></svg>'
  };
  function step(n, key, title, hint) {
    return '<li><span class="n">' + n + '</span><span class="text">' + title +
      (hint ? '<small>' + hint + '</small>' : '') + '</span><span class="key">' + key + '</span></li>';
  }
  var where = isIPad ? 'أعلى الشاشة' : 'أسفل الشاشة';
  var iosSteps;
  if (notSafari) {
    iosSteps = step(1, ICON.safari, 'افتح هذا الموقع في Safari', 'انسخ الرابط بالزر تحت، ثم الصقه في Safari') +
               step(2, ICON.add, 'ثم اضغط «تثبيت على الآيفون»');
    document.getElementById('ios-next').hidden = true;
    var copyBtn = document.getElementById('ios-copy');
    copyBtn.hidden = false;
    copyBtn.addEventListener('click', function () {
      var url = 'https://hassnmo998-del.github.io/mihrab-app/';
      var done = function () { copyBtn.textContent = 'تم النسخ ✓'; };
      if (navigator.clipboard) navigator.clipboard.writeText(url).then(done, function () { prompt('', url); });
      else prompt('', url);
    });
  } else if (safariMajor >= 26 || !isIOS) {
    // iOS 26 وما بعد: زر المشاركة داخل زر ••• بجانب شريط العنوان
    iosSteps = step(1, ICON.more, 'اضغط •••', where + '، بجانب شريط العنوان') +
               step(2, ICON.share, 'اضغط «مشاركة»') +
               step(3, ICON.add, 'اختر «إضافة إلى الشاشة الرئيسية»', 'إن لم تظهر، اسحب القائمة للأعلى') +
               step(4, 'إضافة', 'اضغط «إضافة»');
  } else {
    iosSteps = step(1, ICON.share, 'اضغط زر المشاركة', where) +
               step(2, ICON.add, 'اختر «إضافة إلى الشاشة الرئيسية»', 'إن لم تظهر، اسحب القائمة للأعلى') +
               step(3, 'إضافة', 'اضغط «إضافة»');
  }
  document.getElementById('ios-steps').innerHTML = iosSteps;

  // ─── الإصدار وعدد التحميلات ──────────────────────────────────────
  // site-data.json يكتبه النشر (رقم صحيح فوراً)؛ ثم GitHub API يحدّث العدد إن أمكن.
  var shown = { version: null, downloads: null };
  var pill = document.getElementById('meta-pill');

  function parts(tag) {
    return String(tag).replace(/^v/i, '').split(/[+-]/)[0].split('.').map(function (n) { return parseInt(n, 10) || 0; });
  }
  function newer(a, b) {
    var x = parts(a), y = parts(b);
    for (var i = 0; i < Math.max(x.length, y.length); i++) {
      if ((x[i] || 0) !== (y[i] || 0)) return (x[i] || 0) > (y[i] || 0);
    }
    return false;
  }
  function render(version, downloads) {
    if (version && (!shown.version || newer(version, shown.version))) {
      shown.version = /^v/i.test(version) ? version : 'v' + version;
      document.getElementById('version').textContent = 'الإصدار ' + shown.version;
      document.getElementById('btn-windows').setAttribute('download', 'mihrab-windows-' + shown.version + '.exe');
      document.getElementById('apk-link').setAttribute('download', 'mihrab-android-' + shown.version + '.apk');
    }
    if (typeof downloads === 'number' && (shown.downloads === null || downloads > shown.downloads)) {
      shown.downloads = downloads;
      var text;
      try { text = downloads.toLocaleString('ar'); } catch (e) { text = String(downloads); }
      document.getElementById('downloads').textContent = text;
    }
    if (shown.version && shown.downloads !== null) pill.hidden = false;
  }

  function fromReleases(releases) {
    var version = null, downloads = 0;
    for (var i = 0; i < releases.length; i++) {
      var r = releases[i];
      if (!r.draft && !r.prerelease && (!version || newer(r.tag_name, version))) version = r.tag_name;
      var assets = r.assets || [];
      for (var j = 0; j < assets.length; j++) {
        if (/\.(apk|exe)$/i.test(assets[j].name)) downloads += assets[j].download_count || 0;
      }
    }
    render(version, downloads);
  }

  fetch('site-data.json', { cache: 'no-store' })
    .then(function (r) { return r.ok ? r.json() : null; })
    .then(function (d) { if (d) render(d.version, d.downloads); })
    .catch(function () {});

  var CACHE_KEY = 'mihrab_releases_v11';
  var cached = null;
  try { cached = JSON.parse(sessionStorage.getItem(CACHE_KEY) || 'null'); } catch (e) {}
  if (cached && Date.now() - cached.at < 10 * 60 * 1000) {
    fromReleases(cached.data);
  } else {
    fetch('https://api.github.com/repos/hassnmo998-del/mihrab-app/releases?per_page=100', {
      headers: { Accept: 'application/vnd.github+json' }
    })
      .then(function (r) { return r.ok ? r.json() : null; })
      .then(function (data) {
        if (!Array.isArray(data)) return;
        try { sessionStorage.setItem(CACHE_KEY, JSON.stringify({ at: Date.now(), data: data })); } catch (e) {}
        fromReleases(data);
      })
      .catch(function () {});
  }
})();
