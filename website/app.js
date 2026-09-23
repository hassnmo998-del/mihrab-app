/**
 * محراب — منصة إدارة حلقات التحفيظ الذكية
 * app.js — GitHub Release Fetcher & Download Manager
 *
 * ⚙️  Configuration: Replace OWNER and REPO with your GitHub username and repo name.
 */

// ─── Configuration ───────────────────────────────────────────────────────────
const GITHUB_OWNER = 'OWNER';
const GITHUB_REPO  = 'REPO';
const GITHUB_API   = `https://api.github.com/repos/${GITHUB_OWNER}/${GITHUB_REPO}/releases/latest`;
const SESSION_KEY  = 'mihrab_release_cache';

// ─── Utility helpers ─────────────────────────────────────────────────────────

/**
 * Formats an ISO date string into a readable Arabic date.
 * @param {string} iso  e.g. "2026-09-23T03:57:23Z"
 * @returns {string}   e.g. "٢٣ سبتمبر ٢٠٢٦"
 */
function formatArabicDate(iso) {
  try {
    const date = new Date(iso);
    return date.toLocaleDateString('ar-SA', {
      year: 'numeric',
      month: 'long',
      day: 'numeric',
    });
  } catch {
    return iso;
  }
}

/**
 * Converts basic Markdown text to safe HTML.
 * Handles: **bold**, *italic*, `code`, - list items, headings, blank-line paragraphs.
 * @param {string} md
 * @returns {string} HTML string
 */
function markdownToHtml(md) {
  if (!md) return '<em>لا توجد ملاحظات لهذا الإصدار.</em>';

  // Escape HTML entities first
  const escaped = md
    .replace(/&/g, '&amp;')
    .replace(/</g, '&lt;')
    .replace(/>/g, '&gt;');

  const lines = escaped.split('\n');
  const output = [];
  let inList = false;

  for (let line of lines) {
    // Headings
    if (/^### (.+)/.test(line)) {
      if (inList) { output.push('</ul>'); inList = false; }
      output.push(`<h4 style="color:var(--gold-light);margin:20px 0 8px;">${line.replace(/^### /, '')}</h4>`);
      continue;
    }
    if (/^## (.+)/.test(line)) {
      if (inList) { output.push('</ul>'); inList = false; }
      output.push(`<h3 style="color:var(--gold);margin:24px 0 10px;">${line.replace(/^## /, '')}</h3>`);
      continue;
    }
    if (/^# (.+)/.test(line)) {
      if (inList) { output.push('</ul>'); inList = false; }
      output.push(`<h2 style="color:var(--gold);margin:28px 0 12px;">${line.replace(/^# /, '')}</h2>`);
      continue;
    }

    // List items (- or *)
    if (/^[\-\*] (.+)/.test(line)) {
      if (!inList) { output.push('<ul>'); inList = true; }
      const content = line.replace(/^[\-\*] /, '');
      output.push(`<li>${applyInlineMarkdown(content)}</li>`);
      continue;
    }

    // Blank line
    if (line.trim() === '') {
      if (inList) { output.push('</ul>'); inList = false; }
      output.push('');
      continue;
    }

    // Regular paragraph line
    if (inList) { output.push('</ul>'); inList = false; }
    output.push(`<p>${applyInlineMarkdown(line)}</p>`);
  }

  if (inList) output.push('</ul>');
  return output.join('\n');
}

/**
 * Applies inline markdown (bold, italic, code) to a single line.
 */
function applyInlineMarkdown(text) {
  return text
    .replace(/\*\*(.+?)\*\*/g, '<strong>$1</strong>')
    .replace(/\*(.+?)\*/g,     '<em>$1</em>')
    .replace(/`(.+?)`/g,       '<code style="background:rgba(255,255,255,0.1);padding:2px 6px;border-radius:4px;font-size:0.9em;">$1</code>');
}

/**
 * Finds a release asset by matching platform keywords in the filename.
 * @param {Array}  assets   GitHub release assets array
 * @param {string} platform 'windows' | 'android'
 * @returns {object|null}
 */
function findAsset(assets, platform) {
  if (!Array.isArray(assets)) return null;
  const keywords = {
    windows: ['.exe', 'windows', 'win'],
    android: ['.apk', 'android'],
  };
  const keys = keywords[platform] || [];
  return assets.find(a => keys.some(k => a.name.toLowerCase().includes(k))) || null;
}

// ─── DOM helpers ──────────────────────────────────────────────────────────────

