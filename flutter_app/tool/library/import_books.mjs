#!/usr/bin/env node
/**
 * مستورد كتب المكتبة — من النص الكامل للمصدر إلى Supabase.
 *
 *   node tool/library/import_books.mjs                 كل كتب books.json
 *   node tool/library/import_books.mjs --only zad_maad,sayd_khatir
 *   node tool/library/import_books.mjs --dry-run       يبني محلياً بلا رفع
 *   node tool/library/import_books.mjs --force         يرفع ولو لم يتغيّر المحتوى
 *   node tool/library/import_books.mjs --seed-only     يحدّث lib/data/library_cloud_seed.dart فقط
 *
 * ما ينتجه لكل كتاب داخل الـ bucket `books`:
 *   v2/<id>/<rev>/index.json   الفهرس: عدد الصفحات، حدود الأجزاء، العناوين، أرقام المطبوع
 *   v2/<id>/<rev>/c<n>.json    جزء فيه عشرات الصفحات (نحو 110KB)
 * ثم يحدّث صف الكتاب في جدول library_books.
 *
 * `rev` يدخل في المسار، فلا يقرأ أحد نصف كتاب قديم ونصفاً جديداً، وتُخزَّن
 * الملفات عند القارئ بلا انتهاء صلاحية. إعادة التشغيل بلا تغيير لا ترفع شيئاً.
 * تبقى المراجعة السابقة منشورة إلى الاستيراد الذي بعده (--keep-old يبقي الكل).
 *
 * الكتابة محمية برمز استيراد: LIBRARY_INGEST_TOKEN أو الملف .ingest-token
 * (انظر make_ingest_token.mjs). المفتاح العام وحده لا يكتب.
 */
import fs from 'node:fs';
import path from 'node:path';
import crypto from 'node:crypto';
import { fileURLToPath } from 'node:url';

const HERE = path.dirname(fileURLToPath(import.meta.url));
const APP_ROOT = path.resolve(HERE, '../..');

const SUPABASE_URL =
  process.env.SUPABASE_URL ?? 'https://mltxsmonudbtnrloqawf.supabase.co';
// مفتاح التطبيق العام نفسه (غير سرّي)؛ الصلاحية تأتي من رمز الاستيراد.
const PUBLISHABLE_KEY =
  process.env.SUPABASE_PUBLISHABLE_KEY ??
  'sb_publishable_yr45qpkrG5Fp20pAbS7NJg_DCIYQHuf';
const BUCKET = 'books';
const FORMAT = 2;

const CHUNK_TARGET_BYTES = 110_000;
const CHUNK_MAX_PAGES = 150;
const UPLOAD_CONCURRENCY = 6;

export const CACHE_DIR = path.join(HERE, '.cache');
const OUT_DIR = path.join(APP_ROOT, 'build', 'library_import');
const SEED_FILE = path.join(APP_ROOT, 'lib', 'data', 'library_cloud_seed.dart');

// ───────────────────────────── الأدوات العامة ─────────────────────────────

const args = process.argv.slice(2);
const flag = (name) => args.includes(`--${name}`);
const option = (name) => {
  const i = args.indexOf(`--${name}`);
  return i >= 0 ? args[i + 1] : undefined;
};

const sha256 = (data) => crypto.createHash('sha256').update(data).digest('hex');
const sleep = (ms) => new Promise((r) => setTimeout(r, ms));

function ingestToken() {
  if (process.env.LIBRARY_INGEST_TOKEN) return process.env.LIBRARY_INGEST_TOKEN.trim();
  const file = path.join(HERE, '.ingest-token');
  if (fs.existsSync(file)) return fs.readFileSync(file, 'utf8').trim();
  throw new Error(
    'لا يوجد رمز استيراد. شغّل: node tool/library/make_ingest_token.mjs ثم سجّل بصمته في قاعدة البيانات.',
  );
}

function authHeaders(write = false) {
  const h = { apikey: PUBLISHABLE_KEY, Authorization: `Bearer ${PUBLISHABLE_KEY}` };
  if (write) h['x-library-ingest-token'] = ingestToken();
  return h;
}

