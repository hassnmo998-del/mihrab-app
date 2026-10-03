#!/usr/bin/env node
/**
 * يبني ملفات أصوات الأذان من تسجيلاتها الأصلية ويرفعها إلى Supabase.
 *
 *   node tool/adhan/build_audio.mjs              يبني محلياً ويحدّث ملفات التطبيق
 *   node tool/adhan/build_audio.mjs --upload     ثم يرفع إلى الـ bucket `adhan`
 *   node tool/adhan/build_audio.mjs --only iconic_qatami,iconic_salimi
 *
 * لكل مؤذن في sounds.json:
 *   - الأذان العادي: التسجيل بلا «الصلاة خير من النوم» (يُقصّ المقطع `fajrCut` إن وُجد).
 *   - أذان الفجر: التسجيل كاملاً — فقط للتسجيلات التي فيها هذه الجملة. مؤذن له
 *     تسجيل فجر في مدخل آخر يستعيره بـ `fajrFrom` (معرّف ذلك المدخل).
 *   - معاينة قصيرة تُضمَّن في التطبيق، فتُسمع فوراً وبلا إنترنت.
 * الملفات أحادية القناة بمعدل ثابت صغير: تنزل سريعاً على الشبكات الضعيفة.
 * اسم كل ملف يحمل بصمته، فلا يختلط ملف قديم بجديد ولا تنتهي صلاحية ما حُفظ.
 *
 * يكتب: lib/services/adhan_data.dart، assets/audio/ (الأذان الافتراضي والمعاينات)،
 * android/app/src/main/res/raw/ (الأذان الافتراضي للمشغّل الأصلي).
 * يحتاج ffmpeg و ffprobe في PATH، ورمز الاستيراد للرفع (tool/library/.ingest-token).
 */
import fs from 'node:fs';
import path from 'node:path';
import crypto from 'node:crypto';
import { spawnSync } from 'node:child_process';
import { fileURLToPath } from 'node:url';

const HERE = path.dirname(fileURLToPath(import.meta.url));
const APP_ROOT = path.resolve(HERE, '../..');
const CACHE_DIR = path.join(HERE, '.cache');
const OUT_DIR = path.join(APP_ROOT, 'build', 'adhan_audio');
const ASSETS_DIR = path.join(APP_ROOT, 'assets', 'audio');
const RAW_DIR = path.join(APP_ROOT, 'android', 'app', 'src', 'main', 'res', 'raw');
const DART_FILE = path.join(APP_ROOT, 'lib', 'services', 'adhan_data.dart');

const SUPABASE_URL = process.env.SUPABASE_URL ?? 'https://mltxsmonudbtnrloqawf.supabase.co';
// مفتاح التطبيق العام نفسه (غير سرّي)؛ الصلاحية تأتي من رمز الاستيراد.
const PUBLISHABLE_KEY =
  process.env.SUPABASE_PUBLISHABLE_KEY ?? 'sb_publishable_yr45qpkrG5Fp20pAbS7NJg_DCIYQHuf';
const BUCKET = 'adhan';
const PREFIX = 'v1';
const PUBLIC_BASE = `${SUPABASE_URL}/storage/v1/object/public/${BUCKET}/${PREFIX}`;

// الصوت الذي يُضمَّن كاملاً في التطبيق ويعمل من أول تشغيل بلا إنترنت
const DEFAULT_ID = 'iconic_makkah_ali_mullah';

const CROSSFADE = 0.4; // ثوانٍ: وصل ما قبل المقطع المحذوف بما بعده داخل الصمت
const FADE_IN = 0.04;
const FADE_OUT = 0.35;
const PREVIEW_FADE_OUT = 1.0;
const PEAK_DB = -1.0;

const args = process.argv.slice(2);
const flag = (name) => args.includes(`--${name}`);
const option = (name) => {
  const i = args.indexOf(`--${name}`);
  return i >= 0 ? args[i + 1] : undefined;
};
const sleep = (ms) => new Promise((r) => setTimeout(r, ms));
const sha256 = (data) => crypto.createHash('sha256').update(data).digest('hex');

function run(cmd, cmdArgs) {
  const r = spawnSync(cmd, cmdArgs, { encoding: 'utf8', maxBuffer: 64 * 1024 * 1024 });
  if (r.error) throw new Error(`${cmd}: ${r.error.message}`);
  if (r.status !== 0) throw new Error(`${cmd} ${cmdArgs.join(' ')}\n${r.stderr}`);
  return r;
}

