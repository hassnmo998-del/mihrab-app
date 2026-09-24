/**
 * محراب — منصة إدارة حلقات التحفيظ الذكية
 * app.js — GitHub Release Fetcher & Live Download Stats
 */

// ─── Configuration ───────────────────────────────────────────────────────────
const GITHUB_OWNER = 'hassnmo998-del';
const GITHUB_REPO  = 'mihrab-app';
const GITHUB_API   = `https://api.github.com/repos/${GITHUB_OWNER}/${GITHUB_REPO}/releases/latest`;
const SESSION_KEY  = 'mihrab_release_cache_v4';

// Direct permanent download URLs (Always work immediately, zero dependencies)
const DIRECT_URLS = {
  windows: 'https://github.com/hassnmo998-del/mihrab-app/releases/download/v1.0.0/mihrab-windows-v1.0.0.exe',
  android: 'https://github.com/hassnmo998-del/mihrab-app/releases/download/v1.0.0/mihrab-android-v1.0.0.apk',
};

// ─── Number formatting ────────────────────────────────────────────────────────
function formatNumberArabic(num) {
  try {
    return Number(num).toLocaleString('ar-SA');
  } catch {
    return String(num);
  }
}

// ─── Asset matching ───────────────────────────────────────────────────────────
function findAsset(assets, platform) {
  if (!Array.isArray(assets)) return null;
  const keywords = {
    windows: ['.exe', 'windows', 'win'],
    android: ['.apk', 'android'],
  };
  const keys = keywords[platform] || [];
  return assets.find(a => keys.some(k => a.name.toLowerCase().includes(k))) || null;
}

// ─── DOM updates ──────────────────────────────────────────────────────────────
function setVersion(tag) {
  const el = document.getElementById('version-text');
  if (el) el.textContent = tag || 'v1.0.0';
}

function updateDownloadLink(btnId, asset, platformKey) {
  const btn = document.getElementById(btnId);
  if (!btn) return;

  const url = (asset && asset.browser_download_url) ? asset.browser_download_url : DIRECT_URLS[platformKey];

  // Always maintain an active, valid download URL
  btn.href = url;
  btn.removeAttribute('disabled');
  btn.removeAttribute('aria-disabled');

  // Also update direct links in fallback boxes & modal
  if (platformKey === 'android') {
    const modalDirectBtn = document.getElementById('modal-direct-download-btn');
    const fallbackLink = document.getElementById('direct-link-apk');
    if (modalDirectBtn) modalDirectBtn.href = url;
    if (fallbackLink) fallbackLink.href = url;
  }

  // Show live download count if available
  if (asset && asset.download_count > 0) {
    const countEl = btn.querySelector('.btn-download-count');
    if (countEl) {
      countEl.textContent = `(${formatNumberArabic(asset.download_count)} تحميل)`;
      countEl.style.display = 'inline-block';
    }
  }
}

function setLiveDownloadCounts(totalDownloads) {
  const heroDownloads = document.getElementById('hero-total-downloads');
  const statDownloads = document.getElementById('stat-downloads');

  const formatted = formatNumberArabic(totalDownloads);
  if (heroDownloads) heroDownloads.textContent = formatted;
  if (statDownloads) statDownloads.textContent = formatted;
}

// ─── In-App Browser Detector (WhatsApp, Telegram, Facebook, etc.) ─────────────
function checkInAppBrowser() {
  const ua = navigator.userAgent || navigator.vendor || window.opera || '';
  const isInApp = /FBAN|FBAV|Instagram|WhatsApp|Telegram|Line|Twitter|Snapchat|Messenger/i.test(ua);
  const alertEl = document.getElementById('inapp-browser-alert');
  if (alertEl && isInApp) {
    alertEl.style.display = 'block';
  }
}