async function withRetry(label, fn, attempts = 5) {
  let lastError;
  for (let i = 0; i < attempts; i++) {
    try {
      return await fn();
    } catch (e) {
      lastError = e;
      // رفض الصلاحية لا يتغيّر بإعادة المحاولة
      if (e.status === 400 || e.status === 401 || e.status === 403) break;
      await sleep(600 * 2 ** i);
    }
  }
  throw new Error(`${label}: ${lastError?.message ?? lastError}`);
}

async function request(url, init = {}) {
  const res = await fetch(url, { ...init, signal: AbortSignal.timeout(120_000) });
  if (!res.ok) {
    const err = new Error(`${res.status} ${(await res.text()).slice(0, 300)}`);
    err.status = res.status;
    throw err;
  }
  return res;
}

async function mapLimit(items, limit, fn) {
  let next = 0;
  const workers = Array.from({ length: Math.min(limit, items.length) }, async () => {
    while (next < items.length) {
      const i = next++;
      await fn(items[i], i);
    }
  });
  await Promise.all(workers);
}

// ───────────────────────────── قراءة المصدر ─────────────────────────────

/** يعيد { pages:[{text,vol,page}], headings:[{title,level,page}], info, sourceLabel } */
export async function loadSource(source) {
  if (source.file) {
    const raw = JSON.parse(fs.readFileSync(path.resolve(HERE, source.file), 'utf8'));
    return {
      pages: raw.pages ?? [],
      headings: raw.headings ?? [],
      info: raw.info ?? '',
      sourceLabel: raw.sourceLabel ?? path.basename(source.file),
    };
  }
  if (source.turath) {
    const cached = path.join(CACHE_DIR, `turath-${source.turath}.json`);
    if (!fs.existsSync(cached)) {
      fs.mkdirSync(CACHE_DIR, { recursive: true });
      const res = await withRetry(`تنزيل المصدر ${source.turath}`, () =>
        request(`https://files.turath.io/books-v3/${source.turath}.json`, {
          headers: { 'User-Agent': 'Mozilla/5.0 (mihrab-library-import)' },
        }),
      );
      fs.writeFileSync(cached, Buffer.from(await res.arrayBuffer()));
    }
    return parseTurath(JSON.parse(fs.readFileSync(cached, 'utf8')), source.turath);
  }
  throw new Error(`مصدر غير معروف: ${JSON.stringify(source)}`);
}

const isHeadingList = (v) =>
  Array.isArray(v) && v.length > 0 && v[0] && typeof v[0] === 'object' && 'title' in v[0];

/** ملف «تراث» (نصوص المكتبة الشاملة): أسماء المفاتيح تتبدل بين الملفات، فنتعرّف على الأقسام من شكلها. */
function parseTurath(raw, id) {
  const pages = raw.pages;
  if (!Array.isArray(pages) || pages.length === 0) throw new Error('المصدر بلا صفحات');

  let meta = null;
  let indexes = null;
  for (const [key, value] of Object.entries(raw)) {
    if (key === 'pages' || !value || typeof value !== 'object' || Array.isArray(value)) continue;
    if (Object.values(value).some(isHeadingList)) indexes = value;
    else if (!meta) meta = value;
  }
  const headings = indexes ? Object.values(indexes).find(isHeadingList) ?? [] : [];
  const strings = meta ? Object.values(meta).filter((x) => typeof x === 'string') : [];
  const info = strings.find((s) => s.includes('الكتاب:')) ?? '';

  return { pages, headings, info, sourceLabel: `المكتبة الشاملة (${id})` };
}

// ───────────────────────────── تنظيف النص ─────────────────────────────