async function fetchSource(sound) {
  fs.mkdirSync(CACHE_DIR, { recursive: true });
  const file = path.join(CACHE_DIR, `${sound.id}.mp3`);
  if (fs.existsSync(file)) return file;
  const part = `${file}.part`;
  for (let attempt = 1; ; attempt++) {
    const have = fs.existsSync(part) ? fs.statSync(part).size : 0;
    try {
      const res = await fetch(sound.source, {
        headers: have ? { Range: `bytes=${have}-` } : {},
        signal: AbortSignal.timeout(180_000),
      });
      if (!res.ok) throw new Error(`HTTP ${res.status}`);
      const append = res.status === 206;
      const stream = fs.createWriteStream(part, { flags: append ? 'a' : 'w' });
      for await (const chunk of res.body) stream.write(chunk);
      await new Promise((r) => stream.end(r));
      const total = append
        ? Number((res.headers.get('content-range') ?? '').split('/')[1])
        : Number(res.headers.get('content-length'));
      if (total && fs.statSync(part).size !== total) throw new Error('الملف ناقص');
      fs.renameSync(part, file);
      return file;
    } catch (e) {
      if (attempt >= 12) throw new Error(`تعذّر تنزيل ${sound.id}: ${e.message}`);
      await sleep(2000 * attempt);
    }
  }
}

function probe(file) {
  const r = run('ffprobe', [
    '-v', 'error', '-select_streams', 'a:0',
    '-show_entries', 'stream=sample_rate:format=duration', '-of', 'json', file,
  ]);
  const json = JSON.parse(r.stdout);
  return { rate: Number(json.streams[0].sample_rate), duration: Number(json.format.duration) };
}

/** الرفع المطلوب (dB) ليبلغ أعلى الصوت [PEAK_DB]. لا يخفض صوتاً أبداً. */
function gainFor(file, start, end) {
  const r = run('ffmpeg', [
    '-hide_banner', '-nostats', '-ss', String(start), '-to', String(end), '-i', file,
    '-af', 'volumedetect', '-f', 'null', '-',
  ]);
  const m = /max_volume:\s*(-?[\d.]+) dB/.exec(r.stderr);
  if (!m) throw new Error(`لم يُقرأ مستوى الصوت في ${file}`);
  return Math.max(0, Math.min(12, PEAK_DB - Number(m[1])));
}

function encodeArgs(rate, preview) {
  const outRate = rate <= 24000 ? 22050 : preview || rate <= 32000 ? 32000 : 44100;
  const kbps = preview ? (outRate === 22050 ? 32 : 40) : outRate === 22050 ? 48 : outRate === 32000 ? 56 : 64;
  return [
    '-ac', '1', '-ar', String(outRate), '-c:a', 'libmp3lame', '-b:a', `${kbps}k`,
    '-map_metadata', '-1', '-id3v2_version', '0', '-write_id3v1', '0',
  ];
}

function render(source, out, { start, end, cut, gain, rate, fadeOut, preview = false }) {
  const length = cut ? cut[0] - start + (end - cut[1]) : end - start;
  const tail = `volume=${gain.toFixed(2)}dB,afade=t=in:d=${FADE_IN},afade=t=out:st=${(length - fadeOut).toFixed(3)}:d=${fadeOut}`;
  const filter = cut
    ? `[0:a]atrim=start=${start}:end=${cut[0] + CROSSFADE / 2},asetpts=PTS-STARTPTS[a];` +
      `[0:a]atrim=start=${cut[1] - CROSSFADE / 2}:end=${end},asetpts=PTS-STARTPTS[b];` +
      `[a][b]acrossfade=d=${CROSSFADE}:c1=tri:c2=tri,${tail}[out]`
    : `[0:a]atrim=start=${start}:end=${end},asetpts=PTS-STARTPTS,${tail}[out]`;
  run('ffmpeg', [
    '-hide_banner', '-loglevel', 'error', '-y', '-i', source,
    '-filter_complex', filter, '-map', '[out]', ...encodeArgs(rate, preview), out,
  ]);
  const bytes = fs.readFileSync(out);
  return { bytes, size: bytes.length, sha256: sha256(bytes), seconds: probe(out).duration };
}

function ingestToken() {
  if (process.env.LIBRARY_INGEST_TOKEN) return process.env.LIBRARY_INGEST_TOKEN.trim();
  const file = path.resolve(HERE, '../library/.ingest-token');
  if (fs.existsSync(file)) return fs.readFileSync(file, 'utf8').trim();
  throw new Error('لا يوجد رمز استيراد (tool/library/.ingest-token).');
}