function setVersion(tag) {
  document.querySelectorAll('#version-text, #version-text-2').forEach(el => {
    el.textContent = tag || 'v---';
  });
}

function setReleaseDate(iso) {
  const el = document.getElementById('release-date');
  if (!el) return;
  const dateText = el.querySelector('.release-date-text');
  if (dateText) dateText.textContent = formatArabicDate(iso);
}

function setReleaseNotes(body) {
  const el = document.getElementById('release-notes');
  if (el) el.innerHTML = markdownToHtml(body);
}

function setDownloadLink(btnId, asset) {
  const btn = document.getElementById(btnId);
  if (!btn) return;
  if (asset) {
    btn.href = asset.browser_download_url;
    btn.removeAttribute('disabled');
  } else {
    btn.href = '#';
    btn.setAttribute('aria-disabled', 'true');
  }
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
      if (!href || href === '#') {
        e.preventDefault();
        console.warn(`[محراب] زر تحميل ${platform} غير مرتبط بملف بعد.`);
        return;
      }
      console.log(`[محراب] 📥 بدأ تحميل ${platform}:`, href);
      // TODO: Replace with real analytics call, e.g. gtag('event', 'download', { platform })
    });
  });
}

// ─── Main fetch logic ─────────────────────────────────────────────────────────

async function fetchRelease() {
  // Try sessionStorage cache first
  try {
    const cached = sessionStorage.getItem(SESSION_KEY);
    if (cached) {
      const data = JSON.parse(cached);
      applyReleaseData(data);
      console.log('[محراب] ✅ تم تحميل البيانات من الذاكرة المؤقتة.');
      return;
    }
  } catch { /* ignore cache errors */ }

  // Validate config
  if (GITHUB_OWNER === 'OWNER' || GITHUB_REPO === 'REPO') {
    console.warn('[محراب] ⚠️ يرجى تحديث GITHUB_OWNER وGITHUB_REPO في app.js بمعلومات مستودعك.');
    setReleaseNotes('لم يتم تكوين مستودع GitHub بعد. يرجى تحديث ملف app.js.');
    setVersion('v---');
    showFallback();
    return;
  }

  try {
    const response = await fetch(GITHUB_API, {
      headers: { Accept: 'application/vnd.github.v3+json' },
    });

    if (!response.ok) {
      throw new Error(`GitHub API error: ${response.status} ${response.statusText}`);
    }

    const data = await response.json();

    // Cache for this session
    try { sessionStorage.setItem(SESSION_KEY, JSON.stringify(data)); } catch { /* quota */ }

    applyReleaseData(data);
    console.log('[محراب] ✅ تم تحميل بيانات الإصدار من GitHub بنجاح:', data.tag_name);

  } catch (err) {
    console.error('[محراب] ❌ فشل جلب بيانات الإصدار:', err.message);
    handleFetchError(err);
  }
}

/**
 * Applies fetched release data to the DOM.
 * @param {object} data  GitHub release object
 */
function applyReleaseData(data) {
  // Version
  setVersion(data.tag_name);

  // Date
  setReleaseDate(data.published_at || data.created_at);

  // Release notes
  setReleaseNotes(data.body);

  // Download assets
  const assets = data.assets || [];
  const winAsset     = findAsset(assets, 'windows');
  const androidAsset = findAsset(assets, 'android');

  setDownloadLink('btn-windows', winAsset);
  setDownloadLink('btn-android', androidAsset);

  // If either is missing, show fallback section too
  if (!winAsset || !androidAsset) {
    console.warn('[محراب] ⚠️ لم يتم العثور على بعض ملفات التحميل في الإصدار الأخير.');
    showFallback();
  }
}

/**
 * Handles fetch errors gracefully.
 */
function handleFetchError(err) {
  setVersion('v---');
  setReleaseNotes(`
    <p style="color:rgba(255,255,255,0.5);">
      ⚠️ تعذّر تحميل ملاحظات الإصدار. يرجى المحاولة لاحقاً.
    </p>
    <p style="color:rgba(255,255,255,0.35);font-size:0.85rem;">${err.message}</p>
  `);
  const dateEl = document.querySelector('#release-date .release-date-text');
  if (dateEl) dateEl.textContent = '—';
  showFallback();
}

// ─── Init ─────────────────────────────────────────────────────────────────────

document.addEventListener('DOMContentLoaded', () => {
  fetchRelease();
  attachDownloadTracking();
});