// رموز الترضّي والترحّم المضافة في يونيكود 14 غير موجودة في خطوط التطبيق
// (تظهر مربعات فارغة)، فنكتبها كلمات. «ﷺ» وحدها مدعومة فتبقى كما هي.
const HONORIFICS = {
  0xfd40: 'رحمه الله',
  0xfd41: 'رضي الله عنه',
  0xfd42: 'رضي الله عنها',
  0xfd43: 'رضي الله عنهم',
  0xfd44: 'رضي الله عنهما',
  0xfd45: 'رضي الله عنهن',
  0xfd46: 'صلى الله عليه وآله',
  0xfd47: 'عليه السلام',
  0xfd48: 'عليهم السلام',
  0xfd49: 'عليهما السلام',
  0xfd4a: 'عليه الصلاة والسلام',
  0xfd4b: 'قدس سره',
  0xfd4c: 'صلى الله عليه وآله وسلم',
  0xfd4d: 'عليها السلام',
  0xfd4e: 'تبارك وتعالى',
  0xfd4f: 'رحمهم الله',
  0xfdfb: 'جل جلاله',
  0xfdfd: 'بسم الله الرحمن الرحيم',
  0xfdfe: 'سبحانه وتعالى',
  0xfdff: 'عز وجل',
};
const HONORIFIC_RE = /[﵀-﵏ﷻ﷽-﷿]/g;

function expandHonorifics(text) {
  return text.replace(HONORIFIC_RE, (glyph, offset, whole) => {
    const prev = whole[offset - 1];
    const next = whole[offset + 1];
    // الرمز يلتصق أحياناً بما قبله أو بعده؛ الكلمات تحتاج فراغاً يفصلها
    const lead = prev && !/[\s(«\[]/.test(prev) ? ' ' : '';
    const tail = next && !/[\s.,،؛:;!?؟)»\]]/.test(next) ? ' ' : '';
    return `${lead}${HONORIFICS[glyph.codePointAt(0)]}${tail}`;
  });
}

const ENTITIES = { quot: '"', amp: '&', lt: '<', gt: '>', nbsp: ' ', apos: "'" };
function decodeEntities(text) {
  return text.replace(/&(#x[0-9a-f]+|#\d+|[a-z]+);/gi, (m, name) => {
    if (name[0] === '#') {
      const code = name[1].toLowerCase() === 'x' ? parseInt(name.slice(2), 16) : parseInt(name.slice(1), 10);
      return Number.isFinite(code) ? String.fromCodePoint(code) : m;
    }
    return ENTITIES[name.toLowerCase()] ?? m;
  });
}

export const HEADING_MARK = '## ';
export const RULE_LINE = '* * *';
const TITLE_SPAN = /<span\b[^>]*title[^>]*>([\s\S]*?)<\/span>/gi;
const stripTags = (s) => s.replace(/<\/?[a-z][^>]*>/gi, '');
// "فصل" وحدها على سطر: عنوان في عرف المصنفين وإن لم يعلّمه المصدر
const BARE_SECTION = /^[(\[]?فَ?صْ?لٌ?[)\]]?[:.]?$/;

/**
 * السطر الذي فيه عنوان يصير سطر عنوان مستقلاً يبدأ بـ "## ".
 * التمهيد القصير قبل العنوان ("٧- فصل:") وعلامة الترقيم بعده يبقيان معه،
 * وأي نص حقيقي ملاصق له يُفصل إلى سطر عادي.
 */
function convertLine(line) {
  if (!/<span\b[^>]*title/i.test(line)) {
    const plain = stripTags(line);
    return [BARE_SECTION.test(plain.trim()) ? HEADING_MARK + plain.trim() : plain];
  }

  const out = [];
  let current = '';
  let isHeading = false;
  const flush = () => {
    const text = stripTags(current).replace(/\s+/g, ' ').trim();
    if (text) out.push(isHeading ? HEADING_MARK + text : text);
    current = '';
    isHeading = false;
  };

  let last = 0;
  for (const m of line.matchAll(TITLE_SPAN)) {
    const before = line.slice(last, m.index);
    if (isHeading) {
      // ما بين عنوانين متتاليين: فراغ أو ترقيم يبقيهما عنواناً واحداً
      if (stripTags(before).trim().length <= 3) current += before;
      else {
        flush();
        current = before;
      }
    } else {
      current += before;
    }
    if (!isHeading && stripTags(current).trim().length > 60) flush();
    current += m[1];
    isHeading = true;
    last = m.index + m[0].length;
  }
  const rest = line.slice(last);
  if (stripTags(rest).trim().length <= 3) {
    current += rest;
    flush();
  } else {
    flush();
    current = rest;
    flush();
  }
  return out;
}