async function upload(name, bytes) {
  const publicUrl = `${PUBLIC_BASE}/${name}`;
  for (let attempt = 1; ; attempt++) {
    try {
      const head = await fetch(publicUrl, { method: 'HEAD', signal: AbortSignal.timeout(30_000) });
      if (head.ok && Number(head.headers.get('content-length')) === bytes.length) return 'موجود';
      const res = await fetch(`${SUPABASE_URL}/storage/v1/object/${BUCKET}/${PREFIX}/${name}`, {
        method: 'POST',
        headers: {
          apikey: PUBLISHABLE_KEY,
          Authorization: `Bearer ${PUBLISHABLE_KEY}`,
          'x-library-ingest-token': ingestToken(),
          'content-type': 'audio/mpeg',
          'cache-control': 'max-age=31536000',
          'x-upsert': 'true',
        },
        body: bytes,
        signal: AbortSignal.timeout(600_000),
      });
      if (!res.ok) throw new Error(`HTTP ${res.status} ${await res.text()}`);
      return 'رُفع';
    } catch (e) {
      if (attempt >= 8) throw new Error(`تعذّر رفع ${name}: ${e.message}`);
      await sleep(3000 * attempt);
    }
  }
}

/** يتأكد أن الملف المنشور هو نفسه ما بُني: الحجم والبصمة. */
async function verifyPublished(name, expected) {
  const res = await fetch(`${PUBLIC_BASE}/${name}`, { signal: AbortSignal.timeout(600_000) });
  if (!res.ok) throw new Error(`${name}: HTTP ${res.status}`);
  const bytes = Buffer.from(await res.arrayBuffer());
  if (sha256(bytes) !== expected.sha256) throw new Error(`${name}: المنشور لا يطابق ما بُني`);
  if (!res.headers.get('accept-ranges')) console.warn(`  ⚠️ ${name}: الخادم لا يعلن دعم الاستكمال`);
}

const dartString = (s) => `'${String(s).replace(/\\/g, '\\\\').replace(/'/g, "\\'").replace(/\$/g, '\\$')}'`;

function writeDart(catalog, built) {
  const lines = [
    '// GENERATED — لا تعدّله يدوياً. المصدر: tool/adhan/sounds.json',
    '// أعد توليده بـ: node tool/adhan/build_audio.mjs',
    "import '../models/adhan_sound.dart';",
    '',
    '/// كتالوج أصوات الأذان. لكل مؤذن ملف الأذان العادي، وملف أذان الفجر',
    '/// («الصلاة خير من النوم») حين يحمله تسجيله.',
    'class AdhanData {',
    '  static const List<String> categories = [',
    "    'الكل',",
    ...catalog.categories.map((c) => `    ${dartString(c)},`),
    '  ];',
    '',
    '  static const List<AdhanSound> allSounds = [',
  ];
  for (const sound of catalog.sounds) {
    const b = built[sound.id];
    const fajr = sound.fajrFrom ? built[sound.fajrFrom].fajr : b.fajr;
    lines.push(
      '    AdhanSound(',
      `      id: ${dartString(sound.id)},`,
      `      title: ${dartString(sound.title)},`,
      `      category: ${dartString(sound.category)},`,
      `      muezzinOrLocation: ${dartString(sound.location)},`,
      `      audioUrl: ${dartString(`${PUBLIC_BASE}/${b.regular.name}`)},`,
      `      audioBytes: ${b.regular.size},`,
      `      audioSha256: ${dartString(b.regular.sha256)},`,
    );
    if (fajr) {
      lines.push(
        `      fajrUrl: ${dartString(`${PUBLIC_BASE}/${fajr.name}`)},`,
        `      fajrBytes: ${fajr.size},`,
        `      fajrSha256: ${dartString(fajr.sha256)},`,
      );
    }
    lines.push(`      durationSeconds: ${Math.round(b.regular.seconds)},`, '    ),');
  }
  lines.push(
    '  ];',
    '',
    '  static AdhanSound get defaultSound => allSounds.first;',
    '',
    '  static AdhanSound getById(String? id) {',
    '    if (id == null) return defaultSound;',
    '    return allSounds.firstWhere((s) => s.id == id, orElse: () => defaultSound);',
    '  }',
    '}',
    '',
  );
  fs.writeFileSync(DART_FILE, lines.join('\n'));
}

