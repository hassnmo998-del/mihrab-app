/**
 * محراب — منصة إدارة حلقات التحفيظ الذكية
 * app.js — GitHub Release Fetcher & Live Download Stats
 */

// ─── Configuration ───────────────────────────────────────────────────────────
const GITHUB_OWNER = 'hassnmo998-del';
const GITHUB_REPO  = 'mihrab-app';
const GITHUB_API   = `https://api.github.com/repos/${GITHUB_OWNER}/${GITHUB_REPO}/releases/latest`;
const SESSION_KEY  = 'mihrab_release_cache_v2';

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

function setDownloadLink(btnId, asset, platformLabel) {
  const btn = document.getElementById(btnId);
  if (!btn) return;
  if (asset) {
    btn.href = asset.browser_download_url;
    btn.removeAttribute('disabled');
    btn.removeAttribute('aria-disabled');

    // Add download count subtext if available
    const count = asset.download_count || 0;
    const platformSpan = btn.querySelector('.btn-platform');
    if (platformSpan && count > 0) {
      platformSpan.textContent = `${platformLabel} (${formatNumberArabic(count)})`;
    }
  } else {
    btn.href = '#';
    btn.setAttribute('aria-disabled', 'true');
  }
}

function setLiveDownloadCounts(totalDownloads) {
  const heroDownloads = document.getElementById('hero-total-downloads');
  const statDownloads = document.getElementById('stat-downloads');

  const formatted = formatNumberArabic(totalDownloads);
  if (heroDownloads) heroDownloads.textContent = formatted;
  if (statDownloads) statDownloads.textContent = formatted;
}

function showFallback() {
  const el = document.getElementById('fallback-links');
  if (el) el.style.display = 'block';
}

// ─── Download tracking ────────────────────────────────────────────────────────
function attachDownloadTracking() {
  document.querySelectorAll('.btn[data-platform]').forEach(btn => {
    btn.addEventListener('click', function(e) {
      const platform = this.dataset.platform;
      const href = this.href;
      if (!href || href === '#' || href.endsWith('#')) {
        e.preventDefault();
        console.warn(`[محراب] زر تحميل ${platform} غير مرتبط بملف بعد.`);
        return;
      }
      console.log(`[محراب] 📥 بدء تحميل ${platform}:`, href);
    });
  });
}

// ─── Fetch Release ────────────────────────────────────────────────────────────
async function fetchRelease() {
  // Check session cache first
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
      throw new Error(`GitHub API error: ${response.status}`);
    }

    const data = await response.json();

    // Cache
    try { sessionStorage.setItem(SESSION_KEY, JSON.stringify(data)); } catch { /* quota */ }

    applyReleaseData(data);
  } catch (err) {
    console.error('[محراب] فشل جلب بيانات الإصدار والتحميلات:', err.message);
    showFallback();
  }
}

function applyReleaseData(data) {
  // Tag
  setVersion(data.tag_name);

  const assets = data.assets || [];
  const winAsset     = findAsset(assets, 'windows');
  const androidAsset = findAsset(assets, 'android');

  // Set download URLs & platform-specific counts
  setDownloadLink('btn-windows', winAsset, 'Windows');
  setDownloadLink('btn-android', androidAsset, 'Android');

  // Calculate live total download count directly from GitHub Release
  let totalDownloads = 0;
  assets.forEach(asset => {
    totalDownloads += (asset.download_count || 0);
  });

  setLiveDownloadCounts(totalDownloads);

  if (!winAsset || !androidAsset) {
    showFallback();
  }
}

// ─── Init ─────────────────────────────────────────────────────────────────────
document.addEventListener('DOMContentLoaded', () => {
  fetchRelease();
  attachDownloadTracking();
});