function tidy(text) {
  return expandHonorifics(decodeEntities(text))
    .replace(/[​‎‏﻿]/g, '')
    .replace(/ /g, ' ')
    .replace(/[ \t]+\n/g, '\n')
    .replace(/\n{3,}/g, '\n\n')
    .trim();
}

/** يفصل متن الصفحة عن حواشيها ويحوّل وسوم العناوين إلى أسطر عناوين. */
export function normalizePage(rawText) {
  const lines = (rawText ?? '').replace(/\r\n?/g, '\n').split('\n');
  const sep = lines.findIndex((l) => /^_{6,}\s*$/.test(l));
  const bodyLines = sep >= 0 ? lines.slice(0, sep) : lines;
  const noteLines = sep >= 0 ? lines.slice(sep + 1) : [];

  const body = tidy(
    bodyLines
      .flatMap((l) => (/<hr\b/i.test(l) ? [RULE_LINE] : convertLine(l)))
      .join('\n'),
  );
  // في الحاشية يُكتب رقمها "(^١)" كما في المتن؛ أول السطر يكفيه "(١)"
  const notes = tidy(noteLines.map(stripTags).join('\n')).replace(/^\(\^([^)]+)\)/gm, '($1)');
  return { body, notes };
}

// ───────────────────────────── بناء الكتاب ─────────────────────────────

function buildBook(entry, source) {
  const pages = [];
  const remap = new Map(); // رقم الصفحة في المصدر (من 1) ← رقمها بعد حذف الفارغ
  const pendingEmpty = [];

  source.pages.forEach((p, i) => {
    const { body, notes } = normalizePage(p.text);
    if (!body && !notes) {
      pendingEmpty.push(i + 1);
      return;
    }
    const number = pages.length + 1;
    remap.set(i + 1, number);
    for (const e of pendingEmpty.splice(0)) remap.set(e, number);
    const printPage = Number.parseInt(p.page, 10);
    pages.push({
      t: body,
      ...(notes ? { f: notes } : {}),
      p: Number.isFinite(printPage) ? printPage : 0,
      vol: p.vol == null ? '' : String(p.vol),
    });
  });
  for (const e of pendingEmpty) remap.set(e, pages.length);
  if (pages.length === 0) throw new Error('كل الصفحات فارغة');

  // المجلدات: نقاط تغيّر اسم المجلد
  const volumes = [];
  pages.forEach((p, i) => {
    if (i === 0 || p.vol !== pages[i - 1].vol) volumes.push({ name: p.vol, from: i + 1 });
  });

  const minLevel = Math.min(...source.headings.map((h) => h.level ?? 1), 9);
  const toc = source.headings
    .map((h) => {
      const title = tidy(stripTags(String(h.title ?? ''))).replace(/\s+/g, ' ');
      const page = remap.get(Number(h.page));
      if (!title || !page) return null;
      return [Math.max(1, (h.level ?? 1) - (Number.isFinite(minLevel) ? minLevel : 1) + 1), page, title];
    })
    .filter(Boolean);

  // الأجزاء
  const chunks = [];
  let current = [];
  let bytes = 0;
  const close = () => {
    if (!current.length) return;
    chunks.push({ from: current[0].number, pages: current.map((c) => c.data) });
    current = [];
    bytes = 0;
  };
  pages.forEach((p, i) => {
    const data = { t: p.t, ...(p.f ? { f: p.f } : {}) };
    const size = Buffer.byteLength(JSON.stringify(data));
    if (current.length && (bytes + size > CHUNK_TARGET_BYTES || current.length >= CHUNK_MAX_PAGES)) close();
    current.push({ number: i + 1, data });
    bytes += size;
  });
  close();

  const chunkFiles = chunks.map((c, i) => ({
    name: `c${i}.json`,
    body: Buffer.from(JSON.stringify(c)),
  }));

  const index = {
    format: FORMAT,
    id: entry.id,
    pages: pages.length,
    chunks: chunks.map((c) => c.from),
    printPages: pages.map((p) => p.p),
    volumes,
    toc,
    edition: tidy(source.info),
    source: source.sourceLabel,
  };

  const hash = sha256(
    Buffer.concat([Buffer.from(JSON.stringify(index)), ...chunkFiles.map((c) => c.body)]),
  );
  const contentBytes = chunkFiles.reduce((n, c) => n + c.body.length, 0);
  const textChars = pages.reduce((n, p) => n + p.t.length + (p.f?.length ?? 0), 0);

  return { index, chunkFiles, hash, contentBytes, textChars, sourcePages: source.pages.length };
}

