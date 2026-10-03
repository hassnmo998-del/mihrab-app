#!/usr/bin/env node
/**
 * ينشر محتوى تبويب «الأذكار والرقية» بلا إصدار جديد للتطبيق.
 *
 *   node tool/zad/publish.mjs             يفحص zad.json، وإن تغيّر ينشره
 *   node tool/zad/publish.mjs --dry-run   يفحص فقط
 *   node tool/zad/publish.mjs --seed-only يحدّث النسخة المضمَّنة في التطبيق فقط
 *
 * المصدر الوحيد هو zad.json: أنواع الأذكار وأذكارها، تصنيفات الأدعية وأدعيتها،
 * الأعمال ذات الأجور، قبسات السيرة. عدّله (أضف نوعاً، ذكراً، دعاءً، أو صحّح نصاً)
 * ثم شغّل هذا الملف. هو يرفع رقم المراجعة `rev` وحده حين يتغيّر المحتوى.
 *
 * ما يحدث عند المستخدم: التطبيق يسأل Supabase عن مراجعة أحدث مما عنده، فإن وُجدت
 * نزّلها مرة واحدة وحفظها على الجهاز، وتبقى تعمل بلا إنترنت. ويكتب هذا الملف أيضاً
 * lib/data/zad_seed.dart ليحملها الإصدار القادم من أول تشغيل.
 *
 * الكتابة محمية برمز الاستيراد نفسه (tool/library/.ingest-token).
 */
import fs from 'node:fs';
import path from 'node:path';
import crypto from 'node:crypto';
import { fileURLToPath } from 'node:url';

const HERE = path.dirname(fileURLToPath(import.meta.url));
const APP_ROOT = path.resolve(HERE, '../..');
const SOURCE = path.join(HERE, 'zad.json');
const SEED_FILE = path.join(APP_ROOT, 'lib', 'data', 'zad_seed.dart');

const SUPABASE_URL = process.env.SUPABASE_URL ?? 'https://mltxsmonudbtnrloqawf.supabase.co';
// مفتاح التطبيق العام نفسه (غير سرّي)؛ الصلاحية تأتي من رمز الاستيراد.
const PUBLISHABLE_KEY =
  process.env.SUPABASE_PUBLISHABLE_KEY ?? 'sb_publishable_yr45qpkrG5Fp20pAbS7NJg_DCIYQHuf';
const TABLE = 'content_packs';
const KEY = 'zad';
const SCHEMA = 1;

const args = process.argv.slice(2);
const flag = (name) => args.includes(`--${name}`);

const fail = (message) => {
  throw new Error(message);
};
const text = (obj, key, where) =>
  typeof obj[key] === 'string' && obj[key].trim() ? obj[key] : fail(`${where}: الحقل "${key}" فارغ أو مفقود`);
const list = (obj, key, where) => (Array.isArray(obj[key]) ? obj[key] : fail(`${where}: "${key}" ليست قائمة`));
const unique = (ids, what) => {
  const seen = new Set();
  for (const id of ids) seen.has(id) ? fail(`${what} مكرر: ${id}`) : seen.add(id);
};

/** القواعد نفسها التي يطبقها التطبيق (ZadContent.fromJson): ما يمرّ هنا يقبله هناك. */
function validate(pack) {
  if (pack.schema !== SCHEMA) fail(`schema يجب أن يكون ${SCHEMA}`);
  if (!Number.isInteger(pack.rev) || pack.rev < 1) fail('rev يجب أن يكون عدداً صحيحاً موجباً');

  const athkar = list(pack, 'athkar', 'الحزمة');
  if (!athkar.length) fail('لا أذكار في الحزمة');
  for (const c of athkar) {
    const where = `نوع الأذكار "${c.id}"`;
    text(c, 'id', where);
    text(c, 'title', where);
    const items = list(c, 'items', where);
    if (!items.length) fail(`${where}: بلا أذكار`);
    items.forEach((item, i) => {
      text(item, 'text', `${where} الذكر ${i + 1}`);
      if (item.count !== undefined && (!Number.isInteger(item.count) || item.count < 1)) {
        fail(`${where} الذكر ${i + 1}: عدد التكرار غير صالح`);
      }
    });
  }
  unique(athkar.map((c) => c.id), 'نوع أذكار');

  const categories = list(pack, 'duaCategories', 'الحزمة');
  categories.forEach((c) => (text(c, 'id', 'تصنيف أدعية'), text(c, 'title', `تصنيف الأدعية "${c.id}"`)));
  unique(categories.map((c) => c.id), 'تصنيف أدعية');
  const known = new Set(categories.map((c) => c.id));

  const duas = list(pack, 'duas', 'الحزمة');
  for (const d of duas) {
    const where = `الدعاء "${d.id}"`;
    for (const key of ['id', 'category', 'title', 'text']) text(d, key, where);
    if (!known.has(d.category)) fail(`${where}: تصنيف مجهول "${d.category}"`);
  }
  unique(duas.map((d) => d.id), 'دعاء');

  const rewards = list(pack, 'rewards', 'الحزمة');
  rewards.forEach((r) => ['id', 'title', 'hadith'].forEach((key) => text(r, key, `العمل "${r.id}"`)));
  unique(rewards.map((r) => r.id), 'عمل');

  const pearls = list(pack, 'pearls', 'الحزمة');
  pearls.forEach((p) => ['id', 'title', 'story'].forEach((key) => text(p, key, `القبسة "${p.id}"`)));
  unique(pearls.map((p) => p.id), 'قبسة');

  return {
    athkar: athkar.reduce((n, c) => n + c.items.length, 0),
    kinds: athkar.length,
    duas: duas.length,
    rewards: rewards.length,
    pearls: pearls.length,
  };
}

