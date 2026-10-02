#!/usr/bin/env node
/**
 * إضافة كتاب إلى المكتبة بلا إصدار جديد للتطبيق.
 *
 *   node tool/library/add_book.mjs search "زاد المعاد"      يبحث في فهرس المكتبة الشاملة
 *   node tool/library/add_book.mjs add 21713                يضيفه إلى books.json ثم يستورده ويرفعه
 *   node tool/library/add_book.mjs remove <id>              يخفيه من التطبيق (يبقى في books.json غير منشور)
 *
 * خيارات add (كلها اختيارية؛ ما لم يُذكر يُؤخذ من بيانات المصدر):
 *   --id slug            معرّف الكتاب في التطبيق (الافتراضي t<رقم المصدر>)
 *   --title "…"          العنوان الكامل
 *   --short "…"          العنوان المختصر الذي يظهر على الغلاف
 *   --author "…"         المؤلف
 *   --category id        التصنيف (الافتراضي من تصنيف المصدر)
 *   --description "…"    نبذة تظهر في بطاقة الكتاب
 *   --color 0xFF1B4332   لون الغلاف
 *   --order 5000         ترتيبه داخل تصنيفه (الأصغر أولاً)
 *   --dry-run            يطبع المدخل ولا يكتب شيئاً
 *   --no-import          يكتب books.json ولا يرفع
 *
 * بعد الرفع يظهر الكتاب عند المستخدمين عند فتح المكتبة (أو السحب للتحديث).
 */
import fs from 'node:fs';
import path from 'node:path';
import { spawnSync } from 'node:child_process';
import { fileURLToPath } from 'node:url';
import { CACHE_DIR, loadSource } from './import_books.mjs';

const HERE = path.dirname(fileURLToPath(import.meta.url));
const MANIFEST = path.join(HERE, 'books.json');
const CATALOG_FILE = path.join(CACHE_DIR, 'turath-catalog.json');
const CATALOG_URL = 'https://files.turath.io/data-v3.json';
const CATALOG_MAX_AGE_MS = 7 * 24 * 3600 * 1000;

/** تصنيف المصدر (40 تصنيفاً) ← تصنيف التطبيق. */
const CATEGORY_NAMES = {
  hadith: 'الحديث النبوي والصحاح',
  tafsir: 'التفسير وعلوم القرآن',
  seerah: 'السيرة والشمائل',
  aqeedah: 'العقيدة والأصول',
  fiqh: 'الفقه والأحكام',
  usul: 'أصول الفقه',
  tazkiyah: 'التزكية والرقائق',
  tarikh: 'التاريخ والتراجم',
  lugha: 'اللغة والأدب',
  general: 'كتب عامة',
};
const SOURCE_CATEGORY = {
  1: 'aqeedah', 2: 'aqeedah',
  3: 'tafsir', 4: 'tafsir', 5: 'tafsir',
  6: 'hadith', 7: 'hadith', 8: 'hadith', 9: 'hadith', 10: 'hadith',
  11: 'usul', 13: 'usul',
  12: 'fiqh', 14: 'fiqh', 15: 'fiqh', 16: 'fiqh', 17: 'fiqh', 18: 'fiqh', 19: 'fiqh', 20: 'fiqh', 21: 'fiqh', 22: 'fiqh',
  23: 'tazkiyah',
  24: 'seerah',
  25: 'tarikh', 26: 'tarikh', 27: 'tarikh', 28: 'tarikh',
  29: 'lugha', 30: 'lugha', 31: 'lugha', 32: 'lugha', 33: 'lugha', 34: 'lugha', 35: 'lugha',
};

/** ألوان جلدية داكنة تليق بالأغلفة؛ يُختار منها بحسب المعرّف فيثبت لون كل كتاب. */
const COVER_COLORS = [
  '0xFF1B4332', '0xFF14342B', '0xFF2A5934', '0xFF283618', '0xFF1D3557', '0xFF0B3C49',
  '0xFF2B2D42', '0xFF3D2C5A', '0xFF422E44', '0xFF5D1A20', '0xFF50282C', '0xFF4A2C2A',
  '0xFF382728', '0xFF5E503F', '0xFF3D3B30', '0xFF354F52', '0xFF2C454E', '0xFF2F3E46',
];

const args = process.argv.slice(2);
const flag = (name) => args.includes(`--${name}`);
const option = (name) => {
  const i = args.indexOf(`--${name}`);
  return i >= 0 ? args[i + 1] : undefined;
};

const fold = (s) =>
  String(s ?? '')
    .replace(/[ً-ْٰـ]/g, '')
    .replace(/[أإآ]/g, 'ا')
    .replace(/ى/g, 'ي')
    .replace(/ة/g, 'ه');

async function loadCatalog() {
  const fresh =
    fs.existsSync(CATALOG_FILE) && Date.now() - fs.statSync(CATALOG_FILE).mtimeMs < CATALOG_MAX_AGE_MS;
  if (!fresh || flag('refresh')) {
    const res = await fetch(CATALOG_URL, {
      headers: { 'User-Agent': 'Mozilla/5.0 (mihrab-library-import)' },
      signal: AbortSignal.timeout(120_000),
    });
    if (!res.ok) throw new Error(`تعذّر تنزيل فهرس المصدر: ${res.status}`);
    fs.mkdirSync(CACHE_DIR, { recursive: true });
    fs.writeFileSync(CATALOG_FILE, Buffer.from(await res.arrayBuffer()));
  }
  return JSON.parse(fs.readFileSync(CATALOG_FILE, 'utf8'));
}

const readManifest = () => JSON.parse(fs.readFileSync(MANIFEST, 'utf8'));
const writeManifest = (m) => fs.writeFileSync(MANIFEST, `${JSON.stringify(m, null, 2)}\n`, 'utf8');