// ───────────────────────────── Supabase ─────────────────────────────

const objectUrl = (key) => `${SUPABASE_URL}/storage/v1/object/${BUCKET}/${key}`;
const publicUrl = (key) => `${SUPABASE_URL}/storage/v1/object/public/${BUCKET}/${key}`;

async function fetchRow(id) {
  const res = await withRetry(`قراءة صف ${id}`, () =>
    request(`${SUPABASE_URL}/rest/v1/library_books?id=eq.${encodeURIComponent(id)}&select=id,content_rev,content_hash,content_format`, {
      headers: authHeaders(),
    }),
  );
  return (await res.json())[0] ?? null;
}

async function uploadObject(key, body) {
  await withRetry(`رفع ${key}`, () =>
    request(objectUrl(key), {
      method: 'POST',
      headers: {
        ...authHeaders(true),
        'Content-Type': 'application/json; charset=utf-8',
        // المسار يحمل رقم المراجعة فلا يتغيّر محتواه أبداً
        'Cache-Control': 'max-age=31536000',
        'x-upsert': 'true',
      },
      body,
    }),
  );
}

async function listObjects(prefix) {
  const names = [];
  for (let offset = 0; ; offset += 1000) {
    const res = await withRetry(`سرد ${prefix}`, () =>
      request(`${SUPABASE_URL}/storage/v1/object/list/${BUCKET}`, {
        method: 'POST',
        headers: { ...authHeaders(), 'Content-Type': 'application/json' },
        body: JSON.stringify({ prefix, limit: 1000, offset, sortBy: { column: 'name', order: 'asc' } }),
      }),
    );
    const batch = await res.json();
    names.push(...batch);
    if (batch.length < 1000) return names;
  }
}

async function deleteObjects(keys) {
  for (let i = 0; i < keys.length; i += 100) {
    await withRetry('حذف مراجعة قديمة', () =>
      request(`${SUPABASE_URL}/storage/v1/object/${BUCKET}`, {
        method: 'DELETE',
        headers: { ...authHeaders(true), 'Content-Type': 'application/json' },
        body: JSON.stringify({ prefixes: keys.slice(i, i + 100) }),
      }),
    );
  }
}

/**
 * يبقي المراجعة الحالية والتي قبلها: قارئ فتح الكتاب قبل دقيقة يكمل قراءته،
 * وتطبيق لم يزامن فهرسه بعد يجد ما يشير إليه. ما قبل ذلك يُحذف.
 */
async function pruneOldRevisions(id, keepRev) {
  const revs = (await listObjects(`v2/${id}/`)).filter(
    (o) => o.id === null && Number(o.name) < keepRev - 1,
  );
  for (const rev of revs) {
    const files = await listObjects(`v2/${id}/${rev.name}/`);
    await deleteObjects(files.map((f) => `v2/${id}/${rev.name}/${f.name}`));
  }
  return revs.length;
}

async function upsertRow(row) {
  await withRetry(`تحديث صف ${row.id}`, () =>
    request(`${SUPABASE_URL}/rest/v1/library_books?on_conflict=id`, {
      method: 'POST',
      headers: {
        ...authHeaders(true),
        'Content-Type': 'application/json',
        Prefer: 'resolution=merge-duplicates,return=minimal',
      },
      body: JSON.stringify(row),
    }),
  );
}