/** نص ثابت للقيمة مهما كان ترتيب مفاتيحها (jsonb في القاعدة يعيد ترتيبها). */
function canonical(value) {
  if (Array.isArray(value)) return `[${value.map(canonical).join(',')}]`;
  if (value && typeof value === 'object') {
    return `{${Object.keys(value).sort().map((k) => `${JSON.stringify(k)}:${canonical(value[k])}`).join(',')}}`;
  }
  return JSON.stringify(value);
}

/** بصمة المحتوى بلا رقم المراجعة: تتغيّر فقط حين يتغيّر النص نفسه. */
function contentHash(pack) {
  const { rev: _rev, ...content } = pack;
  return crypto.createHash('sha256').update(canonical(content)).digest('hex');
}

function writeSeed(pack) {
  const json = JSON.stringify(pack);
  if (json.includes("'''")) fail("المحتوى يحوي ''' ولا يصلح لنص Dart خام");
  fs.writeFileSync(
    SEED_FILE,
    [
      '// GENERATED — لا تعدّله يدوياً. المصدر: tool/zad/zad.json',
      '// أعد توليده بـ: node tool/zad/publish.mjs',
      '',
      '/// محتوى «الأذكار والرقية» المضمَّن في هذا الإصدار: يعمل من أول تشغيل بلا إنترنت،',
      '/// ويحلّ محلّه على الجهاز كل ما يُنشر بعده بمراجعة أحدث.',
      `const int kZadSeedRev = ${pack.rev};`,
      '',
      `const String kZadSeedJson = r'''${json}''';`,
      '',
    ].join('\n'),
  );
}

function ingestToken() {
  if (process.env.LIBRARY_INGEST_TOKEN) return process.env.LIBRARY_INGEST_TOKEN.trim();
  const file = path.resolve(HERE, '../library/.ingest-token');
  if (fs.existsSync(file)) return fs.readFileSync(file, 'utf8').trim();
  return fail('لا يوجد رمز استيراد (tool/library/.ingest-token).');
}

async function rest(query, init = {}) {
  const res = await fetch(`${SUPABASE_URL}/rest/v1/${TABLE}${query}`, {
    ...init,
    headers: { apikey: PUBLISHABLE_KEY, Authorization: `Bearer ${PUBLISHABLE_KEY}`, ...init.headers },
    signal: AbortSignal.timeout(60_000),
  });
  const body = await res.text();
  if (!res.ok) fail(`Supabase ${res.status}: ${body}`);
  return body ? JSON.parse(body) : null;
}

async function main() {
  const pack = JSON.parse(fs.readFileSync(SOURCE, 'utf8'));
  const counts = validate(pack);
  const hash = contentHash(pack);
  console.log(
    `zad.json سليم: ${counts.kinds} أنواع أذكار (${counts.athkar} ذكراً)، ${counts.duas} دعاء، ` +
      `${counts.rewards} عملاً، ${counts.pearls} قبسات.`,
  );
  if (flag('dry-run')) return;
  if (flag('seed-only')) {
    writeSeed(pack);
    console.log(`كُتبت النسخة المضمَّنة (مراجعة ${pack.rev}).`);
    return;
  }

  const [remote] = await rest(`?key=eq.${KEY}&select=rev,content_hash`);
  if (remote && remote.content_hash === hash) {
    if (pack.rev !== remote.rev) {
      pack.rev = remote.rev;
      fs.writeFileSync(SOURCE, `${JSON.stringify(pack, null, 2)}\n`);
    }
    writeSeed(pack);
    console.log(`لا تغيير: المنشور هو المراجعة ${remote.rev} نفسها.`);
    return;
  }

  if (remote) pack.rev = Math.max(remote.rev, pack.rev) + 1;
  fs.writeFileSync(SOURCE, `${JSON.stringify(pack, null, 2)}\n`);
  writeSeed(pack);

  await rest('?on_conflict=key', {
    method: 'POST',
    headers: {
      'content-type': 'application/json',
      'x-library-ingest-token': ingestToken(),
      Prefer: 'resolution=merge-duplicates,return=minimal',
    },
    body: JSON.stringify({
      key: KEY,
      rev: pack.rev,
      payload: pack,
      content_hash: hash,
      updated_at: new Date().toISOString(),
    }),
  });

  // يُقرأ كما يقرؤه التطبيق: بالمفتاح العام وحده، وبطلب «ما هو أحدث مما عندي»
  const [published] = await rest(`?key=eq.${KEY}&rev=gt.${pack.rev - 1}&select=rev,payload`);
  if (!published || published.rev !== pack.rev || contentHash(published.payload) !== hash) {
    fail('المنشور لا يطابق zad.json — لم يكتمل النشر');
  }
  console.log(`نُشرت المراجعة ${pack.rev}. تصل المستخدمين حين يفتحون التبويب، وتبقى على أجهزتهم.`);
}

main().catch((e) => {
  console.error(`✗ ${e.message}`);
  process.exit(1);
});