function authorLabel(catalog, book) {
  const a = catalog.authors[book.author_id];
  if (!a) return '';
  return a.death ? `${a.name} (ت ${a.death} هـ)` : a.name;
}

async function search(query) {
  const catalog = await loadCatalog();
  const manifest = readManifest();
  const added = new Map(manifest.books.filter((b) => b.source?.turath).map((b) => [b.source.turath, b.id]));
  const words = fold(query).split(/\s+/).filter(Boolean);
  if (!words.length) throw new Error('اكتب ما تبحث عنه');

  const hits = Object.values(catalog.books)
    .filter((b) => {
      const text = fold(`${b.name} ${catalog.authors[b.author_id]?.name ?? ''}`);
      return words.every((w) => text.includes(w));
    })
    // الأقرب إلى ما كُتب أولاً: الاسم الأقصر يطابق العبارة أكثر
    .sort((a, b) => a.name.length - b.name.length)
    .slice(0, 30);

  if (!hits.length) {
    console.log('لا نتائج.');
    return;
  }
  for (const b of hits) {
    const cat = catalog.cats[b.cat_id]?.name ?? '';
    const mark = added.has(b.id) ? `  ✓ في المكتبة (${added.get(b.id)})` : '';
    console.log(
      `${String(b.id).padStart(6)}  ${b.name}  —  ${authorLabel(catalog, b)}  [${cat}، ${b.page_count} صفحة]${mark}`,
    );
  }
  console.log('\nللإضافة: node tool/library/add_book.mjs add <الرقم>');
}

/** سطر من بطاقة المصدر: "المؤلف: فلان" ← "فلان". */
function infoField(info, label) {
  const m = info.match(new RegExp(`^${label}\\s*:\\s*(.+)$`, 'm'));
  return m ? m[1].trim() : '';
}

/** "الوابل الصيب - ط عطاءات العلم" ← "الوابل الصيب". */
const stripEdition = (name) => name.replace(/\s+[-–]\s+(ط|ت)\s.*$/, '').trim();

function hashOf(text) {
  let h = 0;
  for (const ch of text) h = (h * 31 + ch.codePointAt(0)) >>> 0;
  return h;
}

async function add(sourceId) {
  if (!Number.isInteger(sourceId)) throw new Error('رقم الكتاب في المصدر مطلوب: add <الرقم>');
  const catalog = await loadCatalog();
  const entry = catalog.books[sourceId];
  if (!entry) throw new Error(`لا يوجد كتاب برقم ${sourceId} في فهرس المصدر (جرّب --refresh)`);

  const manifest = readManifest();
  const existing = manifest.books.find((b) => b.source?.turath === sourceId);
  if (existing) throw new Error(`الكتاب مضاف من قبل بالمعرّف "${existing.id}"`);

  const id = option('id') ?? `t${sourceId}`;
  if (!/^[a-z][a-z0-9_]*$/.test(id)) throw new Error('المعرّف: حروف لاتينية صغيرة وأرقام و _ فقط');
  if (manifest.books.some((b) => b.id === id)) throw new Error(`المعرّف "${id}" مستعمل`);

  const source = await loadSource({ turath: sourceId });
  const cleanName = stripEdition(entry.name);
  const title = option('title') ?? (infoField(source.info, 'الكتاب') || cleanName);
  const author = option('author') ?? (infoField(source.info, 'المؤلف') || authorLabel(catalog, entry));
  const category = option('category') ?? SOURCE_CATEGORY[entry.cat_id] ?? 'general';

  const book = {
    id,
    source: { turath: sourceId },
    title,
    shortTitle: option('short') ?? cleanName,
    author,
    category,
    description: option('description') ?? `«${title}» تأليف ${author}.`,
    coverColor: option('color') ?? COVER_COLORS[hashOf(id) % COVER_COLORS.length],
    sortOrder: Number(option('order') ?? 5000),
  };

  console.log(JSON.stringify(book, null, 2));
  console.log(`\nالمصدر: ${source.pages.length} صفحة، ${source.headings.length} عنواناً.`);
  if (flag('dry-run')) return;

  manifest.categories[category] ??= CATEGORY_NAMES[category] ?? category;
  manifest.books.push(book);
  writeManifest(manifest);
  console.log(`أُضيف إلى books.json بالمعرّف "${id}".`);
  if (!flag('no-import')) runImport(id);
}

function remove(id) {
  const manifest = readManifest();
  const book = manifest.books.find((b) => b.id === id);
  if (!book) throw new Error(`لا يوجد كتاب بالمعرّف "${id}" في books.json`);
  book.published = false;
  writeManifest(manifest);
  console.log(`"${id}" صار غير منشور؛ يختفي من التطبيق عند المزامنة التالية.`);
  if (!flag('no-import')) runImport(id);
}

function runImport(id) {
  const result = spawnSync(process.execPath, [path.join(HERE, 'import_books.mjs'), '--only', id], {
    stdio: 'inherit',
  });
  if (result.status !== 0) process.exit(result.status ?? 1);
}

async function main() {
  const [command, ...rest] = args.filter((a, i) => !a.startsWith('--') && !(args[i - 1] ?? '').match(/^--(id|title|short|author|category|description|color|order)$/));
  switch (command) {
    case 'search':
      return search(rest.join(' '));
    case 'add':
      return add(Number.parseInt(rest[0], 10));
    case 'remove':
      return remove(rest[0]);
    default:
      console.log('الاستعمال: add_book.mjs search "<اسم>" | add <رقم المصدر> [خيارات] | remove <id>');
      process.exit(command ? 1 : 0);
  }
}

main().catch((e) => {
  console.error(`❌ ${e.message}`);
  process.exit(1);
});