async function main() {
  const catalog = JSON.parse(fs.readFileSync(path.join(HERE, 'sounds.json'), 'utf8'));
  if (catalog.sounds[0].id !== DEFAULT_ID) throw new Error(`أول صوت يجب أن يكون ${DEFAULT_ID}`);
  const only = option('only')?.split(',');
  const manifestFile = path.join(OUT_DIR, 'manifest.json');
  fs.mkdirSync(OUT_DIR, { recursive: true });
  const built = fs.existsSync(manifestFile) ? JSON.parse(fs.readFileSync(manifestFile, 'utf8')) : {};

  for (const sound of catalog.sounds) {
    if (only && !only.includes(sound.id)) continue;
    const source = await fetchSource(sound);
    const { rate, duration } = probe(source);
    const [start, end] = [sound.trim[0], Math.min(sound.trim[1], duration)];
    const gain = gainFor(source, start, end);
    const tmp = (suffix) => path.join(OUT_DIR, `${sound.id}.${suffix}.tmp.mp3`);
    const keep = (suffix, kind, result) => {
      const name = kind ? `${sound.id}-${kind}-${result.sha256.slice(0, 8)}.mp3` : `${sound.id}.preview.mp3`;
      fs.renameSync(tmp(suffix), path.join(OUT_DIR, name));
      return { name, size: result.size, sha256: result.sha256, seconds: Number(result.seconds.toFixed(2)) };
    };

    const common = { start, end, gain, rate, fadeOut: FADE_OUT };
    const entry = {
      regular: keep('r', 'r', render(source, tmp('r'), { ...common, cut: sound.fajrCut })),
      fajr: sound.fajrCut ? keep('f', 'f', render(source, tmp('f'), common)) : null,
      preview: keep('p', null, render(source, tmp('p'), {
        ...common, end: sound.previewEnd, fadeOut: PREVIEW_FADE_OUT, preview: true,
      })),
    };
    built[sound.id] = entry;
    fs.writeFileSync(manifestFile, JSON.stringify(built, null, 1));
    const kb = (f) => `${(f.size / 1024).toFixed(0)}KB/${f.seconds.toFixed(0)}s`;
    console.log(
      `${sound.id}: +${gain.toFixed(1)}dB  عادي ${kb(entry.regular)}` +
        (entry.fajr ? `  فجر ${kb(entry.fajr)}` : '') + `  معاينة ${kb(entry.preview)}`,
    );
  }

  const missing = catalog.sounds.filter((s) => !built[s.id]).map((s) => s.id);
  if (missing.length) throw new Error(`لم تُبنَ: ${missing.join(', ')}`);
  for (const s of catalog.sounds) {
    if (!s.fajrFrom) continue;
    if (s.fajrCut) throw new Error(`${s.id}: fajrFrom و fajrCut لا يجتمعان`);
    if (!built[s.fajrFrom]?.fajr) throw new Error(`${s.id}: لا تسجيل فجر عند ${s.fajrFrom}`);
  }

  // ما يُضمَّن في التطبيق: الأذان الافتراضي بنسختيه، ومعاينة قصيرة لكل صوت آخر
  const previews = path.join(ASSETS_DIR, 'previews');
  fs.mkdirSync(previews, { recursive: true });
  fs.mkdirSync(RAW_DIR, { recursive: true });
  const copy = (name, ...targets) => {
    for (const t of targets) fs.copyFileSync(path.join(OUT_DIR, name), t);
  };
  const def = built[DEFAULT_ID];
  copy(def.regular.name, path.join(ASSETS_DIR, 'default_adhan.mp3'), path.join(RAW_DIR, 'adhan_default.mp3'));
  copy(def.fajr.name, path.join(ASSETS_DIR, 'default_adhan_fajr.mp3'), path.join(RAW_DIR, 'adhan_default_fajr.mp3'));
  for (const f of fs.readdirSync(previews)) fs.rmSync(path.join(previews, f));
  for (const sound of catalog.sounds) {
    if (sound.id !== DEFAULT_ID) copy(built[sound.id].preview.name, path.join(previews, `${sound.id}.mp3`));
  }
  writeDart(catalog, built);

  const hosted = catalog.sounds.flatMap((s) => [built[s.id].regular, built[s.id].fajr].filter(Boolean));
  const mb = (n) => (n / 1024 / 1024).toFixed(1);
  console.log(`\n${catalog.sounds.length} صوتاً، ${hosted.length} ملفاً للرفع (${mb(hosted.reduce((n, f) => n + f.size, 0))}MB)`);

  if (flag('upload')) {
    for (const f of hosted) {
      if (only && !only.some((id) => f.name.startsWith(`${id}-`))) continue;
      const state = await upload(f.name, fs.readFileSync(path.join(OUT_DIR, f.name)));
      await verifyPublished(f.name, f);
      console.log(`  ${state}: ${f.name}`);
    }
    console.log('اكتمل الرفع والتحقق.');
  } else {
    console.log('بلا رفع (أضف --upload).');
  }
}

main().catch((e) => {
  console.error(`✗ ${e.message}`);
  process.exit(1);
});