// ─── Android Download Modal & Smart Trigger ──────────────────────────────────
function setupAndroidModal() {
  const btnAndroid = document.getElementById('btn-android');
  const modal = document.getElementById('android-modal');
  const modalClose = document.getElementById('modal-close-btn');
  const copyBtn = document.getElementById('copy-link-btn');
  const copyToast = document.getElementById('copy-toast');
  const modalDirectBtn = document.getElementById('modal-direct-download-btn');

  if (!btnAndroid || !modal) return;

  function openModal() {
    modal.style.display = 'flex';
    modal.setAttribute('aria-hidden', 'false');
    document.body.style.overflow = 'hidden';

    // Reset status indicators
    const statusTitle = document.getElementById('status-title');
    const statusDesc = document.getElementById('status-desc');
    if (statusTitle) statusTitle.textContent = 'يتم الآن بدء التحميل...';
    if (statusDesc) statusDesc.textContent = 'تأكد من شريط إشعارات هاتفك في الأعلى ⬇️ خلال لحظات';

    // Trigger download in background without freezing browser navigation bar
    const downloadUrl = (modalDirectBtn && modalDirectBtn.href) || DIRECT_URLS.android;
    triggerBackgroundDownload(downloadUrl);

    // After 3 seconds, update status to guide user if browser was slow
    setTimeout(() => {
      if (statusTitle) statusTitle.textContent = 'إذا لم يبدأ التنزيل تلقائياً:';
      if (statusDesc) statusDesc.textContent = 'اضغط مطوّلاً على الزر الأخضر بالأسفل واختر (تنزيل الرابط / Download link)';
    }, 3200);
  }

  function closeModal() {
    modal.style.display = 'none';
    modal.setAttribute('aria-hidden', 'true');
    document.body.style.overflow = '';
  }

  // Intercept Android button click
  btnAndroid.addEventListener('click', (e) => {
    e.preventDefault();
    openModal();
  });

  if (modalClose) {
    modalClose.addEventListener('click', closeModal);
  }

  // Close on clicking backdrop outside the card
  modal.addEventListener('click', (e) => {
    if (e.target === modal) {
      closeModal();
    }
  });

  // Close on Escape key
  document.addEventListener('keydown', (e) => {
    if (e.key === 'Escape' && modal.style.display === 'flex') {
      closeModal();
    }
  });

  // Copy link functionality
  if (copyBtn) {
    copyBtn.addEventListener('click', () => {
      const url = (modalDirectBtn && modalDirectBtn.href) || DIRECT_URLS.android;
      if (navigator.clipboard && navigator.clipboard.writeText) {
        navigator.clipboard.writeText(url).then(() => showCopyToast()).catch(() => fallbackCopy(url));
      } else {
        fallbackCopy(url);
      }
    });
  }

  function fallbackCopy(text) {
    const tempInput = document.createElement('input');
    tempInput.value = text;
    document.body.appendChild(tempInput);
    tempInput.select();
    try {
      document.execCommand('copy');
      showCopyToast();
    } catch {
      alert('الرابط: ' + text);
    }
    document.body.removeChild(tempInput);
  }

  function showCopyToast() {
    if (!copyToast) return;
    copyToast.style.display = 'block';
    setTimeout(() => {
      copyToast.style.display = 'none';
    }, 3500);
  }
}

// Triggers download without causing main document navigation freeze
function triggerBackgroundDownload(url) {
  // Method 1: Invisible iframe (fastest, prevents top navigation bar from freezing)
  let iframe = document.getElementById('hidden-download-frame');
  if (!iframe) {
    iframe = document.createElement('iframe');
    iframe.id = 'hidden-download-frame';
    iframe.style.display = 'none';
    iframe.style.width = '0';
    iframe.style.height = '0';
    iframe.style.border = 'none';
    document.body.appendChild(iframe);
  }
  iframe.src = url;

  // Fallback anchor click after short delay if iframe didn't invoke
  setTimeout(() => {
    const a = document.createElement('a');
    a.href = url;
    a.target = '_blank';
    a.rel = 'noopener noreferrer';
    document.body.appendChild(a);
    a.click();
    setTimeout(() => {
      try { document.body.removeChild(a); } catch {}
    }, 500);
  }, 1000);
}

// ─── Fetch Release ────────────────────────────────────────────────────────────
async function fetchRelease() {
  // Ensure default direct links are active immediately
  updateDownloadLink('btn-windows', null, 'windows');
  updateDownloadLink('btn-android', null, 'android');

  // Try cache first
  try {
    const cached = sessionStorage.getItem(SESSION_KEY);
    if (cached) {
      const data = JSON.parse(cached);
      applyReleaseData(data);
      return;
    }
  } catch { /* ignore cache errors */ }

  try {
    const response = await fetch(GITHUB_API, {
      headers: { Accept: 'application/vnd.github.v3+json' },
    });

    if (!response.ok) {
      throw new Error(`GitHub API HTTP ${response.status}`);
    }

    const data = await response.json();

    // Cache in session
    try { sessionStorage.setItem(SESSION_KEY, JSON.stringify(data)); } catch { /* quota */ }

    applyReleaseData(data);
  } catch (err) {
    // Keep direct links untouched and working smoothly
    console.info('[محراب] تم تفعيل الروابط المباشرة الدائمة:', err.message);
  }
}

function applyReleaseData(data) {
  if (data.tag_name) {
    setVersion(data.tag_name);
  }

  const assets = data.assets || [];
  const winAsset     = findAsset(assets, 'windows');
  const androidAsset = findAsset(assets, 'android');

  updateDownloadLink('btn-windows', winAsset, 'windows');
  updateDownloadLink('btn-android', androidAsset, 'android');

  // Calculate total download count across all platforms
  let totalDownloads = 0;
  assets.forEach(asset => {
    totalDownloads += (asset.download_count || 0);
  });

  setLiveDownloadCounts(totalDownloads);
}

// ─── Init ─────────────────────────────────────────────────────────────────────
document.addEventListener('DOMContentLoaded', () => {
  checkInAppBrowser();
  setupAndroidModal();
  fetchRelease();
});