async function verifyUpload(id, rev, built) {
  const base = `v2/${id}/${rev}`;
  const listed = await listObjects(`${base}/`);
  const expected = built.chunkFiles.length + 1;
  if (listed.length !== expected) {
    throw new Error(`تحقق ${id}: عدد الملفات ${listed.length} والمتوقع ${expected}`);
  }
  // عيّنة: الفهرس وأول جزء وآخر جزء وواحد من الوسط، تُقارن بايتاً ببايت
  const picks = new Set([0, built.chunkFiles.length - 1, built.chunkFiles.length >> 1]);
  const checks = [
    { key: `${base}/index.json`, body: Buffer.from(JSON.stringify({ ...built.index, rev })) },
    ...[...picks].map((i) => ({ key: `${base}/${built.chunkFiles[i].name}`, body: built.chunkFiles[i].body })),
  ];
  for (const c of checks) {
    const res = await withRetry(`تحقق ${c.key}`, () => request(publicUrl(c.key)));
    const got = Buffer.from(await res.arrayBuffer());
    if (sha256(got) !== sha256(c.body)) throw new Error(`تحقق ${c.key}: المحتوى المرفوع لا يطابق`);
  }
}

const megabytes = (bytes) => `${(bytes / 1048576).toFixed(bytes < 1048576 ? 2 : 1)} ميغابايت`;
const parseColor = (c) => (typeof c === 'number' ? c : Number.parseInt(String(c), 16) || Number(c));

// ───────────────────────────── بذرة الفهرس المضمّنة ─────────────────────────────

const dartString = (s) =>
  `'${String(s ?? '').replace(/\\/g, '\\\\').replace(/'/g, "\\'").replace(/\$/g, '\\$').replace(/\n/g, '\\n')}'`;

/** نسخة من فهرس السحابة تُضمَّن في التطبيق ليظهر الرف كاملاً قبل أول مزامنة. */
async function writeSeed() {
  const rows = [];
  for (let offset = 0; ; offset += 1000) {
    const res = await withRetry('قراءة الفهرس', () =>
      request(
        `${SUPABASE_URL}/rest/v1/library_books?content_format=eq.${FORMAT}&is_published=eq.true` +
          `&select=*&order=sort_order.asc,id.asc&offset=${offset}&limit=1000`,
        { headers: authHeaders() },
      ),
    );
    const batch = await res.json();
    rows.push(...batch);
    if (batch.length < 1000) break;
  }

  const lines = [
    '// GENERATED — لا تعدّل يدوياً. يولّده: node tool/library/import_books.mjs --seed-only',
    "import '../models/library_book.dart';",
    '',
    '/// نسخة مضمّنة من فهرس الكتب السحابية (جدول library_books) وقت البناء.',
    '/// المزامنة تحدّثها وتضيف عليها؛ وجودها يُظهر الرف كاملاً من أول تشغيل.',
    'const List<LibraryBook> kCloudSeedLibraryBooks = [',
  ];
  for (const r of rows) {
    lines.push(
      '  LibraryBook(',
      `    id: ${dartString(r.id)},`,
      `    title: ${dartString(r.title)},`,
      `    shortTitle: ${dartString(r.short_title)},`,
      `    author: ${dartString(r.author)},`,
      `    category: ${dartString(r.category)},`,
      `    categoryName: ${dartString(r.category_name)},`,
      `    description: ${dartString(r.description)},`,
      `    coverColor: 0x${Number(r.cover_color).toString(16).toUpperCase().padStart(8, '0')},`,
      `    totalPages: ${r.total_pages},`,
      `    chaptersCount: ${r.chapters_count},`,
      `    fileSize: ${dartString(r.file_size)},`,
      '    isBuiltIn: false,',
      `    contentUrl: ${dartString(r.content_url)},`,
      `    contentFormat: ${r.content_format},`,
      `    contentRev: ${r.content_rev},`,
      `    sortOrder: ${r.sort_order},`,
      '  ),',
    );
  }
  lines.push('];', '');
  fs.writeFileSync(SEED_FILE, lines.join('\n'), 'utf8');
  console.log(`🌱 ${path.relative(APP_ROOT, SEED_FILE)} ← ${rows.length} كتاباً`);
}

