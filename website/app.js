/**
 * محراب — منصة إدارة حلقات التحفيظ الذكية
 * app.js — GitHub Release Fetcher & Live Download Stats
 */

// ─── Configuration ───────────────────────────────────────────────────────────
const GITHUB_OWNER = 'hassnmo998-del';
const GITHUB_REPO  = 'mihrab-app';
const GITHUB_RELEASES_API = `https://api.github.com/repos/${GITHUB_OWNER}/${GITHUB_REPO}/releases`;
const CACHE_KEY = 'mihrab_releases_cache_v8';
const CACHE_TTL_MS = 5 * 60 * 1000; // 5 minutes cache

// Fastly CDN direct files hosted on the same domain
const DIRECT_URLS = {
  windows: 'downloads/mihrab-windows.exe',
  android: 'downloads/mihrab-android.apk',
};

// ─── Version Parsing & Comparison ─────────────────────────────────────────────
function parseVersion(tag) {
  if (!tag) return [0, 0, 0];
  const clean = String(tag).replace(/^v/i, '').split('+')[0].trim();
  const parts = clean.split('.').map(p => parseInt(p, 10) || 0);
  while (parts.length < 3) parts.push(0);
  return parts;
}

function compareVersions(v1, v2) {
  const p1 = parseVersion(v1);
  const p2 = parseVersion(v2);
  for (let i = 0; i < 3; i++) {
    if (p1[i] > p2[i]) return 1;
    if (p1[i] < p2[i]) return -1;
  }
  return 0;
}

// ─── Number formatting (Arabic) ───────────────────────────────────────────────
function formatNumberArabic(num) {
  try {
    return Number(num).toLocaleString('ar-SA');
  } catch {
    return String(num);
  }
}

// ─── DOM Updates ──────────────────────────────────────────────────────────────
function setVersion(tagName) {
  if (!tagName) return;
  const tag = tagName.startsWith('v') ? tagName : `v${tagName}`;

  // Don't downgrade if the page already displays a newer or equal version
  const currentWin = document.getElementById('win-version-tag')?.textContent || '';
  if (currentWin && compareVersions(currentWin, tag) > 0) {
    return;
  }

  const heroVersion = document.getElementById('hero-version-text');
  if (heroVersion) {
    heroVersion.textContent = `الإصدار الرسمي ${tag} متاح للتحميل`;
  }

  const winTag = document.getElementById('win-version-tag');
  if (winTag) winTag.textContent = tag;

  const androidTag = document.getElementById('android-version-tag');
  if (androidTag) androidTag.textContent = tag;

  // Also update download button filenames
  const btnWin = document.getElementById('btn-windows');
  if (btnWin) {
    btnWin.setAttribute('download', `mihrab-windows-${tag}.exe`);
  }

  const btnAndroid = document.getElementById('btn-android');
  if (btnAndroid) {
    btnAndroid.setAttribute('download', `mihrab-android-${tag}.apk`);
  }
}

function setTotalDownloads(totalCount) {
  const heroDownloads = document.getElementById('hero-total-downloads');
  const statDownloads = document.getElementById('stat-downloads');

  const formatted = formatNumberArabic(totalCount);
  if (heroDownloads) heroDownloads.textContent = formatted;
  if (statDownloads) statDownloads.textContent = formatted;
}

function updatePlatformDownloadCounts(releases) {
  if (!Array.isArray(releases)) return;

  let winDownloads = 0;
  let androidDownloads = 0;

  releases.forEach(rel => {
    (rel.assets || []).forEach(asset => {
      const name = (asset.name || '').toLowerCase();
      const count = asset.download_count || 0;
      if (name.endsWith('.apk') || name.includes('android')) {
        androidDownloads += count;
      } else if (name.endsWith('.exe') || name.includes('windows')) {
        winDownloads += count;
      }
    });
  });

  const winCountEl = document.querySelector('#btn-windows .btn-download-count');
  if (winCountEl && winDownloads > 0) {
    winCountEl.textContent = `(${formatNumberArabic(winDownloads)} تحميل)`;
    winCountEl.style.display = 'inline-block';
  }

  const androidCountEl = document.querySelector('#btn-android .btn-download-count');
  if (androidCountEl && androidDownloads > 0) {
    androidCountEl.textContent = `(${formatNumberArabic(androidDownloads)} تحميل)`;
    androidCountEl.style.display = 'inline-block';
  }
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

// ─── Fetch Release Data (All releases combined for true cumulative stats) ──────
async function fetchReleaseData() {
  // Check cached releases first
  try {
    const cachedStr = sessionStorage.getItem(CACHE_KEY);
    if (cachedStr) {
      const cached = JSON.parse(cachedStr);
      if (Date.now() - cached.timestamp < CACHE_TTL_MS && Array.isArray(cached.data)) {
        applyReleases(cached.data);
        return;
      }
    }
  } catch {}

  try {
    const response = await fetch(GITHUB_RELEASES_API, {
      headers: { Accept: 'application/vnd.github.v3+json' },
    });

    if (!response.ok) throw new Error(`HTTP ${response.status}`);
    const releases = await response.json();

    if (Array.isArray(releases) && releases.length > 0) {
      try {
        sessionStorage.setItem(CACHE_KEY, JSON.stringify({
          timestamp: Date.now(),
          data: releases,
        }));
      } catch {}
      applyReleases(releases);
    }
  } catch (err) {
    console.info('[محراب] مخدم التحميل المباشر السريع مفعل.');
  }
}

function applyReleases(releases) {
  if (!Array.isArray(releases) || releases.length === 0) return;

  // Filter out drafts and prereleases
  const candidates = releases.filter(r => !r.draft && !r.prerelease);
  const releaseList = candidates.length > 0 ? candidates : releases;

  // Sort descending by semantic version
  releaseList.sort((a, b) => compareVersions(b.tag_name, a.tag_name));

  const latest = releaseList[0];
  if (latest && latest.tag_name) {
    setVersion(latest.tag_name);
  }

  // Sum download counts across ALL releases
  let totalDownloads = 0;
  releases.forEach(rel => {
    (rel.assets || []).forEach(asset => {
      totalDownloads += (asset.download_count || 0);
    });
  });

  setTotalDownloads(totalDownloads);
  updatePlatformDownloadCounts(releases);
}

// ─── Init ─────────────────────────────────────────────────────────────────────
document.addEventListener('DOMContentLoaded', () => {
  checkInAppBrowser();
  fetchReleaseData();
});
