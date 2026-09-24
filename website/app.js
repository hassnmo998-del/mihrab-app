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

  // Always maintain an active, valid download URL
  if (asset && asset.browser_download_url) {
    btn.href = asset.browser_download_url;
  } else if (!btn.href || btn.href.endsWith('#')) {
    btn.href = DIRECT_URLS[platformKey];
  }

  btn.removeAttribute('disabled');
  btn.removeAttribute('aria-disabled');

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
  fetchRelease();
});