// ───────────────────────────── التشغيل ─────────────────────────────

async function importBook(entry, categories, { dryRun, force, keepOld }) {
  const source = await loadSource(entry.source);
  const built = buildBook(entry, source);

  const local = path.join(OUT_DIR, entry.id);
  fs.rmSync(local, { recursive: true, force: true });
  fs.mkdirSync(local, { recursive: true });
  fs.writeFileSync(path.join(local, 'index.json'), JSON.stringify(built.index));
  for (const c of built.chunkFiles) fs.writeFileSync(path.join(local, c.name), c.body);

  const summary =
    `${built.index.pages} صفحة (المصدر ${built.sourcePages})، ${built.index.toc.length} عنواناً، ` +
    `${built.chunkFiles.length} جزءاً، ${megabytes(built.contentBytes)}`;
  if (dryRun) {
    console.log(`🧪 ${entry.id}: ${summary}`);
    return;
  }

  const row = await fetchRow(entry.id);
  const unchanged = row && row.content_format === FORMAT && row.content_hash === built.hash;
  const rev = unchanged && !force ? row.content_rev : (row?.content_rev ?? 0) + 1;

  if (!unchanged || force) {
    const base = `v2/${entry.id}/${rev}`;
    await mapLimit(built.chunkFiles, UPLOAD_CONCURRENCY, (c) => uploadObject(`${base}/${c.name}`, c.body));
    // الفهرس آخراً: وجوده يعني أن كل الأجزاء وصلت
    await uploadObject(`${base}/index.json`, Buffer.from(JSON.stringify({ ...built.index, rev })));
    await verifyUpload(entry.id, rev, built);
  }

  await upsertRow({
    id: entry.id,
    title: entry.title,
    short_title: entry.shortTitle,
    author: entry.author,
    category: entry.category,
    category_name: categories[entry.category] ?? entry.category,
    description: entry.description,
    cover_color: parseColor(entry.coverColor),
    total_pages: built.index.pages,
    chapters_count: built.index.toc.length,
    file_size: megabytes(built.contentBytes),
    content_url: publicUrl(`v2/${entry.id}/${rev}/index.json`),
    content_format: FORMAT,
    content_rev: rev,
    content_hash: built.hash,
    content_bytes: built.contentBytes,
    source_info: built.index.edition,
    sort_order: entry.sortOrder ?? 1000,
    is_built_in: false,
    is_published: entry.published ?? true,
  });

  let pruned = 0;
  if (!keepOld) pruned = await pruneOldRevisions(entry.id, rev);
  console.log(
    `${unchanged && !force ? '⏭️ ' : '✅'} ${entry.id} (مراجعة ${rev}): ${summary}` +
      (pruned ? ` — حُذفت ${pruned} مراجعة قديمة` : ''),
  );
}

async function main() {
  const manifest = JSON.parse(fs.readFileSync(path.join(HERE, 'books.json'), 'utf8'));
  if (flag('seed-only')) return writeSeed();

  const only = option('only')?.split(',').map((s) => s.trim());
  const entries = manifest.books.filter((b) => !only || only.includes(b.id));
  if (only && entries.length !== only.length) {
    const known = new Set(entries.map((e) => e.id));
    throw new Error(`غير موجود في books.json: ${only.filter((id) => !known.has(id)).join(', ')}`);
  }

  const opts = { dryRun: flag('dry-run'), force: flag('force'), keepOld: flag('keep-old') };
  if (!opts.dryRun) ingestToken();

  const failed = [];
  for (const entry of entries) {
    try {
      await importBook(entry, manifest.categories, opts);
    } catch (e) {
      failed.push(entry.id);
      console.error(`❌ ${entry.id}: ${e.message}`);
    }
  }
  if (!opts.dryRun) await writeSeed();
  if (failed.length) {
    console.error(`\nفشل ${failed.length}: ${failed.join(', ')}`);
    process.exit(1);
  }
}

if (process.argv[1] && path.resolve(process.argv[1]) === fileURLToPath(import.meta.url)) {
  main().catch((e) => {
    console.error(`❌ ${e.message}`);
    process.exit(1);
  });
}
